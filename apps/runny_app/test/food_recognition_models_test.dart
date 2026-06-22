import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/food_recognition_models.dart';

void main() {
  test('FoodRecognitionResult parses API response', () {
    final result = FoodRecognitionResult.fromJson({
      'food_name': 'Com ga',
      'confidence': 0.92,
      'nutrition': {
        'calories': 520,
        'protein': 35,
        'carbs': 55,
        'fat': 15,
      },
    });

    expect(result.foodName, 'Com ga');
    expect(result.confidence, 0.92);
    expect(result.nutrition.calories, 520);
    expect(result.nutrition.protein, 35);
    expect(result.nutrition.carbs, 55);
    expect(result.nutrition.fat, 15);
  });
}
