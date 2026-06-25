import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/pages/car_selection_page.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
import 'package:rc_setting_manager/pages/history_page.dart';
import 'package:rc_setting_manager/pages/my_garage_page.dart';
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

Car _buildCar({
  String id = 'tamiya/trf421',
  String name = 'TRF421',
  bool isInGarage = false,
  bool suppressGaragePrompt = false,
}) {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  return Car(
    id: id,
    name: name,
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
    isInGarage: isInGarage,
    suppressGaragePrompt: suppressGaragePrompt,
  );
}

SettingsProvider _createProvider(
  List<Car> cars, {
  List<SavedSetting> savedSettings = const [],
}) {
  SharedPreferences.setMockInitialValues({
    'language_settings': true,
    'cars_settings': jsonEncode(cars.map((car) => car.toJson()).toList()),
    'saved_settings':
        jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
  });

  return SettingsProvider();
}

void main() {
  testWidgets('manufacturer selection opens My Garage from shortcut card',
      (WidgetTester tester) async {
    final provider = _createProvider([
      _buildCar(isInGarage: true),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: CarSelectionPage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    expect(find.text('MY GARAGE'), findsOneWidget);
    expect(find.text('1 model registered'), findsOneWidget);

    await tester.tap(find.text('MY GARAGE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(MyGaragePage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TRF421'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('TRF421'), findsOneWidget);
  });

  testWidgets('garage car selection opens history filtered to that car',
      (WidgetTester tester) async {
    final garageCar = _buildCar(isInGarage: true);
    final otherCar = _buildCar(
      id: 'tamiya/trf420x',
      name: 'TRF420X',
    );
    final provider = _createProvider(
      [
        garageCar,
        otherCar,
      ],
      savedSettings: [
        SavedSetting(
          id: 'setting-1',
          name: 'TRF421 Race Setup',
          createdAt: DateTime(2026, 1, 2, 12, 0),
          car: garageCar,
          settings: const {},
        ),
        SavedSetting(
          id: 'setting-2',
          name: 'TRF420X Practice Setup',
          createdAt: DateTime(2026, 1, 1, 12, 0),
          car: otherCar,
          settings: const {},
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MyGaragePage()),
      ),
    );

    await _pumpUntilInitialized(tester, provider);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('TRF421'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('TRF421').first);
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.text('TRF421 Race Setup'), findsOneWidget);
    expect(find.text('TRF420X Practice Setup'), findsNothing);
  });

  testWidgets('new save shows garage prompt and can suppress future prompts',
      (WidgetTester tester) async {
    final initialCar = _buildCar();
    final provider = _createProvider([
      initialCar,
    ]);

    Future<void> pumpPage() async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: CarSettingPage(
              originalCar: initialCar,
            ),
          ),
        ),
      );
      await _pumpUntilInitialized(tester, provider);
      await tester.pump();
    }

    await pumpPage();

    final saveButton = find.text('Save Setting');

    expect(saveButton, findsOneWidget);

    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add to My Garage?'), findsOneWidget);
    expect(find.text("Don't show again"), findsOneWidget);

    await tester.tap(find.text("Don't show again"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      provider.getCarById('tamiya/trf421')?.suppressGaragePrompt,
      isTrue,
    );
    expect(provider.getCarById('tamiya/trf421')?.isInGarage, isFalse);

    await pumpPage();

    final secondSaveButton = find.text('Save Setting');
    await tester.ensureVisible(secondSaveButton);
    await tester.tap(secondSaveButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add to My Garage?'), findsNothing);
  });
}
