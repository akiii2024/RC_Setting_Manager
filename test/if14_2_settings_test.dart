import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'infinity/if14_2';

  test('IF14-2 を Infinity のツーリングカーとして登録する', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );
    expect(car.name, 'IF14-2');
    expect(car.manufacturer.id, 'infinity');
    expect(car.manufacturer.name, 'Infinity');
    expect(car.manufacturer.logoPath, 'assets/images/infinity.png');
    expect(car.imageUrl, 'assets/images/if14_2.jpg');
    expect(car.category, 'ツーリングカー');
  });

  test('IF14-2 の設定キーは一意で、車種固有項目は指定カテゴリに属する', () {
    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.isHumanVerified, isFalse);
    final settings = definition.availableSettings;
    expect(
      settings.map((setting) => setting.key).toSet(),
      hasLength(settings.length),
    );
    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));

    final specificSettings = settings.skip(basicSettings.length);
    expect(specificSettings, isNotEmpty);
    const categories = {
      'front',
      'rear',
      'frontDamper',
      'rearDamper',
      'other',
      'top',
    };
    for (final setting in specificSettings) {
      expect(categories, contains(setting.category), reason: setting.key);
    }
  });
}
