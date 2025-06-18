import '../../../models/car_setting_definition.dart';

// 全車種共通の基本設定
final List<SettingItem> basicSettings = [
  SettingItem(
    key: 'date',
    type: 'text',
    category: 'basic',
    label: '日付',
    defaultValue: DateTime.now().toString().split(' ')[0],
    isAutoFilled: true,
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
    isAutoFilled: true,
  ),
  SettingItem(
    key: 'humidity',
    type: 'number',
    category: 'basic',
    label: '湿度',
    unit: '%',
    constraints: {'min': 0, 'max': 100},
    isAutoFilled: true,
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
  SettingItem(
    key: 'memo',
    type: 'text',
    category: 'memo',
    label: 'メモ',
  )
];
