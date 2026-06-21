import 'car.dart';

enum SavedSettingKind {
  manual,
  runResult,
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
    required this.settings,
    this.kind = SavedSettingKind.manual,
    this.sourceRunLogId,
    this.parentSettingId,
  });

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
}
