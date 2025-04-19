import '../models/car_setting_definition.dart';
import 'car_settings/definitions/tamiya/trf420x_settings.dart' as trf420x;
import 'car_settings/definitions/tamiya/trf421_settings.dart' as trf421;
import 'car_settings/definitions/yokomo/bd12_settings.dart' as bd12;

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'tamiya/trf421': trf421.trf421Settings,
  'tamiya/trf420x': trf420x.trf420xSettings,
  'yokomo/bd12': bd12.bd12Settings,
};

// 車種IDから設定定義を取得する関数
CarSettingDefinition? getCarSettingDefinition(String carId) {
  print('Searching for car ID: $carId'); // デバッグ用ログ
  print('Available definitions: ${carSettingsDefinitions.keys}'); // デバッグ用ログ
  return carSettingsDefinitions[carId];
}
