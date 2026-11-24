import 'package:rc_setting_manager/utils/app_logger.dart';

import '../models/car_setting_definition.dart';
import 'car_settings/definitions/arc/arc_r12_settings.dart' as arc_r12;
import 'car_settings/definitions/awesomatix/a800r_settings.dart' as a800r;
import 'car_settings/definitions/infinity/if14_2_settings.dart' as if14_2;
import 'car_settings/definitions/mugen/mtc2_fwd_settings.dart' as mtc2_fwd;
import 'car_settings/definitions/mugen/mtc3_settings.dart' as mtc3;
import 'car_settings/definitions/schumacher/mi9_settings.dart' as mi9;
import 'car_settings/definitions/xpress/xq11r_settings.dart' as xq11r;
import 'car_settings/definitions/tamiya/trf420_settings.dart' as trf420;
import 'car_settings/definitions/tamiya/trf420x_settings.dart' as trf420x;
import 'car_settings/definitions/tamiya/trf421_settings.dart' as trf421;
import 'car_settings/definitions/tamiya/trf421x_settings.dart' as trf421x;
import 'car_settings/definitions/xray/x4_24_settings.dart' as x4_24;
import 'car_settings/definitions/yokomo/bd11_settings.dart' as bd11;
import 'car_settings/definitions/yokomo/bd12_settings.dart' as bd12;
import 'car_settings/definitions/yokomo/ms1_settings.dart' as ms1;
import 'car_settings/definitions/yokomo/ms2_settings.dart' as ms2;

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'tamiya/trf421': trf421.trf421Settings,
  'tamiya/trf420': trf420.trf420Settings,
  'tamiya/trf420x': trf420x.trf420xSettings,
  'tamiya/trf421x': trf421x.trf421xSettings,
  'yokomo/bd11': bd11.bd11Settings,
  'yokomo/bd12': bd12.bd12Settings,
  'yokomo/ms1_0': ms1.ms1Settings,
  'yokomo/ms2_0': ms2.ms2Settings,
  'xray/x4_24': x4_24.x4_24Settings,
  'arc/arc_r12': arc_r12.arcR12Settings,
  'awesomatix/a800r': a800r.a800rSettings,
  'infinity/if14_2': if14_2.if142Settings,
  'mugen/mtc2_fwd': mtc2_fwd.mtc2FwdSettings,
  'mugen/mtc3': mtc3.mtc3Settings,
  'schumacher/mi9': mi9.mi9Settings,
  'xpress/xq11r': xq11r.xq11rSettings,
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
