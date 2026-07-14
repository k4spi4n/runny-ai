import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/activity_matcher.dart';

void main() {
  test('ranks the closest activity by time, distance and duration', () {
    final workout = <String, dynamic>{
      'date': '2026-07-14',
      'start_time': '06:00:00',
      'target_distance_km': 5.0,
      'target_duration_min': 30.0,
    };
    final activities = <Map<String, dynamic>>[
      {
        'id': 'far',
        'started_at': '2026-07-10T06:00:00',
        'distance_km': 10.0,
        'duration_min': 70.0,
      },
      {
        'id': 'match',
        'started_at': '2026-07-14T06:15:00',
        'distance_km': 5.1,
        'duration_min': 31.0,
      },
      {
        'id': 'same-day-wrong-distance',
        'started_at': '2026-07-14T07:00:00',
        'distance_km': 2.0,
        'duration_min': 12.0,
      },
    ];

    final ranked = ActivityMatcher.rank(
      workout: workout,
      activities: activities,
    );

    expect(ranked.first.activity['id'], 'match');
    expect(ranked.first.isStrongMatch, isTrue);
    expect(ranked.last.activity['id'], 'far');
  });
}
