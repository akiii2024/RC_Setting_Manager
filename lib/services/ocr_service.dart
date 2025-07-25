import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../models/car_setting_definition.dart';

class OCRService {
  late final GenerativeModel _model;
  final ImagePicker _imagePicker = ImagePicker();

  OCRService() {
    // 環境変数からGemini APIキーを取得
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY が環境変数に設定されていません');
    }

    // Gemini Pro Visionモデルを初期化
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  // Web環境チェック
  bool get isWebPlatform => kIsWeb;

  // 画像から文字を認識（Gemini使用）
  Future<String?> recognizeTextFromImage(dynamic imageFile) async {
    try {
      late Uint8List imageBytes;

      if (kIsWeb) {
        // Web環境の場合
        if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Web環境では XFile が必要です');
        }
      } else {
        // モバイル/デスクトップ環境の場合
        if (imageFile is File) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('モバイル環境では File が必要です');
        }
      }

      // 画像データをData型に変換
      final imagePart = DataPart('image/jpeg', imageBytes);

      // OCR用のプロンプトを作成
      const prompt = '''
この画像からテキストを正確に読み取ってください。
特に以下の点に注意してください：
- 数値は正確に読み取る
- 単位（mm、°、#など）も含めて読み取る
- 日本語と英語の両方に対応する
- 設定項目とその値の関係を明確にする
- 読み取れないテキストは無理に推測しない

可能であれば以下の形式で出力してください：
項目名: 値
例：
タイヤ: 4mm
キャンバー: -1.5°
車高: 3.2mm

読み取ったテキストをそのまま出力してください。
''';

