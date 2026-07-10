import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_models.dart';
import '../models/workout_models.dart';

/// Service theo dõi dinh dưỡng, lưu trữ qua Supabase (bảng `nutrition_goals`
/// và `meal_logs`). Dữ liệu của ~60 ngày gần nhất được nạp vào bộ nhớ để các
/// thao tác xem theo ngày trên giao diện diễn ra tức thì.
class NutritionService extends ChangeNotifier {
  NutritionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    _sessionUserId = _supabase.auth.currentUser?.id;
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      final nextUserId = state.session?.user.id;
      if (nextUserId != _sessionUserId) {
        _sessionUserId = nextUserId;
        _resetForSession();
      }
    });
  }

  final SupabaseClient _supabase;
  late final StreamSubscription<AuthState> _authSubscription;
  String? _sessionUserId;

  /// Số ngày lịch sử được nạp vào bộ nhớ.
  static const int _historyDays = 60;

  /// Ước lượng năng lượng tiêu hao: ~60 kcal mỗi km chạy bộ (đơn giản hóa).
  static const double _kcalPerKm = 60;

  NutritionGoal? _currentGoal;
  List<MealLog> _logs = [];
  List<Activity> _activities = [];
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;

  NutritionGoal? get currentGoal => _currentGoal;
  List<MealLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get _uid => _supabase.auth.currentUser?.id;

  void _resetForSession() {
    _currentGoal = null;
    _logs = [];
    _activities = [];
    _isLoading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  /// Nạp dữ liệu lần đầu (gọi an toàn nhiều lần — chỉ nạp một lần).
  Future<void> ensureLoaded() async {
    if (_loaded || _isLoading) return;
    await refresh();
  }

  /// Nạp lại toàn bộ mục tiêu + nhật ký + hoạt động từ Supabase.
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) {
      _error = 'Chưa đăng nhập';
      _loaded = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final since = DateTime.now()
          .subtract(const Duration(days: _historyDays))
          .toIso8601String();

      final goalRes = await _supabase
          .from('nutrition_goals')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      _currentGoal = goalRes != null
          ? NutritionGoal.fromJson(goalRes)
          : NutritionGoal(userId: uid, dailyCalories: 2000);

      final logsRes = await _supabase
          .from('meal_logs')
          .select()
          .eq('user_id', uid)
          .gte('consumed_at', since)
          .order('consumed_at', ascending: true);
      _logs = (logsRes as List)
          .map((e) => MealLog.fromJson(e as Map<String, dynamic>))
          .toList();

      final actRes = await _supabase
          .from('activities')
          .select('user_id, started_at, distance_km, duration_min')
          .eq('user_id', uid)
          .gte('started_at', since);
      _activities = (actRes as List)
          .map((e) => Activity.fromJson(e as Map<String, dynamic>))
          .toList();

      _loaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DailyNutritionSummary getDailySummary(DateTime date) {
    bool sameDay(DateTime d) =>
        d.year == date.year && d.month == date.month && d.day == date.day;

    final dayLogs = _logs.where((log) => sameDay(log.consumedAt));
    final dayActivities = _activities.where((a) => sameDay(a.startedAt));

    double totalCaloriesIn = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final log in dayLogs) {
      totalCaloriesIn += log.calories;
      totalProtein += log.protein;
      totalCarbs += log.carbs;
      totalFat += log.fat;
    }

    double totalCaloriesOut = 0;
    for (final activity in dayActivities) {
      totalCaloriesOut += activity.distanceKm * _kcalPerKm;
    }

    return DailyNutritionSummary(
      date: date,
      caloriesIn: totalCaloriesIn,
      caloriesOut: totalCaloriesOut,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      goal: _currentGoal ??
          NutritionGoal(userId: _uid ?? 'guest', dailyCalories: 2000),
    );
  }

  /// Ghi nhận một món ăn. [log.userId] được ghi đè bằng người dùng hiện tại.
  Future<void> addMealLog(MealLog log) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final payload = log.toJson()
      ..remove('id')
      ..['user_id'] = uid;

    final inserted = await _supabase
        .from('meal_logs')
        .insert(payload)
        .select()
        .single();

    _logs.add(MealLog.fromJson(inserted));
    notifyListeners();
  }

  Future<void> deleteMealLog(String id) async {
    await _supabase.from('meal_logs').delete().eq('id', id);
    _logs.removeWhere((log) => log.id == id);
    notifyListeners();
  }

  /// Đặt/cập nhật mục tiêu dinh dưỡng (upsert theo user_id).
  Future<void> setGoal(NutritionGoal goal) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final payload = goal.toJson()
      ..['user_id'] = uid
      ..['updated_at'] = DateTime.now().toIso8601String();

    final res = await _supabase
        .from('nutrition_goals')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();

    _currentGoal = NutritionGoal.fromJson(res);
    notifyListeners();
  }

  /// Các món người dùng từng ăn — mỗi tên xuất hiện một lần, mới nhất trước —
  /// để gợi ý thêm nhanh trong màn hình nhập thủ công.
  List<MealLog> get recentDistinctFoods {
    final seen = <String>{};
    final result = <MealLog>[];
    // _logs được sắp xếp tăng dần theo thời gian -> duyệt ngược để lấy bản mới nhất.
    for (final log in _logs.reversed) {
      final key = log.foodName.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(log);
    }
    return result;
  }

  List<MealLog> getLogsForMealType(MealType type, DateTime date) {
    return _logs
        .where((log) =>
            log.mealType == type &&
            log.consumedAt.year == date.year &&
            log.consumedAt.month == date.month &&
            log.consumedAt.day == date.day)
        .toList();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
