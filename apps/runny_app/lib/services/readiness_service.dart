import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/readiness_models.dart';

class ReadinessService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<ReadinessSnapshot> getSnapshot() async {
    final raw = await _supabase.rpc('get_readiness_snapshot');
    final row = raw is List
        ? (raw.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(raw.first as Map))
        : Map<String, dynamic>.from(raw as Map);
    return ReadinessSnapshot.fromJson(row);
  }

  Future<RecoveryFeedback?> getFeedback(String activityId) async {
    final row = await _supabase
        .from('activity_recovery_feedback')
        .select()
        .eq('activity_id', activityId)
        .maybeSingle();
    return row == null ? null : RecoveryFeedback.fromJson(row);
  }

  Future<void> saveFeedback({
    required String activityId,
    required int rpe,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('User not logged in');
    await _supabase.from('activity_recovery_feedback').upsert({
      'activity_id': activityId,
      'user_id': user.id,
      'rpe': rpe,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'activity_id');
  }

  Future<RecoveryCheckin?> getTodayCheckin() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final row = await _supabase
        .from('daily_recovery_checkins')
        .select()
        .eq('checkin_date', today)
        .maybeSingle();
    return row == null ? null : RecoveryCheckin.fromJson(row);
  }

  Future<void> saveCheckin(RecoveryCheckin value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('User not logged in');
    await _supabase.from('daily_recovery_checkins').upsert({
      'user_id': user.id,
      'checkin_date': value.date.toIso8601String().substring(0, 10),
      'sleep_quality': value.sleepQuality,
      'sleep_hours': value.sleepHours,
      'soreness': value.soreness,
      'pain_flag': value.painFlag,
      'notes': value.notes?.trim().isEmpty == true ? null : value.notes?.trim(),
    }, onConflict: 'user_id,checkin_date');
  }
}
