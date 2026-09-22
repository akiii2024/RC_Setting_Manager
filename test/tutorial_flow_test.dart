import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rc_setting_manager/app/app_theme.dart';
import 'package:rc_setting_manager/pages/home_page.dart';
import 'package:rc_setting_manager/pages/settings_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/repositories/tutorial_preferences_repository.dart';
import 'package:rc_setting_manager/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTutorialPreferencesRepository
    implements TutorialPreferencesRepository {
  _FakeTutorialPreferencesRepository({
    this.completed,
    this.saveResult = true,
    this.throwOnLoad = false,
  });

  bool? completed;
  bool saveResult;
  bool throwOnLoad;
  int saveCalls = 0;

  @override
  Future<bool?> load() async {
    if (throwOnLoad) throw StateError('load failed');
    return completed;
  }

  @override
  Future<bool> save(bool completed) async {
    saveCalls++;
    if (saveResult) {
      this.completed = completed;
    }
    return saveResult;
  }
}

Future<SettingsProvider> _pumpHome(
  WidgetTester tester, {
  required _FakeTutorialPreferencesRepository repository,
  bool isEnglish = true,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  SharedPreferences.setMockInitialValues({
    'language_settings': isEnglish,
  });
  final provider = SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: HomePage(tutorialPreferencesRepository: repository),
      ),
    ),
  );

  for (var i = 0; i < 50 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(provider.isInitialized, isTrue);
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('first launch shows the tutorial and completed launch skips it',
      (tester) async {
    final repository = _FakeTutorialPreferencesRepository();
    await _pumpHome(tester, repository: repository);

    expect(find.byKey(const Key('tutorial-overlay')), findsOneWidget);
    expect(find.text('Quick tour'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.completed = true;
    await _pumpHome(tester, repository: repository);

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
  });

  testWidgets('tutorial follows all eight steps and finishes on Home',
      (tester) async {
    final repository = _FakeTutorialPreferencesRepository();
    await _pumpHome(tester, repository: repository);

    await tester.tap(find.text('Garage'), warnIfMissed: false);
    await tester.pump();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);

    const expectedTitles = [
      'Manage your garage',
      'Create a setting',
      'Record a run memo',
      'Check your home',
      'Review your history',
      'Use the tools',
      'Open settings',
    ];
    const expectedDestinations = [1, 1, 1, 0, 2, 3, 3];

    for (var index = 0; index < expectedTitles.length; index++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
      expect(find.text(expectedTitles[index]), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        expectedDestinations[index],
      );
      expect(find.text('${index + 2} / 8'), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(repository.completed, isTrue);
    expect(repository.saveCalls, 1);
  });

  testWidgets('skipping the tutorial saves completion', (tester) async {
    final repository = _FakeTutorialPreferencesRepository();
    await _pumpHome(tester, repository: repository);

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(repository.completed, isTrue);
    expect(repository.saveCalls, 1);
  });

  testWidgets('system back is treated as a completed skip', (tester) async {
    final repository = _FakeTutorialPreferencesRepository();
    await _pumpHome(tester, repository: repository);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(repository.completed, isTrue);
    expect(repository.saveCalls, 1);
  });

  testWidgets('preference load failure does not block the app', (tester) async {
    final repository = _FakeTutorialPreferencesRepository(throwOnLoad: true);
    await _pumpHome(tester, repository: repository);

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('save failure closes the tutorial and explains the retry risk',
      (tester) async {
    final repository = _FakeTutorialPreferencesRepository(saveResult: false);
    await _pumpHome(tester, repository: repository);

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(
      find.text(
        'The tutorial status could not be saved. It may appear again next time.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings can replay a completed tutorial and return',
      (tester) async {
    SharedPreferences.setMockInitialValues({'language_settings': false});
    final repository = _FakeTutorialPreferencesRepository(completed: true);
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
          home: const SettingsPage(),
          routes: {
            '/tutorial': (_) => HomePage(
                  tutorialLaunchMode: TutorialLaunchMode.manualReplay,
                  tutorialPreferencesRepository: repository,
                ),
          },
        ),
      ),
    );
    for (var i = 0; i < 50 && !settingsProvider.isInitialized; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('tutorial-replay-tile')),
      300,
    );
    await tester.tap(find.byKey(const Key('tutorial-replay-tile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tutorial-overlay')), findsOneWidget);
    expect(find.text('使い方を確認'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byKey(const Key('tutorial-overlay')), findsNothing);
    expect(repository.completed, isTrue);
  });

  testWidgets('dark theme and large text fit on a phone-sized screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeTutorialPreferencesRepository();
    await _pumpHome(
      tester,
      repository: repository,
      isEnglish: false,
      theme: AppTheme.dark(),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('使い方を確認'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var i = 1; i < 8; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
