import 'manufacturer.dart';
import 'immutable_json.dart';

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

  Car({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.manufacturer,
    required this.category,
    Map<String, dynamic>? settings,
    List<String> availableSettings = const [],
    Map<String, String> settingTypes = const {},
    this.isInGarage = false,
    this.suppressGaragePrompt = false,
  })  : settings = settings == null ? null : freezeJsonMap(settings),
        availableSettings = List<String>.unmodifiable(availableSettings),
        settingTypes = Map<String, String>.unmodifiable(settingTypes);

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

  factory Car.fromJsonStrict(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id', allowEmpty: false);
    final name = _requiredString(json, 'name', allowEmpty: false);
    final imageUrl = _requiredString(json, 'imageUrl');
    final category = _requiredString(json, 'category');
    final manufacturerJson = json['manufacturer'];
    if (manufacturerJson is! Map<String, dynamic>) {
      throw const FormatException('Car manufacturer must be a JSON object.');
    }
    _requiredString(manufacturerJson, 'id', allowEmpty: false);
    _requiredString(manufacturerJson, 'name', allowEmpty: false);
    _requiredString(manufacturerJson, 'logoPath');

    if (!json.containsKey('settings')) {
      throw const FormatException('Car settings field is required.');
    }
    final settingsJson = json['settings'];
    if (settingsJson != null && settingsJson is! Map<String, dynamic>) {
      throw const FormatException(
          'Car settings must be a JSON object or null.');
    }
    final availableSettingsJson = json['availableSettings'];
    if (availableSettingsJson is! List<dynamic> ||
        availableSettingsJson.any((value) => value is! String)) {
      throw const FormatException(
          'Car availableSettings must contain strings.');
    }
    final settingTypesJson = json['settingTypes'];
    if (settingTypesJson is! Map<String, dynamic> ||
        settingTypesJson.values.any((value) => value is! String)) {
      throw const FormatException('Car settingTypes must contain strings.');
    }
    if (json['isInGarage'] is! bool || json['suppressGaragePrompt'] is! bool) {
      throw const FormatException('Car garage flags must be booleans.');
    }

    return Car(
      id: id,
      name: name,
      imageUrl: imageUrl,
      manufacturer: Manufacturer.fromJson(manufacturerJson),
      category: category,
      settings:
          settingsJson == null ? null : Map<String, dynamic>.from(settingsJson),
      availableSettings: List<String>.from(availableSettingsJson),
      settingTypes: Map<String, String>.from(settingTypesJson),
      isInGarage: json['isInGarage'] as bool,
      suppressGaragePrompt: json['suppressGaragePrompt'] as bool,
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

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    bool allowEmpty = true,
  }) {
    final value = json[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException(
          'Car $key must be a${allowEmpty ? '' : ' non-empty'} string.');
    }
    return value;
  }
}
