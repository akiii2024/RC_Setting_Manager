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
import '../services/ai_provider_client.dart';
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
  String _serviceInitMessage(bool isEnglish) => isEnglish
      ? 'Could not initialize OCR. Restart the app and try again.'
      : 'OCRサービスを初期化できませんでした。アプリを再起動してください。';

  @override
  void initState() {
    super.initState();
    _ownsService = widget.ocrService == null;
    try {
      _ocrService = widget.ocrService ?? OCRService();
    } catch (error, stackTrace) {
      debugLog('OCR service initialization failed: $error');
      debugLog('Stack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    if (_ownsService) _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final isEnglish = context.read<SettingsProvider>().isEnglish;
    final service = _ocrService;
    if (service == null) {
      _showMessage(_serviceInitMessage(isEnglish));
      return;
    }
    if (!await _ensureAiConfigured() || !mounted) return;
    try {
      await service.requireImageInputSupport();
    } on OcrExtractionException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    }
    if (!mounted) return;

    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.aiAndOcr,
      isEnglish: isEnglish,
    );
    if (!consentGranted || !mounted) return;

    if (source == ImageSource.camera && !kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showMessage(
            isEnglish ? 'Camera permission is required.' : 'カメラの権限が必要です。');
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
        _showMessage(isEnglish ? 'No image was selected.' : '画像が選択されませんでした。');
        return;
      }
      setState(() => _selectedImage = image);
      await _processImage(image);
    } on UnsupportedError catch (error) {
      if (mounted) _showMessage(error.message?.toString() ?? error.toString());
    } catch (error, stackTrace) {
      debugLog('Image selection failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        _showMessage(isEnglish
            ? 'Could not load the image. Try again.'
            : '画像の取得に失敗しました。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(dynamic image) async {
    final isEnglish = context.read<SettingsProvider>().isEnglish;
    final service = _ocrService;
    final definition = getCarSettingDefinition(widget.car.id);
    if (service == null || definition == null) {
      _showMessage(isEnglish
          ? 'No setup definition was found for this car model.'
          : 'この車種の設定定義が見つかりません。');
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
        _showMessage(isEnglish
            ? 'No filled-in setup values could be recognized.'
            : '入力済みの設定値を認識できませんでした。');
      }
    } on OcrExtractionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on AiProviderException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error, stackTrace) {
      debugLog('Structured OCR failed: $error');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        _showMessage(isEnglish
            ? 'Could not read the image. Check that it is upright and clear.'
            : '画像の解析に失敗しました。画像の向きや鮮明さを確認してください。');
      }
    }
  }

  Future<bool> _ensureAiConfigured() async {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    String? availabilityIssue;
    try {
      final configuration = AiConfigurationService();
      availabilityIssue = await configuration.availabilityIssue(
          requireImages: true, isEnglish: isEnglish);
      if (availabilityIssue == null && await configuration.isReady) return true;
    } catch (_) {
      // The same setup guidance is shown when secure storage is unavailable.
    }
    if (!mounted) return false;
    final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isEnglish ? 'AI setup required' : 'AI設定が必要です'),
            content: Text(
              availabilityIssue ??
                  (isEnglish
                      ? 'Select standard Gemini or configure an OpenAI, Anthropic, Gemini, or OpenCode Go API key with an image-capable model before using image OCR.'
                      : '画像OCRを使う前に、標準Geminiを選択するか、OpenAI・Anthropic・Gemini・OpenCode GoのAPIキーと画像対応モデルを設定してください。'),
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
      final configuration = AiConfigurationService();
      return await configuration.availabilityIssue(requireImages: true) ==
              null &&
          await configuration.isReady;
    } catch (_) {
      return false;
    }
  }

  Future<void> _importSettings() async {
    final isEnglish = context.read<SettingsProvider>().isEnglish;
    final result = _result;
    if (result == null || result.modelMismatch) return;
    final imported = result.selectedSettings(_selectedKeys);
    if (imported.isEmpty) {
      _showMessage(
          isEnglish ? 'Select the values to import.' : '取り込む候補を選択してください。');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isEnglish ? 'Import Setup' : 'セッティングのインポート'),
            content: Text(
              isEnglish
                  ? 'This will overwrite ${imported.length} values in the current setup.'
                  : '${imported.length}個の設定を現在のセッティングへ上書きします。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isEnglish ? 'Import' : 'インポート'),
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

  Widget _buildImagePreview(bool isEnglish) {
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
                  errorBuilder: (_, __, ___) => Center(
                      child: Text(isEnglish
                          ? 'Could not display the image'
                          : '画像を表示できません')),
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
    final provider = context.watch<SettingsProvider>();
    final isEnglish = provider.isEnglish;
    final definition = carSettingsDefinitions[widget.car.id];
    final labelsByKey = <String, String>{
      for (final item in definition?.availableSettings ?? [])
        item.key: provider.settingLabel(item),
    };
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(isEnglish ? 'Detected Values' : '読み取り候補',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          result.detectedModel.trim().isEmpty
              ? (isEnglish ? 'Detected model: Unknown' : '検出車種: 判定できませんでした')
              : (isEnglish
                  ? 'Detected model: ${result.detectedModel}'
                  : '検出車種: ${result.detectedModel}'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (result.modelMismatch) ...[
          _buildNotice(
            icon: Icons.error_outline_rounded,
            text: isEnglish
                ? 'This appears to be a ${result.detectedModel} setup sheet and cannot be imported into ${widget.car.name}. Select the correct car model and try again.'
                : '画像は${result.detectedModel}のシートと判定されました。現在選択中の${widget.car.name}には取り込めません。正しい車種からやり直してください。',
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
              isEnglish
                  ? 'No filled-in setup values could be recognized.'
                  : '入力済みの設定値を認識できませんでした。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          )
        else
          OcrCandidateReviewList(
            result: result,
            labelsByKey: labelsByKey,
            isEnglish: isEnglish,
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
          label: Text(isEnglish
              ? 'Import Selected Values (${_selectedKeys.length})'
              : '選択した設定をインポート (${_selectedKeys.length}個)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEnglish = context.watch<SettingsProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
          title:
              Text(isEnglish ? 'Import Setup with OCR' : 'OCRでセッティングをインポート')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_ocrService == null) ...[
                  _buildNotice(
                    icon: Icons.error_outline_rounded,
                    text: _serviceInitMessage(isEnglish),
                    background: colors.errorContainer,
                    foreground: colors.onErrorContainer,
                  ),
                  const SizedBox(height: 16),
                ],
                if (kIsWeb) ...[
                  _buildNotice(
                    icon: Icons.info_outline_rounded,
                    text: isEnglish
                        ? 'On the web, choose an image from the gallery for best results.'
                        : 'Web版ではギャラリーからの画像選択を推奨します。',
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
                      label: Text(kIsWeb
                          ? (isEnglish ? 'Open Camera' : 'カメラを起動')
                          : (isEnglish ? 'Take Photo' : 'カメラで撮影')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProcessing || _ocrService == null
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label:
                          Text(isEnglish ? 'Choose from Gallery' : 'ギャラリーから選択'),
                    ),
                  ],
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 20),
                  _buildImagePreview(isEnglish),
                ],
                if (_isProcessing) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(
                    isEnglish
                        ? 'Reading text and selection marks on the sheet…'
                        : 'シートの文字と選択マークを解析しています…',
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
    this.labelsByKey = const {},
    this.isEnglish = false,
    required this.selectedKeys,
    required this.onSelectionChanged,
  });

  final OcrExtractionResult result;
  final Map<String, String> labelsByKey;
  final bool isEnglish;
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
      OcrConfidence.high => isEnglish ? 'High confidence' : '確信度 高',
      OcrConfidence.medium => isEnglish ? 'Medium confidence' : '確信度 中',
      OcrConfidence.low => isEnglish ? 'Low confidence' : '確信度 低',
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
      title: Text(labelsByKey[candidate.key] ?? candidate.label),
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
          displayValue(candidate, isEnglish: isEnglish),
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }

  static String displayValue(OcrCandidate candidate, {bool isEnglish = false}) {
    String positionLabel(int row, int col) =>
        isEnglish ? 'Row ${row + 1}, col ${col + 1}' : '${row + 1}行${col + 1}列';

    final value = candidate.value;
    if (value is List) {
      final positions = <String>[];
      for (final point in value) {
        if (point is Map && point['row'] is int && point['col'] is int) {
          positions
              .add(positionLabel(point['row'] as int, point['col'] as int));
        }
      }
      return positions.isEmpty
          ? (isEnglish ? 'Unknown position' : '位置不明')
          : positions.join(', ');
    }
    if (value != null) return value.toString();
    if (candidate.rawValue.isNotEmpty) return candidate.rawValue;
    if (candidate.points.isNotEmpty) {
      return candidate.points
          .map((point) => positionLabel(point.row, point.col))
          .join(', ');
    }
    return '—';
  }
}
