import '../../../../models/car_setting_definition.dart';
import '../../common/basic_settings.dart';

// TRF420固有の設定
final List<SettingItem> trf420SpecificSettings = [
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
];

// TRF420の設定定義（基本設定 + 固有設定）
final trf420xSettings = CarSettingDefinition(
  carId: 'tamiya/trf420x',
  availableSettings: [...basicSettings, ...trf420SpecificSettings],
);
