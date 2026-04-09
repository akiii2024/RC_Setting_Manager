import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/services/xml_service.dart';

void main() {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  test('exports and imports garage fields', () async {
    final result = await XmlService.importFromXml(
      await XmlService.exportToXml(
        savedSettings: const [],
        cars: [
          Car(
            id: 'tamiya/trf421',
            name: 'TRF421',
            imageUrl: '',
            manufacturer: manufacturer,
            category: 'touring',
            isInGarage: true,
            suppressGaragePrompt: true,
          ),
        ],
        visibilitySettings: const {},
        isEnglish: true,
      ),
    );

    expect(result.cars, hasLength(1));
    expect(result.cars.first.isInGarage, isTrue);
    expect(result.cars.first.suppressGaragePrompt, isTrue);
  });

  test('imports legacy xml without garage fields', () async {
    const legacyXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<RCCarSettingsData>
  <metadata>
    <exportDate>2026-04-09T00:00:00.000</exportDate>
    <version>1.0</version>
    <exportedTypes>
      <type>cars</type>
    </exportedTypes>
    <language>en</language>
  </metadata>
  <cars>
    <car>
      <id>tamiya/trf421</id>
      <name>TRF421</name>
      <manufacturer>Tamiya</manufacturer>
      <category>touring</category>
      <availableSettings />
    </car>
  </cars>
</RCCarSettingsData>
''';

    final result = await XmlService.importFromXml(legacyXml);

    expect(result.cars, hasLength(1));
    expect(result.cars.first.isInGarage, isFalse);
    expect(result.cars.first.suppressGaragePrompt, isFalse);
  });
}
