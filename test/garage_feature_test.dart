import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/pages/car_selection_page.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
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
  bool isInGarage = false,
  bool suppressGaragePrompt = false,
}) {
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

SettingsProvider _createProvider(List<Car> cars) {
  SharedPreferences.setMockInitialValues({
    'language_settings': true,
    'cars_settings': jsonEncode(cars.map((car) => car.toJson()).toList()),
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
    expect(find.text('TRF421'), findsOneWidget);
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
