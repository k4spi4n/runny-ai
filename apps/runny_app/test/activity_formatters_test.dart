import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/activity_formatters.dart';

void main() {
  group('formatPace', () {
    test('carries rounded seconds into the next minute', () {
      expect(formatPace(4.999), '5:00');
    });

    test('formats ordinary pace and rejects invalid values', () {
      expect(formatPace(6.5), '6:30');
      expect(formatPace(double.nan), '-:--');
      expect(formatPace(0), '-:--');
      expect(formatPace(0, zeroAsValid: true), '0:00');
    });
  });

  group('formatDurationMinutes', () {
    test('formats sub-hour and hour durations', () {
      expect(formatDurationMinutes(4.999), '5:00');
      expect(formatDurationMinutes(61.5), '1:01:30');
    });
  });
}
