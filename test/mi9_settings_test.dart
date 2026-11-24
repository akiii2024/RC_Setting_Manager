import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'schumacher/mi9';

  test('カタログに Schumacher Mi9 が登録されている', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );

    expect(car.name, 'Mi9');
    expect(car.category, 'ツーリングカー');
    expect(car.imageUrl, 'assets/images/mi9.jpg');
    expect(car.manufacturer.id, 'schumacher');
    expect(car.manufacturer.name, 'Schumacher');
    expect(car.manufacturer.logoPath, 'assets/images/schumacher.png');
  });

  test('Mi9 の定義に重複キーがなく、固有項目が指定カテゴリに属する', () {
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
    for (final setting in specificSettings) {
      expect(
        setting.category,
        isIn(['front', 'rear', 'frontDamper', 'rearDamper', 'other', 'top']),
        reason: setting.key,
      );
    }
  });
}