      // Gemini APIに画像とプロンプトを送信
      final content = [
        Content.multi([
          TextPart(prompt),
          imagePart,
        ])
      ];

      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      print('Gemini OCR エラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      print('スタックトレース: ${StackTrace.current}');
      return null;
    }
  }

  // カメラから画像を取得
  Future<dynamic> pickImageFromCamera() async {
    if (kIsWeb) {
      // Web環境でもカメラを試行する
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        return image;
      } catch (e) {
        print('Web環境でのカメラエラー: $e');
        throw UnsupportedError('Web環境でカメラが利用できません。ギャラリーをご利用ください。');
      }
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('カメラからの画像取得エラー: $e');
      print('エラータイプ: ${e.runtimeType}');
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
      print('ギャラリーからの画像取得エラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      return null;
    }
  }

  // Geminiの応答からセッティング値を抽出（改良版）
  Map<String, String> extractSettingsFromText(
      String text, List<SettingItem> settingDefinitions) {
    final Map<String, String> extractedSettings = {};
    final lines = text.split('\n');

    // セッティング項目のラベルとキーのマッピングを作成
    final Map<String, String> labelToKeyMap = {};
    for (final setting in settingDefinitions) {
      labelToKeyMap[setting.label] = setting.key;
      // 英語のキーも考慮
      labelToKeyMap[_getEnglishLabel(setting.key)] = setting.key;
      // よくある略語も追加
      labelToKeyMap[_getAbbreviation(setting.key)] = setting.key;
    }

    // 各行を解析
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // パターン1: "ラベル: 値" または "ラベル：値"
      final pattern1 = RegExp(r'(.+?)[:：]\s*(.+)');
      final match1 = pattern1.firstMatch(trimmedLine);

      if (match1 != null) {
        final label = match1.group(1)!.trim();
        final value = match1.group(2)!.trim();
        _processLabelValue(
            label, value, labelToKeyMap, extractedSettings, settingDefinitions);
        continue;
      }

      // パターン2: "ラベル 値" (スペース区切り)
      final pattern2 = RegExp(r'(.+?)\s+([0-9.,\-]+.*)');
      final match2 = pattern2.firstMatch(trimmedLine);

      if (match2 != null) {
        final label = match2.group(1)!.trim();
        final value = match2.group(2)!.trim();
        _processLabelValue(
            label, value, labelToKeyMap, extractedSettings, settingDefinitions);
        continue;
      }

      // パターン3: 表形式のデータ（タブ区切りなど）
      final parts = trimmedLine.split(RegExp(r'\s{2,}|\t'));
      if (parts.length >= 2) {
        final label = parts[0].trim();
        final value = parts[1].trim();
        _processLabelValue(
            label, value, labelToKeyMap, extractedSettings, settingDefinitions);
      }
    }

    return extractedSettings;
  }

  // AIベースの賢いマッピング機能（バッチ処理版）
  Future<Map<String, String>> aiMappingForSettings(
      Map<String, String> extractedSettings,
      List<SettingItem> settingDefinitions) async {
    final Map<String, String> mappedSettings = {};
    final List<String> unmatchedItems = [];
    final Map<String, List<String>> valuesToMap = {};

    // 第1段階：マッチした項目と未マッチ項目を分類
    for (final entry in extractedSettings.entries) {
      final key = entry.key;
      final rawValue = entry.value;

      // 未マッチラベルの処理
      if (key.startsWith('_unmatched_')) {
        unmatchedItems.add(rawValue);
        continue;
      }

      // 対応するセッティング定義を検索
      final settingDef = settingDefinitions.firstWhere(
        (setting) => setting.key == key,
        orElse: () => SettingItem(
          key: key,
          type: 'text',
          category: 'general',
          label: key,
        ),
      );

      // オプションが定義されている場合は値マッピング用リストに追加
      if (settingDef.options != null && settingDef.options!.isNotEmpty) {
        valuesToMap[key] = [rawValue, ...settingDef.options!];
      } else {
        // オプションが定義されていない場合はそのまま使用
        mappedSettings[key] = rawValue;
      }
    }

    // 第2段階：未マッチラベルをバッチでAI処理
    if (unmatchedItems.isNotEmpty) {
      final labelMappingResults =
          await _mapMultipleLabelsWithAI(unmatchedItems, settingDefinitions);

      for (final result in labelMappingResults) {
        final key = result['key'];
        final value = result['value'];

        if (key != null && value != null && key.isNotEmpty) {
          final settingDef = settingDefinitions.firstWhere(
            (setting) => setting.key == key,
            orElse: () => SettingItem(
              key: '',
              type: 'text',
              category: 'general',
              label: '',
            ),
          );

          if (settingDef.key.isNotEmpty) {
            // 値のマッピングも準備
            if (settingDef.options != null && settingDef.options!.isNotEmpty) {
              valuesToMap[key] = [value, ...settingDef.options!];
            } else {
              mappedSettings[key] = _cleanValue(value);
            }
          }
        }
      }
    }

    // 第3段階：値マッピングをバッチでAI処理
    if (valuesToMap.isNotEmpty) {
      final valueMappingResults = await _mapMultipleValuesWithAI(valuesToMap);

      for (final entry in valueMappingResults.entries) {
        mappedSettings[entry.key] = entry.value;
      }
    }

    return mappedSettings;
  }

  // Gemini AIを使用して値をマッピング
  Future<String?> _mapValueWithAI(
      String rawValue, List<String> availableOptions) async {
    // まずローカルでの類似性チェックを試行
    final localMatch = _findLocalMatch(rawValue, availableOptions);
    if (localMatch != null) {
      print('ローカルマッチング成功: "$rawValue" -> "$localMatch"');
      return localMatch;
    }

    try {
      final prompt = '''
以下の読み取られた値を、利用可能なオプションの中から最も適切なものにマッピングしてください。

読み取られた値: "$rawValue"

利用可能なオプション:
${availableOptions.map((option) => '- $option').join('\n')}

要求事項:
1. 読み取られた値と最も近い意味のオプションを選択
2. 数値が含まれる場合は数値を優先してマッチング
3. 完全一致でなくても、意味が近いものを選択
4. どのオプションも適切でない場合は "NO_MATCH" と回答
5. 回答は選択したオプションのみを出力（説明不要）

回答:''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim();

      if (result == null || result.isEmpty || result == 'NO_MATCH') {
        print('AIマッピング失敗: "$rawValue" -> オプション: $availableOptions');
        return null;
      }

      // 結果が利用可能なオプションに含まれているかチェック
      if (availableOptions.contains(result)) {
        print('AIマッピング成功: "$rawValue" -> "$result"');
        return result;
      } else {
        print('AIマッピング結果が無効: "$rawValue" -> "$result" (利用不可)');
        return null;
      }
    } catch (e) {
      print('AIマッピングエラー: $e');
      return null;
    }
  }

  // ラベルからキーをマッピング（AI使用）
  Future<String?> _mapLabelWithAI(
      String label, List<SettingItem> settingDefinitions) async {
    final prompt = '''
以下のラベルを、利用可能なセッティング項目の中から最も適切なものにマッピングしてください。

ラベル: "$label"

利用可能なセッティング項目:
${settingDefinitions.map((setting) => '- ${setting.label} (キー: ${setting.key})').join('\n')}

要求事項:
1. ラベルと最も近い意味のセッティング項目を選択
2. 完全一致でなくても、意味が近いものを選択
3. フロント/リア、左/右、前/後などの方向も考慮
4. どのセッティング項目も適切でない場合は "NO_MATCH" と回答
5. 回答は選択したセッティング項目のラベルのみを出力（説明不要）

回答:''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim();

      if (result == null || result.isEmpty || result == 'NO_MATCH') {
        print(
            'AIラベルマッピング失敗: "$label" -> 利用可能項目: ${settingDefinitions.map((s) => s.label)}');
        return null;
      }

      // 結果が利用可能なセッティング項目に含まれているかチェック
      final matchedSetting = settingDefinitions.firstWhere(
        (setting) => setting.label == result,
        orElse: () => SettingItem(
          key: '',
          type: 'text',
          category: 'general',
          label: '',
        ),
      );

      if (matchedSetting.key.isNotEmpty) {
        print(
            'AIラベルマッピング成功: "$label" -> "${matchedSetting.label}" (${matchedSetting.key})');
        return matchedSetting.key;
      } else {
        // 部分マッチングも試行
        for (final setting in settingDefinitions) {
          if (setting.label.contains(result) ||
              result.contains(setting.label)) {
            print(
                'AIラベルマッピング部分一致: "$label" -> "${setting.label}" (${setting.key})');
            return setting.key;
          }
        }

        print('AIラベルマッピング結果が無効: "$label" -> "$result" (利用不可)');
        return null;
      }
    } catch (e) {
      print('AIラベルマッピングエラー: $e');
      return null;
    }
  }

  // ラベルからキーをマッピング（AI使用） - 真のバッチ処理版
  Future<List<Map<String, String>>> _mapMultipleLabelsWithAI(
      List<String> unmatchedItems, List<SettingItem> settingDefinitions) async {
    final List<Map<String, String>> results = [];

    if (unmatchedItems.isEmpty) return results;

    // バッチ処理用のプロンプトを作成
    final itemsText = unmatchedItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final parts = item.split(':');
      if (parts.length >= 2) {
        final label = parts[0].trim();
        return '${index + 1}. ラベル: "$label"';
      }
      return '${index + 1}. ラベル: "$item"';
    }).join('\n');

    final availableSettings = settingDefinitions
        .map((setting) => '- ${setting.label} (キー: ${setting.key})')
        .join('\n');

    final prompt = '''
以下の複数のラベルを、利用可能なセッティング項目の中から最も適切なものにマッピングしてください。

マッピング対象のラベル:
$itemsText

利用可能なセッティング項目:
$availableSettings

要求事項:
1. 各ラベルと最も近い意味のセッティング項目を選択
2. 完全一致でなくても、意味が近いものを選択
3. フロント/リア、左/右、前/後などの方向も考慮
4. マッピングできない場合は "NO_MATCH" を記載

回答形式（JSON）:
{
  "mappings": [
    {"index": 1, "label": "適切なセッティング項目のラベル"},
    {"index": 2, "label": "適切なセッティング項目のラベル"},
    ...
  ]
}

回答:''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim();

      if (result != null && result.isNotEmpty) {
        // JSONパースを試行
        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(result);
          if (jsonMatch != null) {
            final jsonString = jsonMatch.group(0)!;
            final parsedJson = json.decode(jsonString);
            final mappings = parsedJson['mappings'] as List<dynamic>;

            for (final mapping in mappings) {
              final index = mapping['index'] as int;
              final matchedLabel = mapping['label'] as String;

              if (index > 0 &&
                  index <= unmatchedItems.length &&
                  matchedLabel != 'NO_MATCH') {
                final originalItem = unmatchedItems[index - 1];
                final parts = originalItem.split(':');
                if (parts.length >= 2) {
                  final value = parts.sublist(1).join(':').trim();

                  // マッチしたラベルからキーを取得
                  final settingDef = settingDefinitions.firstWhere(
                    (setting) => setting.label == matchedLabel,
                    orElse: () => SettingItem(
                        key: '', type: 'text', category: 'general', label: ''),
                  );

                  if (settingDef.key.isNotEmpty) {
                    results.add({'key': settingDef.key, 'value': value});
                    print(
                        'バッチAIラベルマッピング成功: "${parts[0].trim()}" -> "$matchedLabel" (${settingDef.key})');
                  }
                }
              }
            }
          }
        } catch (e) {
          print('バッチAIラベルマッピングのJSONパースエラー: $e');
          // フォールバック：従来の個別処理
          return await _mapMultipleLabelsWithAIFallback(
              unmatchedItems, settingDefinitions);
        }
      }
    } catch (e) {
      print('バッチAIラベルマッピングエラー: $e');
      // フォールバック：従来の個別処理
      return await _mapMultipleLabelsWithAIFallback(
          unmatchedItems, settingDefinitions);
    }

    return results;
  }

  // フォールバック用の個別処理
  Future<List<Map<String, String>>> _mapMultipleLabelsWithAIFallback(
      List<String> unmatchedItems, List<SettingItem> settingDefinitions) async {
    final List<Map<String, String>> results = [];

    for (final unmatchedItem in unmatchedItems) {
      final parts = unmatchedItem.split(':');
      if (parts.length >= 2) {
        final label = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();

        final mappedKey = await _mapLabelWithAI(label, settingDefinitions);
        if (mappedKey != null && mappedKey.isNotEmpty) {
          results.add({'key': mappedKey, 'value': value});
        } else {
          print('AIラベルマッピング失敗: "$label" = "$value"');
        }
      }
    }

    return results;
  }

  // 値をマッピング（AI使用） - 真のバッチ処理版
  Future<Map<String, String>> _mapMultipleValuesWithAI(
      Map<String, List<String>> valuesToMap) async {
    final Map<String, String> mappedValues = {};

    if (valuesToMap.isEmpty) return mappedValues;

    // バッチ処理用のプロンプトを作成
    final entryList = valuesToMap.entries.toList();
    final itemsText = entryList.asMap().entries.map((entry) {
      final index = entry.key;
      final mapEntry = entry.value;
      final key = mapEntry.key;
      final valueList = mapEntry.value;

      if (valueList.isNotEmpty) {
        final rawValue = valueList.first;
        final options = valueList.skip(1).toList();
        return '${index + 1}. キー: "$key", 読み取り値: "$rawValue", オプション: [${options.join(', ')}]';
      }
      return '${index + 1}. キー: "$key", 読み取り値: "不明"';
    }).join('\n');

    final prompt = '''
