import '../domain/settings/setting_label_mode.dart';
import '../models/car_setting_definition.dart';

String resolveSettingLabel(
  SettingItem item, {
  required bool isEnglish,
  required SettingLabelMode mode,
}) {
  final useEnglish = switch (mode) {
    SettingLabelMode.auto => isEnglish,
    SettingLabelMode.japanese => false,
    SettingLabelMode.english => true,
  };
  return useEnglish ? item.labelEn ?? item.label : item.label;
}
