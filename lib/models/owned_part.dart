const Set<String> ownedPartCategories = {
  'motor',
  'battery',
  'body',
  'tire',
};

class OwnedPart {
  final String id;
  final String category;
  final String name;
  final DateTime createdAt;

  const OwnedPart({
    required this.id,
    required this.category,
    required this.name,
    required this.createdAt,
  });

  OwnedPart copyWith({
    String? id,
    String? category,
    String? name,
    DateTime? createdAt,
  }) {
    return OwnedPart(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory OwnedPart.fromJson(Map<String, dynamic> json) {
    return OwnedPart(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class OwnedPartImportCandidate {
  final String category;
  final String name;

  const OwnedPartImportCandidate({
    required this.category,
    required this.name,
  });
}
