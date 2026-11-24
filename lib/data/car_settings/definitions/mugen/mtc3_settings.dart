import '../../../../models/car_setting_definition.dart';
import '../../../motor_name_options.dart';
import '../../../setting_name_options.dart';
import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import '../common/setting_item_helpers.dart';

final mtc3Settings = buildCarSettingDefinition(
  carId: 'mugen/mtc3',
  basicSettings: basicSettings,
  specificSettings: [
    ..._endSettings('front', 'フロント'),
    ..._damperSettings('front', 'フロント'),
    ..._endSettings('rear', 'リヤ'),
    ..._damperSettings('rear', 'リヤ'),
    ..._chassisSettings,
    ..._equipmentSettings,
  ],
  isHumanVerified: false,
);

List<SettingItem> _endSettings(String end, String label) => [
  // 入力範囲の記載がないため、車高・キャンバーは
  // X4'24 の同種項目の範囲と刻みを使用。
  numberSetting(
    key: '${end}RideHeight',
    category: end,
    label: '$label 車高',
    unit: 'mm',
    min: 3,
    max: 10,
    step: 0.1,
    defaultValue: '5',
  ),
  numberSetting(
    key: '${end}Camber',
    category: end,
    label: '$label キャンバー角',
    unit: 'degr.',
    min: -10,
    max: 10,
    step: 0.5,
    defaultValue: '-2',
  ),
  // シートのダウンストップ記入値（23.6 / 22.4 mm）は
  // X4'24 の範囲（-3〜10 mm）外のため、単位付きの自由記入。
  textSetting(
    key: '${end}Droop',
    category: end,
    label: '$label ダウンストップ',
    unit: 'mm',
  ),
  // アップトラベルとキャスターは同じ測定方式で比較できる
  // 入力範囲を確認できないため自由記入。
  textSetting(key: '${end}UpTravel', category: end, label: '$label アップトラベル'),
  textSetting(
    key: '${end}CasterAngle',
    category: end,
    label: '$label キャスター角',
    unit: 'degr.',
  ),
  textSetting(key: '${end}UpperArm', category: end, label: '$label アッパーアーム'),
];

List<SettingItem> _damperSettings(String end, String label) {
  final category = '${end}Damper';
  return [
    selectSetting(
      key: '${end}DamperHolder',
      category: category,
      label: '$label ダンパーホルダー形式',
      options: const ['ACTIVE', 'FIXED'],
    ),
    selectSetting(
      key: '${end}DamperBypass',
      category: category,
      label: '$label ダンパーバイパス方向',
      options: const ['VERTICAL', 'HORIZONTAL'],
    ),
    textSetting(
      key: '${end}DamperSpring',
      category: category,
      label: '$label スプリング',
    ),
    textSetting(
      key: '${end}ShockOil',
      category: category,
      label: '$label ダンパーオイル',
      unit: 'cSt',
    ),
    if (end == 'rear')
      textSetting(
        key: 'rearDamperOring',
        category: category,
        label: '$label ダンパーOリング',
      ),
  ];
}

final _chassisSettings = [
  textSetting(key: 'chassisType', category: 'top', label: 'シャーシタイプ'),
  selectSetting(
    key: 'steeringPosition',
    category: 'top',
    label: 'ステアリング位置',
    options: const ['OUTSIDE', 'INSIDE'],
  ),
  textSetting(key: 'rodPosition', category: 'top', label: 'ロッド位置'),
  textSetting(key: 'screwPositions', category: 'top', label: 'ビス位置'),
  textSetting(
    key: 'motorMountScrewPositions',
    category: 'top',
    label: 'モーターマウントのビス位置',
  ),
  textSetting(key: 'sideStiffener', category: 'top', label: 'サイドスティフナー'),
  // X4'24 と同じく、総重量は自由記入、重量配分は 0〜100%。
  textSetting(key: 'totalWeight', category: 'top', label: '車重', unit: 'g'),
  for (final (end, label) in const [('front', '前'), ('rear', '後')])
    numberSetting(
      key: '${end}WeightBalance',
      category: 'top',
      label: '$label重量配分',
      unit: '%',
      min: 0,
      max: 100,
      step: 0.5,
      defaultValue: '50',
    ),
  // シートに範囲の記載がないため、X4'24 のバランスウエイトを参照。
  for (final (key, label) in const [
    ('batteryWeight', 'バッテリー下のウエイト'),
    ('centerWeight', 'センターウエイト'),
  ])
    numberSetting(
      key: key,
      category: 'top',
      label: label,
      unit: 'g',
      min: 0,
      max: 100,
      step: 0.5,
    ),
];

