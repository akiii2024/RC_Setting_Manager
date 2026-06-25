import 'package:rc_setting_manager/utils/app_logger.dart';
import '../models/car_setting_definition.dart';
import 'car_settings/definitions/tamiya/trf420x_settings.dart' as trf420x;
import 'car_settings/definitions/tamiya/trf421_settings.dart' as trf421;
import 'car_settings/definitions/tamiya/trf421x_settings.dart' as trf421x;
import 'car_settings/definitions/yokomo/bd11_settings.dart' as bd11;
import 'car_settings/definitions/yokomo/bd12_settings.dart' as bd12;
import 'car_settings/definitions/yokomo/ms1_settings.dart' as ms1;
import 'car_settings/definitions/yokomo/ms2_settings.dart' as ms2;

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'tamiya/trf421': trf421.trf421Settings,
  'tamiya/trf420x': trf420x.trf420xSettings,
  'tamiya/trf421x': trf421x.trf421xSettings,
  'yokomo/bd11': bd11.bd11Settings,
  'yokomo/bd12': bd12.bd12Settings,
  'yokomo/ms1_0': ms1.ms1Settings,
  'yokomo/ms2_0': ms2.ms2Settings,
};

// 車種IDから設定定義を取得する関数
CarSettingDefinition? getCarSettingDefinition(String carId) {
  debugLog('Searching for car ID: $carId'); // デバッグ用ログ
  debugLog('Available definitions: ${carSettingsDefinitions.keys}'); // デバッグ用ログ
  return carSettingsDefinitions[carId];
}

bool isDamperSettingKey(String key) {
  return key.contains('Damper') ||
      key.contains('Dumper') ||
      key.contains('Shock') ||
      key.contains('Bladder') ||
      key.contains('Piston') ||
      key.endsWith('Spring');
}

String displayCategoryForSetting(SettingItem setting) {
  final key = setting.key;
  final category = setting.category;

  if (category == 'frontDamper' || category == 'rearDamper') {
    return category;
  }

  if (category == 'damper') {
    if (key.startsWith('front')) {
      return 'frontDamper';
    }
    if (key.startsWith('rear')) {
      return 'rearDamper';
    }
  }

  if ((category == 'front' || key.startsWith('front')) &&
      isDamperSettingKey(key)) {
    return 'frontDamper';
  }

  if ((category == 'rear' || key.startsWith('rear')) &&
      isDamperSettingKey(key)) {
    return 'rearDamper';
  }

  if (category == 'general' || category == 'chassis') {
    return 'other';
  }

  if (category == 'suspension') {
    if (key.startsWith('front')) {
      return 'front';
    }
    if (key.startsWith('rear')) {
      return 'rear';
    }
    return 'front';
  }

  return category;
}
