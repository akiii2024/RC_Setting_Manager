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
    ..._endSettings('front', 'フロント', 'Front'),
    ..._damperSettings('front', 'フロント'),
    ..._endSettings('rear', 'リヤ', 'Rear'),
    ..._damperSettings('rear', 'リヤ'),
    ..._chassisSettings,
    ..._equipmentSettings,
  ],
  isHumanVerified: false,
);

List<SettingItem> _endSettings(String end, String label, String side) => [
      // 入力範囲の記載がないため、車高・キャンバーは
      // X4'24 の同種項目の範囲と刻みを使用。
      numberSetting(
        key: '${end}RideHeight',
        category: end,
        label: '$label 車高',
        labelEn: '$side Ride Height',
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
        labelEn: '$side Camber',
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
        labelEn: '$side Downstop',
        unit: 'mm',
      ),
      // アップトラベルとキャスターは同じ測定方式で比較できる
      // 入力範囲を確認できないため自由記入。
      textSetting(
        key: '${end}UpTravel',
        category: end,
        label: '$label アップトラベル',
        labelEn: '$side Up Travel',
      ),
      textSetting(
        key: '${end}CasterAngle',
        category: end,
        label: '$label キャスター角',
        labelEn: '$side Caster',
        unit: 'degr.',
      ),
      textSetting(
        key: '${end}UpperArm',
        category: end,
        label: '$label アッパーアーム',
        labelEn: '$side Upper Arm',
      ),
    ];

List<SettingItem> _damperSettings(String end, String label) {
  final side = end == 'front' ? 'Front' : 'Rear';
  final category = '${end}Damper';
  return [
    selectSetting(
      key: '${end}DamperHolder',
      category: category,
      label: '$label ダンパーホルダー形式',
      labelEn: '$side Damper Holder Type',
      options: const ['ACTIVE', 'FIXED'],
    ),
    selectSetting(
      key: '${end}DamperBypass',
      category: category,
      label: '$label ダンパーバイパス方向',
      labelEn: '$side Damper Bypass Direction',
      options: const ['VERTICAL', 'HORIZONTAL'],
    ),
    textSetting(
      key: '${end}DamperSpring',
      category: category,
      label: '$label スプリング',
      labelEn: '$side Spring',
    ),
    textSetting(
      key: '${end}ShockOil',
      category: category,
      label: '$label ダンパーオイル',
      labelEn: '$side Shock Oil',
      unit: 'cSt',
    ),
    if (end == 'rear')
      textSetting(
        key: 'rearDamperOring',
        category: category,
        label: '$label ダンパーOリング',
        labelEn: '$side Damper O-Ring',
      ),
  ];
}

final _chassisSettings = [
  textSetting(
    key: 'chassisType',
    category: 'top',
    label: 'シャーシタイプ',
    labelEn: 'Chassis Type',
  ),
  selectSetting(
    key: 'steeringPosition',
    category: 'top',
    label: 'ステアリング位置',
    labelEn: 'Steering Position',
    options: const ['OUTSIDE', 'INSIDE'],
  ),
  textSetting(
    key: 'rodPosition',
    category: 'top',
    label: 'ロッド位置',
    labelEn: 'Rod Position',
  ),
  textSetting(
    key: 'screwPositions',
    category: 'top',
    label: 'ビス位置',
    labelEn: 'Screw Positions',
  ),
  textSetting(
    key: 'motorMountScrewPositions',
    category: 'top',
    label: 'モーターマウントのビス位置',
    labelEn: 'Motor Mount Screw Positions',
  ),
  textSetting(
    key: 'sideStiffener',
    category: 'top',
    label: 'サイドスティフナー',
    labelEn: 'Side Stiffener',
  ),
  // X4'24 と同じく、総重量は自由記入、重量配分は 0〜100%。
  textSetting(
    key: 'totalWeight',
    category: 'top',
    label: '車重',
    labelEn: 'Car Weight',
    unit: 'g',
  ),
  for (final (end, label, side) in const [
    ('front', '前', 'Front'),
    ('rear', '後', 'Rear'),
  ])
    numberSetting(
      key: '${end}WeightBalance',
      category: 'top',
      label: '$label重量配分',
      labelEn: '$side Weight Balance',
      unit: '%',
      min: 0,
      max: 100,
      step: 0.5,
      defaultValue: '50',
    ),
  // シートに範囲の記載がないため、X4'24 のバランスウエイトを参照。
  for (final (key, label, labelEn) in const [
    ('batteryWeight', 'バッテリー下のウエイト', 'Weight Under Battery'),
    ('centerWeight', 'センターウエイト', 'Center Weight'),
  ])
    numberSetting(
      key: key,
      category: 'top',
      label: label,
      labelEn: labelEn,
      unit: 'g',
      min: 0,
      max: 100,
      step: 0.5,
    ),
];

