import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/activity_import_policy.dart';

void main() {
  group('shouldAttachCurrentWeather', () {
    final now = DateTime.utc(2026, 7, 16, 12);

    test('allows a run that just finished', () {
      expect(
        shouldAttachCurrentWeather(DateTime.utc(2026, 7, 16, 10, 30), now: now),
        isTrue,
      );
    });

    test('rejects historical activity weather', () {
      expect(
        shouldAttachCurrentWeather(DateTime.utc(2026, 7, 15, 12), now: now),
        isFalse,
      );
    });

    test('rejects an activity too far in the future', () {
      expect(
        shouldAttachCurrentWeather(DateTime.utc(2026, 7, 16, 12, 31), now: now),
        isFalse,
      );
    });
  });
}
