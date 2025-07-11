import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/car_setting_definition.dart';

class OCRService {
  // 日本語認識を削除し、デフォルトのラテン文字認識を使用
  final TextRecognizer? _textRecognizer;
  final ImagePicker _imagePicker = ImagePicker();

  OCRService() : _textRecognizer = kIsWeb ? null : TextRecognizer();

  // Web環境チェック
  bool get isWebPlatform => kIsWeb;

  // 画像から文字を認識
  Future<RecognizedText?> recognizeTextFromImage(dynamic imageFile) async {
    if (kIsWeb) {
      throw UnsupportedError('OCR機能はWeb環境では利用できません');
    }

    try {
      final inputImage = InputImage.fromFile(imageFile as File);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      return recognizedText;
    } catch (e) {
      print('Error recognizing text: $e');
      // より詳細なエラー情報を出力
      print('Error type: ${e.runtimeType}');
      print('Error stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // カメラから画像を取得
  Future<dynamic> pickImageFromCamera() async {
    if (kIsWeb) {
      throw UnsupportedError('カメラ機能はWeb環境では制限されています');
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 画質を少し下げて処理を軽くする
        maxWidth: 1920, // 最大幅を設定
        maxHeight: 1920, // 最大高さを設定
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      print('Error type: ${e.runtimeType}');
      return null;
    }
  }

  // ギャラリーから画像を取得
  Future<dynamic> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        if (kIsWeb) {
          return image; // WebではXFileをそのまま返す
        } else {
          return File(image.path);
        }
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      print('Error type: ${e.runtimeType}');
      return null;
    }
  }

  // 認識したテキストからセッティング値を抽出
  Map<String, String> extractSettingsFromText(
      String text, List<SettingItem> settingDefinitions) {
    final Map<String, String> extractedSettings = {};
    final lines = text.split('\n');

    // セッティング項目のラベルとキーのマッピングを作成
    final Map<String, String> labelToKeyMap = {};
    for (final setting in settingDefinitions) {
      labelToKeyMap[setting.label] = setting.key;
      // 英語のキーも考慮（例：「車高」と「Ground Clearance」）
      labelToKeyMap[_getEnglishLabel(setting.key)] = setting.key;
    }

    // 各行を解析
    for (final line in lines) {
      // パターン1: "ラベル: 値" または "ラベル：値"
      final pattern1 = RegExp(r'(.+?)[:：]\s*(.+)');
      final match1 = pattern1.firstMatch(line);

      if (match1 != null) {
        final label = match1.group(1)!.trim();
        final value = match1.group(2)!.trim();

        // ラベルがマッピングに存在する場合、値を抽出
        for (final entry in labelToKeyMap.entries) {
          if (label.contains(entry.key) || entry.key.contains(label)) {
            // 数値と単位を分離
            final cleanedValue = _cleanValue(value);
            if (cleanedValue.isNotEmpty) {
              extractedSettings[entry.value] = cleanedValue;
            }
            break;
          }
        }
      }

      // パターン2: "ラベル 値" (スペース区切り)
      final pattern2 = RegExp(r'(.+?)\s+([0-9.,]+.*)');
      final match2 = pattern2.firstMatch(line);

      if (match2 != null && match1 == null) {
        final label = match2.group(1)!.trim();
        final value = match2.group(2)!.trim();

        for (final entry in labelToKeyMap.entries) {
          if (label.contains(entry.key) || entry.key.contains(label)) {
            final cleanedValue = _cleanValue(value);
            if (cleanedValue.isNotEmpty) {
              extractedSettings[entry.value] = cleanedValue;
            }
            break;
          }
        }
      }
    }

    return extractedSettings;
  }

  // 値から単位を除去してクリーンな値を取得
  String _cleanValue(String value) {
    // 単位を除去 (mm, °, φ, T, g など)
    final cleanedValue =
        value.replaceAll(RegExp(r'(mm|°|度|φ|T|g|#)\s*$'), '').trim();

    // 数値の妥当性をチェック
    if (RegExp(r'^-?[0-9]+\.?[0-9]*$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }

    // テキスト値の場合はそのまま返す
    return value.trim();
  }

  // 英語ラベルを取得（簡易的なマッピング）
  String _getEnglishLabel(String key) {
    final Map<String, String> keyToEnglishMap = {
      'frontCamberAngle': 'Front Camber',
      'rearCamberAngle': 'Rear Camber',
      'frontGroundClearance': 'Front Ride Height',
      'rearGroundClearance': 'Rear Ride Height',
      'frontStabilizer': 'Front Stabilizer',
      'rearStabilizer': 'Rear Stabilizer',
      'spurGear': 'Spur Gear',
      'pinionGear': 'Pinion Gear',
      // 必要に応じて追加
    };

    return keyToEnglishMap[key] ?? key;
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
