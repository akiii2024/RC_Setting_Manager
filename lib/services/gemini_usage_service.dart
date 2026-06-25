import 'package:flutter/foundation.dart';

import 'firebase_functions_service.dart';

class GeminiLimitUsage {
  final int limit;
  final int used;
  final int remaining;
  final DateTime resetAt;

  const GeminiLimitUsage({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetAt,
  });

  factory GeminiLimitUsage.fromMap(Map<String, dynamic> map) {
    final resetAtMilliseconds = (map['resetAt'] as num?)?.toInt() ?? 0;
    return GeminiLimitUsage(
      limit: (map['limit'] as num?)?.toInt() ?? 0,
      used: (map['used'] as num?)?.toInt() ?? 0,
      remaining: (map['remaining'] as num?)?.toInt() ?? 0,
      resetAt: DateTime.fromMillisecondsSinceEpoch(
        resetAtMilliseconds,
        isUtc: true,
      ).toLocal(),
    );
  }
}

class GeminiUsageStatus {
  final GeminiLimitUsage burst;
  final GeminiLimitUsage daily;

  const GeminiUsageStatus({
    required this.burst,
    required this.daily,
  });

  factory GeminiUsageStatus.fromMap(Map<String, dynamic> map) {
    return GeminiUsageStatus(
      burst: GeminiLimitUsage.fromMap(
        Map<String, dynamic>.from(map['burst'] as Map),
      ),
      daily: GeminiLimitUsage.fromMap(
        Map<String, dynamic>.from(map['daily'] as Map),
      ),
    );
  }
}

class GeminiUsageService {
  GeminiUsageService._();

  static final ValueNotifier<GeminiUsageStatus?> usage =
      ValueNotifier<GeminiUsageStatus?>(null);

  static Future<GeminiUsageStatus> refresh() async {
    final response = await FirebaseFunctionsService.call(
      'getGeminiUsage',
      const {},
    );
    final status = _parseResponse(response);
    usage.value = status;
    return status;
  }

  static void updateFromResponse(Map<String, dynamic> response) {
    final usageData = response['usage'];
    if (usageData is! Map) {
      return;
    }

    usage.value = GeminiUsageStatus.fromMap(
      Map<String, dynamic>.from(usageData),
    );
  }

  static GeminiUsageStatus _parseResponse(Map<String, dynamic> response) {
    final usageData = response['usage'];
    if (usageData is! Map) {
      throw StateError('Gemini usage information is unavailable.');
    }
    return GeminiUsageStatus.fromMap(
      Map<String, dynamic>.from(usageData),
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    usage.value = null;
  }
}
