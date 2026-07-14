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

      expect(prompt, contains('Local current date: 2026-07-14'));
      expect(prompt, contains('2026-07-13'));
      expect(prompt, contains('Do not discuss the training plan'));
      expect(prompt, contains('Do not invent'));
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

    expect(prompt, contains('exactly one short conclusion sentence'));
    expect(prompt, contains('at most 24 words'));
    expect(prompt, contains('2 completed / 3 scheduled'));
    expect(prompt, contains('2026-07-14'));
  });
}
