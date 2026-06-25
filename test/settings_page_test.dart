import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/pages/settings_page.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/services/api_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettingsPage(WidgetTester tester) async {
  final settingsProvider = SettingsProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );

  for (var i = 0; i < 50 && !settingsProvider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'language_settings': false,
    });
    ApiConsentService.resetPendingRequestsForTesting();
  });

  testWidgets('suppressed location prompt can be restored from settings',
      (tester) async {
    await ApiConsentService.suppressPrompt(
      ApiConsentType.weatherAndLocation,
    );
    await _pumpSettingsPage(tester);

    await tester.scrollUntilVisible(
      find.text('位置情報・天気サービス'),
      200,
    );
    await tester.pumpAndSettle();

    expect(find.text('利用しない（確認画面を表示しません）'), findsOneWidget);

    await tester.tap(find.text('位置情報・天気サービス'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('利用時に確認する'));
    await tester.pumpAndSettle();

    expect(
      await ApiConsentService.isPromptSuppressed(
        ApiConsentType.weatherAndLocation,
      ),
      isFalse,
    );
    expect(
      await ApiConsentService.hasConsent(
        ApiConsentType.weatherAndLocation,
      ),
      isFalse,
    );
    final locationTile = find.ancestor(
      of: find.text('位置情報・天気サービス'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: locationTile,
        matching: find.text('利用時に確認します'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Gemini consent can be revoked from settings', (tester) async {
    await ApiConsentService.grantConsent(
      ApiConsentType.aiAndOcr,
    );
    await _pumpSettingsPage(tester);

    await tester.scrollUntilVisible(
      find.text('Gemini（AI・OCR）'),
      200,
    );
    await tester.pumpAndSettle();

    expect(find.text('AIアドバイス・OCRの利用に同意済みです'), findsOneWidget);

    await tester.tap(find.text('Gemini（AI・OCR）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意を取り消す'));
    await tester.pumpAndSettle();

    expect(
      await ApiConsentService.hasConsent(ApiConsentType.aiAndOcr),
      isFalse,
    );
    final geminiTile = find.ancestor(
      of: find.text('Gemini（AI・OCR）'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: geminiTile,
        matching: find.text('利用時に確認します'),
      ),
      findsOneWidget,
    );
  });
}
