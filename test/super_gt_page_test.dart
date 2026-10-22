import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/super_gt.dart';
import 'package:rc_setting_manager/app/app_theme.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/pages/super_gt_page.dart';
import 'package:rc_setting_manager/pages/tools_page.dart';
import 'package:rc_setting_manager/repositories/settings_local_repository.dart';

SettingsProvider _provider() => SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
      ),
    );

Future<void> _ready(SettingsProvider provider) async {
  await provider.initialization;
  expect(provider.isInitialized, isTrue);
}

Car _car(SettingsProvider provider) => provider.cars.first;

Future<void> _pumpPage(WidgetTester tester, SettingsProvider provider,
    {Map<String, dynamic> initialSettings = const {},
    String? parentId,
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1,
    Key? pageKey}) async {
  await tester.pumpWidget(ChangeNotifierProvider<SettingsProvider>.value(
    value: provider,
    child: MaterialApp(
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SuperGtPage(
        key: pageKey,
        car: _car(provider),
        initialSettings: initialSettings,
        parentSettingId: parentId,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _pageScrollable() => find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollPageTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 500, scrollable: _pageScrollable());
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('測定値からモーター回転数と変更後タイヤ回転数を表示する', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    await _enter(tester, 'measuredRatio', '5.3');
    await _enter(tester, 'measuredTireRpm', '4000');
    expect(find.textContaining('推定モーター回転数 21200.0 rpm'), findsOneWidget);

    await _enter(tester, 'targetRatio', '5.5');
    expect(find.textContaining('予測タイヤ回転数 3854.5 rpm'), findsOneWidget);
    await _enter(tester, 'targetRatio', '5.8');
    expect(find.textContaining('予測タイヤ回転数 3655.2 rpm'), findsOneWidget);
    await _enter(tester, 'targetRatio', '5.5');
    expect(find.textContaining('予測タイヤ回転数 3854.5 rpm'), findsOneWidget);
    expect(find.textContaining('推定モーター回転数 21200.0 rpm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存時に元設定を残し、測定値と親設定を保存して再読込できる', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    final car = _car(provider);
    const baseSettings = <String, dynamic>{'spurGear': 64, 'pinionGear': 20};
    final baseResult =
        await provider.addSetting('Base setup', car, baseSettings);
    final base = provider.savedSettings.single;

    await _pumpPage(tester, provider,
        initialSettings: baseSettings, parentId: base.id);
    await _enter(tester, 'measuredRatio', '5.3');
    await _enter(tester, 'measuredTireRpm', '4000');
    await _enter(tester, 'targetRatio', '5.5');
    await tester.tap(find.byKey(const ValueKey('saveMeasurement')));
    await tester.pumpAndSettle();

    expect(baseResult, isNotNull);
    expect(provider.savedSettings, hasLength(2));
    final saved = provider.savedSettings.first;
    expect(saved.parentSettingId, base.id);
    expect(saved.settings['spurGear'], 64);
    final measurement = saved.settings[SuperGtMeasurement.settingKey];
    expect(measurement, isA<Map>());
    expect((measurement as Map)['inferredMotorRpm'], 21200.0);
    expect(measurement['predictionFinalDriveRatio'], 5.5);
    expect(base.settings, baseSettings);

    final reloaded = _provider();
    await _ready(reloaded);
    addTearDown(reloaded.dispose);
    expect(reloaded.savedSettings, hasLength(2));
    final reloadedMeasurement = reloaded
        .savedSettings.first.settings[SuperGtMeasurement.settingKey] as Map;
    expect(reloadedMeasurement['inferredMotorRpm'], 21200.0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpPage(tester, reloaded,
        initialSettings: reloaded.savedSettings.first.settings,
        parentId: reloaded.savedSettings.first.id);
    expect(find.byKey(const ValueKey('measuredRatio')), findsOneWidget);
    expect(find.byKey(const ValueKey('targetRatio')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('measuredRatio')))
          .controller
          ?.text,
      '5.3',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('targetRatio')))
          .controller
          ?.text,
      '5.5',
    );
  });

  testWidgets('内部減速比を含む歯数計算を予測側だけに反映する', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);
    await _enter(tester, 'measuredRatio', '5.3');
    await _enter(tester, 'measuredTireRpm', '4000');
    final expansion = find.text('変更後のギヤ歯数から計算');
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '内部減速比'))
          .controller!
          .text,
      '1.85',
    );
    for (final entry
        in {'スパーギヤ（歯数）': '100', 'ピニオンギヤ（歯数）': '40', '内部減速比': '2.2'}.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    final calculate = find.text('最終減速比を計算');
    await tester.ensureVisible(calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('targetRatio')))
            .controller!
            .text,
        '5.5');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('measuredRatio')))
            .controller!
            .text,
        '5.3');
    expect(find.text('予測タイヤ回転数 3854.5 rpm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('車両切替を取り消すと選択表示と測定値を保持する', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);
    await _enter(tester, 'measuredRatio', '5.3');
    final carPicker = find.byWidgetPredicate((widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == '車両');
    await tester.ensureVisible(carPicker);
    await tester.tap(carPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text(provider.cars[1].name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('入力に戻る'));
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<String>>(carPicker).value,
        provider.cars.first.id);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('measuredRatio')))
            .controller!
            .text,
        '5.3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('負数・NaN・Infinity・0は保存せず例外を出さない', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    for (final value in ['-1', 'NaN', 'Infinity', '0']) {
      await _enter(tester, 'measuredRatio', value);
      await _enter(tester, 'measuredTireRpm', '4000');
      await tester.tap(find.byKey(const ValueKey('saveMeasurement')));
      await tester.pump();
      expect(provider.savedSettings, isEmpty, reason: value);
      expect(tester.takeException(), isNull, reason: value);
    }
  });

  testWidgets('測定保存に失敗しても入力を保持し、再操作できる', (tester) async {
    var failWrites = false;
    final repository = SharedPreferencesSettingsLocalRepository(
      stringWriter: (preferences, key, value) async {
        if (failWrites) return false;
        return preferences.setString(key, value);
      },
    );
    final provider = SettingsProvider(
      appModeProvider: AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
      ),
      localRepository: repository,
    );
    await _ready(provider);
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);
    await _enter(tester, 'measuredRatio', '5.3');
    await _enter(tester, 'measuredTireRpm', '4000');
    failWrites = true;

    await tester.tap(find.byKey(const ValueKey('saveMeasurement')));
    await tester.pumpAndSettle();
    expect(provider.savedSettings, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('measuredRatio')))
          .controller
          ?.text,
      '5.3',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('measuredTireRpm')))
          .controller
          ?.text,
      '4000',
    );
    expect(find.text('端末への保存に失敗しました。変更は適用されていません。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('saveMeasurement')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ToolsPageのSUPER GTカードからページを開ける', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<SettingsProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ToolsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    final cardTitle = find.text('SUPER GT レギュレーション');
    await tester.ensureVisible(cardTitle);
    await tester.tap(cardTitle);
    await tester.pumpAndSettle();
    expect(find.text('SUPER GT レギュレーション'), findsOneWidget);
    expect(find.byKey(const ValueKey('measuredRatio')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存済みmeasurementの復元と狭い画面・テーマでのスクロールに失敗しない', (tester) async {
    final provider = _provider();
    await _ready(provider);
    addTearDown(provider.dispose);
    final measurement = SuperGtMeasurement(
      measuredAt: DateTime(2026, 6, 19),
      rules: SuperGtRuleProfile.hobbywingA,
      finalDriveRatio: 5.3,
      tireRpm: 4000,
    ).toJson();
    measurement['inferredMotorRpm'] = 21200.0;
    measurement['predictionFinalDriveRatio'] = 5.5;
    final initial = <String, dynamic>{
      'motor': 'Hobbywing',
      SuperGtMeasurement.settingKey: measurement,
    };

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpPage(tester, provider, initialSettings: initial);
    await _scrollPageTo(tester, find.byKey(const ValueKey('measurementName')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('measuredRatio')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpPage(tester, provider,
        initialSettings: initial,
        themeMode: ThemeMode.dark,
        textScale: 1.5,
        pageKey: const ValueKey('dark-super-gt-page'));
    await _scrollPageTo(tester, find.byKey(const ValueKey('measurementName')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
