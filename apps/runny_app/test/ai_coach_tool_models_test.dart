import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/ai_coach_tool_models.dart';

void main() {
  test('interactive coach action round-trips and changes status', () {
    const action = CoachInteractiveAction(
      kind: 'workout_update',
      targetId: 'workout-1',
      title: 'Easy run',
      before: {'target_distance_km': 10},
      changes: {'target_distance_km': 8},
    );

    final restored = CoachInteractiveAction.fromJson(action.toJson());

    expect(restored.kind, 'workout_update');
    expect(restored.isPending, isTrue);
    expect(restored.changes['target_distance_km'], 8);
    expect(restored.copyWith(status: 'applied').status, 'applied');
  });

  test('tool call parses OpenAI JSON string arguments', () {
    final call = CoachToolCall.fromJson({
      'id': 'call-1',
      'type': 'function',
      'function': {
        'name': 'propose_meal_update',
        'arguments': '{"meal_id":"meal-1","calories":420}',
      },
    });

    expect(call.id, 'call-1');
    expect(call.name, 'propose_meal_update');
    expect(call.arguments, {'meal_id': 'meal-1', 'calories': 420});
  });
}
