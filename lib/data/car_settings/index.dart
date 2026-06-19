import '../../models/car_setting_definition.dart';
import 'definitions/tamiya/trf420x_settings.dart';
import 'definitions/tamiya/trf421_settings.dart';
import 'definitions/tamiya/trf421x_settings.dart';
import 'definitions/yokomo/bd11_settings.dart';
import 'definitions/yokomo/bd12_settings.dart';
import 'definitions/yokomo/ms1_settings.dart';
import 'definitions/yokomo/ms2_settings.dart';

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'tamiya/trf421': trf421Settings,
  'tamiya/trf420x': trf420xSettings,
  'tamiya/trf421x': trf421xSettings,
  'yokomo/bd11': bd11Settings,
  'yokomo/bd12': bd12Settings,
  'yokomo/ms1_0': ms1Settings,
  'yokomo/ms2_0': ms2Settings,
};

// 車種IDから設定定義を取得する関数
CarSettingDefinition? getCarSettingDefinition(String carId) {
  return carSettingsDefinitions[carId];
}
