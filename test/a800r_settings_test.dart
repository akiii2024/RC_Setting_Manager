import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'awesomatix/a800r';

  test('A800R が Awesomatix のツーリングカーとして登録されている', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );
    expect(car.name, 'A800R');
    expect(car.manufacturer.id, 'awesomatix');
    expect(car.manufacturer.name, 'Awesomatix');
    expect(car.manufacturer.logoPath, 'assets/images/awesomatix.png');
    expect(car.imageUrl, 'assets/images/a800r.jpg');
    expect(car.category, 'ツーリングカー');
  });

  test('A800R は共通設定を持ち、固有設定のキーとカテゴリが有効', () {
    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.isHumanVerified, isFalse);

    final settings = definition.availableSettings;
    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));
    expect(
      settings.map((setting) => setting.key).toSet(),
      hasLength(settings.length),
    );

    final specificSettings = settings.skip(basicSettings.length);
    expect(
      specificSettings.map((setting) => setting.category).toSet(),
      equals({'front', 'rear', 'frontDamper', 'rearDamper', 'other', 'top'}),
    );
  });
}
