import '../../../../models/car_setting_definition.dart';
import '../../../motor_name_options.dart';
import '../../../setting_name_options.dart';
import '../common/setting_item_helpers.dart';
import 'yokomo_touring_common.dart';

List<SettingItem> _masterSpeedSideSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
}) {
  return yokomoTouringSideSettings(
    prefix: prefix,
    category: category,
    labelPrefix: labelPrefix,
    includeCamHeight: true,
    wheelHubOptions: const ['4.0mm', '4.5mm', '5.0mm'],
    camberLabel: 'キャンバー',
    swayBarMax: 1.2,
    swayBarDefaultValue: '1.0',
    includeWeight: true,
  );
}

List<SettingItem> _masterSpeedShockSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
}) {
  return yokomoTouringShockSettings(
    prefix: prefix,
    category: category,
    labelPrefix: labelPrefix,
  );
}

List<SettingItem> masterSpeedSpecificSettings({required bool isMs2}) {
  return [
    textSetting(
      key: 'frontUpperDeck',
      category: 'front',
      label: 'フロント アッパーデッキ',
    ),
    gridSetting(
      key: 'frontUpperArmPosition',
      category: 'front',
      label: 'フロント アッパーアーム位置',
      rows: 1,
      cols: 5,
    ),
    numberSetting(
      key: 'frontBellCrankPostSpacer',
      category: 'front',
      label: 'フロント ベルクランクポストスペーサー',
      unit: 'mm',
      max: 10,
    ),
    selectSetting(
      key: 'frontBellCrank',
      category: 'front',
      label: 'フロント ベルクランク',
      options: const ['18.5mm', '20.0mm'],
    ),
    numberSetting(
      key: 'frontBellCrankSpacer',
      category: 'front',
      label: 'フロント ベルクランクスペーサー',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'frontSpacerFF',
      category: 'front',
      label: 'フロント スペーサー FF',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'frontSpacerFR',
      category: 'front',
      label: 'フロント スペーサー FR',
      unit: 'mm',
      max: 10,
    ),
    if (!isMs2)
      selectSetting(
        key: 'frontSteeringBlock',
        category: 'front',
        label: 'フロント ステアリングナックル',
        options: const ['グラファイト', 'スタンダード', 'アルミ'],
      ),
    numberSetting(
      key: 'frontSteeringSpacer',
      category: 'front',
      label: 'フロント ステアリングスペーサー',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'frontOuterSpacer',
      category: 'front',
      label: 'フロント アウタースペーサー',
      unit: 'mm',
      max: 10,
    ),
    ..._masterSpeedSideSettings(
      prefix: 'front',
      category: 'front',
      labelPrefix: 'フロント',
    ),
    ..._masterSpeedShockSettings(
      prefix: 'front',
      category: 'frontDamper',
      labelPrefix: 'フロント',
    ),
    textSetting(
      key: 'rearUpperDeck',
      category: 'rear',
      label: 'リア アッパーデッキ',
    ),
    gridSetting(
      key: 'rearUpperArmPosition',
      category: 'rear',
      label: 'リア アッパーアーム位置',
      rows: 1,
      cols: isMs2 ? 2 : 3,
      multiple: true,
    ),
    textSetting(
      key: 'rearGear',
      category: 'rear',
      label: 'リア ギア',
    ),
    textSetting(
      key: 'rearGearOil',
      category: 'rear',
      label: 'リア ギアオイル',
      unit: '#',
      constraints: const {
        'composite': 'diffOil',
        'oilTypeKey': 'rearGearOilType',
        'oilKey': 'rearGearOil',
        'weightKey': 'rearGearOilWeight',
      },
    ),
    numberSetting(
      key: 'rearSpacerRF',
      category: 'rear',
      label: 'リア スペーサー RF',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'rearSpacerRR',
      category: 'rear',
      label: 'リア スペーサー RR',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'rearInnerSpacer',
      category: 'rear',
      label: 'リア インナースペーサー',
      unit: 'mm',
      max: 10,
    ),
    numberSetting(
      key: 'rearOuterSpacer',
      category: 'rear',
      label: 'リア アウタースペーサー',
      unit: 'mm',
      max: 10,
    ),
    if (isMs2) ...[
      numberSetting(
        key: 'rearUpperDeckSpacer',
        category: 'rear',
        label: 'リア アッパーデッキスペーサー',
        unit: 'mm',
        max: 10,
      ),
      numberSetting(
        key: 'rearMotorMountSpacer',
        category: 'rear',
        label: 'リア モーターマウントスペーサー',
        unit: 'mm',
        max: 10,
      ),
    ],
    ..._masterSpeedSideSettings(
      prefix: 'rear',
      category: 'rear',
      labelPrefix: 'リア',
    ),
    ..._masterSpeedShockSettings(
      prefix: 'rear',
      category: 'rearDamper',
      labelPrefix: 'リア',
    ),
    selectSetting(
      key: 'mainChassis',
      category: 'other',
      label: 'メインシャーシ',
      options: const ['カーボン', 'FRP', 'アルミ'],
    ),
    selectSetting(
      key: 'upperDeck',
      category: 'top',
      label: 'アッパーデッキ',
      options: const ['標準タイプ', '薄型タイプ'],
    ),
    textSetting(
      key: 'motor',
      category: 'other',
      label: 'モーター',
      options: motorNameOptions,
    ),
    numberSetting(
      key: 'spurGear',
      category: 'other',
      label: 'スパーギア',
      unit: 'T',
      min: 60,
      max: 120,
      step: 1,
      defaultValue: '60',
    ),
    numberSetting(
      key: 'pinionGear',
      category: 'other',
      label: 'ピニオンギア',
      unit: 'T',
      min: 20,
      max: 60,
      step: 1,
      defaultValue: '20',
    ),
    textSetting(
      key: 'battery',
      category: 'other',
      options: batteryNameOptions,
      label: 'バッテリー',
    ),
    textSetting(
      key: 'esc',
      category: 'other',
      label: 'アンプ',
      options: const ['Hobbywing', 'Muchmore', 'Yokomo', 'Futaba', 'Sanwa'],
    ),
    textSetting(
      key: 'body',
      category: 'other',
      options: bodyNameOptions,
      label: 'ボディ',
    ),
    textSetting(
      key: 'wing',
      category: 'other',
      label: 'ウイング',
    ),
    gridSetting(
      key: 'motorMountPosition',
      category: 'top',
      label: 'モーターマウント位置',
      rows: isMs2 ? 6 : 8,
      cols: 1,
      multiple: true,
    ),
    gridSetting(
      key: 'batteryPosition',
      category: 'top',
      label: 'バッテリー位置',
      rows: 4,
      cols: 2,
      multiple: true,
    ),
    textSetting(
      key: 'tire',
      category: 'other',
      options: tireNameOptions,
      label: 'タイヤ',
    ),
    textSetting(
      key: 'tireInsert',
      category: 'other',
      label: 'インナー',
    ),
    textSetting(
      key: 'wheel',
      category: 'other',
      label: 'ホイール',
    ),
    textSetting(
      key: 'tireTreatment',
      category: 'other',
      label: 'トラクション剤',
    ),
  ];
}
