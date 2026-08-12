import '../../data/car_settings_definitions.dart';
import '../../models/car_setting_definition.dart';

/// Builds the ordered, localized view model used by the visibility settings
/// dialog.
///
/// Keeping this transformation outside the widget makes category fallback and
/// ordering deterministic and directly testable.
abstract final class VisibilitySettingsPresenter {
  static const _categoryOrder = <String>[
    'basic',
    'front',
    'frontDamper',
    'rear',
    'rearDamper',
    'top',
    'other',
    'memo',
  ];

  static Map<String, List<String>> groupSettingKeys({
    required List<String> settingKeys,
    required Map<String, SettingItem> definitionByKey,
    required bool isEnglish,
  }) {
    final groupedByKey = <String, List<String>>{};

    for (final key in settingKeys) {
      final definition = definitionByKey[key];
      final categoryKey = definition == null
          ? fallbackCategoryForKey(key)
          : displayCategoryForSetting(definition);
      groupedByKey.putIfAbsent(categoryKey, () => <String>[]).add(key);
    }

    final ordered = <String, List<String>>{};
    for (final categoryKey in _categoryOrder) {
      final keys = groupedByKey.remove(categoryKey);
      if (keys != null && keys.isNotEmpty) {
        ordered[categoryLabel(categoryKey, isEnglish)] = keys;
      }
    }

    for (final entry in groupedByKey.entries) {
      ordered[categoryLabel(entry.key, isEnglish)] = entry.value;
    }
    return ordered;
  }

  static String fallbackCategoryForKey(String key) {
    const basicKeys = {
      'date',
      'track',
      'surface',
      'airTemp',
      'humidity',
      'trackTemp',
      'condition',
    };
    if (basicKeys.contains(key) || key == 'memo') {
      return key == 'memo' ? 'memo' : 'basic';
    }

    if (key.startsWith('front')) {
      return isDamperSettingKey(key) ? 'frontDamper' : 'front';
    }
    if (key.startsWith('rear')) {
      return isDamperSettingKey(key) ? 'rearDamper' : 'rear';
    }
    if (key.contains('upperDeck') ||
        key.contains('ballast') ||
        key.contains('knuckle') ||
        key.contains('steering') ||
        key.contains('lowerDeck')) {
      return 'top';
    }
    return 'other';
  }

  static String categoryLabel(String category, bool isEnglish) {
    return switch (category) {
      'basic' => isEnglish ? 'Basic Information' : '基本情報',
      'front' => isEnglish ? 'Front Settings' : 'フロント設定',
      'frontDamper' => isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定',
      'rear' => isEnglish ? 'Rear Settings' : 'リア設定',
      'rearDamper' => isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定',
      'top' => isEnglish ? 'Top Settings' : 'トップ設定',
      'other' => isEnglish ? 'Other Settings' : 'その他設定',
      'memo' => isEnglish ? 'Memo' : 'メモ',
      _ => category,
    };
  }

  static String settingLabel(String key, bool isEnglish) {
    if (!isEnglish) {
      return key;
    }

    final spaced = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }
}
