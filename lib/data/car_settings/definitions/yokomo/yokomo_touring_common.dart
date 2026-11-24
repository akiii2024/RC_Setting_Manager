import '../../../../models/car_setting_definition.dart';
import '../common/setting_item_helpers.dart';

/// Yokomoツーリングカーで共通する左右の基本項目を構築する。
/// 公開セットアップを参考に、車高5mm・負キャンバー2度を汎用の基準にする。
/// https://www.teamyokomo.com/pages/setting-sheets
/// トーはトーインを正、トーアウトを負とする。
/// ドループは既存の0〜10mm範囲のゲージ値を想定する。実測時は測定基準を確認。
/// キットで指定できない別売メカ/タイヤは空欄、追加ウェイトは0g。
///
/// 各車固有の選択肢とスタビ範囲は呼び出し側で明示する。
List<SettingItem> yokomoTouringSideSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
  required bool includeCamHeight,
  required List<String>? wheelHubOptions,
  required String camberLabel,
  required num swayBarMax,
  required String swayBarDefaultValue,
  required bool includeWeight,
}) {
  final side = prefix == 'front' ? 'Front' : 'Rear';
  return [
    if (includeCamHeight)
      selectSetting(
        key: '${prefix}CamHeight',
        category: category,
        label: '$labelPrefix カム',
        labelEn: '$side Cams',
        options: const ['高', '低'],
        defaultValue: '高',
      ),
    if (wheelHubOptions != null)
      selectSetting(
        key: '${prefix}WheelHub',
        category: category,
        label: '$labelPrefix ホイールハブ',
        labelEn: '$side Wheel Hubs',
        options: wheelHubOptions,
        defaultValue: wheelHubOptions.first,
      ),
    numberSetting(
      key: '${prefix}RideHeight',
      category: category,
      label: '$labelPrefix 車高',
      labelEn: '$side Ride Height',
      unit: 'mm',
      min: 3,
      max: 10,
      step: 0.1,
      defaultValue: '5',
    ),
    numberSetting(
      key: '${prefix}Camber',
      category: category,
      label: '$labelPrefix $camberLabel',
      labelEn: '$side Camber Angle',
      unit: '°',
      min: -5,
      max: 5,
      defaultValue: '-2',
    ),
    numberSetting(
      key: '${prefix}SwayBar',
      category: category,
      label: '$labelPrefix スタビ',
      labelEn: '$side Sway Bar',
      unit: 'mm',
      min: 1.0,
      max: swayBarMax,
      step: 0.1,
      defaultValue: swayBarDefaultValue,
      constraints: {
        'composite': 'stabilizer',
        'noteKey': '${prefix}SwayBarNote',
      },
    ),
    numberSetting(
      key: '${prefix}Droop',
      category: category,
      label: '$labelPrefix ドループ',
      labelEn: '$side Droop',
      unit: 'mm',
      max: 10,
      step: 0.1,
      defaultValue: prefix == 'front' ? '5' : '4.5',
    ),
    numberSetting(
      key: '${prefix}ArmOuterLower',
      category: category,
      label: '$labelPrefix サスアーム外下',
      labelEn: '$side Arm (Outer Underside)',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: '${prefix}ToeAngle',
      category: category,
      label: '$labelPrefix トー角',
      labelEn: '$side Toe Angle',
      unit: '°',
      min: -5,
      max: 5,
      step: 0.1,
      defaultValue: prefix == 'front' ? '-1' : '3',
    ),
    if (includeWeight)
      numberSetting(
        key: '${prefix}Weight',
        category: category,
        label: '$labelPrefix ウェイト',
        labelEn: '$side Weight',
        unit: 'g',
        max: 200,
      ),
    textSetting(
      key: '${prefix}Notes',
      category: category,
      label: '$labelPrefix メモ',
      labelEn: '$side Notes',
    ),
  ];
}

/// Yokomoツーリングカーで共通する前後ショック項目を構築する。
List<SettingItem> yokomoTouringShockSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
}) {
  final side = prefix == 'front' ? 'Front' : 'Rear';
  return [
    textSetting(
      key: '${prefix}ShockOil',
      category: category,
      label: '$labelPrefix オイル',
      labelEn: '$side Damper Oil',
      unit: '#',
      constraints: {
        'composite': 'damperOil',
        'oilKey': '${prefix}ShockOil',
        'oilNameKey': '${prefix}ShockOilName',
      },
    ),
    textSetting(
      key: '${prefix}ShockOilName',
      category: category,
      label: '$labelPrefix オイル名',
      labelEn: '$side Damper Oil Name',
    ),
    numberSetting(
      key: '${prefix}Piston',
      category: category,
      label: '$labelPrefix ピストン',
      labelEn: '$side Piston',
      unit: 'mm',
      min: 0.5,
      max: 3.0,
      step: 0.1,
      defaultValue: '1.1',
      constraints: {
        'composite': 'damperPiston',
        'pistonKey': '${prefix}Piston',
        'holeKey': '${prefix}PistonHole',
      },
    ),
    numberSetting(
      key: '${prefix}PistonHole',
      category: category,
      label: '$labelPrefix ピストン穴数',
      labelEn: '$side Piston Hole Count',
      min: 1,
      max: 10,
      step: 1,
      defaultValue: '4',
    ),
    textSetting(
      key: '${prefix}Spring',
      category: category,
      label: '$labelPrefix スプリング',
      labelEn: '$side Spring',
    ),
    textSetting(
      key: '${prefix}Bladder',
      category: category,
      label: '$labelPrefix ブラダー',
      labelEn: '$side Bladder',
    ),
    textSetting(
      key: '${prefix}ShockNotes',
      category: category,
      label: '$labelPrefix ショックメモ',
      labelEn: '$side Damper Notes',
    ),
  ];
}
