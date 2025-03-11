class Car {
  final String id;
  final String name;
  final String imageUrl;
  Map<String, dynamic>? settings;

  Car({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.settings,
  });

  // JSONからのデシリアライズ
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'])
          : null,
    );
  }

  // JSONへのシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'settings': settings,
    };
  }
}
