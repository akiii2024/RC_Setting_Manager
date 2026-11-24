import '../../../../models/car_setting_definition.dart';

Map<String, dynamic> _mergedConstraints(
  Map<String, dynamic> base,
  Map<String, dynamic> extra,
) {
  return {
    ...base,
    ...extra,
  };
}

SettingItem numberSetting({
  required String key,
  required String category,
  required String label,
  String? labelEn,
  String? unit,
  num min = 0,
  num max = 100,
  num step = 0.5,
  String defaultValue = '0',
  Map<String, dynamic> constraints = const {},
}) {
  return SettingItem(
    key: key,
    type: 'number',
    category: category,
    label: label,
    labelEn: labelEn,
    unit: unit,
    constraints: _mergedConstraints(
      {'min': min, 'max': max, 'step': step},
      constraints,
    ),
    defaultValue: defaultValue,
  );
}

SettingItem textSetting({
  required String key,
  required String category,
  required String label,
  String? labelEn,
  String? unit,
  List<String>? options,
  String defaultValue = '',
  Map<String, dynamic> constraints = const {},
}) {
  return SettingItem(
    key: key,
    type: 'text',
    category: category,
    label: label,
    labelEn: labelEn,
    unit: unit,
    options: options,
    constraints: constraints,
    defaultValue: defaultValue,
  );
}

SettingItem selectSetting({
  required String key,
  required String category,
  required String label,
  String? labelEn,
  required List<String> options,
  String? defaultValue,
  Map<String, dynamic> constraints = const {},
}) {
  return SettingItem(
    key: key,
    type: 'select',
    category: category,
    label: label,
    labelEn: labelEn,
    options: options,
    constraints: constraints,
    defaultValue: defaultValue ?? options.first,
  );
}

SettingItem gridSetting({
  required String key,
  required String category,
  required String label,
  String? labelEn,
  required int rows,
  required int cols,
  bool multiple = false,
  String defaultValue = '',
  Map<String, dynamic> constraints = const {},
}) {
  return SettingItem(
    key: key,
    type: 'grid',
    defaultValue: defaultValue,
    category: category,
    label: label,
    labelEn: labelEn,
    constraints: _mergedConstraints(
      {
        'rows': rows,
        'cols': cols,
        'multiple': multiple,
      },
      constraints,
    ),
  );
}
