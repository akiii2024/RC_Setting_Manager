import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/pages/settings_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/services/api_consent_service.dart';
import 'package:rc_setting_manager/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  ThemeProvider? themeProvider,
  double textScale = 1,
}) async {
  final theme = themeProvider ?? await ThemeProvider.create();
  addTearDown(theme.dispose);
  final settingsProvider = SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: theme),
        Provider<AuthService?>.value(value: null),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) => MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: theme.themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
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

  testWidgets('テーマは3択から選択でき、選択した値が保存される', (tester) async {
    await _pumpSettingsPage(tester);
    expect(find.text('端末と同期'), findsOneWidget);

    for (final entry in {
      ThemeMode.light: 'ライト',
      ThemeMode.dark: 'ダーク',
      ThemeMode.system: '端末と同期',
    }.entries) {
      await tester.tap(find.text('テーマ'));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
      final dialog = find.byType(AlertDialog);
      await tester
          .tap(find.descendant(of: dialog, matching: find.text(entry.value)));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.text(entry.value), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(
          preferences.getString(
              SharedPreferencesThemePreferencesRepository.themeModeKey),
          entry.key.name);
    }
  });

  testWidgets('テーマ選択をキャンセルしても設定を変更しない', (tester) async {
    await _pumpSettingsPage(tester);
    await tester.tap(find.text('テーマ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('端末と同期'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(
        preferences.containsKey(
            SharedPreferencesThemePreferencesRepository.themeModeKey),
        isFalse);
  });

  testWidgets('テーマ保存の失敗を通知し、選択済みのテーマを維持する', (tester) async {
    final theme = await ThemeProvider.create(
      preferencesRepository: SharedPreferencesThemePreferencesRepository(
        preferencesWriter: (_, key, value) async => false,
      ),
    );
    await _pumpSettingsPage(tester, themeProvider: theme);
    await tester.tap(find.text('テーマ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();
    expect(find.text('端末への保存に失敗しました。変更は適用されていません。'), findsOneWidget);
    expect(find.text('端末と同期'), findsOneWidget);
    expect(theme.themeMode, ThemeMode.system);
  });

  testWidgets('360dpのダーク表示と文字拡大でテーマを選択できる', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pumpSettingsPage(tester, textScale: 2);
    await tester.tap(find.text('テーマ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('端末と同期'), findsNWidgets(2));
    await tester.ensureVisible(find.text('ライト'));
    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();
    expect(find.text('ライト'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('AI data consent can be revoked from settings', (tester) async {
    await ApiConsentService.grantConsent(
      ApiConsentType.aiAndOcr,
    );
    await _pumpSettingsPage(tester);

    await tester.scrollUntilVisible(
      find.text('AI・OCRのデータ送信'),
      200,
    );
    await tester.pumpAndSettle();

    expect(find.text('AIアドバイス・OCRの利用に同意済みです'), findsOneWidget);

    await tester.tap(find.text('AI・OCRのデータ送信'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意を取り消す'));
    await tester.pumpAndSettle();

    expect(
      await ApiConsentService.hasConsent(ApiConsentType.aiAndOcr),
      isFalse,
    );
    final aiConsentTile = find.ancestor(
      of: find.text('AI・OCRのデータ送信'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: aiConsentTile,
        matching: find.text('利用時に確認します'),
      ),
      findsOneWidget,
    );
  });
}
