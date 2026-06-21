import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
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
    expect(result.runLogs, isEmpty);
  });

  test('exports and imports run logs', () async {
    final car = Car(
      id: 'tamiya/trf421',
      name: 'TRF421',
      imageUrl: '',
      manufacturer: manufacturer,
      category: 'touring',
    );

    final result = await XmlService.importFromXml(
      await XmlService.exportToXml(
        savedSettings: const [],
        runLogs: [
          RunLog(
            id: 'run-1',
            createdAt: DateTime(2026, 6, 19, 12, 0),
            runAt: DateTime(2026, 6, 19, 11, 55),
            car: car,
            baseSettingId: 'base-1',
            baseSettingName: 'Base',
            resultSettingId: 'result-1',
            resultSettingName: 'Result',
            bestLapMillis: 13520,
            airTempC: 23.5,
            humidityPercent: 55,
            weatherCondition: 'Sunny',
            trackTempC: 34.0,
            trackCondition: 'Dusty',
            feelTagIds: const ['stable'],
            memo: 'Good balance',
            changes: const [
              RunSettingChange(
                settingKey: 'frontCamber',
                settingLabel: 'Front Camber',
                beforeValue: 1.0,
                afterValue: 1.5,
              ),
            ],
          ),
        ],
        cars: [car],
        visibilitySettings: const {},
        isEnglish: true,
      ),
    );

    expect(result.runLogs, hasLength(1));
    expect(result.runLogs.first.bestLapMillis, 13520);
    expect(result.runLogs.first.airTempC, 23.5);
    expect(result.runLogs.first.humidityPercent, 55);
    expect(result.runLogs.first.weatherCondition, 'Sunny');
    expect(result.runLogs.first.trackTempC, 34.0);
    expect(result.runLogs.first.trackCondition, 'Dusty');
    expect(result.runLogs.first.feelTagIds, ['stable']);
    expect(result.runLogs.first.changes.single.afterValue, 1.5);
  });

  test('exports and imports saved setting run result metadata', () async {
    final car = Car(
      id: 'tamiya/trf421',
      name: 'TRF421',
      imageUrl: '',
      manufacturer: manufacturer,
      category: 'touring',
    );

    final result = await XmlService.importFromXml(
      await XmlService.exportToXml(
        savedSettings: [
          SavedSetting(
            id: 'result-1',
            name: 'Run result',
            createdAt: DateTime(2026, 6, 19, 12, 5),
            car: car,
            settings: const {'frontCamber': 1.5},
            kind: SavedSettingKind.runResult,
            sourceRunLogId: 'run-1',
            parentSettingId: 'base-1',
          ),
        ],
        cars: [car],
        visibilitySettings: const {},
        isEnglish: true,
      ),
    );

    expect(result.savedSettings, hasLength(1));
    expect(result.savedSettings.first.kind, SavedSettingKind.runResult);
    expect(result.savedSettings.first.sourceRunLogId, 'run-1');
    expect(result.savedSettings.first.parentSettingId, 'base-1');
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
    expect(result.runLogs, isEmpty);
  });
}