final _equipmentSettings = [
  textSetting(key: 'driverName', category: 'other', label: 'ドライバー名'),
  textSetting(key: 'track', category: 'other', label: 'サーキット名'),
  selectSetting(
    key: 'trackLayout',
    category: 'other',
    label: 'コースレイアウト',
    options: const ['TECHNICAL', 'MIXED', 'FAST'],
  ),
  selectSetting(
    key: 'traction',
    category: 'other',
    label: '路面グリップ',
    options: const ['LOW', 'MEDIUM', 'HIGH'],
  ),
  textSetting(key: 'race', category: 'other', label: 'レース名'),
  textSetting(key: 'result', category: 'other', label: 'レース結果'),
  textSetting(key: 'transmitter', category: 'other', label: '送信機'),
  textSetting(key: 'receiver', category: 'other', label: '受信機'),
  textSetting(key: 'servo', category: 'other', label: 'サーボ'),
  // シートに入力範囲がなく、X4'24 に同種項目がないため自由記入。
  textSetting(key: 'steeringExpo', category: 'other', label: 'ステアリングEXP'),
  textSetting(key: 'steeringSpeed', category: 'other', label: 'ステアリング速度'),
  textSetting(
    key: 'motor',
    category: 'other',
    label: 'モーター',
    options: motorNameOptions,
  ),
  textSetting(
    key: 'battery',
    category: 'other',
    label: 'バッテリー',
    options: batteryNameOptions,
  ),
  textSetting(key: 'pinionGearType', category: 'other', label: 'ピニオンギヤの種類'),
  textSetting(key: 'spurGearType', category: 'other', label: 'スパーギヤの種類'),
  // シートに入力範囲の記載がないため、X4'24 の同種項目を使用。
  numberSetting(
    key: 'pinionGear',
    category: 'other',
    label: 'ピニオンギヤ',
    unit: 'T',
    min: 20,
    max: 60,
    step: 1,
    defaultValue: '30',
  ),
  numberSetting(
    key: 'spurGear',
    category: 'other',
    label: 'スパーギヤ',
    unit: 'T',
    min: 60,
    max: 120,
    step: 1,
    defaultValue: '116',
  ),
  textSetting(
    key: 'tire',
    category: 'other',
    label: 'タイヤ',
    options: tireNameOptions,
  ),
  textSetting(key: 'additive', category: 'other', label: 'タイヤ添加剤'),
  // ウォーマーの温度と時間は X4'24 と同様に自由記入。
  textSetting(
    key: 'tireWarmerTemperature',
    category: 'other',
    label: 'タイヤウォーマー温度',
    unit: '℃',
  ),
  textSetting(
    key: 'tireWarmerTiming',
    category: 'other',
    label: 'タイヤウォーマー加温時間',
  ),
  textSetting(key: 'sidewallGlue', category: 'other', label: 'タイヤ側面の接着剤'),
  textSetting(
    key: 'body',
    category: 'other',
    label: 'ボディ',
    options: bodyNameOptions,
  ),
  textSetting(key: 'wing', category: 'other', label: 'ウイング'),
  selectSetting(
    key: 'winglet',
    category: 'other',
    label: 'ウイングレット',
    options: const ['WIDE', 'NARROW'],
  ),
];
