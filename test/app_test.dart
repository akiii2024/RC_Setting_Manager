import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/app/app.dart';
import 'package:rc_setting_manager/app/app_bootstrap.dart';
import 'package:rc_setting_manager/pages/home_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/providers/theme_provider.dart';
import 'package:rc_setting_manager/services/auth_service.dart';

Widget _withAppDependencies({
  required AppModeProvider mode,
  required SettingsProvider settings,
  Widget child = const MyApp(),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModeProvider>.value(value: mode),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      Provider<AuthService?>.value(value: null),
    ],
    child: child,
  );
}

Future<void> _pumpUntilInitialized(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var i = 0; i < 500 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(provider.isInitialized, isTrue);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'online_mode': false,
    });
  });

  testWidgets('application root preserves locale, routes, and offline home',
      (tester) async {
    final mode = AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    );
    final settings = SettingsProvider(appModeProvider: mode);

    await tester.pumpWidget(
      _withAppDependencies(
        mode: mode,
        settings: settings,
      ),
    );
    await _pumpUntilInitialized(tester, settings);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('en', 'US'));
    expect(materialApp.routes, contains('/car-selection'));
    expect(materialApp.routes, contains('/settings'));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('online preference offers recovery while Firebase is unavailable',
      (tester) async {
    final mode = AppModeProvider(
      preferredOnline: true,
      isFirebaseReady: false,
    );
    final settings = SettingsProvider(appModeProvider: mode);

    await tester.pumpWidget(
      _withAppDependencies(
        mode: mode,
        settings: settings,
        child: const MaterialApp(home: AuthWrapper()),
      ),
    );
    await _pumpUntilInitialized(tester, settings);

    expect(find.text('Online mode is not ready.'), findsOneWidget);
    expect(find.byKey(const Key('online-mode-retry')), findsOneWidget);
    expect(find.byKey(const Key('online-mode-use-offline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('online-mode-use-offline')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('online preference shows progress only during initialization',
      (tester) async {
    final mode = AppModeProvider(
      preferredOnline: true,
      isFirebaseReady: false,
      isInitializingFirebase: true,
    );
    final settings = SettingsProvider(appModeProvider: mode);

    await tester.pumpWidget(
      _withAppDependencies(
        mode: mode,
        settings: settings,
        child: const MaterialApp(home: AuthWrapper()),
      ),
    );
    await _pumpUntilInitialized(tester, settings);

    expect(find.text('Loading online mode...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('online-mode-retry')), findsNothing);
  });

  testWidgets('failed online retry returns to actionable recovery controls',
      (tester) async {
    final mode = _FailingOnlineAppModeProvider();
    final settings = SettingsProvider(appModeProvider: mode);

    await tester.pumpWidget(
      _withAppDependencies(
        mode: mode,
        settings: settings,
        child: const MaterialApp(home: AuthWrapper()),
      ),
    );
    await _pumpUntilInitialized(tester, settings);

    await tester.tap(find.byKey(const Key('online-mode-retry')));
    await tester.pumpAndSettle();

    expect(
      find.text('Online mode could not be initialized.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('online-mode-retry')), findsOneWidget);
    expect(find.byKey(const Key('online-mode-use-offline')), findsOneWidget);
  });

  testWidgets('auth provider mode switch preserves the navigator subtree',
      (tester) async {
    SharedPreferences.setMockInitialValues({'online_mode': true});
    final mode = AppModeProvider(
      preferredOnline: true,
      isFirebaseReady: true,
    );
    final authService = _RecordingAuthService();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppModeProvider>.value(
        value: mode,
        child: ApplicationAuthScope(
          authServiceFactory: () => authService,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            routes: {
              '/': (_) => const Scaffold(body: Text('first route')),
              '/second': (_) => const Scaffold(body: Text('second route')),
            },
          ),
        ),
      ),
    );
    navigatorKey.currentState!.pushNamed('/second');
    await tester.pumpAndSettle();
    expect(find.text('second route'), findsOneWidget);

    await mode.setOffline();
    await tester.pumpAndSettle();

    expect(find.text('second route'), findsOneWidget);
    expect(find.text('first route'), findsNothing);
    expect(authService.disposeCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    mode.dispose();
  });
}

class _RecordingAuthService extends AuthService {
  _RecordingAuthService()
      : super(authStateChanges: const Stream<User?>.empty());

  var disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

class _FailingOnlineAppModeProvider extends AppModeProvider {
  _FailingOnlineAppModeProvider()
      : super(
          preferredOnline: true,
          isFirebaseReady: false,
        );

  @override
  Future<void> setOnlineAndInit() async {
    throw StateError('Firebase initialization failed');
  }
}
