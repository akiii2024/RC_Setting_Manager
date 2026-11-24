import '../../../../models/car_setting_definition.dart';
import '../../../motor_name_options.dart';
import '../../../setting_name_options.dart';
import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import '../common/setting_item_helpers.dart';

List<SettingItem> _endSettings(String end, String label, String side) => [
      // OCR では範囲・刻みを確認できないため、X4'24 の同種項目を踏襲。
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
      numberSetting(
        key: '${end}ToeAngle',
        category: end,
        label: '$label トー角',
        labelEn: '$side Toe',
        unit: 'degr.',
        min: -5,
        max: 5,
        step: 0.1,
        defaultValue: end == 'front' ? '-1' : '3',
      ),
      numberSetting(
        key: '${end}Droop',
        category: end,
        label: '$label ダウンストップ',
        labelEn: '$side Downstop',
        unit: 'mm',
        min: -3,
        max: 10,
        step: 1,
      ),
      selectSetting(
        key: '${end}DiffPositionHeight',
        category: end,
        label: '$label デフ位置',
        labelEn: '$side Diff Position',
        options: const ['High Diff', 'Low Diff'],
      ),
      textSetting(
        key: '${end}Diff',
        category: end,
        label: '$label デフオイル',
        labelEn: '$side Diff Oil',
        unit: 'cSt',
      ),
      // デフ重量の範囲・刻みは X4'24 のウエイト項目を踏襲。
      numberSetting(
        key: '${end}DiffWeight',
        category: end,
        label: '$label デフ重量',
        labelEn: '$side Diff Weight',
        unit: 'g',
        max: 100,
      ),
    ];

List<SettingItem> _damperSettings(String end, String label) {
  final side = end == 'front' ? 'Front' : 'Rear';
  final category = '${end}Damper';
  return [
    textSetting(
      key: '${end}ShockOil',
      category: category,
      label: '$label ダンパーオイル',
      labelEn: '$side Shock Oil',
      unit: 'cSt',
    ),
    // リバウンドとダンパー長の範囲・刻みは X4'24 を踏襲。
    numberSetting(
      key: '${end}DamperRebound',
      category: category,
      label: '$label リバウンド',
      labelEn: '$side Rebound',
      unit: '%',
      max: 100,
      step: 0.5,
    ),
    // OCR からピストンの選択肢を確認できないため、
    // 穴数の範囲・刻みは同じ選択肢に依存しない BD12 の数値項目を踏襲。
    numberSetting(
      key: '${end}PistonHole',
      category: category,
      label: '$label ピストン穴数',
      labelEn: '$side Piston Hole Count',
      min: 1,
      max: 10,
      step: 1,
      defaultValue: '4',
    ),
    numberSetting(
      key: '${end}DamperLength',
      category: category,
      label: '$label ダンパー長',
      labelEn: '$side Shock Length',
      unit: 'mm',
      max: 50,
      step: 0.5,
      defaultValue: '8',
    ),
    textSetting(
      key: '${end}DamperNote',
      category: category,
      label: '$label ダンパーメモ',
      labelEn: '$side Shock Notes',
    ),
  ];
}

final xq11rSettings = buildCarSettingDefinition(
  carId: 'xpress/xq11r',
  basicSettings: basicSettings,
  specificSettings: [
    ..._endSettings('front', 'フロント', 'Front'),
    selectSetting(
      key: 'frontDrive',
      category: 'front',
      label: 'フロント 駆動方式',
      labelEn: 'Front Drive Type',
      options: const ['Spool', 'Gear Diff'],
    ),
    textSetting(
      key: 'frontSpring',
      category: 'frontDamper',
      label: 'フロント スプリング',
      labelEn: 'Front Spring',
    ),
    ..._damperSettings('front', 'フロント'),
    ..._endSettings('rear', 'リヤ', 'Rear'),
    // OCR で確認できる Sway Bar は後段のサスペンション欄にある。
    // 範囲・刻みは X4'24 のスタビライザー厚を踏襲。
    numberSetting(
      key: 'rearStabilizer',
      category: 'rear',
      label: 'リヤ スタビライザー厚',
      labelEn: 'Rear Sway Bar Thickness',
      unit: 'mm',
      min: 1,
      max: 3,
      step: 0.1,
      defaultValue: '1.2',
    ),
    ..._damperSettings('rear', 'リヤ'),
    // 高さの範囲・刻みは X4'24 の高さ調整項目を踏襲。
    numberSetting(
      key: 'servoHornHeight',
      category: 'top',
      label: 'サーボホーン高さ',
      labelEn: 'Servo Horn Height',
      unit: 'mm',
      max: 10,
    ),
    // ギヤ歯数の範囲・刻みは X4'24 の同種項目を踏襲。
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
    textSetting(
      key: 'motor',
      category: 'other',
      label: 'モーター',
      labelEn: 'Motor',
      options: motorNameOptions,
    ),
    textSetting(key: 'esc', category: 'other', label: 'アンプ', labelEn: 'ESC'),
    textSetting(
      key: 'servo',
      category: 'other',
      label: 'サーボ',
      labelEn: 'Servo',
    ),
    // サーボ重量の範囲・刻みは X4'24 のウエイト項目を踏襲。
    numberSetting(
      key: 'servoWeight',
      category: 'other',
      label: 'サーボ重量',
      labelEn: 'Servo Weight',
      unit: 'g',
      max: 100,
    ),
    textSetting(
      key: 'battery',
      category: 'other',
      label: 'バッテリー',
      labelEn: 'Battery',
      options: batteryNameOptions,
    ),
    textSetting(
      key: 'body',
      category: 'other',
      label: 'ボディ',
      labelEn: 'Body',
      options: bodyNameOptions,
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
      label: 'グリップ剤',
      labelEn: 'Tire Additive',
    ),
    textSetting(
      key: 'driverName',
      category: 'other',
      label: 'ドライバー名',
      labelEn: 'Driver',
    ),
    textSetting(
      key: 'country',
      category: 'other',
      label: '開催国',
      labelEn: 'Track Country',
    ),
    textSetting(
      key: 'result',
      category: 'other',
      label: '結果',
      labelEn: 'Result',
    ),
    textSetting(
      key: 'bestLapTime',
      category: 'other',
      label: 'ベストラップ',
      labelEn: 'Best Lap',
    ),
  ],
  isHumanVerified: false,
);
