import '../../../../models/car_setting_definition.dart';
import '../../../motor_name_options.dart';
import '../../../setting_name_options.dart';
import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import '../common/setting_item_helpers.dart';
import 'yokomo_touring_common.dart';

List<SettingItem> _bd11SetupSideSettings({
  required String prefix,
  required String category,
  required String labelPrefix,
  required List<String> hubOptions,
}) {
  return yokomoTouringSideSettings(
    prefix: prefix,
    category: category,
    labelPrefix: labelPrefix,
    includeCamHeight: true,
    wheelHubOptions: hubOptions,
    camberLabel: 'キャンバー',
    swayBarMax: 2.0,
    swayBarDefaultValue: '1.2',
    includeWeight: true,
  );
}

List<SettingItem> _bd11ShockSettings({
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

final List<SettingItem> bd11SpecificSettings = [
  gridSetting(
    key: 'frontUpperArmPosition',
    category: 'front',
    label: 'フロント アッパーアーム位置',
    rows: 1,
    cols: 5,
  ),
  selectSetting(
    key: 'frontCHub',
    category: 'front',
    label: 'フロント Cハブ',
    options: const ['グラファイト', 'スタンダード'],
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
  selectSetting(
    key: 'frontSteeringBlock',
    category: 'front',
    label: 'フロント ステアリングナックル',
    options: const ['グラファイト', 'スタンダード'],
  ),
  numberSetting(
    key: 'frontSteeringBlockSpacer',
    category: 'front',
    label: 'フロント ステアリングナックルスペーサー',
    unit: 'mm',
    max: 10,
  ),
  ..._bd11SetupSideSettings(
    prefix: 'front',
    category: 'front',
    labelPrefix: 'フロント',
    hubOptions: const ['4.0mm', '4.5mm', '5.0mm', '6.0mm'],
  ),
  ..._bd11ShockSettings(
    prefix: 'front',
    category: 'frontDamper',
    labelPrefix: 'フロント',
  ),
  gridSetting(
    key: 'rearUpperArmPosition',
    category: 'rear',
    label: 'リア アッパーアーム位置',
    rows: 1,
    cols: 5,
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
  ..._bd11SetupSideSettings(
    prefix: 'rear',
    category: 'rear',
    labelPrefix: 'リア',
    hubOptions: const ['4.0mm', '4.5mm', '5.0mm', '6.0mm'],
  ),
  ..._bd11ShockSettings(
    prefix: 'rear',
    category: 'rearDamper',
    labelPrefix: 'リア',
  ),
  selectSetting(
    key: 'mainChassis',
    category: 'other',
    label: 'メインシャーシ',
    options: const ['カーボン', 'アルミ'],
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
    key: 'batteryPosition',
    category: 'top',
    label: 'バッテリー位置',
    rows: 3,
    cols: 2,
    multiple: true,
  ),
  textSetting(
    key: 'frontTire',
    category: 'other',
    options: tireNameOptions,
    label: 'フロント タイヤ',
  ),
  textSetting(
    key: 'rearTire',
    category: 'other',
    options: tireNameOptions,
    label: 'リア タイヤ',
  ),
  textSetting(
    key: 'frontTireInsert',
    category: 'other',
    label: 'フロント インナー',
  ),
  textSetting(
    key: 'rearTireInsert',
    category: 'other',
    label: 'リア インナー',
  ),
  textSetting(
    key: 'frontWheel',
    category: 'other',
    label: 'フロント ホイール',
  ),
  textSetting(
    key: 'rearWheel',
    category: 'other',
    label: 'リア ホイール',
  ),
  textSetting(
    key: 'frontTireTreatment',
    category: 'other',
    label: 'フロント トラクション剤',
  ),
  textSetting(
    key: 'rearTireTreatment',
    category: 'other',
    label: 'リア トラクション剤',
  ),
];

final bd11Settings = buildCarSettingDefinition(
  carId: 'yokomo/bd11',
  basicSettings: basicSettings,
  specificSettings: bd11SpecificSettings,
  isHumanVerified: false,
);
