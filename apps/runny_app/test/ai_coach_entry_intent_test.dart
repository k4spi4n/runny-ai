import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runny_app/models/workout_models.dart';
import 'package:runny_app/services/ai_coach_hub_controller.dart';
import 'package:runny_app/utils/ai_coach_hub_navigation.dart';

void main() {
  final activity = Activity(
    id: 'activity-1',
    userId: 'user-1',
    startedAt: DateTime(2026, 7, 14),
    distanceKm: 5,
    durationMin: 30,
  );

  test('activity review is sent to the central AI Coach without auto-send', () {
    final controller = AICoachHubController();

    controller.open(activity: activity);

    expect(controller.request?.activity, same(activity));
    expect(controller.request?.prompt, isNull);
    expect(controller.request?.autoSend, isFalse);
  });

  test('plan optimization is sent to the central AI Coach with auto-send', () {
    final controller = AICoachHubController();

    controller.open(
      activity: activity,
      prompt: 'Tối ưu kế hoạch của tôi.',
      autoSend: true,
    );

    expect(controller.request?.activity, same(activity));
    expect(controller.request?.prompt, 'Tối ưu kế hoạch của tôi.');
    expect(controller.request?.autoSend, isTrue);
  });

  testWidgets('AI Coach entry returns to the central dashboard route', (
    tester,
  ) async {
    final controller = AICoachHubController();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const ValueKey('open_activity_details'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: FilledButton(
                        key: const ValueKey('analyze_in_ai_coach'),
                        onPressed: () =>
                            openAICoachHub(context, activity: activity),
                        child: const Text('Phân tích hoạt động'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mở hoạt động'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open_activity_details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analyze_in_ai_coach')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analyze_in_ai_coach')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open_activity_details')), findsOneWidget);
    expect(find.byKey(const ValueKey('analyze_in_ai_coach')), findsNothing);
    expect(controller.request?.activity, same(activity));
  });
}
