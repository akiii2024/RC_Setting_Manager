import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/run_log.dart';
import '../models/settings_operation_result.dart';
import '../models/telemetry.dart';
import '../models/telemetry_ai.dart';
import '../providers/settings_provider.dart';
import '../services/ai_provider_client.dart';
import '../services/api_consent_service.dart';
import '../services/telemetry_analysis_service.dart';
import '../services/telemetry_ai_analysis_service.dart';
import '../services/telemetry_feature_service.dart';
import '../services/telemetry_file_service.dart';
import '../services/telemetry_palette.dart';
import '../services/telemetry_repository.dart';
import '../services/telemetry_video_controller.dart';
import '../widgets/ai_provider_indicator.dart';

class TelemetryAnalysisPage extends StatefulWidget {
  const TelemetryAnalysisPage({
    super.key,
    this.initialSession,
    this.runLog,
    this.selectionMode = false,
    this.aiAnalysisService,
  });

  final TelemetrySession? initialSession;
  final RunLog? runLog;
  final bool selectionMode;
  final TelemetryAiAnalysisService? aiAnalysisService;

  @override
  State<TelemetryAnalysisPage> createState() => _TelemetryAnalysisPageState();
}

class _TelemetryAnalysisPageState extends State<TelemetryAnalysisPage> {
  final _repository = HiveTelemetryRepository.instance;
  late final TelemetryAiAnalysisService _aiAnalysisService;
  TelemetrySession? _session;
  TelemetryFeatureReport? _featureReport;
  VideoPlayerController? _videoController;
  Timer? _playTimer;
  DateTime? _lastTick;
  int _playMillis = 0;
  double _speed = 1;
  bool _playing = false;
  bool _loading = false;
  bool _aiLoading = false;
  bool _courseEditing = false;
  int _selectedLap = 0;
  String? _error;
  String? _aiError;

  bool get _isEnglish =>
      Provider.of<SettingsProvider>(context, listen: false).isEnglish;

  String _t(String en, String ja) => _isEnglish ? en : ja;

