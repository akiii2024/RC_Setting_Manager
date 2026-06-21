import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/track_location.dart';
import 'package:rc_setting_manager/pages/home_page.dart';
import 'package:rc_setting_manager/pages/login_page.dart';
import 'package:rc_setting_manager/pages/quick_run_log_page.dart';
import 'package:rc_setting_manager/pages/simple_import_page.dart';
import 'package:rc_setting_manager/pages/tools_page.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';
import 'package:rc_setting_manager/services/weather_service.dart';

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

TrackLocation _testTrack({
  String name = 'Test Course',
  String prefecture = 'Tokyo',
  String address = '1-2-3 Test',
}) {
  return TrackLocation(
    name: name,
    latitude: 35.0,
    longitude: 139.0,
    radius: 1000,
    prefecture: prefecture,
    address: address,
    type: 'indoor',
    surfaceType: 'carpet',
    description: 'Indoor carpet course',
    website: 'https://example.com',
    phone: '000-0000-0000',
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

  testWidgets('home add action opens quick run log and validates best lap',
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

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Run Memo'), findsOneWidget);

    await tester.tap(find.text('Run Memo'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickRunLogPage), findsOneWidget);

    await tester.tap(find.text('Save Run Log'));
    await tester.pump();

    expect(find.text('Enter best lap as 13.52 or 0:13.52.'), findsOneWidget);
  });

  testWidgets('quick run log fills weather conditions automatically',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();
    final weather = WeatherData(
      temperature: 24.6,
      humidity: 58,
      description: 'Sunny',
      feelsLike: 25.1,
      pressure: 1012,
      visibility: 9000,
      windSpeed: 2.4,
      windDirection: 120,
      cloudiness: 15,
      cityName: 'Test Track',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QuickRunLogPage(
            weatherFetcher: ({bool forceRefresh = false}) async => weather,
          ),
        ),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();
    await tester.pump();

    expect(find.text('24.6'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('Sunny'), findsAtLeastNWidgets(1));
    expect(find.textContaining('24.6 C / 58%'), findsOneWidget);

    await tester.ensureVisible(find.text('Very good'));
    await tester.pump();
    await tester.tap(find.text('Very good'));
    await tester.enterText(
        find.bySemanticsLabel('Track Condition Note'), 'dusty');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Best Lap'), '13.52');
    await tester.tap(find.text('Save Run Log'));
    await tester.pump();

    expect(provider.runLogs, hasLength(1));
    expect(provider.runLogs.first.weatherCondition, 'Sunny');
    expect(provider.runLogs.first.trackCondition, 'Very good - dusty');
  });

  testWidgets('quick run log saves selected course name from database',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();
    final track = _testTrack(name: 'Test Course Alpha');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QuickRunLogPage(
            weatherFetcher: ({bool forceRefresh = false}) async => null,
            trackSearchLoader: () async => [track],
          ),
        ),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Course Name'), 'Alpha');
    await tester.pump();
    await tester.tap(find.text('Test Course Alpha'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Best Lap'), '13.52');
    await tester.tap(find.text('Save Run Log'));
    await tester.pump();

    expect(provider.runLogs, hasLength(1));
    expect(provider.runLogs.first.trackName, 'Test Course Alpha');
  });

  testWidgets('quick run log saves free text course name',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QuickRunLogPage(
            weatherFetcher: ({bool forceRefresh = false}) async => null,
            trackSearchLoader: () async => const [],
          ),
        ),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Course Name'), 'Parking Lot');
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Best Lap'), '13.52');
    await tester.tap(find.text('Save Run Log'));
    await tester.pump();

    expect(provider.runLogs, hasLength(1));
    expect(provider.runLogs.first.trackName, 'Parking Lot');
  });

  testWidgets('quick run log fills course name from current location',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'language_settings': true,
      'cars_settings': jsonEncode([_testCar().toJson()]),
    });

    final provider = SettingsProvider();
    final track = _testTrack(name: 'Nearest Course');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QuickRunLogPage(
            weatherFetcher: ({bool forceRefresh = false}) async => null,
            trackFinder: () async => track,
          ),
        ),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();
    await tester.tap(find.byTooltip('Use current location'));
    await tester.pump();

    expect(find.text('Nearest Course'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Best Lap'), '13.52');
    await tester.tap(find.text('Save Run Log'));
    await tester.pump();

    expect(provider.runLogs, hasLength(1));
    expect(provider.runLogs.first.trackName, 'Nearest Course');
  });
}
