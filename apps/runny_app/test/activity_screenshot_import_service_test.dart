import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/services/activity_screenshot_import_service.dart';

void main() {
  group('ActivityScreenshotImportService', () {
    test('parses fenced JSON activity payload', () {
      const content = '''
```json
{
  "is_activity": true,
  "activity_type": "run",
  "started_at": "2026-07-08T06:30:00+07:00",
  "distance_km": 5.02,
  "duration_min": 31.5,
  "avg_hr": 152,
  "elevation_gain_m": 36,
  "confidence": 0.91,
  "source_app": "Strava",
  "notes": "Morning run"
}
```
''';

      final result = ActivityScreenshotImportService.parseModelContent(content);

      expect(result.activity.distanceKm, 5.02);
      expect(result.activity.durationMin, 31.5);
      expect(result.activity.avgHr, 152);
      expect(result.activity.elevationGainM, 36);
      expect(result.confidence, 0.91);
      expect(result.sourceApp, 'Strava');
      expect(result.notes, 'Morning run');
    });

    test('rejects non-activity payload', () {
      expect(
        () => ActivityScreenshotImportService.parseModelContent(
          '{"is_activity": false}',
        ),
        throwsA(isA<ActivityScreenshotImportException>()),
      );
    });

    test('rejects missing core metrics', () {
      expect(
        () => ActivityScreenshotImportService.parseModelContent(
          '{"is_activity": true, "distance_km": 5}',
        ),
        throwsA(isA<ActivityScreenshotImportException>()),
      );
    });

    test('defaults missing date to today at noon', () {
      final now = DateTime.now();

      final result = ActivityScreenshotImportService.parseModelContent(
        '{"is_activity": true, "distance_km": 5, "duration_min": 30, "started_at": ""}',
      );

      expect(result.activity.startedAt.year, now.year);
      expect(result.activity.startedAt.month, now.month);
      expect(result.activity.startedAt.day, now.day);
      expect(result.activity.startedAt.hour, 12);
      expect(result.activity.startedAt.minute, 0);
    });
  });
}
