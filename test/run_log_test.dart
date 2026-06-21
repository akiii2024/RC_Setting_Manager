import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/models/car.dart';
import 'package:rc_setting_manager/models/manufacturer.dart';
import 'package:rc_setting_manager/models/run_log.dart';
import 'package:rc_setting_manager/utils/run_log_formatters.dart';

void main() {
  final manufacturer = Manufacturer(
    id: 'tamiya',
    name: 'Tamiya',
    logoPath: '',
  );

  final car = Car(
    id: 'tamiya/trf421',
    name: 'TRF421',
    imageUrl: '',
    manufacturer: manufacturer,
    category: 'touring',
  );

  test('serializes and deserializes run log json', () {
    final runLog = RunLog(
      id: 'run-1',
      createdAt: DateTime(2026, 6, 19, 12, 0),
      runAt: DateTime(2026, 6, 19, 11, 55),
      car: car,
      baseSettingId: 'base-1',
      baseSettingName: 'Base',
      resultSettingId: 'result-1',
      resultSettingName: 'Result',
      bestLapMillis: 13520,
      airTempC: 22.5,
      humidityPercent: 48,
      weatherCondition: 'Sunny',
      trackTempC: 31.2,
      trackCondition: 'High grip',
      feelTagIds: const ['stable', 'push'],
      memo: 'Good balance',
      changes: const [
        RunSettingChange(
          settingKey: 'frontCamber',
          settingLabel: 'Front Camber',
          beforeValue: 1.0,
          afterValue: 1.5,
        ),
      ],
    );

    final decoded = RunLog.fromJson(runLog.toJson());

    expect(decoded.id, 'run-1');
    expect(decoded.car.id, 'tamiya/trf421');
    expect(decoded.bestLapMillis, 13520);
    expect(decoded.airTempC, 22.5);
    expect(decoded.humidityPercent, 48);
    expect(decoded.weatherCondition, 'Sunny');
    expect(decoded.trackTempC, 31.2);
    expect(decoded.trackCondition, 'High grip');
    expect(decoded.feelTagIds, ['stable', 'push']);
    expect(decoded.changes.single.settingKey, 'frontCamber');
    expect(decoded.changes.single.afterValue, 1.5);
  });

  test('parses supported best lap formats', () {
    expect(parseBestLapMillis('13.52'), 13520);
    expect(parseBestLapMillis('0:13.52'), 13520);
    expect(parseBestLapMillis('1:02.50'), 62500);
    expect(parseBestLapMillis('bad'), isNull);
    expect(parseBestLapMillis('0:61.00'), isNull);
    expect(formatBestLapMillis(13520), '13.52');
  });
}
