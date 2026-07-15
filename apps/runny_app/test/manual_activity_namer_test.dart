import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/manual_activity_namer.dart';

void main() {
  group('ManualActivityNamer', () {
    String createVietnamese(double distanceKm, DateTime startedAt) {
      return ManualActivityNamer.create(
        distanceKm: distanceKm,
        startedAt: startedAt,
        titleTemplate: 'Buổi chạy %s km %s',
        morningLabel: 'Sáng',
        afternoonLabel: 'Chiều',
        eveningLabel: 'Tối',
      );
    }

    test('creates a morning title and omits an unnecessary decimal', () {
      expect(
        createVietnamese(5, DateTime(2026, 7, 15, 5)),
        'Buổi chạy 5 km Sáng',
      );
    });

    test('uses the afternoon label from noon through 17:59', () {
      expect(
        createVietnamese(10.5, DateTime(2026, 7, 15, 17, 59)),
        'Buổi chạy 10.5 km Chiều',
      );
    });

    test('uses the evening label outside morning and afternoon hours', () {
      expect(
        createVietnamese(3.2, DateTime(2026, 7, 15)),
        'Buổi chạy 3.2 km Tối',
      );
    });

    test('uses the supplied English labels and title template', () {
      expect(
        ManualActivityNamer.create(
          distanceKm: 5,
          startedAt: DateTime(2026, 7, 15, 6),
          titleTemplate: '%s km %s run',
          morningLabel: 'morning',
          afternoonLabel: 'afternoon',
          eveningLabel: 'evening',
        ),
        '5 km morning run',
      );
    });
  });
}