以下の複数の読み取り値を、それぞれの利用可能なオプションの中から最も適切なものにマッピングしてください。

マッピング対象:
$itemsText

要求事項:
1. 読み取り値と最も近い意味のオプションを選択
2. 数値が含まれる場合は数値を優先してマッチング
3. 完全一致でなくても、意味が近いものを選択
4. マッピングできない場合は元の読み取り値をそのまま使用

回答形式（JSON）:
{
  "mappings": [
    {"index": 1, "mapped_value": "選択したオプション"},
    {"index": 2, "mapped_value": "選択したオプション"},
    ...
  ]
}

回答:''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim();

      if (result != null && result.isNotEmpty) {
        // JSONパースを試行
        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(result);
          if (jsonMatch != null) {
            final jsonString = jsonMatch.group(0)!;
            final parsedJson = json.decode(jsonString);
            final mappings = parsedJson['mappings'] as List<dynamic>;

            final entryList = valuesToMap.entries.toList();

            for (final mapping in mappings) {
              final index = mapping['index'] as int;
              final mappedValue = mapping['mapped_value'] as String;

              if (index > 0 && index <= entryList.length) {
                final originalEntry = entryList[index - 1];
                final key = originalEntry.key;
                final originalValue = originalEntry.value.first;

                mappedValues[key] = mappedValue;
                print(
                    'バッチAI値マッピング成功: "$originalValue" -> "$mappedValue" (キー: $key)');
              }
            }
          }
        } catch (e) {
          print('バッチAI値マッピングのJSONパースエラー: $e');
          // フォールバック：従来の個別処理
          return await _mapMultipleValuesWithAIFallback(valuesToMap);
        }
      }
    } catch (e) {
      print('バッチAI値マッピングエラー: $e');
      // フォールバック：従来の個別処理
      return await _mapMultipleValuesWithAIFallback(valuesToMap);
    }

    return mappedValues;
  }

  // フォールバック用の個別値処理
  Future<Map<String, String>> _mapMultipleValuesWithAIFallback(
      Map<String, List<String>> valuesToMap) async {
    final Map<String, String> mappedValues = {};

    for (final entry in valuesToMap.entries) {
      final key = entry.key;
      final valueList = entry.value;

      if (valueList.isNotEmpty) {
        final rawValue = valueList.first;
        final options = valueList.skip(1).toList();

        final mappedValue = await _mapValueWithAI(rawValue, options);
        mappedValues[key] = mappedValue ?? rawValue;
      }
    }

    return mappedValues;
  }

  // ローカルでの類似性チェック
  String? _findLocalMatch(String rawValue, List<String> availableOptions) {
    final cleanRawValue =
        rawValue.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');

    // 完全一致チェック
    for (final option in availableOptions) {
      if (option.toLowerCase() == rawValue.toLowerCase()) {
        return option;
      }
    }

    // 部分一致チェック（数値を含む場合）
    final rawNumbers = RegExp(r'[0-9]+\.?[0-9]*').allMatches(rawValue);
    if (rawNumbers.isNotEmpty) {
      for (final option in availableOptions) {
        final optionNumbers = RegExp(r'[0-9]+\.?[0-9]*').allMatches(option);
        if (optionNumbers.isNotEmpty) {
          final rawNum = rawNumbers.first.group(0);
          final optionNum = optionNumbers.first.group(0);
          if (rawNum == optionNum) {
            return option;
          }
        }
      }
    }

    // 文字列の類似性チェック
    for (final option in availableOptions) {
      final cleanOption = option.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');

      // 50%以上の類似性があれば候補とする
      if (_calculateStringSimilarity(cleanRawValue, cleanOption) > 0.5) {
        return option;
      }

      // 一方が他方を含む場合
      if (cleanRawValue.contains(cleanOption) ||
          cleanOption.contains(cleanRawValue)) {
        return option;
      }
    }

    return null;
  }

  // 文字列の類似性を計算（簡易版）
  double _calculateStringSimilarity(String str1, String str2) {
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final longer = str1.length > str2.length ? str1 : str2;
    final shorter = str1.length > str2.length ? str2 : str1;

    if (longer.isEmpty) return 1.0;

    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  // レーベンシュタイン距離を計算
  int _levenshteinDistance(String str1, String str2) {
    final matrix = List.generate(
      str1.length + 1,
      (i) => List.generate(str2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= str1.length; i++) {
      for (int j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[str1.length][str2.length];
  }

  // ラベルと値の処理を共通化（AI対応版）
  void _processLabelValue(
      String label,
      String value,
      Map<String, String> labelToKeyMap,
      Map<String, String> extractedSettings,
      List<SettingItem> settingDefinitions) {
    String? matchedKey;

    // 従来のラベルマッチングを試行
    for (final entry in labelToKeyMap.entries) {
      if (_isLabelMatch(label, entry.key)) {
        matchedKey = entry.value;
        print('従来マッチング成功: "$label" -> "${entry.key}" (${entry.value})');
        break;
      }
    }

    // 従来のマッチングで見つからない場合、AIマッピングを後で実行するため記録
    if (matchedKey == null) {
      print('従来マッチング失敗、AIマッピング候補: "$label" = "$value"');
      // 一時的にラベルをキーとして保存（後でAIマッピングで修正）
      extractedSettings['_unmatched_${extractedSettings.length}'] =
          '$label:$value';
      return;
    }

    // マッチした場合は値を抽出
    final cleanedValue = _cleanValue(value);
    if (cleanedValue.isNotEmpty) {
      extractedSettings[matchedKey] = cleanedValue;
    }
  }

  // ラベルマッチングの改良
  bool _isLabelMatch(String label, String targetLabel) {
    final normalizedLabel = label.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final normalizedTarget =
        targetLabel.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    return normalizedLabel.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedLabel) ||
        normalizedLabel == normalizedTarget;
  }

  // 値から単位を除去してクリーンな値を取得
  String _cleanValue(String value) {
    // 不要な文字を除去
    String cleanedValue = value.replaceAll(RegExp(r'[()（）\[\]]'), '').trim();

    // 単位を除去 (mm, °, φ, T, g など)
    cleanedValue = cleanedValue
        .replaceAll(RegExp(r'(mm|°|度|φ|T|g|#|点|ポイント)\s*$'), '')
        .trim();

    // 数値の妥当性をチェック
    if (RegExp(r'^-?[0-9]+\.?[0-9]*$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }

    // 範囲表記の場合（例：1-3）
    if (RegExp(r'^[0-9]+-[0-9]+$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }

    // テキスト値の場合はそのまま返す
    return value.trim();
  }

  // 英語ラベルを取得（改良版）
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
      'frontToe': 'Front Toe',
      'rearToe': 'Rear Toe',
      'frontSpring': 'Front Spring',
      'rearSpring': 'Rear Spring',
      'frontDamper': 'Front Damper',
      'rearDamper': 'Rear Damper',
      'frontTireCompound': 'Front Tire',
      'rearTireCompound': 'Rear Tire',
    };

    return keyToEnglishMap[key] ?? key;
  }

  // 略語マッピングを取得
  String _getAbbreviation(String key) {
    final Map<String, String> keyToAbbrevMap = {
      'frontCamberAngle': 'F Camber',
      'rearCamberAngle': 'R Camber',
      'frontGroundClearance': 'F Height',
      'rearGroundClearance': 'R Height',
      'frontStabilizer': 'F Stabi',
      'rearStabilizer': 'R Stabi',
      'spurGear': 'Spur',
      'pinionGear': 'Pinion',
    };

    return keyToAbbrevMap[key] ?? key;
  }

  void dispose() {
    // Gemini APIクライアントのクリーンアップ（必要に応じて）
  }
}
