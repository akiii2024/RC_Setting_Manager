import '../models/ai_advisor.dart';

/// AIアドバイザーの構造化応答を、アプリで安全に扱える形へ正規化する。
///
/// 通信や認証には依存せず、応答内容と現在のセッティング定義だけを使う。
class AiAdvisorResponseNormalizer {
  const AiAdvisorResponseNormalizer._();

  static Map<String, dynamic> normalizeChatResponse(
    Map<String, dynamic> response,
  ) {
    return {
      'message': _outputString(response['message'], 'message', 4000),
      'readyForAdvice': response['readyForAdvice'] == true,
      'missingTopics': _outputStringList(
        response['missingTopics'],
        'missingTopics',
        3,
        200,
      ),
    };
  }

  static Map<String, dynamic> normalizeFinalResponse(
    Map<String, dynamic> response,
    AIAdvisorContext context,
  ) {
    final confidence =
        {'low', 'medium', 'high'}.contains(response['confidence'])
            ? response['confidence'] as String
            : 'low';
    return {
      'summary': _outputString(response['summary'], 'summary', 4000),
      'confidence': confidence,
      'evidence': _outputStringList(
        response['evidence'],
        'evidence',
        5,
        800,
      ),
      'missingInformation': _outputStringList(
        response['missingInformation'],
        'missingInformation',
        5,
        500,
      ),
      'changes': _validatedChanges(response['changes'], context),
      'manualTips': _outputStringList(
        response['manualTips'],
        'manualTips',
        5,
        800,
      ),
      'testPlan': _outputString(response['testPlan'], 'testPlan', 2500),
      'drivingTips': _outputString(
        response['drivingTips'],
        'drivingTips',
        2500,
        required: false,
      ),
    };
  }

  static String _outputString(
    dynamic value,
    String name,
    int maxLength, {
    bool required = true,
  }) {
    if (value is! String) {
      throw StateError('AI応答の$nameが不正です。');
    }
    final normalized = value.trim();
    if ((required && normalized.isEmpty) || normalized.length > maxLength) {
      throw StateError('AI応答の$nameが不正です。');
    }
    return normalized;
  }

  static List<String> _outputStringList(
    dynamic value,
    String name,
    int maxItems,
    int maxLength,
  ) {
    if (value is! List) {
      throw StateError('AI応答の$nameが不正です。');
    }
    return value
        .take(maxItems)
        .map((item) => _outputString(item, name, maxLength))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _validatedChanges(
    dynamic rawChanges,
    AIAdvisorContext context,
  ) {
    if (rawChanges is! List) {
      throw StateError('AI応答のchangesが不正です。');
    }
    final currentByKey = <String, Map<String, dynamic>>{
      for (final item in context.settings)
        if (item['key'] is String) item['key'] as String: item,
    };
    final catalogByKey = <String, Map<String, dynamic>>{
      for (final item in context.settingCatalog)
        if (item['key'] is String) item['key'] as String: item,
    };
    final validated = <Map<String, dynamic>>[];

    for (final value in rawChanges.take(3)) {
      if (value is! Map) continue;
      final raw = Map<String, dynamic>.from(value);
      final key = raw['settingKey'] is String
          ? (raw['settingKey'] as String).trim()
          : '';
      final currentItem = currentByKey[key];
      final catalogItem = catalogByKey[key];
      if (currentItem == null ||
          catalogItem == null ||
          catalogItem['autoApplicable'] != true) {
        continue;
      }

      final current = _advisorNumber(currentItem['value']);
      final proposed = _advisorNumber(raw['proposedValue']);
      final min = _advisorNumber(catalogItem['min']);
      final max = _advisorNumber(catalogItem['max']);
      final step = _advisorNumber(catalogItem['step'])?.abs() ?? 0;
      if (current == null ||
          proposed == null ||
          min == null ||
          max == null ||
          step <= 0 ||
          proposed < min ||
          proposed > max) {
        continue;
      }
      const epsilon = 0.000001;
      final delta = (proposed - current).abs();
      final stepsFromMin = (proposed - min) / step;
      if (delta <= epsilon ||
          delta > step + epsilon ||
          (stepsFromMin - stepsFromMin.round()).abs() > epsilon) {
        continue;
      }

      final rawPriority = _advisorNumber(raw['priority'])?.round() ?? 3;
      validated.add({
        'settingKey': key,
        'settingLabel': catalogItem['label'] is String
            ? catalogItem['label'] as String
            : key,
        'currentValue': currentItem['value'].toString(),
        'proposedValue': proposed.toString(),
        'reason': _outputString(raw['reason'], 'changes.reason', 800),
        'expectedEffect': _outputString(
          raw['expectedEffect'],
          'changes.expectedEffect',
          800,
        ),
        'tradeoff': _outputString(
          raw['tradeoff'],
          'changes.tradeoff',
          800,
          required: false,
        ),
        'priority': rawPriority.clamp(1, 3),
      });
    }
    validated.sort(
      (left, right) =>
          (left['priority'] as int).compareTo(right['priority'] as int),
    );
    return validated;
  }

  static double? _advisorNumber(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value.trim().replaceAll(',', '.'))
            : null;
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}
