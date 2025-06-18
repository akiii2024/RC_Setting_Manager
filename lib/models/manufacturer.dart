class Manufacturer {
  final String id;
  final String name;
  final String logoPath;

  Manufacturer({
    required this.id,
    required this.name,
    required this.logoPath,
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoPath': logoPath,
    };
  }

  // JSON deserialization
  factory Manufacturer.fromJson(Map<String, dynamic> json) {
    return Manufacturer(
      id: json['id'] as String,
      name: json['name'] as String,
      logoPath: json['logoPath'] as String? ?? '',
    );
  }
}
