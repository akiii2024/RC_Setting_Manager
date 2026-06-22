import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/providers/settings_provider.dart';

Future<void> _waitForProvider(SettingsProvider provider) async {
  for (var i = 0; i < 50; i++) {
    if (provider.isInitialized) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
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

void main() {
  test('persists garage membership and suppression flags', () async {
    final initialCar = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([initialCar.toJson()]),
      'language_settings': true,
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.setGarageMembership(initialCar.id, true);
    await provider.setGaragePromptSuppressed(initialCar.id, true);

    expect(provider.garageCars.map((car) => car.id), contains(initialCar.id));
    expect(provider.getCarById(initialCar.id)?.suppressGaragePrompt, isTrue);

    final reloadedProvider = SettingsProvider();
    await _waitForProvider(reloadedProvider);

    final reloadedCar = reloadedProvider.getCarById(initialCar.id);
    expect(reloadedCar, isNotNull);
    expect(reloadedCar?.isInGarage, isTrue);
    expect(reloadedCar?.suppressGaragePrompt, isTrue);
  });

  test('adds numeric suffix when saving duplicate setting names', () async {
    final car = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.addSetting('Race Setup', car, const {});
    await provider.addSetting('Race Setup', car, const {});
    await provider.addSetting('Race Setup', car, const {});

    expect(
      provider.savedSettings.map((setting) => setting.name),
      ['Race Setup (2)', 'Race Setup (1)', 'Race Setup'],
    );
  });

  test('saves run log without creating a result setting when unchanged',
      () async {
    final car = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.addSetting('Base Setup', car, const {'frontCamber': 1.0});
    final baseSetting = provider.savedSettings.first;

    final runLog = await provider.addRunLog(
      runAt: DateTime(2026, 6, 19, 10, 0),
      car: car,
      baseSetting: baseSetting,
      trackName: 'Test Course',
      bestLapMillis: 13520,
      airTempC: 24,
      humidityPercent: 50,
      weatherCondition: 'Sunny',
      trackTempC: 36.5,
      trackCondition: 'High grip',
      feelTagIds: const ['stable'],
      memo: 'Good',
    );

    expect(provider.runLogs, hasLength(1));
    expect(runLog.trackName, 'Test Course');
    expect(runLog.airTempC, 24);
    expect(runLog.humidityPercent, 50);
    expect(runLog.weatherCondition, 'Sunny');
    expect(runLog.trackTempC, 36.5);
    expect(runLog.trackCondition, 'High grip');
    expect(runLog.resultSettingId, isNull);
    expect(provider.savedSettings, hasLength(1));
  });

  test('saves run log changes and creates result setting', () async {
    final car = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.addSetting('Base Setup', car, const {'frontCamber': 1.0});
    final baseSetting = provider.savedSettings.first;

    final runLog = await provider.addRunLog(
      runAt: DateTime(2026, 6, 19, 10, 0),
      car: car,
      baseSetting: baseSetting,
      bestLapMillis: 13520,
      feelTagIds: const ['push'],
      memo: 'Needs more front',
      changes: const [
        RunSettingChange(
          settingKey: 'frontCamber',
          settingLabel: 'Front Camber',
          beforeValue: 1.0,
          afterValue: 1.5,
        ),
      ],
    );

    expect(provider.runLogs, hasLength(1));
    expect(runLog.resultSettingId, isNotNull);
    expect(provider.savedSettings, hasLength(2));
    final resultSetting = provider.savedSettings.first;
    expect(resultSetting.settings['frontCamber'], 1.5);
    expect(resultSetting.kind, SavedSettingKind.runResult);
    expect(resultSetting.sourceRunLogId, runLog.id);
    expect(resultSetting.parentSettingId, baseSetting.id);

    final reloadedProvider = SettingsProvider();
    await _waitForProvider(reloadedProvider);

    expect(reloadedProvider.runLogs, hasLength(1));
    expect(
        reloadedProvider.runLogs.first.resultSettingId, runLog.resultSettingId);
    expect(
        reloadedProvider.savedSettings.first.kind, SavedSettingKind.runResult);
    expect(reloadedProvider.savedSettings.first.sourceRunLogId, runLog.id);
    expect(
        reloadedProvider.savedSettings.first.parentSettingId, baseSetting.id);
  });

  test('uses next numeric suffix when updating to another setting name',
      () async {
    final car = _buildCar();
    final savedSettings = [
      SavedSetting(
        id: 'setting-1',
        name: 'Race Setup',
        createdAt: DateTime(2026, 6, 1),
        car: car,
        settings: const {},
      ),
      SavedSetting(
        id: 'setting-2',
        name: 'Practice Setup',
        createdAt: DateTime(2026, 6, 2),
        car: car,
        settings: const {},
      ),
    ];

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
      'saved_settings':
          jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    final settingToUpdate = provider.savedSettings
        .firstWhere((setting) => setting.name == 'Practice Setup');

    await provider.updateSetting(
      SavedSetting(
        id: settingToUpdate.id,
        name: 'Race Setup',
        createdAt: settingToUpdate.createdAt,
        car: settingToUpdate.car,
        settings: settingToUpdate.settings,
      ),
    );

    expect(
      provider.savedSettings.map((setting) => setting.name),
      ['Race Setup (1)', 'Race Setup'],
    );
  });

  test('resolves built-in available settings from definitions', () async {
    final car = _buildCar();

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    expect(
      provider.getCarAvailableSettings('tamiya/trf421'),
      containsAll(['frontUpperArmSpacerIn', 'motor', 'additive']),
    );
  });

  test('merges saved motor names into suggestions without turn-only values',
      () async {
    final car = _buildCar();
    final savedSettings = [
      SavedSetting(
        id: 'setting-1',
        name: 'Custom Motor Setup',
        createdAt: DateTime(2026, 6, 1),
        car: car,
        settings: const {'motor': 'Custom Brand XYZ 17.5T'},
      ),
      SavedSetting(
        id: 'setting-2',
        name: 'Duplicate Custom Motor Setup',
        createdAt: DateTime(2026, 6, 2),
        car: car,
        settings: const {'motor': 'Custom Brand XYZ 17.5T'},
      ),
      SavedSetting(
        id: 'setting-3',
        name: 'Legacy Turn Setup',
        createdAt: DateTime(2026, 6, 3),
        car: car,
        settings: const {'motor': '13.5T'},
      ),
    ];

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
      'saved_settings':
          jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    final suggestions = provider.getSuggestionsForSetting(
      'motor',
      const ['Hobbywing XeRun V10 G5 13.5T', '13.5T'],
    );

    expect(suggestions, contains('Hobbywing XeRun V10 G5 13.5T'));
    expect(suggestions, contains('Custom Brand XYZ 17.5T'));
    expect(suggestions, isNot(contains('13.5T')));
    expect(
      suggestions.where((option) => option == 'Custom Brand XYZ 17.5T'),
      hasLength(1),
    );
  });

  test('merges new built-in cars into persisted car list', () async {
    final car = _buildCar(isInGarage: true);

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    final carIds = provider.cars.map((car) => car.id).toSet();

    expect(
      carIds,
      containsAll({
        'tamiya/trf421',
        'tamiya/trf420x',
        'tamiya/trf421x',
        'yokomo/bd11',
        'yokomo/bd12',
        'yokomo/ms1_0',
        'yokomo/ms2_0',
      }),
    );
    expect(provider.getCarById('tamiya/trf421')?.isInGarage, isTrue);
  });
}
