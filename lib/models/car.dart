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
}
