import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/pages/home_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  final provider = SettingsProvider(
    appModeProvider: AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: HomePage()),
    ),
  );
  for (var i = 0; i < 50 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(provider.isInitialized, isTrue);
  await tester.pump();
}

Finder _appBarText(String text) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(text),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'language_settings': true});
  });

  testWidgets('bottom navigation keeps destination titles aligned',
      (tester) async {
    await _pumpHome(tester);
    expect(_appBarText('Home'), findsOneWidget);

    await tester.tap(find.text('Garage'));
    await tester.pump();
    expect(_appBarText('My Garage'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pump();
    expect(_appBarText('History'), findsOneWidget);

    await tester.tap(find.text('Tools'));
    await tester.pump();
    expect(_appBarText('Tools'), findsOneWidget);
  });
}
