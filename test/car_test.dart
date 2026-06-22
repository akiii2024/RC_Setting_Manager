import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';
import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';

void main() {
  group('Car', () {
    final manufacturer = Manufacturer(
      id: 'tamiya',
      name: 'Tamiya',
      logoPath: '',
    );

    test('serializes and deserializes garage fields', () {
      final car = Car(
        id: 'tamiya/trf421',
        name: 'TRF421',
        imageUrl: 'assets/images/trf421.jpg',
        manufacturer: manufacturer,
        category: 'touring',
        availableSettings: const ['frontCamber'],
        settingTypes: const {'frontCamber': 'number'},
        isInGarage: true,
        suppressGaragePrompt: true,
      );

      final decoded = Car.fromJson(car.toJson());

      expect(decoded.isInGarage, isTrue);
      expect(decoded.suppressGaragePrompt, isTrue);
      expect(decoded.availableSettings, ['frontCamber']);
      expect(decoded.settingTypes['frontCamber'], 'number');
    });

    test('defaults garage fields to false for legacy json', () {
      final legacyJson = {
        'id': 'tamiya/trf421',
        'name': 'TRF421',
        'imageUrl': '',
        'manufacturer': manufacturer.toJson(),
        'category': 'touring',
        'availableSettings': ['frontCamber'],
        'settingTypes': {'frontCamber': 'number'},
      };

      final decoded = Car.fromJson(legacyJson);

      expect(decoded.isInGarage, isFalse);
      expect(decoded.suppressGaragePrompt, isFalse);
    });
  });

  group('car setting definitions', () {
    test('power fields expose suggested options while remaining text fields',
        () {
      final trf420x = getCarSettingDefinition('tamiya/trf420x')!;
      final bd12 = getCarSettingDefinition('yokomo/bd12')!;

      final trf420xMotor = trf420x.availableSettings
          .firstWhere((setting) => setting.key == 'motor');
      final bd12Esc =
          bd12.availableSettings.firstWhere((setting) => setting.key == 'esc');

      expect(trf420xMotor.type, 'text');
      expect(trf420xMotor.options, contains('Hobbywing XeRun V10 G5 13.5T'));
      expect(trf420xMotor.options, isNot(contains('13.5T')));
      expect(bd12Esc.type, 'text');
      expect(bd12Esc.options, contains('Hobbywing'));
    });

    test('trf420x exposes separate front and rear sus mount shaft positions',
        () {
      final trf420x = getCarSettingDefinition('tamiya/trf420x')!;
      final settingsByKey = {
        for (final setting in trf420x.availableSettings) setting.key: setting,
      };

      for (final key in const [
        'frontSusMountFrontShaftPosition',
        'frontSusMountRearShaftPosition',
        'rearSusMountFrontShaftPosition',
        'rearSusMountRearShaftPosition',
      ]) {
        expect(settingsByKey[key]?.type, 'grid');
        expect(settingsByKey[key]?.constraints['rows'], 5);
        expect(settingsByKey[key]?.constraints['cols'], 5);
      }

      expect(settingsByKey, isNot(contains('frontSusMountShaftPosition')));
      expect(settingsByKey, isNot(contains('rearSusMountShaftPosition')));
    });

    test('trf420x exposes top sheet layout settings', () {
      final trf420x = getCarSettingDefinition('tamiya/trf420x')!;
      final settingsByKey = {
        for (final setting in trf420x.availableSettings) setting.key: setting,
      };

      for (final key in const [
        'toeAngle',
        'ballastWeightA',
        'ballastWeightB',
        'ballastWeightC',
        'rearSusType',
        'rearSusHardness',
      ]) {
        expect(settingsByKey[key]?.category, 'top');
      }

      expect(settingsByKey['topScrewPositions']?.type, 'grid');
      expect(settingsByKey['topScrewPositions']?.constraints['cols'], 7);
      expect(
          settingsByKey['topScrewPositions']?.constraints['multiple'], isTrue);
    });

    test('trf421 exposes pdf setup sheet details', () {
      final trf421 = getCarSettingDefinition('tamiya/trf421')!;
      final settingsByKey = {
        for (final setting in trf421.availableSettings) setting.key: setting,
      };

      expect(settingsByKey['frontUpperArmSpacerIn']?.category, 'front');
      expect(settingsByKey['frontUpperArmSpacerOut']?.category, 'front');
      expect(settingsByKey['frontDiffPositionShim']?.options,
          contains('Alu. 0.5'));
      expect(settingsByKey['frontDamperPiston']?.constraints['composite'],
          'damperPiston');
      expect(settingsByKey['motorMountScrewPositions']?.type, 'grid');
      expect(settingsByKey['motorMountScrewPositions']?.constraints['rows'], 2);
      expect(settingsByKey['motorMountScrewPositions']?.constraints['cols'], 7);

      for (final key in const [
        'ballastWeightA',
        'ballastWeightB',
        'ballastWeightC',
        'batteryWeight',
        'servoHornLength',
      ]) {
        expect(settingsByKey[key]?.category, 'top');
      }
    });

    test('bd12 exposes pdf setup sheet details', () {
      final bd12 = getCarSettingDefinition('yokomo/bd12')!;
      final settingsByKey = {
        for (final setting in bd12.availableSettings) setting.key: setting,
      };

      expect(settingsByKey['frontUpperArmPosition']?.type, 'grid');
      expect(settingsByKey['frontBellCrankPostSpacer']?.category, 'front');
      expect(settingsByKey['frontSwayBar']?.constraints['composite'],
          'stabilizer');
      expect(settingsByKey['frontShockOil']?.constraints['composite'],
          'damperOil');
      expect(settingsByKey['frontPiston']?.constraints['composite'],
          'damperPiston');
      expect(settingsByKey['rearGearOil']?.constraints['composite'], 'diffOil');
      expect(settingsByKey['motorMountPosition']?.type, 'grid');
      expect(settingsByKey['topDeckScrewPositions']?.type, 'grid');
      expect(settingsByKey['batteryPosition']?.constraints['multiple'], isTrue);
    });

    test('all setting definitions resolve to visible editor categories', () {
      const visibleCategories = {
        'basic',
        'front',
        'frontDamper',
        'rear',
        'rearDamper',
        'top',
        'other',
        'memo',
      };

      for (final entry in carSettingsDefinitions.entries) {
        final unmappedSettings = entry.value.availableSettings
            .where(
              (setting) => !visibleCategories
                  .contains(displayCategoryForSetting(setting)),
            )
            .map((setting) => '${setting.key}:${setting.category}')
            .toList();

        expect(
          unmappedSettings,
          isEmpty,
          reason: '${entry.key} has settings outside visible categories.',
        );
      }
    });

    test('legacy definition categories are normalized for the editor', () {
      final trf421 = getCarSettingDefinition('tamiya/trf421')!;
      final bd12 = getCarSettingDefinition('yokomo/bd12')!;

      final trf421Motor = trf421.availableSettings
          .firstWhere((setting) => setting.key == 'motor');
      final bd12MainChassis = bd12.availableSettings
          .firstWhere((setting) => setting.key == 'mainChassis');
      final bd12FrontRideHeight = bd12.availableSettings
          .firstWhere((setting) => setting.key == 'frontRideHeight');
      final bd12RearRideHeight = bd12.availableSettings
          .firstWhere((setting) => setting.key == 'rearRideHeight');

      expect(displayCategoryForSetting(trf421Motor), 'other');
      expect(displayCategoryForSetting(bd12MainChassis), 'other');
      expect(displayCategoryForSetting(bd12FrontRideHeight), 'front');
      expect(displayCategoryForSetting(bd12RearRideHeight), 'rear');
    });

    test('new built-in car definitions are registered', () {
      const expectedCarIds = {
        'tamiya/trf421x',
        'yokomo/bd11',
        'yokomo/ms1_0',
        'yokomo/ms2_0',
      };

      for (final carId in expectedCarIds) {
        final definition = getCarSettingDefinition(carId);

        expect(definition, isNotNull, reason: '$carId should be registered.');
        expect(definition!.availableSettings, isNotEmpty);
        expect(definition.availableSettings.map((setting) => setting.key),
            containsAll(['date', 'motor']));
      }
    });

    test('all setting definitions use unique keys', () {
      for (final entry in carSettingsDefinitions.entries) {
        final keys = entry.value.availableSettings
            .map((setting) => setting.key)
            .toList();
        final duplicateKeys = <String>{
          for (final key in keys)
            if (keys.where((candidate) => candidate == key).length > 1) key,
        };

        expect(
          duplicateKeys,
          isEmpty,
          reason: '${entry.key} has duplicate setting keys.',
        );
      }
    });

    test('composite input metadata is available across supported cars', () {
      final trf421x = getCarSettingDefinition('tamiya/trf421x')!;
      final bd11 = getCarSettingDefinition('yokomo/bd11')!;
      final ms1 = getCarSettingDefinition('yokomo/ms1_0')!;

      final trf421xStabilizer = trf421x.availableSettings
          .firstWhere((setting) => setting.key == 'frontStabilizer');
      final bd11ShockOil = bd11.availableSettings
          .firstWhere((setting) => setting.key == 'frontShockOil');
      final ms1Piston = ms1.availableSettings
          .firstWhere((setting) => setting.key == 'frontPiston');

      expect(trf421xStabilizer.constraints['composite'], 'stabilizer');
      expect(bd11ShockOil.constraints['composite'], 'damperOil');
      expect(ms1Piston.constraints['composite'], 'damperPiston');
    });
  });
}