  @override
  void initState() {
    super.initState();
    _aiAnalysisService =
        widget.aiAnalysisService ?? TelemetryAiAnalysisService();
    _session = widget.initialSession;
    _featureReport = _buildFeatureReport(_session);
    if (_session != null) {
      unawaited(_prepareVideo());
    } else if (widget.runLog?.telemetryAttachment != null) {
      unawaited(_loadAttachedSession());
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadAttachedSession() async {
    setState(() => _loading = true);
    try {
      final loaded = await _repository.loadSession(
        widget.runLog!.telemetryAttachment!.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _session = loaded;
        _featureReport = _buildFeatureReport(loaded);
        _error = loaded == null
            ? _t(
                'The telemetry file is not available on this device. Reattach a CSV or .stg file.',
                'この端末にテレメトリー本体がありません。CSVまたは.stgを再添付してください。',
              )
            : null;
      });
      await _prepareVideo();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() => _runLoading(() async {
        final session = await TelemetryFileService.pickCsv();
        if (session != null) await _replaceSession(session);
      });

  Future<void> _pickStg() => _runLoading(() async {
        final session = await TelemetryFileService.pickStg();
        if (session != null) await _replaceSession(session);
      });

  Future<void> _replaceSession(TelemetrySession session) async {
    _stop();
    await _videoController?.dispose();
    _videoController = null;
    if (!mounted) return;
    setState(() {
      _session = session;
      _featureReport = _buildFeatureReport(session);
      _playMillis = 0;
      _selectedLap = 0;
      _error = null;
      _aiError = null;
    });
    await _prepareVideo();
  }

  Future<void> _pickVideo() => _runLoading(() async {
        final video = await TelemetryFileService.pickVideo();
        if (video == null || _session == null) return;
        _session!
          ..videoFileName = video.$1
          ..videoBytes = video.$2;
        await _prepareVideo();
        if (mounted) setState(() {});
      });

  Future<void> _prepareVideo() async {
    final session = _session;
    await _videoController?.dispose();
    _videoController = null;
    if (session?.videoBytes == null || session?.videoFileName == null) return;
    try {
      final controller = await createTelemetryVideoController(
        session!.videoBytes!,
        session.videoFileName!,
      );
      await controller.initialize();
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
      await _syncVideo(force: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _t(
              'The selected video cannot be played: $error',
              '選択した動画を再生できません: $error',
            ));
      }
    }
  }

  Future<void> _runLoading(Future<void> Function() operation) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
  }

  TelemetryFeatureReport? _buildFeatureReport(TelemetrySession? session) {
    if (session == null) return null;
    try {
      return TelemetryFeatureService.build(session);
    } catch (_) {
      return null;
    }
  }

  String _aiErrorMessage(Object error) {
    if (error is AiProviderException) return error.message;
    if (error is StateError) {
      return error.message.toString();
    }
    return _t(
      'The AI driving review could not be generated. Check your connection and AI provider settings, then try again.',
      'AI走行レビューを生成できませんでした。通信とAIプロバイダー設定を確認して、再試行してください。',
    );
  }

  Future<void> _analyzeWithAi() async {
    final session = _session;
    if (session == null || _aiLoading) return;
    final report = _buildFeatureReport(session);
    final steeringQuality = report?.sensorStatus['ST(%)']?.quality;
    if (report == null ||
        report.laps.isEmpty ||
        steeringQuality != TelemetrySensorQuality.dynamic) {
      setState(() {
        _aiError = _t(
          'A changing ST(%) signal is required for AI driving analysis.',
          'AI走行分析には、変化のあるST(%)データが必要です。',
        );
      });
      return;
    }
    final consented = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.aiAndOcr,
      isEnglish: _isEnglish,
    );
    if (!consented || !mounted) return;

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _featureReport = report;
    });
    try {
      final result = await _aiAnalysisService.analyze(
        report,
        isEnglish: _isEnglish,
      );
      if (!mounted || !identical(_session, session)) return;
      session.aiAnalysis = result;
      setState(() {});
      await _persistAiAnalysis(session);
    } catch (error) {
      if (mounted) setState(() => _aiError = _aiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _persistAiAnalysis(TelemetrySession session) async {
    final runLog = widget.runLog;
    final attachment = runLog?.telemetryAttachment;
    if (runLog == null ||
        attachment == null ||
        attachment.sessionId != session.id) {
      return;
    }
    await _repository.saveSession(session);
    await _repository.saveJob(
      TelemetrySyncJob(
        sessionId: session.id,
        runLogId: runLog.id,
        operation: 'upload',
        ownerUid: attachment.ownerUid,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final updateResult = await provider.updateRunLog(
      runLog.copyWith(
        telemetryAttachment: attachment.copyWith(
          syncState: TelemetrySyncState.pendingUpload,
        ),
      ),
    );
    if (updateResult is SettingsOperationFailure<bool>) {
      throw updateResult.failure.cause;
    }
  }

  void _togglePlay() {
    if (_playing) {
      _stop();
      return;
    }
    if (_session == null) return;
    setState(() => _playing = true);
    _lastTick = DateTime.now();
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_playing || _session == null) return;
      final now = DateTime.now();
      final elapsed = now.difference(_lastTick!).inMilliseconds;
      _lastTick = now;
      final next = _playMillis + (elapsed * _speed).round();
      if (next >= _session!.durationMillis) {
        _seek(_session!.durationMillis);
        _stop();
      } else {
        setState(() => _playMillis = next);
        unawaited(_syncVideo());
      }
    });
    final video = _videoController;
    if (video != null) {
      unawaited(video.setPlaybackSpeed(_speed));
      unawaited(video.play());
    }
  }

  void _stop() {
    _playTimer?.cancel();
    _playTimer = null;
    _videoController?.pause();
    if (mounted) setState(() => _playing = false);
  }

  void _seek(int millis) {
    final max = _session?.durationMillis ?? 0;
    setState(() => _playMillis = millis.clamp(0, max));
    unawaited(_syncVideo(force: true));
  }

  Future<void> _syncVideo({bool force = false}) async {
    final controller = _videoController;
    final session = _session;
    if (controller == null ||
        session == null ||
        !controller.value.isInitialized) {
      return;
    }
    var targetMillis = _playMillis + session.videoOffsetMillis;
    if (session.videoSyncMode == 'end') {
      targetMillis = controller.value.duration.inMilliseconds -
          (session.durationMillis - _playMillis) +
          session.videoOffsetMillis;
    }
    targetMillis =
        targetMillis.clamp(0, controller.value.duration.inMilliseconds);
    final drift =
        (controller.value.position.inMilliseconds - targetMillis).abs();
    if (force || drift > 250) {
      await controller.seekTo(Duration(milliseconds: targetMillis));
    }
  }

  Future<void> _saveLocalAndAttach([RunLog? target]) async {
    final session = _session;
    if (session == null) return;
    if (widget.selectionMode) {
      Navigator.pop(context, session);
      return;
    }
    final runLog = target ?? widget.runLog;
    if (runLog == null) {
      await _chooseRunLog();
      return;
    }
    await _runLoading(() async {
      await _saveSessionWithVideoFallback(session);
      await _repository.saveJob(
        TelemetrySyncJob(
          sessionId: session.id,
          runLogId: runLog.id,
          operation: 'upload',
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      final result = await provider.updateRunLog(
        runLog.copyWith(
          telemetryAttachment: session.attachment(
            syncState: TelemetrySyncState.pendingUpload,
          ),
        ),
      );
      if (result is SettingsOperationFailure<bool>) throw result.failure.cause;
      final previous = runLog.telemetryAttachment;
      if (previous != null && previous.sessionId != session.id) {
        try {
          await _repository.deleteSession(previous.sessionId);
        } catch (_) {
          // The queued delete job below preserves cleanup responsibility.
        } finally {
          await _repository.saveJob(
            TelemetrySyncJob(
              sessionId: previous.sessionId,
              runLogId: runLog.id,
              operation: 'delete',
              ownerUid: previous.ownerUid,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Telemetry linked.', 'テレメトリーを紐付けました。'))),
        );
      }
    });
  }

  Future<void> _saveSessionWithVideoFallback(TelemetrySession session) async {
    try {
      await _repository.saveSession(session);
    } catch (_) {
      if (session.videoBytes == null || !mounted) rethrow;
      final withoutVideo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Not enough storage', '保存容量が不足しています')),
          content: Text(_t(
            'Save the analysis without the video? The video will not be discarded unless you confirm.',
            '動画を除いて分析を保存しますか？確認なしに動画を破棄することはありません。',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('Cancel', 'キャンセル')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Save without video', '動画なしで保存')),
            ),
          ],
        ),
      );
      if (withoutVideo != true) rethrow;
      session
        ..videoBytes = null
        ..videoFileName = null;
      await _repository.saveSession(session);
    }
  }

  Future<void> _chooseRunLog() async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final chosen = await showModalBottomSheet<RunLog>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              _t('Link to run log', '走行ログに紐付け'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final log in provider.runLogs)
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text('${log.car.name} / ${log.trackName}'),
                subtitle: Text(log.runAt.toLocal().toString().split('.').first),
                onTap: () => Navigator.pop(context, log),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await _saveLocalAndAttach(chosen);
  }

  Future<void> _applyBestLap() async {
    final candidate = _session?.bestLapCandidateMillis;
    final log = widget.runLog;
    if (candidate == null || log == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Update best lap?', 'ベストラップを更新しますか？')),
        content: Text(_t(
          'Replace the current value with ${formatTelemetryTime(candidate)}. The prediction is a reference value.',
          '現在値を ${formatTelemetryTime(candidate)} に置き換えます。推定値は参考値です。',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Update', '更新する')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Provider.of<SettingsProvider>(context, listen: false)
        .updateRunLog(log.copyWith(bestLapMillis: candidate));
  }

  Future<void> _detachTelemetry() async {
    final runLog = widget.runLog;
    final attachment = runLog?.telemetryAttachment;
    if (runLog == null || attachment == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Unlink telemetry?', 'テレメトリーの紐付けを解除しますか？')),
        content: Text(_t(
          'The local analysis data will be removed. Export .stg first if you need a portable copy.',
          '端末内の分析データを削除します。持ち運ぶ場合は先に.stgを書き出してください。',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('Unlink', '解除する')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runLoading(() async {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      final result = await provider.updateRunLog(
        runLog.copyWith(clearTelemetryAttachment: true),
      );
      if (result is SettingsOperationFailure<bool>) throw result.failure.cause;
      await _repository.deleteSession(attachment.sessionId);
      await _repository.saveJob(
        TelemetrySyncJob(
          sessionId: attachment.sessionId,
          runLogId: runLog.id,
          operation: 'delete',
          ownerUid: attachment.ownerUid,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _retrySync() async {
    final runLog = widget.runLog;
    final attachment = runLog?.telemetryAttachment;
    if (runLog == null || attachment == null) return;
    await _repository.saveJob(
      TelemetrySyncJob(
        sessionId: attachment.sessionId,
        runLogId: runLog.id,
        operation: 'upload',
        ownerUid: attachment.ownerUid,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    await Provider.of<SettingsProvider>(context, listen: false).updateRunLog(
      runLog.copyWith(
        telemetryAttachment: attachment.copyWith(
          syncState: TelemetrySyncState.pendingUpload,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'Sync retry was queued. Online features remain disabled.',
            '同期の再試行を予約しました。オンライン機能は現在無効です。',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? TelemetryPalette.dark
        : TelemetryPalette.light;
    return Theme(
      data: theme.copyWith(
        extensions: [palette],
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _seek(_playMillis - 5000),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _seek(_playMillis + 5000),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
              () => _seek(_playMillis - 10000),
          const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
              () => _seek(_playMillis + 10000),
          const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_t('Telemetry Analysis', 'テレメトリー分析')),
              actions: [
                if (session != null)
                  IconButton(
                    tooltip: _t('Save .stg', '.stgを保存'),
                    onPressed: () => TelemetryFileService.saveStg(session),
                    icon: const Icon(Icons.save_alt_rounded),
                  ),
                if (widget.runLog?.telemetryAttachment != null)
                  PopupMenuButton<String>(
                    tooltip: _t('Telemetry actions', 'テレメトリー操作'),
                    onSelected: (value) {
                      if (value == 'retry') _retrySync();
                      if (value == 'detach') _detachTelemetry();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'retry',
                        child: ListTile(
                          leading: const Icon(Icons.sync_rounded),
                          title: Text(_t('Retry sync', '同期を再試行')),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'detach',
                        child: ListTile(
                          leading: const Icon(Icons.link_off_rounded),
                          title: Text(_t('Unlink', '紐付け解除')),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: _loading && session == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        children: [
                          _ImportCard(
                            isEnglish: _isEnglish,
                            session: session,
                            loading: _loading,
                            onCsv: _pickCsv,
                            onStg: _pickStg,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorCard(message: _error!),
                          ],
                          if (session != null) ...[
                            const SizedBox(height: 16),
                            _buildSummary(session),
                            const SizedBox(height: 16),
                            _buildAiCoach(session),
                            const SizedBox(height: 16),
                            _buildGraph(session),
                            const SizedBox(height: 16),
                            _buildReplay(session),
                            const SizedBox(height: 16),
                            _buildVideo(session),
                            const SizedBox(height: 16),
                            _buildCourse(session),
                            const SizedBox(height: 16),
                            _buildPreview(session),
                          ],
                        ],
                      ),
                    ),
                  ),
            bottomNavigationBar: session == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _saveLocalAndAttach,
                        icon: Icon(widget.selectionMode
                            ? Icons.attach_file_rounded
                            : Icons.link_rounded),
                        label: Text(widget.selectionMode
                            ? _t('Use this telemetry', 'このテレメトリーを使用')
                            : _t('Link to run log', '走行ログに紐付け')),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );

  Widget _buildSummary(TelemetrySession session) {
    final prediction = session.prediction;
    return _section(
      _t('Session Summary', 'セッション概要'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Stat(label: 'Records', value: '${session.samples.length}'),
              _Stat(
                  label: 'Total',
                  value: formatTelemetryTime(session.durationMillis)),
              _Stat(
                  label: _t('Estimated laps', '推定LAP数'),
                  value: '${prediction.lapCount}'),
              _Stat(
                label: _t('Estimated best', '推定BEST'),
                value: prediction.bestLapMillis == null
                    ? '-'
                    : formatTelemetryTime(prediction.bestLapMillis!),
              ),
              _Stat(
                label: _t('Estimated average', '推定AVERAGE'),
                value: prediction.averageLapMillis == null
                    ? '-'
                    : formatTelemetryTime(prediction.averageLapMillis!),
              ),
            ],
          ),
          if (prediction.lapCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              prediction.lowConfidence
                  ? _t('Low-confidence estimate. Use as reference only.',
                      '信頼性が低い推定です。参考値として使用してください。')
                  : _t('Estimated from recurring steering patterns.',
                      'ステアリング操作の周期性から推定しています。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (widget.runLog != null &&
              session.bestLapCandidateMillis != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _applyBestLap,
              icon: const Icon(Icons.timer_rounded),
              label: Text(_t('Apply best lap to run log', 'ベストラップを走行ログへ反映')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiCoach(TelemetrySession session) {
    final report = _featureReport ??= _buildFeatureReport(session);
    final steeringQuality = report?.sensorStatus['ST(%)']?.quality;
    final throttleQuality = report?.sensorStatus['TH(%)']?.quality;
    final available = steeringQuality == TelemetrySensorQuality.dynamic &&
        report != null &&
        report.laps.isNotEmpty;
    final storedResult = session.aiAnalysis;
    final result = storedResult != null &&
            report != null &&
            storedResult.schemaVersion == 1 &&
            storedResult.inputFingerprint == report.inputFingerprint
        ? storedResult
        : null;

    return _section(
      _t('AI Driving Coach', 'AI走行コーチ'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiProviderIndicator(),
          const SizedBox(height: 12),
          Text(
            _t(
              'Only locally calculated lap summaries, corner features, compressed control traces, and evidence IDs are sent. The raw CSV, filename, and video are not sent.',
              '端末内で算出したラップ要約、コーナー特徴量、圧縮した操作波形、Evidence IDだけを送信します。生CSV、ファイル名、動画は送信しません。',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (throttleQuality != TelemetrySensorQuality.dynamic) ...[
            const SizedBox(height: 8),
            Text(
              _t(
                'TH(%) is unavailable or static, so the review will use steering data only.',
                'TH(%)が利用できないか一定値のため、ステアリングデータだけで分析します。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (_aiLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_t('Generating driving review…', '走行レビューを生成しています…')),
          ],
          if (_aiError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _aiError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          if (result == null && !_aiLoading) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: available ? _analyzeWithAi : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_t('Analyze driving with AI', 'AIで走行を分析')),
              ),
            ),
            if (!available) ...[
              const SizedBox(height: 8),
              Text(
                _t(
                  'A changing ST(%) signal is required.',
                  '変化のあるST(%)データが必要です。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _buildAiResult(result, report!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _aiLoading ? null : _analyzeWithAi,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t('Analyze again', '再分析する')),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _t(
              'AI output is an estimate based on control inputs and does not prove vehicle behavior. Verify suggestions with repeatable runs.',
              'AIの回答は操作入力に基づく推定で、車体挙動を断定するものではありません。同じ条件で再走行して確認してください。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResult(
    TelemetryAiResult result,
    TelemetryFeatureReport report,
  ) {
    final confidence = switch (result.confidence) {
      'high' => _t('High confidence', '確信度: 高'),
      'medium' => _t('Medium confidence', '確信度: 中'),
      _ => _t('Low confidence', '確信度: 低'),
    };
    final generated = result.generatedAt.toLocal().toString().split('.').first;
    final provider = switch (result.provider) {
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      'gemini' => 'Gemini',
      _ => result.provider,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(confidence)),
            Text(
              '$provider / ${result.model} · $generated',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(result.summary, style: Theme.of(context).textTheme.bodyLarge),
        if (result.strengthEvidenceIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          _aiTextList(
            _t('Measured strengths', '数値で確認できた強み'),
            _evidenceLabels(report, result.strengthEvidenceIds),
          ),
        ],
        for (final area in result.focusAreas) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.title,
                    style: Theme.of(context).textTheme.titleMedium),
                if (area.evidenceIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final label in _evidenceLabels(report, area.evidenceIds))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $label'),
                    ),
                ],
                if (area.inference.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${_t('Interpretation', '推定')}: ${area.inference}'),
                ],
                if (area.coachingTip.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${_t('Try', '試すこと')}: ${area.coachingTip}'),
                ],
                if (area.verification.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${_t('Verify', '確認方法')}: ${area.verification}'),
                ],
              ],
            ),
          ),
        ],
        if (result.limitations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _aiTextList(_t('Limitations', '分析上の制約'), result.limitations),
        ],
      ],
    );
  }

  Widget _aiTextList(String title, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
        ],
      );

  List<String> _evidenceLabels(
    TelemetryFeatureReport report,
    List<String> ids,
  ) {
    final byId = {
      for (final evidence in report.evidence) evidence.id: evidence
    };
    return ids
        .map((id) => byId[id])
        .whereType<TelemetryEvidence>()
        .map(_evidenceLabel)
        .toList(growable: false);
  }

  String _evidenceLabel(TelemetryEvidence evidence) {
    final metric = switch (evidence.metric) {
      'fullThrottleRatio' => _t('Full throttle', '全開率'),
      'steeringCorrections' => _t('Steering corrections', '修正舵'),
      'peakSteering' => _t('Peak steering', '最大舵角'),
      'brakeStart' => _t('Brake start from turn-in', 'ターンイン基準のブレーキ開始'),
      'throttleReapply' =>
        _t('Throttle reapply from turn-in', 'ターンイン基準のスロットル再開'),
      'fullThrottle' => _t('Full throttle from turn-in', 'ターンイン基準の全開到達'),
      _ => evidence.metric,
    };
    final target = [
      if (evidence.lap != null) 'Lap ${evidence.lap}',
      if (evidence.corner != null) 'Corner ${evidence.corner}',
    ].join(' / ');
    final value = _formatEvidenceValue(evidence.value, evidence.unit);
    final reference = evidence.referenceValue;
    final referenceText = reference == null
        ? ''
        : ' (${_t('reference', '基準')}: ${_formatEvidenceValue(reference, evidence.unit)})';
    final difference = evidence.difference;
    final differenceText = difference == null
        ? ''
        : ' [${_t('difference', '差')}: ${_formatEvidenceDifference(difference, evidence.unit)}]';
    return '${target.isEmpty ? '' : '$target · '}$metric: $value$referenceText$differenceText';
  }

  String _formatEvidenceValue(double value, String unit) {
    if (unit == 'ratio') return '${(value * 100).toStringAsFixed(1)}%';
    if (unit == 'count') return value.round().toString();
    return '${value.toStringAsFixed(1)}$unit';
  }

  String _formatEvidenceDifference(double value, String unit) {
    final sign = value > 0 ? '+' : '';
    if (unit == 'ratio') {
      return '$sign${(value * 100).toStringAsFixed(1)}pt';
    }
    if (unit == 'count') return '$sign${value.round()}';
    return '$sign${value.toStringAsFixed(1)}$unit';
  }

  Widget _buildGraph(TelemetrySession session) {
    final metrics = session.metrics;
    final windowMillis = session.viewWindowSeconds <= 0
        ? session.durationMillis
        : (session.viewWindowSeconds * 1000).round();
    final maxTime =
        math.max(_playMillis, math.min(windowMillis, session.durationMillis));
    final minTime = math.max(0, maxTime - windowMillis);
    return _section(
      _t('Telemetry Graph', 'テレメトリーグラフ'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                FilterChip(
                  label: Text(metric),
                  selected: session.selectedMetrics.contains(metric),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        session.selectedMetrics = [
                          ...session.selectedMetrics,
                          metric
                        ];
                      } else if (session.selectedMetrics.length > 1) {
                        session.selectedMetrics = session.selectedMetrics
                            .where((value) => value != metric)
                            .toList();
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => session.viewWindowSeconds = 0),
                child: Text(_t('Full', '全体')),
              ),
              if (session.prediction.detectedPeriodMillis > 0)
                OutlinedButton(
                  onPressed: () => setState(() => session.viewWindowSeconds =
                      session.prediction.detectedPeriodMillis / 1000),
                  child: Text(_t('Estimated lap', '推定1周')),
                ),
              DropdownButton<double>(
                value: const [0.0, 10.0, 30.0, 60.0, 120.0]
                        .contains(session.viewWindowSeconds)
                    ? session.viewWindowSeconds
                    : 0,
                items: [0.0, 10.0, 30.0, 60.0, 120.0]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value == 0
                              ? _t('All', '全体')
                              : '${value.round()} s'),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => session.viewWindowSeconds = value ?? 0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            width: double.infinity,
            child: CustomPaint(
              painter: _TelemetryChartPainter(
                session: session,
                minTime: minTime,
                maxTime: maxTime,
                playMillis: _playMillis,
                colors: TelemetryPalette.of(context),
                scheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: session.selectedMetrics.indexed.map((entry) {
              final color = TelemetryPalette.of(context).series[
                  entry.$1 % TelemetryPalette.of(context).series.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.horizontal_rule_rounded, color: color),
                  Text(entry.$2),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplay(TelemetrySession session) {
    final st = TelemetryAnalysisService.valueAtTime(
        session.samples, 'ST(%)', _playMillis);
    final th = TelemetryAnalysisService.valueAtTime(
        session.samples, 'TH(%)', _playMillis);
    TelemetryLap? currentLap;
    for (final lap in session.prediction.laps) {
      if (_playMillis >= lap.startMillis && _playMillis <= lap.endMillis) {
        currentLap = lap;
        break;
      }
    }
    final lapProgress = currentLap == null || currentLap.durationMillis <= 0
        ? null
        : ((_playMillis - currentLap.startMillis) / currentLap.durationMillis)
            .clamp(0, 1);
    return _section(
      _t('Replay', 'リプレイ'),
      Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _togglePlay,
                icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_playing ? _t('Pause', '一時停止') : _t('Play', '再生')),
              ),
              for (final seconds in [-10, -5, 5, 10])
                OutlinedButton(
                  onPressed: () => _seek(_playMillis + seconds * 1000),
                  child: Text('${seconds > 0 ? '+' : ''}$seconds s'),
                ),
              DropdownButton<double>(
                value: _speed,
                items: [0.5, 1.0, 2.0, 4.0]
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text('${value}x')))
                    .toList(),
                onChanged: (value) {
                  setState(() => _speed = value ?? 1);
                  _videoController?.setPlaybackSpeed(_speed);
                },
              ),
            ],
          ),
          Slider(
            min: 0,
            max: math.max(1, session.durationMillis).toDouble(),
            value: _playMillis
                .clamp(0, math.max(1, session.durationMillis))
                .toDouble(),
            label: formatTelemetryTime(_playMillis),
            onChanged: (value) => _seek(value.round()),
          ),
          Text(formatTelemetryTime(_playMillis)),
          if (currentLap != null && lapProgress != null) ...[
            const SizedBox(height: 4),
            Text(_t(
              'Estimated lap ${currentLap.number} / ${(lapProgress * 100).round()}%',
              '推定LAP ${currentLap.number} / ${(lapProgress * 100).round()}%',
            )),
          ],
          const SizedBox(height: 12),
          _InputBar(label: 'ST(%)', value: st, split: true),
          const SizedBox(height: 12),
          _InputBar(label: 'TH(%)', value: th, split: true),
        ],
      ),
    );
  }

  Widget _buildVideo(TelemetrySession session) => _section(
        _t('Synchronized Video', '動画同期再生'),
        Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_file_rounded),
                  label: Text(_t('Choose video', '動画を選択')),
                ),
                if (session.videoBytes != null) ...[
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'start', label: Text(_t('Start', '開始基準'))),
                      ButtonSegment(
                          value: 'end', label: Text(_t('End', '終了基準'))),
                    ],
                    selected: {session.videoSyncMode},
                    onSelectionChanged: (value) {
                      setState(() => session.videoSyncMode = value.first);
                      _syncVideo(force: true);
                    },
                  ),
                  for (final delta in [-1000, -100, 100, 1000])
                    OutlinedButton(
                      onPressed: () {
                        setState(() => session.videoOffsetMillis += delta);
                        _syncVideo(force: true);
                      },
                      child: Text('${delta > 0 ? '+' : ''}${delta / 1000}s'),
                    ),
                  Text('${session.videoOffsetMillis} ms'),
                ],
              ],
            ),
            if (_videoController case final controller?) ...[
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(_t(
                'Video remains on this device and is included only when exporting .stg.',
                '動画はこの端末に保持し、.stg書き出し時だけ同梱します。',
              )),
            ],
          ],
        ),
      );

  Widget _buildCourse(TelemetrySession session) {
    final generated = TelemetryAnalysisService.buildCourse(session);
    final points = session.editedCoursePoints ?? generated;
    return _section(
      _t('Estimated Course', '推定コースマップ'),
      Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: points.isEmpty
                    ? null
                    : () => setState(() {
                          if (!_courseEditing) {
                            session.editedCoursePoints = [...points];
                          }
                          _courseEditing = !_courseEditing;
                        }),
                icon: Icon(
                    _courseEditing ? Icons.done_rounded : Icons.edit_rounded),
                label: Text(
                    _courseEditing ? _t('Done', '編集終了') : _t('Edit', '編集')),
              ),
              OutlinedButton(
                onPressed: session.editedCoursePoints == null
                    ? null
                    : () => setState(() {
                          session.editedCoursePoints = null;
                          _courseEditing = false;
                        }),
                child: Text(_t('Reset', 'リセット')),
              ),
              OutlinedButton.icon(
                onPressed: points.isEmpty
                    ? null
                    : () => TelemetryFileService.saveCourse(
                          points,
                          session.prediction.detectedPeriodMillis,
                        ),
                icon: const Icon(Icons.save_alt_rounded),
                label: Text(_t('Save JSON', 'JSON保存')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final loaded = await TelemetryFileService.pickCourse();
                  if (loaded != null && mounted) {
                    setState(() => session.editedCoursePoints = loaded);
                  }
                },
                icon: const Icon(Icons.file_open_rounded),
                label: Text(_t('Load JSON', 'JSON読込')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _NumberControl(
                label: _t('Speed', '速度'),
                value: session.courseOptions.baseSpeed,
                min: 0.5,
                max: 10,
                onChanged: (value) => setState(() => session.courseOptions =
                    session.courseOptions.copyWith(baseSpeed: value)),
              ),
              _NumberControl(
                label: _t('Steering', '切れ角'),
                value: session.courseOptions.steerGain,
                min: 0.2,
                max: 3,
                onChanged: (value) => setState(() => session.courseOptions =
                    session.courseOptions.copyWith(steerGain: value)),
              ),
              _NumberControl(
                label: 'Gamma',
                value: session.courseOptions.steerGamma,
                min: 0.5,
                max: 2.5,
                onChanged: (value) => setState(() => session.courseOptions =
                    session.courseOptions.copyWith(steerGamma: value)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Text(_t('A periodic ST(%) pattern is required.',
                '周期を検出できるST(%)データが必要です。'))
          else
            SizedBox(
              height: 340,
              width: double.infinity,
              child: _CourseEditor(
                points: points,
                playMillis: _playMillis,
                durationMillis: session.prediction.detectedPeriodMillis,
                editing: _courseEditing,
                color: TelemetryPalette.of(context).course,
                onChanged: (next) =>
                    setState(() => session.editedCoursePoints = next),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(TelemetrySession session) {
    final lapLabels = <String>[];
    for (final sample in session.samples) {
      final label = sample['LAP'];
      if (label.isNotEmpty && !lapLabels.contains(label)) lapLabels.add(label);
    }
    final selected = lapLabels.isEmpty
        ? session.samples.take(50).toList()
        : session.samples
            .where((sample) =>
                sample['LAP'] ==
                lapLabels[_selectedLap.clamp(0, lapLabels.length - 1)])
            .take(200)
            .toList();
    return _section(
      _t('Data Preview', 'データプレビュー'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lapLabels.isNotEmpty)
            DropdownButton<int>(
              value: _selectedLap.clamp(0, lapLabels.length - 1),
              items: lapLabels.indexed
                  .map((entry) =>
                      DropdownMenuItem(value: entry.$1, child: Text(entry.$2)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedLap = value ?? 0),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: session.columns
                  .map((column) => DataColumn(label: Text(column)))
                  .toList(),
              rows: selected
                  .map((sample) => DataRow(
                        cells: session.columns
                            .map((column) => DataCell(Text(sample[column])))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.isEnglish,
    required this.session,
    required this.loading,
    required this.onCsv,
    required this.onStg,
  });

  final bool isEnglish;
  final TelemetrySession? session;
  final bool loading;
  final VoidCallback onCsv;
  final VoidCallback onStg;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnglish ? 'Load telemetry' : 'テレメトリー読込',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(session?.csvFileName ??
                  (isEnglish
                      ? 'Select a SANWA CSV or .stg session.'
                      : 'SANWA CSVまたは.stgセッションを選択してください。')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: loading ? null : onCsv,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(isEnglish ? 'Load CSV' : 'CSVを読み込む'),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : onStg,
                    icon: const Icon(Icons.folder_zip_rounded),
                    label: Text(isEnglish ? 'Load .stg' : '.stgを読み込む'),
                  ),
                  if (loading) const CircularProgressIndicator(),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 132),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.label, required this.value, required this.split});
  final String label;
  final double value;
  final bool split;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(-1.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final brakeColor = TelemetryPalette.of(context).brake;
    return Row(children: [
      SizedBox(width: 58, child: Text(label)),
      Expanded(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
                height: 18,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                )),
            if (split)
              Row(
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: normalized < 0 ? normalized.abs() : 0,
                      alignment: Alignment.centerRight,
                      child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          )),
                    ),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: normalized > 0 ? normalized : 0,
                      alignment: Alignment.centerLeft,
                      child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          )),
                    ),
                  ),
                ],
              )
            else
              FractionallySizedBox(
                widthFactor: normalized.abs(),
                alignment: normalized < 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: normalized < 0 ? brakeColor : scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    )),
              ),
            if (split)
              Container(width: 2, height: 24, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
      SizedBox(
          width: 64,
          child: Text(value.toStringAsFixed(0), textAlign: TextAlign.end)),
    ]);
  }
}

class _NumberControl extends StatelessWidget {
  const _NumberControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label ${value.toStringAsFixed(2)}'),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ],
        ),
      );
}

class _TelemetryChartPainter extends CustomPainter {
  _TelemetryChartPainter({
    required this.session,
    required this.minTime,
    required this.maxTime,
    required this.playMillis,
    required this.colors,
    required this.scheme,
  });
  final TelemetrySession session;
  final int minTime;
  final int maxTime;
  final int playMillis;
  final TelemetryPalette colors;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(
        8, 8, math.max(1, size.width - 16), math.max(1, size.height - 32));
    final grid = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.5);
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    final visible = session.samples
        .where((sample) =>
            sample.recordMillis >= minTime && sample.recordMillis <= maxTime)
        .toList();
    if (visible.length < 2) return;
    for (final (metricIndex, metric) in session.selectedMetrics.indexed) {
      final values = visible.map((sample) => sample.numeric(metric)).toList();
      final low = values.reduce(math.min);
      final high = values.reduce(math.max);
      final span = math.max(1e-9, high - low);
      final path = Path();
      for (var index = 0; index < visible.length; index++) {
        final x = chart.left +
            (maxTime - visible[index].recordMillis) /
                math.max(1, maxTime - minTime) *
                chart.width;
        final y = chart.bottom - (values[index] - low) / span * chart.height;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors.series[metricIndex % colors.series.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
    final playX = chart.left +
        (maxTime - playMillis.clamp(minTime, maxTime)) /
            math.max(1, maxTime - minTime) *
            chart.width;
    canvas.drawLine(
        Offset(playX, chart.top),
        Offset(playX, chart.bottom),
        Paint()
          ..color = colors.playhead
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _TelemetryChartPainter oldDelegate) => true;
}

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({
    required this.points,
    required this.playMillis,
    required this.durationMillis,
    required this.editing,
    required this.color,
    required this.onChanged,
  });
  final List<CoursePoint> points;
  final int playMillis;
  final int durationMillis;
  final bool editing;
  final Color color;
  final ValueChanged<List<CoursePoint>> onChanged;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  int? _dragIndex;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final transform = _CourseTransform(widget.points, size);
        return GestureDetector(
          onPanStart: widget.editing
              ? (details) =>
                  _dragIndex = transform.nearest(details.localPosition)
              : null,
          onPanUpdate: widget.editing
              ? (details) {
                  final index = _dragIndex;
                  if (index == null) return;
                  final point = transform.fromScreen(details.localPosition);
                  final next = [...widget.points];
                  next[index] = next[index].copyWith(x: point.dx, y: point.dy);
                  widget.onChanged(next);
                }
              : null,
          onPanEnd: (_) => _dragIndex = null,
          child: CustomPaint(
            size: size,
            painter: _CoursePainter(
              points: widget.points,
              playMillis: widget.playMillis,
              durationMillis: widget.durationMillis,
              editing: widget.editing,
              color: widget.color,
              scheme: Theme.of(context).colorScheme,
            ),
          ),
        );
      });
}

class _CourseTransform {
  _CourseTransform(this.points, this.size) {
    minX = points.map((p) => p.x).reduce(math.min);
    maxX = points.map((p) => p.x).reduce(math.max);
    minY = points.map((p) => p.y).reduce(math.min);
    maxY = points.map((p) => p.y).reduce(math.max);
    scale = math.min((size.width - 48) / math.max(1, maxX - minX),
        (size.height - 48) / math.max(1, maxY - minY));
  }
  final List<CoursePoint> points;
  final Size size;
  late final double minX, maxX, minY, maxY, scale;
  Offset toScreen(CoursePoint point) => Offset(
        24 + (point.x - minX) * scale,
        24 + (point.y - minY) * scale,
      );
  Offset fromScreen(Offset point) => Offset(
        minX + (point.dx - 24) / scale,
        minY + (point.dy - 24) / scale,
      );
  int nearest(Offset position) {
    var best = 0;
    var distance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final current = (toScreen(points[index]) - position).distanceSquared;
      if (current < distance) {
        distance = current;
        best = index;
      }
    }
    return best;
  }
}

class _CoursePainter extends CustomPainter {
  _CoursePainter(
      {required this.points,
      required this.playMillis,
      required this.durationMillis,
      required this.editing,
      required this.color,
      required this.scheme});
  final List<CoursePoint> points;
  final int playMillis;
  final int durationMillis;
  final bool editing;
  final Color color;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final transform = _CourseTransform(points, size);
    final path = Path();
    for (final (index, point) in points.indexed) {
      final screen = transform.toScreen(point);
      index == 0
          ? path.moveTo(screen.dx, screen.dy)
          : path.lineTo(screen.dx, screen.dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        transform.toScreen(points.first), 7, Paint()..color = scheme.tertiary);
    if (editing) {
      final step = math.max(1, points.length ~/ 24);
      for (var index = 0; index < points.length; index += step) {
        canvas.drawCircle(transform.toScreen(points[index]), 5,
            Paint()..color = scheme.primary);
      }
    } else {
      final wrapped = durationMillis <= 0 ? 0 : playMillis % durationMillis;
      final point = points.reduce((a, b) =>
          (a.timeMillis - wrapped).abs() < (b.timeMillis - wrapped).abs()
              ? a
              : b);
      canvas.drawCircle(
          transform.toScreen(point), 8, Paint()..color = scheme.error);
    }
  }

  @override
  bool shouldRepaint(covariant _CoursePainter oldDelegate) => true;
}
