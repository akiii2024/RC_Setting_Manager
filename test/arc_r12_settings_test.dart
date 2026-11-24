import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'arc/arc_r12';

  test('ARC R12 をカタログと設定定義に登録する', () {
    final car =
        BuiltInCarCatalog.create().singleWhere((car) => car.id == carId);
    expect(car.name, 'R12');
    expect(car.manufacturer.id, 'arc');
    expect(car.manufacturer.name, 'ARC');

    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.isHumanVerified, isFalse);
  });

  test('ARC R12 のキーは一意で、車種固有項目は指定カテゴリに収まる', () {
    final settings = getCarSettingDefinition(carId)!.availableSettings;
    final keys = settings.map((setting) => setting.key);
    expect(keys.toSet(), hasLength(settings.length));

    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));
    final specificSettings = settings.skip(basicSettings.length);
    expect(specificSettings, isNotEmpty);
    expect(
      specificSettings.map((setting) => setting.category),
      everyElement(isIn({
        'front',
        'rear',
        'frontDamper',
        'rearDamper',
        'other',
        'top',
      })),
    );
  });
}
