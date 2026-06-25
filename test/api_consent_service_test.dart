import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/api_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConsentService.resetPendingRequestsForTesting();
  });

  test('consent is stored separately for each API category', () async {
    expect(
      await ApiConsentService.hasConsent(ApiConsentType.weatherAndLocation),
      isFalse,
    );
    expect(
      await ApiConsentService.hasConsent(ApiConsentType.aiAndOcr),
      isFalse,
    );

    await ApiConsentService.grantConsent(
      ApiConsentType.weatherAndLocation,
    );

    expect(
      await ApiConsentService.hasConsent(ApiConsentType.weatherAndLocation),
      isTrue,
    );
    expect(
      await ApiConsentService.hasConsent(ApiConsentType.aiAndOcr),
      isFalse,
    );
  });

  testWidgets('weather consent dialog stores agreement',
      (WidgetTester tester) async {
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    final request = ApiConsentService.requestConsent(
      pageContext,
      type: ApiConsentType.weatherAndLocation,
      isEnglish: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('位置情報・天気サービスの利用'), findsOneWidget);
    expect(find.text('同意して続ける'), findsOneWidget);

    await tester.tap(find.text('同意して続ける'));
    await tester.pumpAndSettle();

    expect(await request, isTrue);
    expect(
      await ApiConsentService.hasConsent(ApiConsentType.weatherAndLocation),
      isTrue,
    );
  });

  testWidgets('AI consent dialog does not store cancellation',
      (WidgetTester tester) async {
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    final request = ApiConsentService.requestConsent(
      pageContext,
      type: ApiConsentType.aiAndOcr,
      isEnglish: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('AI・OCRサービスの利用'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(await request, isFalse);
    expect(
      await ApiConsentService.hasConsent(ApiConsentType.aiAndOcr),
      isFalse,
    );
  });
}
