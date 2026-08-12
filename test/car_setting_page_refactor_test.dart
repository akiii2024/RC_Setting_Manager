import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/pages/car_setting_page.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

final _manufacturer = Manufacturer(
  id: 'tamiya',
  name: 'Tamiya',
  logoPath: '',
);

Car _car({
  String id = 'tamiya/trf421',
  String name = 'TRF421',
  bool suppressGaragePrompt = true,
}) {
  return Car(
    id: id,
    name: name,
    imageUrl: '',
    manufacturer: _manufacturer,
    category: 'touring',
    suppressGaragePrompt: suppressGaragePrompt,
  );
}

Future<void> _waitForProvider(
  WidgetTester tester,
  SettingsProvider provider,
) async {
  for (var i = 0; i < 50 && !provider.isInitialized; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(provider.isInitialized, isTrue);
}

Future<SettingsProvider> _pumpEditor(
  WidgetTester tester, {
  required Car car,
  Map<String, dynamic>? savedSettings,
  String? savedSettingId,
  String? settingName,
  List<SavedSetting> storedSettings = const [],
  bool paperEditor = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'language_settings': true,
    'cars_settings': jsonEncode([car.toJson()]),
    'saved_settings':
        jsonEncode(storedSettings.map((setting) => setting.toJson()).toList()),
    'editor_layout_paper': paperEditor,
    'weather_location_api_prompt_suppressed_v1': true,
  });
  final provider = SettingsProvider();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: CarSettingPage(
          originalCar: car,
          savedSettings: savedSettings,
          savedSettingId: savedSettingId,
          settingName: settingName,
        ),
      ),
    ),
  );
  await _waitForProvider(tester, provider);
  await tester.pump();
  return provider;
}

Finder _textFormFieldWithInitialValue(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is TextFormField && widget.initialValue == value,
  );
}

void main() {
  testWidgets('layout switch preserves input and favorite selection',
      (tester) async {
    final car = _car();
    final provider = await _pumpEditor(tester, car: car);

    expect(find.byKey(const Key('setting-editor-scroll-view')), findsOneWidget);

    final appNameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Setting Name',
    );
    await tester.enterText(appNameField, 'Layout retained');

    await tester.tap(find.text('Paper UI'));
    await tester.pumpAndSettle();

    expect(provider.usePaperStyleEditor, isTrue);
    expect(find.byKey(const Key('setting-editor-scroll-view')), findsNothing);
    final paperNameField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Setting Name',
      ),
    );
    expect(paperNameField.controller?.text, 'Layout retained');

    await tester.tap(find.text('App UI'));
    await tester.pumpAndSettle();
    expect(provider.usePaperStyleEditor, isFalse);

    await provider.toggleFavoriteSetting(car.id, 'date', true);
    await tester.pump();
    expect(provider.getFavoriteSettings(car.id), contains('date'));
    await tester.tap(find.widgetWithText(Tab, 'Favorites'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsWidgets);
    expect(find.textContaining('No favorite items yet'), findsNothing);
  });

  testWidgets('paper editor updates TRF420X composite piston values',
      (tester) async {
    final car = _car(id: 'tamiya/trf420x', name: 'TRF420X');
    final initialValues = <String, dynamic>{
      'frontDamperPiston': '1.2',
      'frontDamperPistonHole': '2',
      'frontDumperPistonSize': '1.2',
      'frontDumperPistonHole': '2',
    };
    final stored = SavedSetting(
      id: 'trf-composite',
      name: 'Composite Setup',
      createdAt: DateTime(2026, 8, 12),
      car: car,
      settings: initialValues,
    );
    final provider = await _pumpEditor(
      tester,
      car: car,
      savedSettings: initialValues,
      savedSettingId: stored.id,
      settingName: stored.name,
      storedSettings: [stored],
      paperEditor: true,
    );

    final frontDamperSection = find.text('Front Damper').first;
    await tester.ensureVisible(frontDamperSection);
    await tester.pumpAndSettle();
    await tester.tap(frontDamperSection);
    await tester.pumpAndSettle();

    final pistonField = _textFormFieldWithInitialValue('1.2').first;
    final holeField = _textFormFieldWithInitialValue('2').first;
    await tester.ensureVisible(pistonField);
    await tester.pumpAndSettle();
    await tester.enterText(pistonField, '1.4');
    await tester.enterText(holeField, '3');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update Setting'));
    await tester.pumpAndSettle();

    final updated = provider.savedSettings.single;
    expect(updated.settings['frontDamperPiston'], '1.4');
    expect(updated.settings['frontDumperPistonSize'], '1.4');
    expect(updated.settings['frontDamperPistonHole'], '3');
    expect(updated.settings['frontDumperPistonHole'], '3');
  });

  testWidgets('editing can save the current values as a new setting',
      (tester) async {
    final car = _car();
    final initialValues = <String, dynamic>{'motor': '17.5T'};
    final stored = SavedSetting(
      id: 'original-setting',
      name: 'Original Setup',
      createdAt: DateTime(2026, 8, 12),
      car: car,
      settings: initialValues,
    );
    final provider = await _pumpEditor(
      tester,
      car: car,
      savedSettings: initialValues,
      savedSettingId: stored.id,
      settingName: stored.name,
      storedSettings: [stored],
    );

    await tester.tap(find.text('Save as New'));
    await tester.pumpAndSettle();

    expect(provider.savedSettings, hasLength(2));
    expect(
      provider.savedSettings.map((setting) => setting.id),
      contains('original-setting'),
    );
    expect(
      provider.savedSettings
          .where((setting) => setting.id != stored.id)
          .single
          .settings['motor'],
      '17.5T',
    );
  });
}
