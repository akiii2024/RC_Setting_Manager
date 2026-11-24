import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'mugen/mtc3';

  test('Mugen MTC3 をカタログと設定定義に登録する', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );
    expect(car.name, 'MTC3');
    expect(car.manufacturer.id, 'mugen');
    expect(car.manufacturer.name, 'Mugen');
    expect(car.manufacturer.logoPath, 'assets/images/mugen.png');
    expect(car.imageUrl, 'assets/images/mtc3.jpg');
    expect(car.category, 'ツーリングカー');

    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.carId, carId);
    expect(definition.isHumanVerified, isFalse);
  });

  test('MTC3 のキーは一意で、固有項目は指定のカテゴリに属する', () {
    final settings = getCarSettingDefinition(carId)!.availableSettings;
    expect(
      settings.map((item) => item.key).toSet(),
      hasLength(settings.length),
    );
    expect(settings.take(basicSettings.length), orderedEquals(basicSettings));

    final specificSettings = settings.skip(basicSettings.length);
    expect(
      specificSettings.map((item) => item.category),
      everyElement(
        isIn(['front', 'rear', 'frontDamper', 'rearDamper', 'other', 'top']),
      ),
    );
    final byKey = {for (final item in specificSettings) item.key: item};
    expect(byKey['trackLayout']?.options, ['TECHNICAL', 'MIXED', 'FAST']);
    expect(byKey['traction']?.options, ['LOW', 'MEDIUM', 'HIGH']);
    expect(byKey['frontDamperHolder']?.options, ['ACTIVE', 'FIXED']);
    expect(byKey['rearDamperBypass']?.options, ['VERTICAL', 'HORIZONTAL']);
  });
}
