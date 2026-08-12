import '../../../../models/car_setting_definition.dart';

/// 全車共通設定と車種固有設定を、順序を保ったまま1つの定義へまとめる。
CarSettingDefinition buildCarSettingDefinition({
  required String carId,
  required List<SettingItem> basicSettings,
  required List<SettingItem> specificSettings,
  bool isHumanVerified = false,
}) {
  return CarSettingDefinition(
    carId: carId,
    availableSettings: [...basicSettings, ...specificSettings],
    isHumanVerified: isHumanVerified,
  );
}
