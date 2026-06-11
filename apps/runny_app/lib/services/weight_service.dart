import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_models.dart';

/// Service cho Issue #30: Quản lý và theo dõi cân nặng.
class WeightService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _uid {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');
    return user.id;
  }

  /// Lấy tổng quan mục tiêu + cân nặng hiện tại từ hồ sơ.
  Future<WeightGoal> fetchGoal() async {
    final data = await _supabase
        .from('profiles')
        .select('weight_kg, target_weight_kg, start_weight_kg')
        .eq('id', _uid)
        .single();
    return WeightGoal.fromProfile(data);
  }

  Future<List<WeightLog>> fetchLogs({int limit = 60}) async {
    final response = await _supabase
        .from('weight_logs')
        .select()
        .eq('user_id', _uid)
        .order('logged_at', ascending: true)
        .limit(limit);
    return (response as List).map((e) => WeightLog.fromJson(e)).toList();
  }

  /// Đặt/cập nhật mục tiêu cân nặng. [startWeight] là mốc bắt đầu (mặc định
  /// dùng cân nặng hiện tại nếu không truyền).
  Future<void> setGoal({
    required double targetWeight,
    double? startWeight,
  }) async {
    final update = <String, dynamic>{'target_weight_kg': targetWeight};
    if (startWeight != null) {
      update['start_weight_kg'] = startWeight;
      update['weight_kg'] = startWeight;
    }
    await _supabase.from('profiles').update(update).eq('id', _uid);
  }

  /// Ghi nhận một lần cân. Đồng thời cập nhật cân nặng hiện tại trên hồ sơ;
  /// nếu chưa có mốc bắt đầu thì lấy lần ghi này làm mốc.
  Future<void> logWeight(double weightKg, {DateTime? loggedAt, String? note}) async {
    await _supabase.from('weight_logs').insert({
      'user_id': _uid,
      'weight_kg': weightKg,
      'logged_at': (loggedAt ?? DateTime.now()).toIso8601String(),
      'note': note,
    });

    final profile = await _supabase
        .from('profiles')
        .select('start_weight_kg')
        .eq('id', _uid)
        .single();

    final update = <String, dynamic>{'weight_kg': weightKg};
    if (profile['start_weight_kg'] == null) {
      update['start_weight_kg'] = weightKg;
    }
    await _supabase.from('profiles').update(update).eq('id', _uid);
  }

  Future<void> deleteLog(String id) async {
    await _supabase.from('weight_logs').delete().eq('id', id);
  }
}
