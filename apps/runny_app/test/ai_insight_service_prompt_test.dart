import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/workout_models.dart';
import 'package:runny_app/services/ai_insight_service.dart';

void main() {
  test('weekly cache period changes only when a new week starts', () {
    expect(
      AiInsightService.weeklyCachePeriod(DateTime(2026, 7, 14)),
      '2026-07-13',
    );
    expect(
      AiInsightService.weeklyCachePeriod(DateTime(2026, 7, 19)),
      '2026-07-13',
    );
    expect(
      AiInsightService.weeklyCachePeriod(DateTime(2026, 7, 20)),
      '2026-07-20',
    );
  });

  test(
    'dashboard activity prompt is grounded in the supplied current date',
    () {
      final prompt = AiInsightService.buildActivityTrendPrompt(
        activities: [
          Activity(
            id: 'activity-1',
            userId: 'user-1',
            startedAt: DateTime(2026, 7, 13, 6),
            distanceKm: 5,
            durationMin: 30,
            avgHr: 145,
          ),
        ],
        languageCode: 'vi',
        today: DateTime(2026, 7, 14, 9),
      );

      expect(prompt, contains('REFERENCE_DATE:2026-07-14'));
      expect(prompt, contains('2026-07-13'));
      expect(prompt, contains('no training-plan discussion'));
      expect(prompt, contains('Listed metrics only'));
      expect(prompt.length, lessThan(700));
    },
  );

  test('training prompt asks for one short weekly conclusion', () {
    final prompt = AiInsightService.buildWeeklyTrainingPrompt(
      currentWeek: const WeeklyTrainingMetrics(
        activityCount: 2,
        distanceKm: 12,
        durationMin: 72,
      ),
      previousWeek: const WeeklyTrainingMetrics(
        activityCount: 1,
        distanceKm: 5,
        durationMin: 32,
      ),
      plannedWorkouts: 3,
      completedWorkouts: 2,
      skippedWorkouts: 0,
      languageCode: 'vi',
      today: DateTime(2026, 7, 14),
    );

    expect(prompt, contains('exactly one sentence'));
    expect(prompt, contains('maximum 24 words'));
    expect(prompt, contains('completed=2,scheduled=3'));
    expect(prompt, contains('2026-07-14'));
    expect(prompt.length, lessThan(700));
  });

  test(
    'activity prompt keeps missing pace and heart rate explicit but compact',
    () {
      final prompt = AiInsightService.buildActivityTrendPrompt(
        activities: [
          Activity(
            id: 'activity-1',
            userId: 'user-1',
            startedAt: DateTime(2026, 7, 14),
            distanceKm: 0,
            durationMin: 12,
          ),
        ],
        languageCode: 'en',
        today: DateTime(2026, 7, 14),
      );

      expect(prompt, contains('OUTPUT_LANGUAGE:en'));
      expect(prompt, contains('2026-07-14,0.0,12,,'));
      expect(prompt, isNot(contains('NaN')));
      expect(prompt, isNot(contains('null')));
    },
  );
}
