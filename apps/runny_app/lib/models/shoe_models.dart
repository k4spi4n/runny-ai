class Shoe {
  final String? id;
  final String userId;
  final DateTime? createdAt;
  final String name;
  final String? brand;
  final String? model;
  final DateTime acquiredAt;
  final double distanceKm;
  final bool isActive;

  Shoe({
    this.id,
    required this.userId,
    this.createdAt,
    required this.name,
    this.brand,
    this.model,
    required this.acquiredAt,
    this.distanceKm = 0.0,
    this.isActive = true,
  });

  factory Shoe.fromJson(Map<String, dynamic> json) {
    return Shoe(
      id: json['id'],
      userId: json['user_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      name: json['name'],
      brand: json['brand'],
      model: json['model'],
      acquiredAt: DateTime.parse(json['acquired_at']),
      distanceKm: (json['distance_km'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      'acquired_at': acquiredAt.toIso8601String().split('T')[0],
      'distance_km': distanceKm,
      'is_active': isActive,
    };
  }
}
