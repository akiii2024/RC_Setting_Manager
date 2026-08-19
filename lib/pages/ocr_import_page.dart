import 'package:rc_setting_manager/utils/app_logger.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../providers/settings_provider.dart';
import '../services/api_consent_service.dart';
import '../services/ai_configuration_service.dart';
import '../services/ocr_service.dart';
import '../widgets/ai_provider_indicator.dart';
import '../data/car_settings_definitions.dart';
import 'ai_provider_settings_page.dart';
import 'package:permission_handler/permission_handler.dart';

class OCRImportPage extends StatefulWidget {
  final Car car;
  final Map<String, dynamic> currentSettings;

  const OCRImportPage({
    super.key,
    required this.car,
    required this.currentSettings,
  });

  @override
  State<OCRImportPage> createState() => _OCRImportPageState();
}

class _OCRImportPageState extends State<OCRImportPage> {
  OCRService? _ocrService;
  dynamic _selectedImage;
  String? _recognizedText;
  Map<String, String>? _extractedSettings;
  bool _isProcessing = false;
  String? _serviceInitError;

  @override
  void initState() {
    super.initState();
    try {
      _ocrService = OCRService();
    } catch (error, stackTrace) {
      debugLog('OCR service initialization failed: $error');
      debugLog('Stack trace: $stackTrace');
      _serviceInitError = 'OCRサービスを初期化できませんでした。アプリを再起動してください。';
    }
  }

  @override
  void dispose() {
    _ocrService?.dispose();
    super.dispose();
  }

  bool _ensureServiceReady() {
    if (_ocrService != null) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _serviceInitError ?? 'OCR service is not available.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    return false;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_ensureServiceReady()) {
      return;
    }

