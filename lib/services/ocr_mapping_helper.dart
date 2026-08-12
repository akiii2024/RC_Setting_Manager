import '../models/car_setting_definition.dart';

/// OCR結果のローカル照合と、インポート前の値検証を行う純粋ロジック。
class OcrMappingHelper {
  const OcrMappingHelper._();

  static Map<String, String> validateSettingsForImport(
    Map<String, String> settings,
    List<SettingItem> settingDefinitions,
  ) {
    final definitions = {
      for (final item in settingDefinitions) item.key: item,
    };
    final validated = <String, String>{};

    for (final entry in settings.entries) {
      final item = definitions[entry.key];
      if (item == null || entry.key.startsWith('_unmatched_')) continue;
      final value = entry.value.trim();
      if (value.isEmpty) continue;

      final options = item.options;
      if (options != null && options.isNotEmpty) {
        if (options.contains(value)) validated[entry.key] = value;
        continue;
      }

      if (item.type == 'number') {
        var numericText = value.replaceAll(',', '.');
        final unit = item.unit;
        if (unit != null && unit.isNotEmpty) {
          numericText = numericText.replaceAll(unit, '');
        }
        numericText = cleanValue(numericText);
        final number = double.tryParse(numericText);
        if (number == null || !number.isFinite) continue;

        final minValue = item.constraints['min'];
        final maxValue = item.constraints['max'];
        final stepValue = item.constraints['step'];
        final min = minValue is num ? minValue.toDouble() : null;
        final max = maxValue is num ? maxValue.toDouble() : null;
        final step = stepValue is num ? stepValue.toDouble().abs() : null;
        if ((min != null && (!min.isFinite || number < min)) ||
            (max != null && (!max.isFinite || number > max))) {
          continue;
        }
        if (step != null) {
          if (!step.isFinite || step <= 0 || min == null) continue;
          final stepsFromMin = (number - min) / step;
          if ((stepsFromMin - stepsFromMin.round()).abs() > 0.000001) {
            continue;
          }
        }

        validated[entry.key] = number == number.truncateToDouble()
            ? number.toInt().toString()
            : number.toString();
        continue;
      }

      if (item.type == 'text' && value.length <= 500) {
        validated[entry.key] = value;
      }
    }

    return validated;
  }

  static String? findLocalMatch(
    String rawValue,
    List<String> availableOptions,
  ) {
    final cleanRawValue =
        rawValue.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');

    for (final option in availableOptions) {
      if (option.toLowerCase() == rawValue.toLowerCase()) {
        return option;
      }
    }

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

    for (final option in availableOptions) {
      final cleanOption = option.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (calculateStringSimilarity(cleanRawValue, cleanOption) > 0.5) {
        return option;
      }
      if (cleanRawValue.contains(cleanOption) ||
          cleanOption.contains(cleanRawValue)) {
        return option;
      }
    }

    return null;
  }

  static double calculateStringSimilarity(String str1, String str2) {
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final longer = str1.length > str2.length ? str1 : str2;
    final shorter = str1.length > str2.length ? str2 : str1;
    if (longer.isEmpty) return 1.0;

    final editDistance = levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  static int levenshteinDistance(String str1, String str2) {
    final matrix = List.generate(
      str1.length + 1,
      (i) => List.generate(str2.length + 1, (j) => 0),
    );

    for (var i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= str1.length; i++) {
      for (var j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[str1.length][str2.length];
  }

  static String cleanValue(String value) {
    var cleanedValue = value.replaceAll(RegExp(r'[()（）\[\]]'), '').trim();
    cleanedValue = cleanedValue
        .replaceAll(RegExp(r'(mm|°|度|φ|T|g|#|点|ポイント)\s*$'), '')
        .trim();

    if (RegExp(r'^-?[0-9]+\.?[0-9]*$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }
    if (RegExp(r'^[0-9]+-[0-9]+$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }
    return value.trim();
  }
}
