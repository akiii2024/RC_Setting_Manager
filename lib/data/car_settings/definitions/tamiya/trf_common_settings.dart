import '../../../../models/car_setting_definition.dart';
import '../common/setting_item_helpers.dart';

/// TRF421系で共通する前後ダンパー項目を構築する。
///
/// シート表記が異なるエア抜き穴のラベルだけを車種側から受け取る。
List<SettingItem> trfDamperSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
  required String airHoleLabel,
}) {
  return [
    selectSetting(
      key: '${prefix}DamperPosition',
      category: category,
      label: '$labelPrefix ダンパーポジション',
      options: const ['1', '2', '3'],
      constraints: const {'selectGuide': 'insideOutside'},
    ),
    numberSetting(
      key: '${prefix}SusArm',
      category: category,
      label: '$labelPrefix サスアーム',
      unit: 'mm',
      max: 10,
    ),
    textSetting(
      key: '${prefix}DamperType',
      category: category,
      label: '$labelPrefix ダンパータイプ',
    ),
    textSetting(
      key: '${prefix}DamperOilSeal',
      category: category,
      label: '$labelPrefix オイルシール',
    ),
    numberSetting(
      key: '${prefix}DamperPiston',
      category: category,
      label: '$labelPrefix ピストン',
      unit: 'φ',
      min: 1.0,
      max: 3.0,
      step: 0.1,
      defaultValue: '1.0',
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
      min: 1,
      max: 10,
      step: 1,
      defaultValue: '4',
    ),
    textSetting(
      key: '${prefix}DamperOil',
      category: category,
      label: '$labelPrefix オイル',
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
    ),
    textSetting(
      key: '${prefix}DamperSpring',
      category: category,
      label: '$labelPrefix スプリング',
    ),
    numberSetting(
      key: '${prefix}DamperStroke',
      category: category,
      label: '$labelPrefix ストローク長',
      unit: 'mm',
      max: 50,
    ),
    numberSetting(
      key: '${prefix}DamperAirHole',
      category: category,
      label: '$labelPrefix $airHoleLabel',
      unit: 'mm',
      max: 5,
      step: 0.1,
    ),
  ];
}
