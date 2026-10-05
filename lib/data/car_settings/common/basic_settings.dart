import '../../../models/car_setting_definition.dart';

// 全車種共通の基本設定。気象項目の初期値は実測値ではなく入力の出発点。
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
    type: 'select',
    category: 'basic',
    label: '路面',
    options: ['アスファルト', 'カーペット', 'その他'],
    defaultValue: 'アスファルト',
  ),
  SettingItem(
    key: 'airTemp',
    type: 'number',
    category: 'basic',
    label: '気温',
    unit: '℃',
    constraints: {'min': -10, 'max': 50},
    defaultValue: '20',
    isAutoFilled: true,
  ),
  SettingItem(
    key: 'humidity',
    type: 'number',
    category: 'basic',
    label: '湿度',
    unit: '%',
    constraints: {'min': 0, 'max': 100},
    defaultValue: '50',
    isAutoFilled: true,
  ),
  SettingItem(
    key: 'trackTemp',
    type: 'number',
    category: 'basic',
    label: '路面温度',
    unit: '℃',
    constraints: {'min': -10, 'max': 70},
    defaultValue: '20',
  ),
  SettingItem(
    key: 'condition',
    type: 'text',
    category: 'basic',
    label: 'コンディション',
    defaultValue: '',
  ),
  SettingItem(
    key: 'memo',
    type: 'text',
    category: 'memo',
    label: 'メモ',
    defaultValue: '',
  )
];