    if (!await _ensureAiConfigured() || !mounted) {
      return;
    }

    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.aiAndOcr,
      isEnglish:
          Provider.of<SettingsProvider>(context, listen: false).isEnglish,
    );
    if (!consentGranted || !mounted) {
      return;
    }

    final ocrService = _ocrService!;

    // カメラの場合は権限を確認（Web環境では権限チェックをスキップ）
    if (source == ImageSource.camera && !kIsWeb) {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('カメラの権限が必要です')),
            );
          }
          return;
        }
      }
    }

    setState(() {
      _isProcessing = true;
      _recognizedText = null;
      _extractedSettings = null;
    });

    try {
      dynamic imageFile;
      if (source == ImageSource.camera) {
        try {
          imageFile = await ocrService.pickImageFromCamera();
        } catch (error, stackTrace) {
          // Web環境でカメラが利用できない場合のエラーハンドリング
          if (kIsWeb && error is UnsupportedError) {
            debugLog('Web camera is unavailable: $error');
            debugLog('Stack trace: $stackTrace');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'この環境ではカメラを利用できません。ギャラリーから画像を選択してください。',
                  ),
                ),
              );
            }
            return;
          }
          rethrow;
        }
      } else {
        imageFile = await ocrService.pickImageFromGallery();
      }

      if (imageFile != null) {
        setState(() {
          _selectedImage = imageFile;
        });
        await _processImage(imageFile);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像が選択されませんでした')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugLog('Error in _pickImage: $e');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('画像の取得に失敗しました。もう一度お試しください。'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _ensureAiConfigured() async {
    try {
      if (await AiConfigurationService().activeConfiguration != null) {
        return true;
      }
    } catch (_) {
      // Show the same setup guidance for unavailable secure storage.
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
                  ? 'Set an OpenAI, Anthropic, or Gemini API key before '
                      'using image OCR.'
                  : '画像OCRを使う前に、OpenAI・Anthropic・Geminiのいずれかの'
                      'APIキーを設定してください。',
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
    if (openSettings && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AiProviderSettingsPage(
            isEnglish: isEnglish,
          ),
        ),
      );
      if (!mounted) return false;
      setState(() {});
      try {
        return await AiConfigurationService().activeConfiguration != null;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _processImage(dynamic imageFile) async {
    if (_ocrService == null) {
      return;
    }

    try {
      if (kIsWeb) {
        debugLog('Processing image (Web): ${imageFile.name}');
        debugLog('Image size: ${await imageFile.length()} bytes');
      } else {
        debugLog('Processing image: ${imageFile.path}');
        debugLog('Image exists: ${await imageFile.exists()}');
        debugLog('Image size: ${await imageFile.length()} bytes');
      }
      if (!mounted) return;

      final recognizedText =
          await _ocrService!.recognizeTextFromImage(imageFile);
      if (!mounted) return;

      if (recognizedText != null) {
        debugLog('Text recognized successfully');
        setState(() {
          _recognizedText = recognizedText;
        });

        // セッティング定義を取得
        final carDefinition = getCarSettingDefinition(widget.car.id);

        if (carDefinition != null) {
          // テキストからセッティングを抽出
          final extractedSettings = _ocrService!.extractSettingsFromText(
            recognizedText,
            carDefinition.availableSettings,
          );

          debugLog('基本抽出完了: ${extractedSettings.length}個の設定を抽出');

          // AIを使用してより正確なマッピングを実行
          try {
            // ユーザーに処理中であることを通知
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Text('AIが設定値を最適化しています...'),
                    ],
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }

            final mappedSettings = await _ocrService!.aiMappingForSettings(
              extractedSettings,
              carDefinition.availableSettings,
            );
            if (!mounted) return;

            setState(() {
              _extractedSettings = mappedSettings;
            });

            debugLog('設定値抽出完了: ${mappedSettings.length}個の設定を取得');
            debugLog('マッピング結果: $mappedSettings');

            // 成功メッセージを表示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${mappedSettings.length}個の設定値を認識しました'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            debugLog('AIマッピングでエラーが発生しました: $e');
            if (!mounted) return;
            // エラーの場合は基本抽出結果を使用
            final safeExtractedSettings =
                _ocrService!.validateSettingsForImport(
              extractedSettings,
              carDefinition.availableSettings,
            );
            setState(() {
              _extractedSettings = safeExtractedSettings;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('基本的な設定値抽出を使用します'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } else {
        debugLog('No text recognized from image');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像からテキストを認識できませんでした')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugLog('Error in _processImage: $e');
      debugLog('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('テキスト認識に失敗しました。別の画像でお試しください。'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _importSettings() async {
    if (_extractedSettings == null || _extractedSettings!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('インポートするセッティングがありません')),
      );
      return;
    }

    // ダイアログで確認
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('セッティングのインポート'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_serviceInitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serviceInitError!,
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_serviceInitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serviceInitError!,
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('${_extractedSettings!.length}個のセッティングが認識されました。'),
            const SizedBox(height: 8),
            const Text('現在のセッティングに上書きしますか？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('インポート'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 抽出されたセッティングを現在のセッティングとマージして返す
      final mergedSettings = <String, dynamic>{
        ...widget.currentSettings,
        ..._extractedSettings!,
      };

      Navigator.of(context).pop(mergedSettings);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_extractedSettings!.length}個のセッティングをインポートしました'),
        ),
      );
    }
  }

  Widget _buildImageDisplay() {
    if (_selectedImage == null) return Container();

    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: kIsWeb
            ? Image.network(
                _selectedImage.path ?? '',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text('画像を表示できません'),
                  );
                },
              )
            : Image.file(
                _selectedImage as File,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCRでセッティングをインポート'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_serviceInitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serviceInitError!,
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Web環境での注意事項を表示
            if (kIsWeb) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Web版ではカメラ機能が制限される場合があります。ギャラリーからの画像選択をお勧めします。',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const AiProviderIndicator(),
            const SizedBox(height: 16),

            // 画像選択ボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || _ocrService == null
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(kIsWeb ? 'カメラを起動' : 'カメラで撮影'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || _ocrService == null
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('ギャラリーから選択'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 選択された画像
            if (_selectedImage != null) ...[
              _buildImageDisplay(),
              const SizedBox(height: 16),
            ],

            // 処理中インジケーター
            if (_isProcessing) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('画像を処理中...')),
              const SizedBox(height: 16),
            ],

            // 認識されたテキスト
            if (_recognizedText != null) ...[
              const Text(
                '認識されたテキスト:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _recognizedText!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 抽出されたセッティング
            if (_extractedSettings != null) ...[
              const Text(
                '抽出されたセッティング:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_extractedSettings!.isEmpty)
                const Center(
                  child: Text(
                    'セッティングが認識できませんでした',
                    style: TextStyle(color: Colors.red),
                  ),
                )
              else
                Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _extractedSettings!.length,
                    itemBuilder: (context, index) {
                      final entry =
                          _extractedSettings!.entries.elementAt(index);

                      // セッティング定義を取得してラベルを表示
                      final carDefinition =
                          getCarSettingDefinition(widget.car.id);

                      SettingItem? settingItem;
                      if (carDefinition != null) {
                        try {
                          settingItem =
                              carDefinition.availableSettings.firstWhere(
                            (item) => item.key == entry.key,
                          );
                        } catch (e) {
                          // 見つからない場合はnullのまま
                        }
                      }

                      return ListTile(
                        title: Text(settingItem?.label ?? entry.key),
                        subtitle: Text(entry.key),
                        trailing: Text(
                          '${entry.value}${settingItem?.unit != null ? ' ${settingItem!.unit}' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // インポートボタン
              ElevatedButton.icon(
                onPressed: _extractedSettings!.isEmpty ? null : _importSettings,
                icon: const Icon(Icons.download),
                label: Text('セッティングをインポート (${_extractedSettings!.length}個)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum ImageSource {
  camera,
  gallery,
}
