import 'manufacturer.dart';

class Car {
  final String id;
  final String name;
  final String imageUrl;
  final Manufacturer manufacturer;
  final String category;
  Map<String, dynamic>? settings;
  final List<String> availableSettings; // 車種固有の設定項目リスト
  final Map<String, String> settingTypes; // 設定項目のタイプを管理するマップ

  Car({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.manufacturer,
    required this.category,
    this.settings,
    this.availableSettings = const [], // デフォルトは空のリスト
    this.settingTypes = const {}, // デフォルトは空のマップ
  });

  // Deserialize from JSON
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      manufacturer: json['manufacturer'] != null
          ? Manufacturer.fromJson(json['manufacturer'] as Map<String, dynamic>)
          : Manufacturer(id: 'unknown', name: 'Unknown', logoPath: ''),
      category: json['category'] as String? ?? '',
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'])
          : null,
      availableSettings: json['availableSettings'] != null
          ? List<String>.from(json['availableSettings'])
          : [],
      settingTypes: json['settingTypes'] != null
          ? Map<String, String>.from(json['settingTypes'])
          : {},
    );
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'manufacturer': manufacturer.toJson(),
      'category': category,
      'settings': settings,
      'availableSettings': availableSettings,
      'settingTypes': settingTypes,
    };
  }
}
