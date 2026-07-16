import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/pace_calculator.dart';

void main() {
  group('parsePaceMinutesPerKm', () {
    test('accepts minutes and seconds or decimal minutes', () {
      expect(parsePaceMinutesPerKm('5:30'), 5.5);
      expect(parsePaceMinutesPerKm('5,5'), 5.5);
    });

    test('rejects invalid pace values', () {
      expect(parsePaceMinutesPerKm('5:60'), isNull);
      expect(parsePaceMinutesPerKm('0:00'), isNull);
    });
  });

  test('durationFromPace calculates total minutes', () {
    expect(durationFromPace(distanceKm: 7.5, paceMinutesPerKm: 5.5), 41.25);
  });
}
