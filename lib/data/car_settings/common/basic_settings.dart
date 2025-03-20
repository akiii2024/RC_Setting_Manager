import '../../../models/car_setting_definition.dart';

// 全車種共通の基本設定
final List<SettingItem> basicSettings = [
  SettingItem(
    key: 'date',
    type: 'text',
    category: 'basic',
    label: '日付',
  ),
  SettingItem(
    key: 'track',
    type: 'text',
    category: 'basic',
    label: 'トラック',
  ),
  SettingItem(
    key: 'surface',
    type: 'text',
    category: 'basic',
    label: '路面',
  ),
  SettingItem(
    key: 'airTemp',
    type: 'number',
    category: 'basic',
    label: '気温',
    unit: '℃',
    constraints: {'min': -10, 'max': 50},
  ),
  SettingItem(
    key: 'humidity',
    type: 'number',
    category: 'basic',
    label: '湿度',
    unit: '%',
    constraints: {'min': 0, 'max': 100},
  ),
  SettingItem(
    key: 'trackTemp',
    type: 'number',
    category: 'basic',
    label: '路面温度',
    unit: '℃',
    constraints: {'min': -10, 'max': 70},
  ),
  SettingItem(
    key: 'condition',
    type: 'text',
    category: 'basic',
    label: 'コンディション',
  ),
];
