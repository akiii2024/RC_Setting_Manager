import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/data/built_in_car_catalog.dart';
import 'package:rc_setting_manager/domain/settings/setting_name_policy.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';

void main() {
  test('built-in catalog keeps persisted identifiers and merge order', () {
    final catalog = BuiltInCarCatalog.create();
    expect(catalog.map((car) => car.id), [
      'tamiya/trf421',
      'tamiya/trf420x',
      'tamiya/trf421x',
      'yokomo/bd11',
      'yokomo/bd12',
      'yokomo/ms1_0',
      'yokomo/ms2_0',
    ]);

    final customized = catalog.first.copyWith(isInGarage: true);
    final merged = BuiltInCarCatalog.mergeInto([customized]);
    expect(merged.first.isInGarage, isTrue);
    expect(merged.map((car) => car.id).toSet(), hasLength(catalog.length));
  });

  test('setting name policy keeps numeric suffix behavior', () {
    final car = BuiltInCarCatalog.create().first;
    final existing = [
      SavedSetting(
        id: '1',
        name: 'Race Setup',
        createdAt: DateTime(2026),
        car: car,
        settings: const {},
      ),
      SavedSetting(
        id: '2',
        name: 'Race Setup (1)',
        createdAt: DateTime(2026),
        car: car,
        settings: const {},
      ),
    ];

    expect(
      SettingNamePolicy.uniqueName(' Race Setup ', existing),
      'Race Setup (2)',
    );
    expect(
      SettingNamePolicy.uniqueName('Race Setup', existing, excludeId: '1'),
      'Race Setup',
    );
    expect(
      SettingNamePolicy.runResultName(DateTime(2026, 8, 3), car),
      '2026-08-03-TRF421-run',
    );
  });
}
