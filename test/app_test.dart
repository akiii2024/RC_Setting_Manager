import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/app/app.dart';
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
  for (var i = 0; i < 50 && !provider.isInitialized; i++) {
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
    final settings = SettingsProvider();

    await tester.pumpWidget(
      _withAppDependencies(
        mode: AppModeProvider(
          preferredOnline: false,
          isFirebaseReady: false,
        ),
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

  testWidgets('online preference waits while Firebase is unavailable',
      (tester) async {
    final settings = SettingsProvider();

    await tester.pumpWidget(
      _withAppDependencies(
        mode: AppModeProvider(
          preferredOnline: true,
          isFirebaseReady: false,
        ),
        settings: settings,
        child: const MaterialApp(home: AuthWrapper()),
      ),
    );
    await _pumpUntilInitialized(tester, settings);

    expect(find.text('Loading online mode...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
