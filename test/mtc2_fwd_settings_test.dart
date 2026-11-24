import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'mugen/mtc2_fwd';

  test('MTC2 FWD が組み込みカタログに存在する', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );
    expect(car.name, 'MTC2 FWD');
    expect(car.manufacturer.id, 'mugen');
  });

  test('MTC2 FWD の設定定義は未確認で、キーとカテゴリが有効', () {
    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.isHumanVerified, isFalse);

    final settings = definition.availableSettings;
    expect(
      settings.map((item) => item.key).toSet(),
      hasLength(settings.length),
    );
    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));

    const categories = {
      'front',
      'rear',
      'frontDamper',
      'rearDamper',
      'other',
      'top',
    };
    final specificSettings = settings.skip(basicSettings.length);
    expect(specificSettings, isNotEmpty);
    for (final item in specificSettings) {
      expect(categories, contains(item.category), reason: item.key);
    }
  });
}
