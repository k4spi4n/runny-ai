import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/workout_models.dart';
import 'package:runny_app/pages/ai_coach_page.dart';

void main() {
  test('activity review attaches activity without auto sending', () {
    final activity = Activity(
      id: 'activity-1',
      userId: 'user-1',
      startedAt: DateTime(2026, 7, 14),
      distanceKm: 5,
      durationMin: 30,
    );
    final page = AICoachPage.activityReview(activity: activity);

    expect(page.initialActivity, same(activity));
    expect(page.autoSendInitialPrompt, isFalse);
  });

  test('draft prompt is prefilled without auto sending', () {
    const prompt = 'Gợi ý bài khởi động cho buổi tempo.';
    const page = AICoachPage.draftPrompt(prompt: prompt);

    expect(page.initialPrompt, prompt);
    expect(page.autoSendInitialPrompt, isFalse);
  });
}
