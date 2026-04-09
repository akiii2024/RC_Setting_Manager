import 'manufacturer.dart';

class Car {
  final String id;
  final String name;
  final String imageUrl;
  final Manufacturer manufacturer;
  final String category;
  final Map<String, dynamic>? settings;
  final List<String> availableSettings;
  final Map<String, String> settingTypes;
  final bool isInGarage;
  final bool suppressGaragePrompt;

  const Car({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.manufacturer,
    required this.category,
    this.settings,
    this.availableSettings = const [],
    this.settingTypes = const {},
    this.isInGarage = false,
    this.suppressGaragePrompt = false,
  });

  Car copyWith({
    String? id,
    String? name,
    String? imageUrl,
    Manufacturer? manufacturer,
    String? category,
    Map<String, dynamic>? settings,
    bool clearSettings = false,
    List<String>? availableSettings,
    Map<String, String>? settingTypes,
    bool? isInGarage,
    bool? suppressGaragePrompt,
  }) {
    return Car(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      manufacturer: manufacturer ?? this.manufacturer,
      category: category ?? this.category,
      settings: clearSettings ? null : (settings ?? this.settings),
      availableSettings: availableSettings ?? this.availableSettings,
      settingTypes: settingTypes ?? this.settingTypes,
      isInGarage: isInGarage ?? this.isInGarage,
      suppressGaragePrompt: suppressGaragePrompt ?? this.suppressGaragePrompt,
    );
  }

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
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : null,
      availableSettings: json['availableSettings'] != null
          ? List<String>.from(json['availableSettings'] as List)
          : const [],
      settingTypes: json['settingTypes'] != null
          ? Map<String, String>.from(json['settingTypes'] as Map)
          : const {},
      isInGarage: json['isInGarage'] as bool? ?? false,
      suppressGaragePrompt: json['suppressGaragePrompt'] as bool? ?? false,
    );
  }

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
      'isInGarage': isInGarage,
      'suppressGaragePrompt': suppressGaragePrompt,
    };
  }
}
