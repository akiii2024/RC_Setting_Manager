import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../services/ocr_service.dart';
import '../data/car_settings_definitions.dart';
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
  final OCRService _ocrService = OCRService();
  dynamic _selectedImage;
  String? _recognizedText;
  Map<String, String>? _extractedSettings;
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
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
          imageFile = await _ocrService.pickImageFromCamera();
        } catch (e) {
          // Web環境でカメラが利用できない場合のエラーハンドリング
          if (kIsWeb && e is UnsupportedError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message ?? 'カメラが利用できません')),
              );
            }
            return;
          }
          rethrow;
        }
      } else {
        imageFile = await _ocrService.pickImageFromGallery();
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
      print('Error in _pickImage: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の取得に失敗しました: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(dynamic imageFile) async {
    try {
      if (kIsWeb) {
        print('Processing image (Web): ${imageFile.name}');
        print('Image size: ${await imageFile.length()} bytes');
      } else {
        print('Processing image: ${imageFile.path}');
        print('Image exists: ${await imageFile.exists()}');
        print('Image size: ${await imageFile.length()} bytes');
      }

      final recognizedText =
          await _ocrService.recognizeTextFromImage(imageFile);

      if (recognizedText != null) {
        print('Text recognized successfully');
        setState(() {
          _recognizedText = recognizedText;
        });

        // セッティング定義を取得
        final carDefinition = getCarSettingDefinition(widget.car.id);

        if (carDefinition != null) {
          // テキストからセッティングを抽出
          final extractedSettings = _ocrService.extractSettingsFromText(
            recognizedText,
            carDefinition.availableSettings,
          );

          print('基本抽出完了: ${extractedSettings.length}個の設定を抽出');

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

            final mappedSettings = await _ocrService.aiMappingForSettings(
              extractedSettings,
              carDefinition.availableSettings,
            );

            setState(() {
              _extractedSettings = mappedSettings;
            });

            print('設定値抽出完了: ${mappedSettings.length}個の設定を取得');
            print('マッピング結果: $mappedSettings');

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
            print('AIマッピングでエラーが発生しました: $e');
            // エラーの場合は基本抽出結果を使用
            setState(() {
              _extractedSettings = extractedSettings;
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
        print('No text recognized from image');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像からテキストを認識できませんでした')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _processImage: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('テキスト認識に失敗しました: ${e.toString()}'),
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

            // 画像選択ボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(kIsWeb ? 'カメラを起動' : 'カメラで撮影'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
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
