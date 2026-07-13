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

/// Cách một mục tiêu dinh dưỡng được tạo. Giá trị này chỉ để minh bạch với
/// runner; mọi mục tiêu đều có thể chỉnh tay sau khi áp dụng đề xuất.
enum NutritionGoalSource {
  manual,
  weightBased;

  String get databaseValue => switch (this) {
    NutritionGoalSource.manual => 'manual',
    NutritionGoalSource.weightBased => 'weight_based',
  };

  static NutritionGoalSource fromDatabaseValue(String? value) =>
      value == 'weight_based'
      ? NutritionGoalSource.weightBased
      : NutritionGoalSource.manual;
}

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
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final NutritionGoalSource source;

  NutritionGoal({
    required this.userId,
    required this.dailyCalories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    this.source = NutritionGoalSource.manual,
  }) : proteinGrams = proteinGrams ?? dailyCalories * .30 / 4,
       carbsGrams = carbsGrams ?? dailyCalories * .40 / 4,
       fatGrams = fatGrams ?? dailyCalories * .30 / 9;

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    final calories = (json['daily_calories'] as num).toDouble();
    final proteinPercentage =
        (json['protein_percentage'] as num?)?.toDouble() ?? 30;
    final carbsPercentage =
        (json['carbs_percentage'] as num?)?.toDouble() ?? 40;
    final fatPercentage = (json['fat_percentage'] as num?)?.toDouble() ?? 30;
    return NutritionGoal(
      userId: json['user_id'],
      dailyCalories: calories,
      proteinGrams:
          (json['protein_grams'] as num?)?.toDouble() ??
          calories * proteinPercentage / 100 / 4,
      carbsGrams:
          (json['carbs_grams'] as num?)?.toDouble() ??
          calories * carbsPercentage / 100 / 4,
      fatGrams:
          (json['fat_grams'] as num?)?.toDouble() ??
          calories * fatPercentage / 100 / 9,
      source: NutritionGoalSource.fromDatabaseValue(json['source'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'daily_calories': dailyCalories,
      // Giữ các cột phần trăm cũ để dữ liệu hiện hữu và dashboard cũ vẫn đọc
      // được; mục tiêu chính xác được lưu theo gram ở các cột mới.
      'protein_percentage': proteinPercentage,
      'carbs_percentage': carbsPercentage,
      'fat_percentage': fatPercentage,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fat_grams': fatGrams,
      'source': source.databaseValue,
    };
  }

  double get macroCalories => proteinGrams * 4 + carbsGrams * 4 + fatGrams * 9;
  double get proteinPercentage => proteinGrams * 4 / dailyCalories * 100;
  double get carbsPercentage => carbsGrams * 4 / dailyCalories * 100;
  double get fatPercentage => fatGrams * 9 / dailyCalories * 100;

  double get targetProteinGrams => proteinGrams;
  double get targetCarbsGrams => carbsGrams;
  double get targetFatGrams => fatGrams;

  NutritionGoal copyWith({
    double? dailyCalories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    NutritionGoalSource? source,
  }) => NutritionGoal(
    userId: userId,
    dailyCalories: dailyCalories ?? this.dailyCalories,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbsGrams: carbsGrams ?? this.carbsGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    source: source ?? this.source,
  );
}

/// Đề xuất khởi điểm dành cho người chạy. Đây không phải đơn dinh dưỡng y tế:
/// người dùng luôn thấy và chỉnh được cả kcal lẫn gram macro trước khi lưu.
class NutritionGoalRecommendation {
  final double weightKg;
  final double dailyCalories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  const NutritionGoalRecommendation({
    required this.weightKg,
    required this.dailyCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  factory NutritionGoalRecommendation.forRunner({
    required double weightKg,
    double? targetWeightKg,
  }) {
    final isLosing = targetWeightKg != null && targetWeightKg < weightKg;
    final isGaining = targetWeightKg != null && targetWeightKg > weightKg;
    final proteinPerKg = isLosing ? 1.8 : 1.6;
    final carbsPerKg = isLosing ? 4.5 : (isGaining ? 5.5 : 5.0);
    final fatPerKg = isGaining ? 1.0 : 0.9;
    final protein = weightKg * proteinPerKg;
    final carbs = weightKg * carbsPerKg;
    final fat = weightKg * fatPerKg;
    return NutritionGoalRecommendation(
      weightKg: weightKg,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      dailyCalories: protein * 4 + carbs * 4 + fat * 9,
    );
  }

  NutritionGoal toGoal(String userId) => NutritionGoal(
    userId: userId,
    dailyCalories: dailyCalories,
    proteinGrams: proteinGrams,
    carbsGrams: carbsGrams,
    fatGrams: fatGrams,
    source: NutritionGoalSource.weightBased,
  );
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

  /// Mục tiêu là lượng **nạp** trong ngày. Calories chạy được hiển thị như dữ
  /// liệu vận động riêng, không cộng vào "còn lại" để tránh trộn hai cách tính
  /// gross và net calories trên cùng một màn hình.
  double get caloriesLeft => goal.dailyCalories - caloriesIn;
  double get calorieCompletion =>
      (caloriesIn / goal.dailyCalories).clamp(0, 1.0);
  bool get isOverCalories => caloriesLeft < 0;
  double get caloriesRemaining => caloriesLeft < 0 ? 0 : caloriesLeft;
  double get caloriesOver => caloriesLeft < 0 ? -caloriesLeft : 0;

  double get proteinCompletion =>
      (protein / goal.targetProteinGrams).clamp(0, 1.2);
  double get carbsCompletion => (carbs / goal.targetCarbsGrams).clamp(0, 1.2);
  double get fatCompletion => (fat / goal.targetFatGrams).clamp(0, 1.2);
}
