class FoodItem {
  final String? id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? servingUnit;
  final double servingSize;

  FoodItem({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingUnit,
    required this.servingSize,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      servingUnit: json['serving_unit'],
      servingSize: (json['serving_size'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'serving_unit': servingUnit,
      'serving_size': servingSize,
    };
  }
}

enum MealType { breakfast, lunch, dinner, snack }

class MealLog {
  final String? id;
  final String userId;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double amount;
  final String unit;
  final MealType mealType;
  final DateTime consumedAt;

  MealLog({
    this.id,
    required this.userId,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.amount,
    required this.unit,
    required this.mealType,
    required this.consumedAt,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: json['id'],
      userId: json['user_id'],
      foodName: json['food_name'],
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'],
      mealType: MealType.values.firstWhere(
        (e) => e.name == json['meal_type'],
        orElse: () => MealType.snack,
      ),
      consumedAt: DateTime.parse(json['consumed_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'amount': amount,
      'unit': unit,
      'meal_type': mealType.name,
      'consumed_at': consumedAt.toIso8601String(),
    };
  }
}

class NutritionGoal {
  final String userId;
  final double dailyCalories;
  final double proteinPercentage;
  final double carbsPercentage;
  final double fatPercentage;

  NutritionGoal({
    required this.userId,
    required this.dailyCalories,
    this.proteinPercentage = 30,
    this.carbsPercentage = 40,
    this.fatPercentage = 30,
  });

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    return NutritionGoal(
      userId: json['user_id'],
      dailyCalories: (json['daily_calories'] as num).toDouble(),
      proteinPercentage: (json['protein_percentage'] as num).toDouble(),
      carbsPercentage: (json['carbs_percentage'] as num).toDouble(),
      fatPercentage: (json['fat_percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'daily_calories': dailyCalories,
      'protein_percentage': proteinPercentage,
      'carbs_percentage': carbsPercentage,
      'fat_percentage': fatPercentage,
    };
  }

  double get targetProteinGrams => (dailyCalories * (proteinPercentage / 100)) / 4;
  double get targetCarbsGrams => (dailyCalories * (carbsPercentage / 100)) / 4;
  double get targetFatGrams => (dailyCalories * (fatPercentage / 100)) / 9;
}

class DailyNutritionSummary {
  final DateTime date;
  final double caloriesIn;
  final double caloriesOut;
  final double protein;
  final double carbs;
  final double fat;
  final NutritionGoal goal;

  DailyNutritionSummary({
    required this.date,
    required this.caloriesIn,
    required this.caloriesOut,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.goal,
  });

  double get caloriesLeft => goal.dailyCalories - caloriesIn + caloriesOut;
  double get calorieCompletion => (caloriesIn / goal.dailyCalories).clamp(0, 1.2);
  
  double get proteinCompletion => (protein / goal.targetProteinGrams).clamp(0, 1.2);
  double get carbsCompletion => (carbs / goal.targetCarbsGrams).clamp(0, 1.2);
  double get fatCompletion => (fat / goal.targetFatGrams).clamp(0, 1.2);
}
