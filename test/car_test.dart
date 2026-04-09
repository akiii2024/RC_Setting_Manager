import 'package:flutter_test/flutter_test.dart';
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
}
