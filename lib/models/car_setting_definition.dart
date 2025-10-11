class CarSettingDefinition {
  final String carId;
  final List<SettingItem> availableSettings;
  final bool isHumanVerified; // 人間が確認したかどうか

  CarSettingDefinition({
    required this.carId,
    required this.availableSettings,
    this.isHumanVerified = false,
  });

  // JSONからの変換
  factory CarSettingDefinition.fromJson(Map<String, dynamic> json) {
    return CarSettingDefinition(
      carId: json['carId'] as String,
      availableSettings: (json['availableSettings'] as List)
          .map((item) => SettingItem.fromJson(item))
          .toList(),
      isHumanVerified: json['isHumanVerified'] as bool? ?? false,
    );
  }

  // JSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'carId': carId,
      'availableSettings':
          availableSettings.map((item) => item.toJson()).toList(),
      'isHumanVerified': isHumanVerified,
    };
  }
}

class SettingItem {
  final String key;
  final String type; // 'number', 'text', 'slider', 'select' など
  final Map<String, dynamic> constraints; // min, max, divisions など
  final String? unit; // 単位
  final String category; // 'basic', 'front', 'rear', 'top', 'other' など
  final String label; // 表示名
  final List<String>? options; // select typeの場合の選択肢
  final String? defaultValue; // デフォルト値
  final bool isAutoFilled; // 自動入力フラグ

  SettingItem({
    required this.key,
    required this.type,
    this.constraints = const {},
    this.unit,
    required this.category,
    required this.label,
    this.options,
    this.defaultValue,
    this.isAutoFilled = false,
  });

  // JSONからの変換
  factory SettingItem.fromJson(Map<String, dynamic> json) {
    return SettingItem(
      key: json['key'] as String,
      type: json['type'] as String,
      constraints: Map<String, dynamic>.from(json['constraints'] as Map),
      unit: json['unit'] as String?,
      category: json['category'] as String,
      label: json['label'] as String,
      options: (json['options'] as List?)?.map((e) => e as String).toList(),
      defaultValue: json['defaultValue'] as String?,
      isAutoFilled: json['isAutoFilled'] as bool? ?? false,
    );
  }

  // JSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'constraints': constraints,
      'unit': unit,
      'category': category,
      'label': label,
      'options': options,
      'defaultValue': defaultValue,
      'isAutoFilled': isAutoFilled,
    };
  }
}
