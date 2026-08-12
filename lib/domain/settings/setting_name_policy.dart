import '../../models/car.dart';
import '../../models/saved_setting.dart';

/// Stable naming rules shared by manual, copied, and run-result settings.
abstract final class SettingNamePolicy {
  static String uniqueName(
    String requestedName,
    Iterable<SavedSetting> existingSettings, {
    String? excludeId,
  }) {
    final trimmedName = requestedName.trim();
    if (trimmedName.isEmpty) {
      return requestedName;
    }

    final existingNames = existingSettings
        .where((setting) => setting.id != excludeId)
        .map((setting) => setting.name.trim())
        .toSet();
    if (!existingNames.contains(trimmedName)) {
      return trimmedName;
    }

    final baseName = _stripNumericSuffix(trimmedName);
    var suffix = 1;
    while (existingNames.contains('$baseName ($suffix)')) {
      suffix++;
    }
    return '$baseName ($suffix)';
  }

  static String runResultName(DateTime runAt, Car car) {
    final formattedDate =
        '${runAt.year}-${runAt.month.toString().padLeft(2, '0')}-${runAt.day.toString().padLeft(2, '0')}';
    return '$formattedDate-${car.name}-run';
  }

  static String _stripNumericSuffix(String name) {
    final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(name);
    if (match == null) {
      return name;
    }
    final baseName = match.group(1)?.trim();
    return baseName == null || baseName.isEmpty ? name : baseName;
  }
}