final _equipmentSettings = [
  textSetting(
    key: 'driverName',
    category: 'other',
    label: 'ドライバー名',
    labelEn: 'Driver',
  ),
  textSetting(
    key: 'track',
    category: 'other',
    label: 'サーキット名',
    labelEn: 'Track',
  ),
  selectSetting(
    key: 'trackLayout',
    category: 'other',
    label: 'コースレイアウト',
    labelEn: 'Track Layout',
    options: const ['TECHNICAL', 'MIXED', 'FAST'],
  ),
  selectSetting(
    key: 'traction',
    category: 'other',
    label: '路面グリップ',
    labelEn: 'Track Traction',
    options: const ['LOW', 'MEDIUM', 'HIGH'],
  ),
  textSetting(key: 'race', category: 'other', label: 'レース名', labelEn: 'Race'),
  textSetting(
    key: 'result',
    category: 'other',
    label: 'レース結果',
    labelEn: 'Race Result',
  ),
  textSetting(
    key: 'transmitter',
    category: 'other',
    label: '送信機',
    labelEn: 'Transmitter',
  ),
  textSetting(
    key: 'receiver',
    category: 'other',
    label: '受信機',
    labelEn: 'Receiver',
  ),
  textSetting(key: 'servo', category: 'other', label: 'サーボ', labelEn: 'Servo'),
  // シートに入力範囲がなく、X4'24 に同種項目がないため自由記入。
  textSetting(
    key: 'steeringExpo',
    category: 'other',
    label: 'ステアリングEXP',
    labelEn: 'Steering Expo',
  ),
  textSetting(
    key: 'steeringSpeed',
    category: 'other',
    label: 'ステアリング速度',
    labelEn: 'Steering Speed',
  ),
  textSetting(
    key: 'motor',
    category: 'other',
    label: 'モーター',
    labelEn: 'Motor',
    options: motorNameOptions,
  ),
  textSetting(
    key: 'battery',
    category: 'other',
    label: 'バッテリー',
    labelEn: 'Battery',
    options: batteryNameOptions,
  ),
  textSetting(
    key: 'pinionGearType',
    category: 'other',
    label: 'ピニオンギヤの種類',
    labelEn: 'Pinion Gear Type',
  ),
  textSetting(
    key: 'spurGearType',
    category: 'other',
    label: 'スパーギヤの種類',
    labelEn: 'Spur Gear Type',
  ),
  // シートに入力範囲の記載がないため、X4'24 の同種項目を使用。
  numberSetting(
    key: 'pinionGear',
    category: 'other',
    label: 'ピニオンギヤ',
    labelEn: 'Pinion Gear',
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
    labelEn: 'Spur Gear',
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
    labelEn: 'Tires',
    options: tireNameOptions,
  ),
  textSetting(
    key: 'additive',
    category: 'other',
    label: 'タイヤ添加剤',
    labelEn: 'Tire Additive',
  ),
  // ウォーマーの温度と時間は X4'24 と同様に自由記入。
  textSetting(
    key: 'tireWarmerTemperature',
    category: 'other',
    label: 'タイヤウォーマー温度',
    labelEn: 'Tire Warmer Temperature',
    unit: '℃',
  ),
  textSetting(
    key: 'tireWarmerTiming',
    category: 'other',
    label: 'タイヤウォーマー加温時間',
    labelEn: 'Tire Warmer Time',
  ),
  textSetting(
    key: 'sidewallGlue',
    category: 'other',
    label: 'タイヤ側面の接着剤',
    labelEn: 'Sidewall Glue',
  ),
  textSetting(
    key: 'body',
    category: 'other',
    label: 'ボディ',
    labelEn: 'Body',
    options: bodyNameOptions,
  ),
  textSetting(key: 'wing', category: 'other', label: 'ウイング', labelEn: 'Wing'),
  selectSetting(
    key: 'winglet',
    category: 'other',
    label: 'ウイングレット',
    labelEn: 'Winglet',
    options: const ['WIDE', 'NARROW'],
  ),
];
