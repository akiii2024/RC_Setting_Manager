import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/gemini_usage_service.dart';
import 'package:rc_setting_manager/widgets/gemini_usage_indicator.dart';

void main() {
  setUp(GeminiUsageService.resetForTesting);

  test('updates displayed Gemini usage from function response', () {
    GeminiUsageService.updateFromResponse({
      'usage': {
        'burst': {
          'limit': 10,
          'used': 3,
          'remaining': 7,
          'resetAt': 1782380000000,
        },
        'daily': {
          'limit': 20,
          'used': 8,
          'remaining': 12,
          'resetAt': 1782399600000,
        },
      },
    });

    final usage = GeminiUsageService.usage.value;
    expect(usage, isNotNull);
    expect(usage!.burst.remaining, 7);
    expect(usage.burst.limit, 10);
    expect(usage.daily.remaining, 12);
    expect(usage.daily.limit, 20);
  });

  testWidgets('indicator displays daily and short-term remaining counts',
      (WidgetTester tester) async {
    GeminiUsageService.updateFromResponse({
      'usage': {
        'burst': {
          'limit': 10,
          'used': 4,
          'remaining': 6,
          'resetAt': 1782380000000,
        },
        'daily': {
          'limit': 20,
          'used': 9,
          'remaining': 11,
          'resetAt': 1782399600000,
        },
      },
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeminiUsageIndicator(isEnglish: false),
        ),
      ),
    );

    expect(find.textContaining('本日残り 11/20回'), findsOneWidget);
    expect(find.textContaining('10分枠 残り6/10回'), findsOneWidget);
  });
}
