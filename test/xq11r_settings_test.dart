import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/data/car_settings/common/basic_settings.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';

void main() {
  const carId = 'xpress/xq11r';

  test('Xpress XQ11R が組み込みカタログに登録されている', () {
    final car = BuiltInCarCatalog.create().singleWhere(
      (car) => car.id == carId,
    );

    expect(car.name, 'XQ11R');
    expect(car.category, 'ツーリングカー');
    expect(car.imageUrl, 'assets/images/xq11r.jpg');
    expect(car.manufacturer.id, 'xpress');
    expect(car.manufacturer.name, 'Xpress');
    expect(car.manufacturer.logoPath, 'assets/images/xpress.png');
  });

  test('XQ11R の定義に重複キーがなく、車種固有項目は指定カテゴリに属する', () {
    final definition = getCarSettingDefinition(carId);
    expect(definition, isNotNull);
    expect(definition!.isHumanVerified, isFalse);

    final settings = definition.availableSettings;
    final keys = settings.map((setting) => setting.key);
    expect(keys.toSet(), hasLength(settings.length));

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
