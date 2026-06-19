import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/pages/home_page.dart';
import 'package:rc_setting_manager/pages/login_page.dart';
import 'package:rc_setting_manager/pages/simple_import_page.dart';
import 'package:rc_setting_manager/pages/tools_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

Future<void> _pumpUntilInitialized(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var i = 0; i < 50; i++) {
    if (provider.isInitialized) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 10));
  }

  fail('SettingsProvider did not initialize in time.');
}

Car _testCar({bool isInGarage = false, bool suppressGaragePrompt = false}) {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  return Car(
    id: 'tamiya/trf421',
    name: 'TRF421',
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
    isInGarage: isInGarage,
    suppressGaragePrompt: suppressGaragePrompt,
  );
}

void main() {
  testWidgets('Home page includes My Garage tab and empty state',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);

    await tester.tap(find.text('Garage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Your garage is empty'), findsOneWidget);
  });

  testWidgets('Home page does not show the my machines section',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    expect(find.text('My machines'), findsNothing);
    expect(find.text('TRF421'), findsNothing);
  });

  testWidgets('offline welcome hides Firebase login controls',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final settingsProvider = SettingsProvider();
    final appModeProvider = AppModeProvider(
      preferredOnline: false,
      isFirebaseReady: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: appModeProvider),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await _pumpUntilInitialized(tester, settingsProvider);
    await tester.pump();

    expect(find.text('Start offline'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Continue as Guest'), findsNothing);
    expect(find.text('Use online (Beta)'), findsNothing);
  });

  testWidgets('tools restore opens simple import page',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ToolsPage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SimpleImportPage), findsOneWidget);
  });
}
