class TrackLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // メートル単位での検出範囲
  final String prefecture;
  final String address;
  final String type; // 'indoor' または 'outdoor'
  final String surfaceType; // 'carpet' または 'asphalt'
  final String? description;
  final String? website;
  final String? phone;

  TrackLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.prefecture,
    required this.address,
    required this.type,
    required this.surfaceType,
    this.description,
    this.website,
    this.phone,
  });

  // JSONからTrackLocationを作成
  factory TrackLocation.fromJson(Map<String, dynamic> json) {
    return TrackLocation(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      prefecture: json['prefecture'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      surfaceType: json['surfaceType'] as String? ?? 'carpet', // デフォルトはカーペット
      description: json['description'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
    );
  }

  // TrackLocationをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'prefecture': prefecture,
      'address': address,
      'type': type,
      'surfaceType': surfaceType,
      'description': description,
      'website': website,
      'phone': phone,
    };
  }

  @override
  String toString() {
    return 'TrackLocation(name: $name, prefecture: $prefecture, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackLocation &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return name.hashCode ^ latitude.hashCode ^ longitude.hashCode;
  }
}