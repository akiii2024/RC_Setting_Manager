import 'package:flutter_test/flutter_test.dart';

import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/presentation/settings/visibility_settings_presenter.dart';

void main() {
  test('groups setting keys in stable editor order', () {
    final definitions = <String, SettingItem>{
      'rearToe': SettingItem(
        key: 'rearToe',
        type: 'number',
        category: 'rear',
        label: 'Rear Toe',
      ),
      'frontSpring': SettingItem(
        key: 'frontSpring',
        type: 'text',
        category: 'front',
        label: 'Front Spring',
      ),
    };

    final grouped = VisibilitySettingsPresenter.groupSettingKeys(
      settingKeys: const ['customValue', 'rearToe', 'date', 'frontSpring'],
      definitionByKey: definitions,
      isEnglish: true,
    );

    expect(grouped.keys, [
      'Basic Information',
      'Front Damper Settings',
      'Rear Settings',
      'Other Settings',
    ]);
    expect(grouped['Front Damper Settings'], ['frontSpring']);
    expect(grouped['Other Settings'], ['customValue']);
  });

  test('fallback categories and labels preserve legacy behavior', () {
    expect(
      VisibilitySettingsPresenter.fallbackCategoryForKey('rearDamperOil'),
      'rearDamper',
    );
    expect(
      VisibilitySettingsPresenter.fallbackCategoryForKey('upperDeckScrew'),
      'top',
    );
    expect(
      VisibilitySettingsPresenter.settingLabel('frontRideHeight', true),
      'Front Ride Height',
    );
    expect(
      VisibilitySettingsPresenter.settingLabel('frontRideHeight', false),
      'frontRideHeight',
    );
  });
}
