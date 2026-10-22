import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/app/app_theme.dart';
import 'package:rc_setting_manager/pages/settings_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/services/api_consent_service.dart';
import 'package:rc_setting_manager/services/ai_configuration_service.dart';
import 'package:rc_setting_manager/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.android,
}) async {
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService?>.value(value: null),
      ],
      child: MaterialApp(
        theme:
            (brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
                .copyWith(platform: platform),
        home: const SettingsPage(),
      ),
    ),
  );

  for (var i = 0; i < 50 && !settingsProvider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

Element _nearestMaterial(WidgetTester tester, Finder finder) {
  final material = find.ancestor(of: finder, matching: find.byType(Material));
  expect(material, findsWidgets);
  return tester.element(material.first);
}

void _expectMaterialIsInsideSettingsList(
  WidgetTester tester,
  Finder itemFinder,
) {
  final materialElement = _nearestMaterial(tester, itemFinder);
  var insideList = false;
  materialElement.visitAncestorElements((ancestor) {
    if (ancestor.widget is ListView) {
      insideList = true;
      return false;
    }
    return true;
  });
  expect(insideList, isTrue, reason: '設定項目の Material が ListView の外側にあります');
}

Future<void> _dragToOverscroll(
  WidgetTester tester, {
  required bool fromBottom,
  required TargetPlatform platform,
}) async {
  final list = find.byType(ListView);
  final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
  final position = scrollable.position;
  if (fromBottom) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }

  final gesture = await tester.startGesture(
    tester.getCenter(list),
  );
  await gesture.moveBy(Offset(0, fromBottom ? -24 : 24));
  await tester.pump();
  await gesture.moveBy(Offset(0, fromBottom ? -180 : 180));
  await tester.pump(const Duration(milliseconds: 100));
  _expectMaterialIsInsideSettingsList(
    tester,
    find.text(fromBottom ? 'アプリについて' : 'ダークモード'),
  );
  if (platform == TargetPlatform.iOS) {
    expect(position.outOfRange, isTrue,
        reason: '端のドラッグでバウンスのオーバースクロールが発生していません');
  } else {
    // Android は位置を範囲内に保ち、StretchingOverscrollIndicator が伸縮を描画する。
    expect(
      find.descendant(
        of: list,
        matching: find.byType(StretchingOverscrollIndicator),
      ),
      findsOneWidget,
      reason: 'Android の伸縮オーバースクロール表示が設定されていません',
    );
    expect(
      tester.widget<StretchEffect>(find.byType(StretchEffect)).stretchStrength,
      isNot(0),
      reason: '端のドラッグで伸縮が発生していません',
    );
    expect(
      position.pixels,
      fromBottom ? position.maxScrollExtent : position.minScrollExtent,
    );
  }
  await gesture.up();
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

  for (final brightness in Brightness.values) {
    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      testWidgets(
          'setting tiles scroll with their Material: ${brightness.name} ${platform.name}',
          (tester) async {
        await _pumpSettingsPage(
          tester,
          brightness: brightness,
          platform: platform,
        );

        final darkMode = find.text('ダークモード');
        final displaySettings = find.text('表示設定');
        _expectMaterialIsInsideSettingsList(tester, darkMode);
        _expectMaterialIsInsideSettingsList(tester, displaySettings);

        await _dragToOverscroll(
          tester,
          fromBottom: false,
          platform: platform,
        );
        await _dragToOverscroll(
          tester,
          fromBottom: true,
          platform: platform,
        );

        // 条件付き項目も同じ描画階層に置かれることを確認する。
        final configuration = AiConfigurationService();
        await configuration.unlockDeveloperMode();
        await configuration.setDeveloperModeEnabled(true);
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpSettingsPage(
          tester,
          brightness: brightness,
          platform: platform,
        );
        final developerMode = find.text('開発者モード');
        final personalApi = find.text('個人AI API設定');
        await tester.scrollUntilVisible(developerMode, 100);
        await tester.pumpAndSettle();
        expect(developerMode, findsOneWidget);
        _expectMaterialIsInsideSettingsList(tester, developerMode);
        await tester.scrollUntilVisible(personalApi, 100);
        await tester.pumpAndSettle();
        expect(personalApi, findsOneWidget);
        _expectMaterialIsInsideSettingsList(tester, personalApi);
      });
    }
  }
}
