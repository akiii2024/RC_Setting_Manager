import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'xray/x4_24';

  test("XRAY X4'24 をカタログと設定定義に登録する", () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );
    expect(car.name, "X4'24");
    expect(car.manufacturer.id, 'xray');
    expect(car.manufacturer.name, 'XRAY');

    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.carId, carId);
    expect(definition.isHumanVerified, isFalse);
  });

  test("X4'24 のキーは一意で、固有項目は既存のカテゴリに属する", () {
    final settings = getCarSettingDefinition(carId)!.availableSettings;
    expect(
      settings.map((setting) => setting.key).toSet(),
      hasLength(settings.length),
    );
    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));

    final specificSettings = settings.skip(basicSettings.length);
    expect(
      specificSettings.map((setting) => setting.category),
      everyElement(
        isIn(['front', 'rear', 'frontDamper', 'rearDamper', 'other', 'top']),
      ),
    );
    final byKey = {
      for (final setting in specificSettings) setting.key: setting,
    };
    expect(byKey['frontCasterAngle']?.options, ['3º', '4º', '5º']);
    expect(byKey['rearCasterAngle']?.options, [
      '0.5º',
      '1.5º',
      '2.5º',
      '3.5º',
      '4.5º',
      '5.5º',
    ]);
    expect(byKey['frontDamperPiston']?.options, ['4 HOLES', 'PSS']);
    expect(byKey['rearDamperPistonDiameter']?.options, ['1.1mm', '1.2mm']);
  });
}
