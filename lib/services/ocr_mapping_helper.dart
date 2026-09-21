import '../models/car_setting_definition.dart';

/// OCR結果のローカル照合と、インポート前の値検証を行う純粋ロジック。
class OcrMappingHelper {
  const OcrMappingHelper._();

  static Map<String, dynamic> validateSettingsForImport(
    Map<String, dynamic> settings,
    List<SettingItem> settingDefinitions,
  ) {
    final definitions = {
      for (final item in settingDefinitions) item.key: item,
    };
    final validated = <String, dynamic>{};

    for (final entry in settings.entries) {
      final item = definitions[entry.key];
      if (item == null || entry.key.startsWith('_unmatched_')) continue;
      final value = entry.value;

      if (item.type == 'grid') {
        final points = _validatedGridPoints(value, item.constraints);
        if (points != null) validated[entry.key] = points;
        continue;
      }

      if (value is! String || value.trim().isEmpty) continue;
      final textValue = value.trim();

      final options = item.options;
      if (item.type == 'select' && options != null && options.isNotEmpty) {
        final match = findLocalMatch(textValue, options);
        if (match != null) validated[entry.key] = match;
        continue;
      }

      if (item.type == 'number') {
        var numericText = _normalizeFullWidth(textValue).replaceAll(',', '.');
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

      final configuredMaxLength = item.constraints['maxLength'];
      final maxLength = configuredMaxLength is num
          ? configuredMaxLength.toInt().clamp(1, 2000)
          : 500;
      if (item.type == 'text' && textValue.length <= maxLength) {
        validated[entry.key] = textValue;
      }
    }

    return validated;
  }

  static String? findLocalMatch(
    String rawValue,
    List<String> availableOptions,
  ) {
    if (availableOptions.isEmpty) return null;
    final normalizedRaw = _normalizeFullWidth(rawValue).trim().toLowerCase();
    final cleanRawValue = _normalizedComparable(normalizedRaw);

    for (final option in availableOptions) {
      if (_normalizeFullWidth(option).trim().toLowerCase() == normalizedRaw ||
          _normalizedComparable(option) == cleanRawValue) {
        return option;
      }
    }

    final semanticAlias = switch (cleanRawValue) {
      'asphalt' => 'アスファルト',
      'carpet' => 'カーペット',
      'carbon' => 'カーボン',
      'aluminum' || 'aluminium' || 'alu' => 'アルミ',
      'plastic' => 'プラスチック',
      _ => null,
    };
    if (semanticAlias != null) {
      for (final option in availableOptions) {
        if (_normalizedComparable(option) ==
            _normalizedComparable(semanticAlias)) {
          return option;
        }
      }
    }

    final rawNumbers =
        RegExp(r'[0-9]+\.?[0-9]*').allMatches(normalizedRaw).toList();
    if (rawNumbers.isNotEmpty) {
      final numericMatches = <String>[];
      final rawNumber = double.tryParse(rawNumbers.first.group(0)!);
      for (final option in availableOptions) {
        final optionNumbers =
            RegExp(r'[0-9]+\.?[0-9]*').allMatches(_normalizeFullWidth(option));
        if (optionNumbers.isNotEmpty) {
          final optionNumber = double.tryParse(optionNumbers.first.group(0)!);
          if (rawNumber != null && optionNumber == rawNumber) {
            numericMatches.add(option);
          }
        }
      }
      if (numericMatches.length == 1) return numericMatches.single;
      // 数値を含む選択肢は、同値候補が複数または0件なら類似度で推測しない。
      return null;
    }

    String? bestOption;
    var bestScore = 0.0;
    for (final option in availableOptions) {
      final cleanOption = _normalizedComparable(option);
      final score = calculateStringSimilarity(cleanRawValue, cleanOption);
      if (score > bestScore) {
        bestScore = score;
        bestOption = option;
      }
      if (cleanRawValue.contains(cleanOption) ||
          cleanOption.contains(cleanRawValue)) {
        if (cleanRawValue.length >= 3 && cleanOption.length >= 3) {
          return option;
        }
      }
    }

    return bestScore > 0.5 ? bestOption : null;
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
    final normalized = _normalizeFullWidth(value);
    var cleanedValue = normalized.replaceAll(RegExp(r'[()（）\[\]]'), '').trim();
    cleanedValue = cleanedValue
        .replaceAll(
          RegExp(
            r'(cst|mm|°|度|φ|T|g|#|点|ポイント)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (RegExp(r'^-?[0-9]+\.?[0-9]*$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }
    if (RegExp(r'^[0-9]+-[0-9]+$').hasMatch(cleanedValue)) {
      return cleanedValue;
    }
    return normalized.trim();
  }

  static List<Map<String, int>>? _validatedGridPoints(
    Object? value,
    Map<String, dynamic> constraints,
  ) {
    if (value is! List) return null;
    final rows = constraints['rows'];
    final cols = constraints['cols'];
    if (rows is! int || cols is! int || rows <= 0 || cols <= 0) return null;
    final points = <Map<String, int>>[];
    final seen = <String>{};
    for (final rawPoint in value) {
      if (rawPoint is! Map) return null;
      final row = rawPoint['row'];
      final col = rawPoint['col'];
      if (row is! int || col is! int) return null;
      if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
      if (seen.add('$row:$col')) points.add({'row': row, 'col': col});
    }
    if (points.isEmpty) return null;
    if (constraints['multiple'] != true && points.length != 1) return null;
    points.sort((a, b) {
      final rowOrder = a['row']!.compareTo(b['row']!);
      return rowOrder != 0 ? rowOrder : a['col']!.compareTo(b['col']!);
    });
    return points;
  }

  static String _normalizedComparable(String value) {
    return _normalizeFullWidth(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_.()（）\[\]/#°φΦ]'), '');
  }

  static String _normalizeFullWidth(String value) {
    const full = '０１２３４５６７８９．，－＋';
    const half = '0123456789.,-+';
    return value.split('').map((character) {
      final index = full.indexOf(character);
      return index < 0 ? character : half[index];
    }).join();
  }
}
