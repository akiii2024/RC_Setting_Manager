import '../../../../models/car_setting_definition.dart';
import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import 'trf420x_settings.dart' as trf420x;

/// TRF420（旧420 Chassis設定シート）の車種固有設定。
///
/// TRF420Xと共通する項目は再利用するが、420X専用のK1/サスマウント選択や
/// リア硬さは含めない。既存TRF420Xの定義オブジェクトは変更せず、
/// SettingItemを複製して独立したリストを構成する。
final List<SettingItem> trf420SpecificSettings = [
  for (final setting in trf420x.trf420xSpecificSettings)
    if (!_trf420xOnlyKeys.contains(setting.key)) _copySetting(setting),

  // TRF420シートのF/Rサスマウントスペーサー（前後それぞれ）。
  _numberSetting(
    key: 'frontFSusMountSpacer',
    label: 'フロント Fサスマウントスペーサー',
    category: 'front',
  ),
  _numberSetting(
    key: 'frontRSusMountSpacer',
    label: 'フロント Rサスマウントスペーサー',
    category: 'front',
  ),
  _numberSetting(
    key: 'rearFSusMountSpacer',
    label: 'リア Fサスマウントスペーサー',
    category: 'rear',
  ),
  _numberSetting(
    key: 'rearRSusMountSpacer',
    label: 'リア Rサスマウントスペーサー',
    category: 'rear',
  ),

  // 420のリア側も、マウント・内側・外側の3か所を別々に記録する。
  _numberSetting(
    key: 'rearUpperArmSpacerMount',
    label: 'リア アッパーアームスペーサー（マウント）',
    category: 'rear',
  ),
  _numberSetting(
    key: 'rearUpperArmSpacerIn',
    label: 'リア アッパーアームスペーサー（内）',
    category: 'rear',
  ),
  _numberSetting(
    key: 'rearUpperArmSpacerOut',
    label: 'リア アッパーアームスペーサー（外）',
    category: 'rear',
  ),
  SettingItem(
    key: 'rearDamperPositionStay',
    type: 'select',
    category: 'rearDamper',
    label: 'リア ダンパーポジション（ステー）',
    constraints: {'selectGuide': 'insideOutside'},
    options: const ['1', '2', '3'],
    defaultValue: '1',
  ),
  SettingItem(
    key: 'rearDamperPositionArm',
    type: 'select',
    category: 'rearDamper',
    label: 'リア ダンパーポジション（アーム）',
    constraints: {'selectGuide': 'insideOutside'},
    options: const ['1', '2', '3', '4'],
    defaultValue: '1',
  ),
  SettingItem(
    key: 'frontToeAngle',
    type: 'number',
    category: 'top',
    label: 'フロント トー角',
    unit: '°',
    constraints: {'min': -5, 'max': 5, 'step': 0.1},
    defaultValue: '0',
  ),
  SettingItem(
    key: 'rearToeAngle',
    type: 'number',
    category: 'top',
    label: 'リア トー角',
    unit: '°',
    constraints: {'min': -5, 'max': 5, 'step': 0.1},
    defaultValue: '0',
  ),
  _numberSetting(
    key: 'frontUprightSpacer',
    label: 'フロント アップライトスペーサー',
  ),
  _numberSetting(
    key: 'rearUprightSpacer',
    label: 'リア アップライトスペーサー',
  ),

  // 420シートのバッテリー位置は前後方向の距離（mm）。
  SettingItem(
    key: 'batteryPosition',
    type: 'number',
    category: 'top',
    label: 'バッテリー位置',
    unit: 'mm',
    constraints: {'min': -50, 'max': 50, 'step': 0.5},
    defaultValue: '0',
  ),

  // 420シートはA〜Eのバランスウェイトを記録する。
  _numberSetting(
    key: 'ballastWeightD',
    label: 'バランスウェイト D',
    unit: 'g',
    max: 100,
  ),
  _numberSetting(
    key: 'ballastWeightE',
    label: 'バランスウェイト E',
    unit: 'g',
    max: 100,
  ),
];

const _trf420xOnlyKeys = <String>{
  'frontK1Position',
  'frontFSusMount',
  'frontRSusMount',
  'rearK1Position',
  'rearFSusMount',
  'rearRSusMount',
  'rearUpperArmSpacer',
  'rearDamperPosition',
  'rearSusHardness',
  'toeAngle',
  'uprightSpacer',
};

SettingItem _copySetting(SettingItem setting) {
  final options = switch (setting.key) {
    // 420のシートはステー側3位置、アーム側4位置を持つ。
    'frontDamperPositionArm' => const [
        '1',
        '2',
        '3',
        '4',
      ],
    _ => setting.options,
  };
  return SettingItem(
    key: setting.key,
    type: setting.type,
    constraints: Map<String, dynamic>.from(setting.constraints),
    unit: setting.unit,
    category: setting.category,
    label: setting.label,
    options: options == null ? null : List<String>.from(options),
    defaultValue: setting.defaultValue,
    isAutoFilled: setting.isAutoFilled,
  );
}

SettingItem _numberSetting({
  required String key,
  required String label,
  String category = 'top',
  String unit = 'mm',
  double max = 10,
}) {
  return SettingItem(
    key: key,
    type: 'number',
    category: category,
    label: label,
    unit: unit,
    constraints: {'min': 0, 'max': max, 'step': 0.5},
    defaultValue: '0',
  );
}

/// TRF420はAI OCRの初期値を持たず、読み取れた候補だけを取り込む。
final trf420Settings = buildCarSettingDefinition(
  carId: 'tamiya/trf420',
  basicSettings: basicSettings,
  specificSettings: trf420SpecificSettings,
  isHumanVerified: false,
);
