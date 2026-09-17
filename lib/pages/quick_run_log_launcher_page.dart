import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/run_log.dart';
import '../models/settings_operation_result.dart';
import '../models/telemetry.dart';
import '../providers/settings_provider.dart';
import '../services/telemetry_repository.dart';
import '../utils/settings_operation_feedback.dart';
import 'quick_run_log_page.dart';
import 'telemetry_analysis_page.dart';

/// Adds the optional telemetry step without changing the existing run-log form.
class QuickRunLogLauncherPage extends StatefulWidget {
  const QuickRunLogLauncherPage({super.key});

  @override
  State<QuickRunLogLauncherPage> createState() =>
      _QuickRunLogLauncherPageState();
}

class _QuickRunLogLauncherPageState extends State<QuickRunLogLauncherPage> {
  TelemetrySession? _session;
  bool _saving = false;

  bool get _isEnglish =>
      Provider.of<SettingsProvider>(context, listen: false).isEnglish;

  String _t(String en, String ja) => _isEnglish ? en : ja;

  Future<void> _selectTelemetry() async {
    final session = await Navigator.of(context).push<TelemetrySession>(
      MaterialPageRoute<TelemetrySession>(
        builder: (_) => TelemetryAnalysisPage(
          initialSession: _session,
          selectionMode: true,
        ),
      ),
    );
    if (session != null && mounted) setState(() => _session = session);
  }

  Future<void> _openRunLog({required bool withTelemetry}) async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final beforeIds = provider.runLogs.map((log) => log.id).toSet();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QuickRunLogPage()),
    );
    if (!mounted) return;
    final created = provider.runLogs
        .where((log) => !beforeIds.contains(log.id))
        .cast<RunLog?>()
        .firstOrNull;
    if (created == null) return;
    if (withTelemetry && _session != null) {
      await _attachTelemetry(provider, created, _session!);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _attachTelemetry(
    SettingsProvider provider,
    RunLog runLog,
    TelemetrySession session,
  ) async {
    setState(() => _saving = true);
    try {
      final repository = HiveTelemetryRepository.instance;
      try {
        await repository.saveSession(session);
      } catch (_) {
        if (session.videoBytes == null || !mounted) rethrow;
        final saveWithoutVideo = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_t('Not enough storage', '保存容量が不足しています')),
            content: Text(_t(
              'Save the run telemetry without its video?',
              '動画を除いて走行テレメトリーを保存しますか？',
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
        if (saveWithoutVideo != true) rethrow;
        session
          ..videoBytes = null
          ..videoFileName = null;
        await repository.saveSession(session);
      }
      await repository.saveJob(
        TelemetrySyncJob(
          sessionId: session.id,
          runLogId: runLog.id,
          operation: 'upload',
          createdAt: DateTime.now(),
        ),
      );
      final attachResult = await provider.updateRunLog(
        runLog.copyWith(
          telemetryAttachment: session.attachment(
            syncState: TelemetrySyncState.pendingUpload,
          ),
        ),
      );
      if (!mounted ||
          !handleSettingsOperationResult(
            context,
            attachResult,
            isEnglish: _isEnglish,
          )) {
        return;
      }
      final candidate = session.bestLapCandidateMillis;
      if (candidate != null) {
        await _confirmBestLap(provider, runLog, session, candidate);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmBestLap(
    SettingsProvider provider,
    RunLog runLog,
    TelemetrySession session,
    int candidate,
  ) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Use predicted best lap?', '推定ベストラップを反映しますか？')),
        content: Text(_t(
          '${formatTelemetryTime(candidate)} is a reference value. The saved value will change only if you confirm.',
          '${formatTelemetryTime(candidate)} は参考値です。確認した場合だけ保存済みの値を変更します。',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Keep current', '現在値を維持')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('Apply', '反映する')),
          ),
        ],
      ),
    );
    if (apply != true || !mounted) return;
    final current = provider.runLogs.firstWhere(
      (item) => item.id == runLog.id,
      orElse: () => runLog.copyWith(
        telemetryAttachment: session.attachment(
          syncState: TelemetrySyncState.pendingUpload,
        ),
      ),
    );
    final result = await provider.updateRunLog(
      current.copyWith(bestLapMillis: candidate),
    );
    if (mounted && result is SettingsOperationFailure<bool>) {
      handleSettingsOperationResult(
        context,
        result,
        isEnglish: _isEnglish,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: Text(_t('New run log', '走行メモを作成'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Telemetry attachment', 'テレメトリー添付'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_t(
                        'Optional. Import a SANWA CSV or .stg to preview the analysis before entering the run memo.',
                        '任意です。SANWA CSVまたは.stgを読み込み、走行メモ入力前に解析概要を確認できます。',
                      )),
                      if (session != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          session.csvFileName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(_t(
                          '${session.samples.length} samples / ${formatTelemetryTime(session.durationMillis)} / ${session.prediction.lapCount} predicted laps',
                          '${session.samples.length}サンプル / ${formatTelemetryTime(session.durationMillis)} / 推定${session.prediction.lapCount}周',
                        )),
                        if (session.bestLapCandidateMillis case final best?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_t(
                              'Predicted best: ${formatTelemetryTime(best)} (reference)',
                              '推定ベスト: ${formatTelemetryTime(best)}（参考値）',
                            )),
                          ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _selectTelemetry,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(session == null
                            ? _t('Attach telemetry', 'テレメトリーを添付')
                            : _t('Replace attachment', '添付を差し替え')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _openRunLog(withTelemetry: session != null),
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(_t('Continue to run memo', '走行メモ入力へ進む')),
              ),
              TextButton(
                onPressed:
                    _saving ? null : () => _openRunLog(withTelemetry: false),
                child: Text(_t('Continue without telemetry', '添付せずに進む')),
              ),
              if (_saving) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
