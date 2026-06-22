import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/owned_part.dart';
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

  test('merges saved equipment names into suggestions', () async {
    final car = _buildCar();
    final savedSettings = [
      SavedSetting(
        id: 'setting-1',
        name: 'Custom Equipment Setup',
        createdAt: DateTime(2026, 6, 1),
        car: car,
        settings: const {
          'motor': 'Custom Brand XYZ 17.5T',
          'battery': 'Custom Battery 6000mAh',
          'body': 'Custom Body 190mm',
          'frontTire': 'Custom Front Tire 32',
        },
      ),
      SavedSetting(
        id: 'setting-2',
        name: 'Duplicate Custom Motor Setup',
        createdAt: DateTime(2026, 6, 2),
        car: car,
        settings: const {
          'motor': 'Custom Brand XYZ 17.5T',
          'rearTire': 'Custom Rear Tire 36',
        },
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

    expect(
      provider.getSuggestionsForSetting('battery', const []),
      containsAll([
        'SUNPADOW Competition Short-Pack LiPo 6000mAh 7.6V 100C',
        'Custom Battery 6000mAh',
      ]),
    );
    expect(
      provider.getSuggestionsForSetting('body', const []),
      containsAll([
        'ZooRacing Wolverine MAX 190mm',
        'Custom Body 190mm',
      ]),
    );
    expect(
      provider.getSuggestionsForSetting('tire', const []),
      containsAll([
        'Rush VR3 32S',
        'Custom Front Tire 32',
        'Custom Rear Tire 36',
      ]),
    );
  });

  test('serializes owned parts and defaults missing storage to empty',
      () async {
    final part = OwnedPart(
      id: 'part-1',
      category: 'motor',
      name: 'Custom Motor 17.5T',
      createdAt: DateTime(2026, 6, 20, 12, 0),
    );

    final decoded = OwnedPart.fromJson(part.toJson());

    expect(decoded.id, part.id);
    expect(decoded.category, part.category);
    expect(decoded.name, part.name);
    expect(decoded.createdAt, part.createdAt);

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([_buildCar().toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    expect(provider.ownedParts, isEmpty);
  });

  test('adds updates deletes and persists owned parts', () async {
    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([_buildCar().toJson()]),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    final added = await provider.addOwnedPart('motor', ' Custom Motor 17.5T ');
    final duplicate =
        await provider.addOwnedPart('motor', 'custom motor 17.5t');

    expect(added, isNotNull);
    expect(duplicate?.id, added?.id);
    expect(provider.getOwnedPartsByCategory('motor'), hasLength(1));
    expect(provider.getOwnedPartsByCategory('motor').single.name,
        'Custom Motor 17.5T');

    final updated = await provider.updateOwnedPart(
      added!.id,
      category: 'motor',
      name: 'Updated Motor 17.5T',
    );
    expect(updated, isTrue);

    final reloadedProvider = SettingsProvider();
    await _waitForProvider(reloadedProvider);

    expect(reloadedProvider.getOwnedPartsByCategory('motor'), hasLength(1));
    expect(reloadedProvider.getOwnedPartsByCategory('motor').single.name,
        'Updated Motor 17.5T');

    await reloadedProvider.deleteOwnedPart(added.id);

    final deletedProvider = SettingsProvider();
    await _waitForProvider(deletedProvider);
    expect(deletedProvider.ownedParts, isEmpty);
  });

  test('owned parts reduce empty suggestions and lead typed suggestions',
      () async {
    final car = _buildCar();
    final savedSettings = [
      SavedSetting(
        id: 'setting-1',
        name: 'History Setup',
        createdAt: DateTime(2026, 6, 1),
        car: car,
        settings: const {
          'motor': 'History Motor 17.5T',
          'frontTire': 'History Tire 32',
        },
      ),
    ];

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
      'saved_settings':
          jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);

    await provider.addOwnedPart('motor', 'Owned Motor 17.5T');
    await provider.addOwnedPart('tire', 'Owned Tire 32');

    expect(
      provider.getSuggestionsForSetting(
        'motor',
        const ['Hobbywing XeRun V10 G5 17.5T'],
      ),
      ['Owned Motor 17.5T'],
    );
    expect(
      provider.getSuggestionsForSetting('frontTire', const []),
      ['Owned Tire 32'],
    );

    final typedSuggestions = provider.getSuggestionsForSetting(
      'motor',
      const ['Hobbywing XeRun V10 G5 17.5T'],
      query: '17.5',
    );

    expect(typedSuggestions.first, 'Owned Motor 17.5T');
    expect(typedSuggestions, contains('Hobbywing XeRun V10 G5 17.5T'));
    expect(typedSuggestions, contains('History Motor 17.5T'));
  });

  test('imports owned part candidates from saved setting history', () async {
    final car = _buildCar();
    final savedSettings = [
      SavedSetting(
        id: 'setting-1',
        name: 'History Setup',
        createdAt: DateTime(2026, 6, 1),
        car: car,
        settings: const {
          'motor': 'Custom Brand XYZ 17.5T',
          'battery': 'Custom Battery 6000mAh',
          'body': 'Custom Body 190mm',
          'frontTire': 'Custom Tire 32',
        },
      ),
      SavedSetting(
        id: 'setting-2',
        name: 'Legacy Turn Setup',
        createdAt: DateTime(2026, 6, 2),
        car: car,
        settings: const {
          'motor': '13.5T',
          'rearTire': 'Custom Tire 32',
        },
      ),
    ];

    SharedPreferences.setMockInitialValues({
      'cars_settings': jsonEncode([car.toJson()]),
      'saved_settings':
          jsonEncode(savedSettings.map((setting) => setting.toJson()).toList()),
    });

    final provider = SettingsProvider();
    await _waitForProvider(provider);
    await provider.addOwnedPart('motor', 'Custom Brand XYZ 17.5T');

    final candidates = provider.getOwnedPartImportCandidatesFromHistory();
    final candidateKeys = candidates
        .map((candidate) => '${candidate.category}::${candidate.name}')
        .toList();

    expect(candidateKeys, isNot(contains('motor::Custom Brand XYZ 17.5T')));
    expect(candidateKeys, isNot(contains('motor::13.5T')));
    expect(candidateKeys, contains('battery::Custom Battery 6000mAh'));
    expect(candidateKeys, contains('body::Custom Body 190mm'));
    expect(candidateKeys.where((key) => key == 'tire::Custom Tire 32'),
        hasLength(1));

    await provider.importOwnedPartsFromHistory(
      candidates
          .where((candidate) => candidate.category == 'battery')
          .toList(growable: false),
    );

    expect(provider.getOwnedPartsByCategory('battery'), hasLength(1));
    expect(provider.getOwnedPartsByCategory('battery').single.name,
        'Custom Battery 6000mAh');
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
