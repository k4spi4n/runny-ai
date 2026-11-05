import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/recorded_run.dart';
import 'package:runny_app/models/workout_models.dart';

void main() {
  final start = DateTime.utc(2026, 11, 3);
  DateTime time(int seconds) => start.add(Duration(seconds: seconds));
  RunFix fix(int seconds, double lat, {double accuracy = 5}) =>
      RunFix(lat, 106, time(seconds), accuracy);
  RecordedRun run() => RecordedRun(
    id: 'run-1',
    userId: 'runner',
    startedAt: start,
    firstFix: fix(0, 10),
  );

  test(
    'pause/resume exclude time and movement and start a separate segment',
    () {
      final recording = run();
      recording.addFix(fix(5, 10.0002), time(5));
      final beforePause = recording.distanceM;
      recording.pause(time(10));
      recording.addFix(fix(20, 11), time(20));
      expect(recording.elapsedMs(time(40)), 10000);
      expect(recording.distanceM, beforePause);
      recording.resume(time(40));
      // A queued pre-resume location must not become a new segment's anchor.
      recording.addFix(fix(39, 10.8), time(41));
      recording.addFix(fix(41, 11), time(41));
      expect(recording.distanceM, beforePause);
      recording.addFix(fix(46, 11.0002), time(46));
      recording.finish(time(50));
      expect(recording.activeMs, 20000);
      expect(recording.elapsedMs(time(90)), 20000);
      expect(recording.segments.map((s) => s.length), [2, 2]);
      expect(recording.distanceM, closeTo(beforePause * 2, 0.1));
    },
  );

  test('GPS silence splits the route without stopping active time', () {
    final recording = run();
    recording.addFix(fix(5, 10.0002), time(5));
    final meters = recording.distanceM;
    recording.addFix(fix(30, 11), time(30));
    expect(recording.distanceM, meters);
    recording.addFix(fix(35, 11.0002), time(35));
    recording.finish(time(40));
    expect(recording.activeMs, 40000);
    expect(recording.segments.length, 2);
    expect(recording.distanceM, closeTo(meters * 2, 0.1));
  });

  test(
    'bad accuracy, explicit outages, and impossible jumps do not bridge gaps',
    () {
      final recording = run();
      recording.addFix(fix(1, 10.00004), time(1));
      final meters = recording.distanceM;
      recording.addFix(fix(2, 11, accuracy: 200), time(2));
      recording.addFix(fix(3, 11), time(3));
      recording.gap();
      recording.addFix(fix(4, 12), time(4));
      recording.addFix(fix(5, 13), time(5)); // Teleport: reject and split.
      recording.addFix(fix(6, 13), time(6));
      expect(recording.segments.length, 4);
      expect(recording.distanceM, meters);
      expect(recording.elapsedMs(time(6)), 6000);
    },
  );

  test(
    'rejects stale, invalid and future fixes without poisoning later fixes',
    () {
      final recording = run();
      expect(fix(0, 10).usableAt(time(11)), isFalse);
      expect(fix(20, 10).usableAt(time(1)), isFalse);
      expect(fix(1, double.nan).usableAt(time(1)), isFalse);
      expect(fix(1, 91).usableAt(time(1)), isFalse);
      recording.addFix(fix(50, 10), time(1));
      recording.addFix(fix(2, 10.0001), time(2));
      expect(recording.segments.length, 2);
      expect(recording.segments.last.single.time, time(2));
      recording.addFix(fix(1, 10.00005), time(2));
      expect(recording.segments.last.length, 1);
    },
  );

  test(
    'pace stays a placeholder below 100m and recovery preserves final stats',
    () {
      final recording = run();
      expect(recording.pace(time(1)), isNull);
      for (var second = 1; second <= 30; second++) {
        recording.addFix(fix(second, 10 + second * 0.00004), time(second));
      }
      expect(recording.pace(time(30)), isNotNull);
      final restored = RecordedRun.restore(recording.toJson(time(30)));
      expect(restored.id, recording.id);
      expect(restored.phase, RunPhase.finished);
      expect(restored.distanceM, recording.distanceM);
      expect(restored.activeMs, 30000);
      expect(restored.elapsedMs(time(500)), 30000);
      expect(restored.routeJson, recording.routeJson);
    },
  );

  test('stationary GPS fixes do not create an artificial signal gap', () {
    final recording = run();
    for (var second = 1; second <= 20; second++) {
      recording.addFix(fix(second, 10), time(second));
    }
    recording.addFix(fix(21, 10.00004), time(21));
    expect(recording.segments.length, 1);
    expect(recording.distanceM, greaterThan(3));
  });

  test('invalid stored coordinates fail before the map can render them', () {
    for (final point in <List<dynamic>>[
      [91, 106, 1],
      [10, 181, 1],
      [10, 106],
      ['10', 106, 1],
      [double.nan, 106, 1],
    ]) {
      expect(() => RunFix.fromJson(point), throwsFormatException);
    }
  });

  test('legacy activity JSON still parses without GPS metadata', () {
    final json = {
      'user_id': 'runner',
      'started_at': start.toIso8601String(),
      'distance_km': 5,
      'duration_min': 30,
    };
    expect(Activity.fromJson(json).hasGpsRoute, isFalse);
    final activity = Activity.fromJson({...json, 'has_gps_route': true});
    expect(activity.hasGpsRoute, isTrue);
    expect(activity.toJson()['has_gps_route'], isTrue);
  });
}
