import '../../../../models/car_setting_definition.dart';
import '../../common/basic_settings.dart';

// TRF421固有の設定
final List<SettingItem> trf421SpecificSettings = [
  SettingItem(
    key: 'frontCamber',
    type: 'number',
    category: 'front',
    label: 'キャンバー角',
    unit: '°',
    constraints: {'min': -10, 'max': 10, 'step': 0.5},
  ),
  SettingItem(
    key: 'frontRideHeight',
    type: 'number',
    category: 'front',
    label: '車高',
    unit: 'mm',
    constraints: {'min': 3, 'max': 15, 'step': 0.5},
  ),
  SettingItem(
    key: 'frontDamperPosition',
    type: 'select',
    category: 'front',
    label: 'ダンパーポジション',
    options: ['1', '2', '3', '4', '5'],
  ),
  SettingItem(
    key: 'frontSpring',
    type: 'text',
    category: 'front',
    label: 'スプリング',
  ),
  SettingItem(
    key: 'frontToe',
    type: 'number',
    category: 'front',
    label: 'トー角',
    unit: '°',
    constraints: {'min': -5, 'max': 5, 'step': 0.5},
  ),
  SettingItem(
    key: 'frontSuspensionArmThickness',
    type: 'number',
    category: 'front',
    label: 'サスアーム厚さ',
    constraints: {'min': 0.5, 'max': 5.0, 'step': 0.5},
    unit: 'mm',
  ),
  SettingItem(
    key: 'frontSusMountPosition',
    type: 'select',
    category: 'front',
    label: 'サスマウント位置',
    options: ['A', 'B', 'C', 'D'],
  ),
];

// TRF421の設定定義（基本設定 + 固有設定）
final trf421Settings = CarSettingDefinition(
  carId: 'tamiya/trf421',
  availableSettings: [...basicSettings, ...trf421SpecificSettings],
);
