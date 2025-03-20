import '../models/car_setting_definition.dart';

// TRF421の設定定義
final trf421Settings = CarSettingDefinition(
  carId: 'trf421',
  availableSettings: [
    // 基本情報
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

    // フロント設定
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
  ],
);

// TRF420の設定定義
final trf420Settings = CarSettingDefinition(
  carId: 'trf420',
  availableSettings: [
    // 基本情報（TRF421と共通）
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

    // TRF420固有の設定
    SettingItem(
      key: 'frontAxisHeight',
      type: 'number',
      category: 'front',
      label: 'フロントアクスル高さ',
      constraints: {'min': 0.0, 'max': 10.0, 'step': 0.5},
      unit: 'mm',
    ),
    SettingItem(
      key: 'motorCoolingType',
      type: 'select',
      category: 'other',
      label: 'モーター冷却タイプ',
      options: ['ファン', 'ヒートシンク', 'なし'],
    ),
  ],
);

// 全ての車種の設定定義を管理
final Map<String, CarSettingDefinition> carSettingsDefinitions = {
  'trf421': trf421Settings,
  'trf420': trf420Settings,
};

// 車種IDから設定定義を取得する関数
CarSettingDefinition? getCarSettingDefinition(String carId) {
  print('Searching for car ID: $carId'); // デバッグ用ログ
  print('Available definitions: ${carSettingsDefinitions.keys}'); // デバッグ用ログ
  return carSettingsDefinitions[carId];
}
