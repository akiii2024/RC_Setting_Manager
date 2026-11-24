import '../../../../models/car_setting_definition.dart';
import '../common/setting_item_helpers.dart';

/// TRF421系で共通する前後ダンパー項目を構築する。
/// キット説明図のロッド露出8mm・エア抜き穴1mmを基準にする。
/// https://www.tamiya.com/japan/download/rcmanual/42384.pdf
///
/// シート表記が異なるエア抜き穴のラベルだけを車種側から受け取る。
List<SettingItem> trfDamperSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
  required String airHoleLabel,
}) {
  final labelEnPrefix = prefix == 'front' ? 'Front' : 'Rear';
  return [
    selectSetting(
      key: '${prefix}DamperPosition',
      category: category,
      label: '$labelPrefix ダンパーポジション',
      labelEn: '$labelEnPrefix Damper Position',
      options: const ['1', '2', '3'],
      constraints: const {'selectGuide': 'insideOutside'},
      defaultValue: '2',
    ),
    numberSetting(
      key: '${prefix}SusArm',
      category: category,
      label: '$labelPrefix サスアーム',
      labelEn: '$labelEnPrefix Suspension Arm',
      unit: 'mm',
      max: 10,
    ),
    textSetting(
      key: '${prefix}DamperType',
      category: category,
      label: '$labelPrefix ダンパータイプ',
      labelEn: '$labelEnPrefix Damper Type',
    ),
    textSetting(
      key: '${prefix}DamperOilSeal',
      category: category,
      label: '$labelPrefix オイルシール',
      labelEn: '$labelEnPrefix Oil Seal',
    ),
    numberSetting(
      key: '${prefix}DamperPiston',
      category: category,
      label: '$labelPrefix ピストン',
      labelEn: '$labelEnPrefix Piston',
      unit: 'φ',
      min: 1.0,
      max: 3.0,
      step: 0.1,
      defaultValue: '1.1',
      constraints: {
        'composite': 'damperPiston',
        'pistonKey': '${prefix}DamperPiston',
        'holeKey': '${prefix}DamperPistonHole',
      },
    ),
    numberSetting(
      key: '${prefix}DamperPistonHole',
      category: category,
      label: '$labelPrefix ピストン穴数',
      labelEn: '$labelEnPrefix Piston Hole Count',
      min: 1,
      max: 10,
      step: 1,
      defaultValue: '4',
    ),
    textSetting(
      key: '${prefix}DamperOil',
      category: category,
      label: '$labelPrefix オイル',
      labelEn: '$labelEnPrefix Damper Oil',
      unit: '#',
      constraints: {
        'composite': 'damperOil',
        'oilKey': '${prefix}DamperOil',
        'oilNameKey': '${prefix}DamperOilName',
      },
    ),
    textSetting(
      key: '${prefix}DamperOilName',
      category: category,
      label: '$labelPrefix オイル名',
      labelEn: '$labelEnPrefix Damper Oil Name',
    ),
    textSetting(
      key: '${prefix}DamperSpring',
      category: category,
      label: '$labelPrefix スプリング',
      labelEn: '$labelEnPrefix Spring',
    ),
    numberSetting(
      key: '${prefix}DamperStroke',
      category: category,
      label: '$labelPrefix ストローク長',
      labelEn: '$labelEnPrefix Stroke Length',
      unit: 'mm',
      max: 50,
      defaultValue: '8',
    ),
    numberSetting(
      key: '${prefix}DamperAirHole',
      category: category,
      label: '$labelPrefix $airHoleLabel',
      labelEn: '$labelEnPrefix Air Hole',
      unit: 'mm',
      max: 5,
      step: 0.1,
      defaultValue: '1',
    ),
  ];
}
