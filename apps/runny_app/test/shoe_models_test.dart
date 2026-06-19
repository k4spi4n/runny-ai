import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/shoe_models.dart';

void main() {
  group('Shoe.fromJson', () {
    test('parse đầy đủ các trường', () {
      final shoe = Shoe.fromJson({
        'id': 's1',
        'user_id': 'u1',
        'created_at': '2026-06-01T00:00:00.000Z',
        'name': 'Nike Pegasus 40',
        'brand': 'Nike',
        'model': 'Pegasus 40',
        'acquired_at': '2026-05-01T00:00:00.000Z',
        'distance_km': 505.0,
        'is_active': true,
      });
      expect(shoe.id, 's1');
      expect(shoe.userId, 'u1');
      expect(shoe.name, 'Nike Pegasus 40');
      expect(shoe.distanceKm, 505.0);
      expect(shoe.isActive, isTrue);
    });

    test('distance_km kiểu int vẫn ép về double', () {
      final shoe = Shoe.fromJson({
        'user_id': 'u1',
        'name': 'Adidas',
        'acquired_at': '2026-05-01T00:00:00.000Z',
        'distance_km': 480,
      });
      expect(shoe.distanceKm, isA<double>());
      expect(shoe.distanceKm, 480.0);
      // is_active vắng mặt -> mặc định true
      expect(shoe.isActive, isTrue);
    });
  });

  group('Shoe.toJson', () {
    test('bỏ qua các trường null tùy chọn và format ngày YYYY-MM-DD', () {
      final shoe = Shoe(
        userId: 'u1',
        name: 'Brooks Ghost',
        acquiredAt: DateTime.utc(2026, 5, 1),
        distanceKm: 0,
      );
      final json = shoe.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('brand'), isFalse);
      expect(json.containsKey('model'), isFalse);
      expect(json['acquired_at'], '2026-05-01');
      expect(json['is_active'], true);
      expect(json['distance_km'], 0);
    });

    test('round-trip giữ nguyên dữ liệu cốt lõi', () {
      final original = Shoe(
        id: 's2',
        userId: 'u9',
        name: 'Hoka Clifton',
        brand: 'Hoka',
        acquiredAt: DateTime.utc(2026, 4, 15),
        distanceKm: 123.4,
        isActive: false,
      );
      final restored = Shoe.fromJson({
        ...original.toJson(),
        'acquired_at': '2026-04-15T00:00:00.000Z',
      });
      expect(restored.name, original.name);
      expect(restored.brand, original.brand);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.isActive, original.isActive);
    });
  });
}
