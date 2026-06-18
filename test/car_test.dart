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
      expect(trf420xMotor.options, contains('13.5T'));
      expect(bd12Esc.type, 'text');
      expect(bd12Esc.options, contains('Hobbywing'));
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
  });
}
