import 'car.dart';
import 'immutable_json.dart';

enum SavedSettingKind {
  manual,
  runResult,
  aiSuggestion,
}

class SavedSetting {
  final String id;
  final String name;
  final DateTime createdAt;
  final Car car;
  final Map<String, dynamic> settings;
  final SavedSettingKind kind;
  final String? sourceRunLogId;
  final String? parentSettingId;

  SavedSetting({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.car,
    required Map<String, dynamic> settings,
    this.kind = SavedSettingKind.manual,
    this.sourceRunLogId,
    this.parentSettingId,
  }) : settings = freezeJsonMap(settings);

  // Deserialize from JSON
  factory SavedSetting.fromJson(Map<String, dynamic> json) {
    return SavedSetting(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      car: Car.fromJson(json['car'] as Map<String, dynamic>),
      settings: Map<String, dynamic>.from(json['settings'] as Map),
      kind: _parseKind(json['kind']),
      sourceRunLogId: json['sourceRunLogId'] as String?,
      parentSettingId: json['parentSettingId'] as String?,
    );
  }

  factory SavedSetting.fromJsonStrict(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id', allowEmpty: false);
    final name = _requiredString(json, 'name', allowEmpty: false);
    final createdAtText = _requiredString(json, 'createdAt', allowEmpty: false);
    final carJson = json['car'];
    final settingsJson = json['settings'];
    final kindJson = json['kind'];
    if (carJson is! Map<String, dynamic>) {
      throw const FormatException('SavedSetting car must be a JSON object.');
    }
    if (settingsJson is! Map<String, dynamic>) {
      throw const FormatException(
          'SavedSetting settings must be a JSON object.');
    }
    if (kindJson is! String ||
        !SavedSettingKind.values.any((kind) => kind.name == kindJson)) {
      throw FormatException('Unsupported SavedSetting kind: $kindJson.');
    }
    _nullableString(json, 'sourceRunLogId');
    _nullableString(json, 'parentSettingId');

    return SavedSetting(
      id: id,
      name: name,
      createdAt: DateTime.parse(createdAtText),
      car: Car.fromJsonStrict(carJson),
      settings: Map<String, dynamic>.from(settingsJson),
      kind: SavedSettingKind.values.firstWhere((kind) => kind.name == kindJson),
      sourceRunLogId: json['sourceRunLogId'] as String?,
      parentSettingId: json['parentSettingId'] as String?,
    );
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'car': car.toJson(),
      'settings': settings,
      'kind': kind.name,
      'sourceRunLogId': sourceRunLogId,
      'parentSettingId': parentSettingId,
    };
  }

  static SavedSettingKind _parseKind(dynamic value) {
    if (value is String) {
      for (final kind in SavedSettingKind.values) {
        if (kind.name == value) {
          return kind;
        }
      }
    }
    return SavedSettingKind.manual;
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    bool allowEmpty = true,
  }) {
    final value = json[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('SavedSetting $key must be a string.');
    }
    return value;
  }

  static void _nullableString(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || (json[key] != null && json[key] is! String)) {
      throw FormatException('SavedSetting $key must be a string or null.');
    }
  }
}

/// Immutable input used by atomic saved-setting operations.
class NewSavedSettingInput {
  NewSavedSettingInput({
    required this.name,
    required this.car,
    required Map<String, dynamic> settings,
    this.kind = SavedSettingKind.manual,
    this.sourceRunLogId,
    this.parentSettingId,
  }) : settings = freezeJsonMap(settings);

  final String name;
  final Car car;
  final Map<String, dynamic> settings;
  final SavedSettingKind kind;
  final String? sourceRunLogId;
  final String? parentSettingId;
}
