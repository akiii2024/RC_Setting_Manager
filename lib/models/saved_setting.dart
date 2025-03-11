import 'car.dart';

class SavedSetting {
  final String id;
  final String name;
  final DateTime createdAt;
  final Car car;
  final Map<String, dynamic> settings;

  SavedSetting({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.car,
    required this.settings,
  });

  // JSONからのデシリアライズ
  factory SavedSetting.fromJson(Map<String, dynamic> json) {
    return SavedSetting(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      car: Car.fromJson(json['car'] as Map<String, dynamic>),
      settings: Map<String, dynamic>.from(json['settings'] as Map),
    );
  }

  // JSONへのシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'car': car.toJson(),
      'settings': settings,
    };
  }
} 