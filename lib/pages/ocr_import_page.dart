import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/car_settings_definitions.dart';
import '../models/car.dart';
import '../models/ocr.dart';
import '../providers/settings_provider.dart';
import '../services/ai_configuration_service.dart';
import '../services/api_consent_service.dart';
import '../services/ocr_service.dart';
import '../utils/app_logger.dart';
import '../widgets/ai_provider_indicator.dart';
import 'ai_provider_settings_page.dart';

class OCRImportPage extends StatefulWidget {
  const OCRImportPage({
    super.key,
    required this.car,
    required this.currentSettings,
    this.ocrService,
  });

  final Car car;
  final Map<String, dynamic> currentSettings;
  final OCRService? ocrService;

  @override
  State<OCRImportPage> createState() => _OCRImportPageState();
}

class _OCRImportPageState extends State<OCRImportPage> {
  OCRService? _ocrService;
  late final bool _ownsService;
  dynamic _selectedImage;
  OcrExtractionResult? _result;
  final Set<String> _selectedKeys = {};
  Key _providerIndicatorKey = UniqueKey();
  bool _isProcessing = false;
  String? _serviceInitError;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.ocrService == null;
    try {
      _ocrService = widget.ocrService ?? OCRService();
    } catch (error, stackTrace) {
      debugLog('OCR service initialization failed: $error');
      debugLog('Stack trace: $stackTrace');
      _serviceInitError = 'OCRサービスを初期化できませんでした。アプリを再起動してください。';
    }
  }

  @override
  void dispose() {
    if (_ownsService) _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final service = _ocrService;
    if (service == null) {
      _showMessage(_serviceInitError ?? 'OCRサービスを利用できません。');
      return;
    }
    if (!await _ensureAiConfigured() || !mounted) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.aiAndOcr,
      isEnglish: settingsProvider.isEnglish,
    );
    if (!consentGranted || !mounted) return;

    if (source == ImageSource.camera && !kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showMessage('カメラの権限が必要です。');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _result = null;
      _selectedKeys.clear();
    });
    try {
      final image = source == ImageSource.camera
          ? await service.pickImageFromCamera()
          : await service.pickImageFromGallery();
      if (!mounted) return;
      if (image == null) {
        _showMessage('画像が選択されませんでした。');
        return;
      }
      setState(() => _selectedImage = image);
      await _processImage(image);
    } on UnsupportedError catch (error) {
      if (mounted) _showMessage(error.message?.toString() ?? error.toString());
    } catch (error, stackTrace) {
      debugLog('Image selection failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) _showMessage('画像の取得に失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(dynamic image) async {
    final service = _ocrService;
    final definition = getCarSettingDefinition(widget.car.id);
    if (service == null || definition == null) {
      _showMessage('この車種の設定定義が見つかりません。');
      return;
    }
    try {
      final result = await service.extractSettingsFromImage(
        image,
        carId: widget.car.id,
        carName: widget.car.name,
        settingDefinitions: definition.availableSettings,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _selectedKeys
          ..clear()
          ..addAll(
            result.modelMismatch
                ? const <String>[]
                : result.candidates
                    .where((candidate) => candidate.isInitiallySelected)
                    .map((candidate) => candidate.key),
          );
      });
      if (result.candidates.isEmpty) {
        _showMessage('入力済みの設定値を認識できませんでした。');
      }
    } on OcrExtractionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error, stackTrace) {
      debugLog('Structured OCR failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        _showMessage('画像の解析に失敗しました。画像の向きや鮮明さを確認してください。');
      }
    }
  }

  Future<bool> _ensureAiConfigured() async {
    try {
      if (await AiConfigurationService().isReady) return true;
    } catch (_) {
      // The same setup guidance is shown when secure storage is unavailable.
    }
    if (!mounted) return false;
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isEnglish ? 'AI setup required' : 'AI設定が必要です'),
            content: Text(
              isEnglish
                  ? 'Select standard Gemini or configure an OpenAI, Anthropic, or Gemini API key before using image OCR.'
                  : '画像OCRを使う前に、標準Geminiを選択するか、OpenAI・Anthropic・GeminiのAPIキーを設定してください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isEnglish ? 'Open settings' : '設定を開く'),
              ),
            ],
          ),
        ) ??
        false;
    if (!openSettings || !mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AiProviderSettingsPage(isEnglish: isEnglish),
      ),
    );
    if (!mounted) return false;
    setState(() => _providerIndicatorKey = UniqueKey());
    try {
      return await AiConfigurationService().isReady;
    } catch (_) {
      return false;
    }
  }

  Future<void> _importSettings() async {
    final result = _result;
    if (result == null || result.modelMismatch) return;
    final imported = result.selectedSettings(_selectedKeys);
    if (imported.isEmpty) {
      _showMessage('取り込む候補を選択してください。');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('セッティングのインポート'),
            content: Text(
              '${imported.length}個の設定を現在のセッティングへ上書きします。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('インポート'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(<String, dynamic>{
      ...widget.currentSettings,
      ...imported,
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Widget _buildImagePreview() {
    final image = _selectedImage;
    if (image == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: kIsWeb
              ? Image.network(
                  image.path as String,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Text('画像を表示できません')),
                )
              : Image.file(image as File, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }

  Widget _buildResult(OcrExtractionResult result) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('読み取り候補', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          result.detectedModel.trim().isEmpty
              ? '検出車種: 判定できませんでした'
              : '検出車種: ${result.detectedModel}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (result.modelMismatch) ...[
          _buildNotice(
            icon: Icons.error_outline_rounded,
            text:
                '画像は${result.detectedModel}のシートと判定されました。現在選択中の${widget.car.name}には取り込めません。正しい車種からやり直してください。',
            background: colors.errorContainer,
            foreground: colors.onErrorContainer,
          ),
          const SizedBox(height: 12),
        ],
        for (final warning in result.warnings) ...[
          _buildNotice(
            icon: Icons.warning_amber_rounded,
            text: warning,
            background: colors.tertiaryContainer,
            foreground: colors.onTertiaryContainer,
          ),
          const SizedBox(height: 8),
        ],
        if (result.candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '入力済みの設定値を認識できませんでした。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          )
        else
          OcrCandidateReviewList(
            result: result,
            selectedKeys: _selectedKeys,
            onSelectionChanged: (key, selected) {
              setState(() {
                if (selected) {
                  _selectedKeys.add(key);
                } else {
                  _selectedKeys.remove(key);
                }
              });
            },
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: result.modelMismatch || _selectedKeys.isEmpty
              ? null
              : _importSettings,
          icon: const Icon(Icons.download_rounded),
          label: Text('選択した設定をインポート (${_selectedKeys.length}個)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('OCRでセッティングをインポート')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_serviceInitError != null) ...[
                  _buildNotice(
                    icon: Icons.error_outline_rounded,
                    text: _serviceInitError!,
                    background: colors.errorContainer,
                    foreground: colors.onErrorContainer,
                  ),
                  const SizedBox(height: 16),
                ],
                if (kIsWeb) ...[
                  _buildNotice(
                    icon: Icons.info_outline_rounded,
                    text: 'Web版ではギャラリーからの画像選択を推奨します。',
                    background: colors.secondaryContainer,
                    foreground: colors.onSecondaryContainer,
                  ),
                  const SizedBox(height: 16),
                ],
                AiProviderIndicator(key: _providerIndicatorKey),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _isProcessing || _ocrService == null
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(kIsWeb ? 'カメラを起動' : 'カメラで撮影'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProcessing || _ocrService == null
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('ギャラリーから選択'),
                    ),
                  ],
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 20),
                  _buildImagePreview(),
                ],
                if (_isProcessing) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(
                    'シートの文字と選択マークを解析しています…',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (_result case final result?) ...[
                  const SizedBox(height: 24),
                  _buildResult(result),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OcrCandidateReviewList extends StatelessWidget {
  const OcrCandidateReviewList({
    super.key,
    required this.result,
    required this.selectedKeys,
    required this.onSelectionChanged,
  });

  final OcrExtractionResult result;
  final Set<String> selectedKeys;
  final void Function(String key, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: result.candidates.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colors.outlineVariant,
        ),
        itemBuilder: (context, index) => _candidateTile(
          context,
          result.candidates[index],
        ),
      ),
    );
  }

  Widget _candidateTile(BuildContext context, OcrCandidate candidate) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = candidate.isValid && !result.modelMismatch;
    final confidenceLabel = switch (candidate.confidence) {
      OcrConfidence.high => '確信度 高',
      OcrConfidence.medium => '確信度 中',
      OcrConfidence.low => '確信度 低',
    };
    final detail = candidate.rejectionReason ??
        (candidate.evidence.isEmpty
            ? confidenceLabel
            : '$confidenceLabel · ${candidate.evidence}');
    return CheckboxListTile(
      value: enabled && selectedKeys.contains(candidate.key),
      onChanged: enabled
          ? (checked) => onSelectionChanged(candidate.key, checked == true)
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(candidate.label),
      subtitle: Text(
        detail,
        style: theme.textTheme.bodySmall?.copyWith(
          color: candidate.rejectionReason == null
              ? colors.onSurfaceVariant
              : colors.error,
        ),
      ),
      secondary: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          displayValue(candidate),
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }

  static String displayValue(OcrCandidate candidate) {
    final value = candidate.value;
    if (value is List) {
      final positions = <String>[];
      for (final point in value) {
        if (point is Map && point['row'] is int && point['col'] is int) {
          positions.add('${point['row'] + 1}行${point['col'] + 1}列');
        }
      }
      return positions.isEmpty ? '位置不明' : positions.join(', ');
    }
    if (value != null) return value.toString();
    if (candidate.rawValue.isNotEmpty) return candidate.rawValue;
    if (candidate.points.isNotEmpty) {
      return candidate.points
          .map((point) => '${point.row + 1}行${point.col + 1}列')
          .join(', ');
    }
    return '—';
  }
}
