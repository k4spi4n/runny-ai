import 'package:flutter/material.dart';
import '../models/nutrition_models.dart';
import '../models/workout_models.dart';

class NutritionService extends ChangeNotifier {

  
  NutritionGoal? _currentGoal;
  List<MealLog> _logs = [];
  List<Activity> _activities = [];

  NutritionGoal? get currentGoal => _currentGoal;
  List<MealLog> get logs => _logs;

  NutritionService() {
    // Mock initial data for UI development
    _currentGoal = NutritionGoal(
      userId: 'user-123',
      dailyCalories: 2200,
      proteinPercentage: 30,
      carbsPercentage: 40,
      fatPercentage: 30,
    );
    
    _logs = [
      MealLog(
        userId: 'user-123',
        foodName: 'Oatmeal with Blueberries',
        calories: 350,
        protein: 10,
        carbs: 60,
        fat: 5,
        amount: 1,
        unit: 'bowl',
        mealType: MealType.breakfast,
        consumedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      MealLog(
        userId: 'user-123',
        foodName: 'Grilled Chicken Salad',
        calories: 450,
        protein: 40,
        carbs: 15,
        fat: 25,
        amount: 1,
        unit: 'plate',
        mealType: MealType.lunch,
        consumedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    _activities = [
      Activity(
        userId: 'user-123',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        distanceKm: 5.0,
        durationMin: 30,
      ),
    ];
  }

  DailyNutritionSummary getDailySummary(DateTime date) {
    final dayLogs = _logs.where((log) => 
      log.consumedAt.year == date.year && 
      log.consumedAt.month == date.month && 
      log.consumedAt.day == date.day
    ).toList();

    final dayActivities = _activities.where((activity) => 
      activity.startedAt.year == date.year && 
      activity.startedAt.month == date.month && 
      activity.startedAt.day == date.day
    ).toList();

    double totalCaloriesIn = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var log in dayLogs) {
      totalCaloriesIn += log.calories;
      totalProtein += log.protein;
      totalCarbs += log.carbs;
      totalFat += log.fat;
    }

    double totalCaloriesOut = 0;
    for (var activity in dayActivities) {
      // Basic calorie burn estimation: 60 kcal per km for running (simplified)
      totalCaloriesOut += activity.distanceKm * 60;
    }

    return DailyNutritionSummary(
      date: date,
      caloriesIn: totalCaloriesIn,
      caloriesOut: totalCaloriesOut,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      goal: _currentGoal ?? NutritionGoal(userId: 'guest', dailyCalories: 2000),
    );
  }

  Future<void> addMealLog(MealLog log) async {
    _logs.add(log);
    notifyListeners();
    // TODO: Implement Supabase save
  }

  Future<void> deleteMealLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
    notifyListeners();
    // TODO: Implement Supabase delete
  }

  List<MealLog> getLogsForMealType(MealType type, DateTime date) {
    return _logs.where((log) => 
      log.mealType == type &&
      log.consumedAt.year == date.year && 
      log.consumedAt.month == date.month && 
      log.consumedAt.day == date.day
    ).toList();
  }
}
