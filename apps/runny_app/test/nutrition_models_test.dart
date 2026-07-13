import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/nutrition_models.dart';

void main() {
  group('NutritionGoalRecommendation', () {
    test('provides a runner-friendly maintenance starting point by weight', () {
      final suggestion = NutritionGoalRecommendation.forRunner(weightKg: 70);

      expect(suggestion.proteinGrams, 112);
      expect(suggestion.carbsGrams, 350);
      expect(suggestion.fatGrams, 63);
      expect(suggestion.dailyCalories, 2415);
    });

    test('raises protein and lowers carbs for a weight-loss target', () {
      final suggestion = NutritionGoalRecommendation.forRunner(
        weightKg: 70,
        targetWeightKg: 65,
      );

      expect(suggestion.proteinGrams, 126);
      expect(suggestion.carbsGrams, 315);
      expect(suggestion.fatGrams, 63);
    });
  });

  test('loads grams from legacy percentage-only nutrition goals', () {
    final goal = NutritionGoal.fromJson({
      'user_id': 'runner',
      'daily_calories': 2000,
      'protein_percentage': 30,
      'carbs_percentage': 40,
      'fat_percentage': 30,
    });

    expect(goal.proteinGrams, 150);
    expect(goal.carbsGrams, 200);
    expect(goal.fatGrams, closeTo(66.67, 0.01));
  });

  test('daily food target is not increased by exercise calories', () {
    final goal = NutritionGoal(
      userId: 'runner',
      dailyCalories: 2200,
      proteinGrams: 120,
      carbsGrams: 300,
      fatGrams: 70,
    );
    final summary = DailyNutritionSummary(
      date: DateTime(2026, 7, 13),
      caloriesIn: 1800,
      caloriesOut: 600,
      protein: 90,
      carbs: 200,
      fat: 50,
      goal: goal,
    );

    expect(summary.caloriesLeft, 400);
    expect(summary.caloriesRemaining, 400);
    expect(summary.calorieCompletion, closeTo(1800 / 2200, 0.001));
  });
}
