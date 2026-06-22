class FoodRecognitionNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const FoodRecognitionNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory FoodRecognitionNutrition.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionNutrition(
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

class FoodRecognitionResult {
  final String foodName;
  final double confidence;
  final FoodRecognitionNutrition nutrition;

  const FoodRecognitionResult({
    required this.foodName,
    required this.confidence,
    required this.nutrition,
  });

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionResult(
      foodName: json['food_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      nutrition: FoodRecognitionNutrition.fromJson(
        Map<String, dynamic>.from(json['nutrition'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'confidence': confidence,
      'nutrition': nutrition.toJson(),
    };
  }
}
