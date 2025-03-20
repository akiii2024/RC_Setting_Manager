import '../../models/car_setting_definition.dart';
import 'definitions/tamiya/trf420x_settings.dart';
import 'definitions/tamiya/trf421_settings.dart';

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'tamiya/trf421': trf421Settings,
  'tamiya/trf420x': trf420xSettings,
};

// 車種IDから設定定義を取得する関数
CarSettingDefinition? getCarSettingDefinition(String carId) {
  return carSettingsDefinitions[carId];
}
