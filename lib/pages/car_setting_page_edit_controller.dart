part of 'car_setting_page.dart';

/// Owns the mutable value state of a car-setting editing session.
///
/// The page state intentionally exposes compatibility accessors so existing
/// editor, import, AI, and save flows keep their behavior while lifecycle and
/// initialization are centralized here.
class _CarSettingEditController {
  final String carName;
  final CarSettingDefinition? settingDefinition;
  final TextEditingController settingNameController = TextEditingController();
  final TextEditingController trackNameController = TextEditingController();

  late Map<String, dynamic> settings;
  late Map<String, dynamic> initialSettingsSnapshot;
  String? activeSavedSettingId;
  bool isEditing = false;

  _CarSettingEditController({
    required CarSettingPage page,
    required this.settingDefinition,
  }) : carName = page.originalCar.name {
    final savedSettings = page.savedSettings;
    if (savedSettings != null) {
      settings = Map<String, dynamic>.from(savedSettings);
      isEditing = page.savedSettingId != null;
      if (page.settingName != null && page.settingName!.trim().isNotEmpty) {
        settingNameController.text = page.settingName!;
      } else {
        settingNameController.text = buildDefaultSettingName();
      }
    } else {
      settings = <String, dynamic>{};
      if (settingDefinition != null) {
        for (final setting in settingDefinition!.availableSettings) {
          settings[setting.key] = _getDefaultValueForType(setting);
        }
      }
      settingNameController.text = buildDefaultSettingName();
    }

    activeSavedSettingId = page.savedSettingId;
    initialSettingsSnapshot = Map<String, dynamic>.from(settings);
  }

  String buildDefaultSettingName() {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '$formattedDate-$carName';
  }

  void dispose() {
    settingNameController.dispose();
    trackNameController.dispose();
  }
}
