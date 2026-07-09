import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/run_reminder_model.dart';
import 'notification_service.dart';

class RunReminderService {
  RunReminderService({
    SupabaseClient? supabase,
    NotificationService? notificationService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _notificationService =
            notificationService ?? NotificationService.instance;

  final SupabaseClient _supabase;
  final NotificationService _notificationService;

  Future<Map<String, RunReminder>> remindersForWorkouts(
    List<String> workoutIds,
  ) async {
    if (workoutIds.isEmpty) return {};
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    final rows = List<Map<String, dynamic>>.from(
      await _supabase
          .from('run_reminders')
          .select()
          .eq('user_id', user.id)
          .inFilter('workout_id', workoutIds),
    );

    final reminders = rows.map(RunReminder.fromJson);
    return {for (final reminder in reminders) reminder.workoutId: reminder};
  }

  Future<RunReminder> saveReminder({
    required String workoutId,
    required String workoutTitle,
    required DateTime workoutAt,
    required int leadMinutes,
    required bool enabled,
  }) async {
    if (!reminderLeadMinuteOptions.contains(leadMinutes)) {
      throw ArgumentError.value(leadMinutes, 'leadMinutes');
    }

    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('User not logged in');

    final notificationId = notificationIdForWorkout(workoutId);
    final scheduledFor = reminderScheduledFor(workoutAt, leadMinutes);
    final reminder = RunReminder(
      userId: user.id,
      workoutId: workoutId,
      leadMinutes: leadMinutes,
      enabled: enabled,
      notificationId: notificationId,
      scheduledFor: scheduledFor,
    );

    if (_notificationService.supportsScheduledNotifications) {
      if (enabled) {
        final granted = await _notificationService.requestReminderPermission();
        if (!granted) throw StateError('Notification permission denied.');
        await _notificationService.scheduleRunReminder(
          reminder: reminder,
          workoutTitle: workoutTitle,
        );
      } else {
        await _notificationService.cancelRunReminder(notificationId);
      }
    }

    try {
      final row = await _supabase
          .from('run_reminders')
          .upsert(reminder.toUpsertJson(), onConflict: 'workout_id')
          .select()
          .single();
      return RunReminder.fromJson(row);
    } catch (_) {
      if (enabled && _notificationService.supportsScheduledNotifications) {
        await _notificationService.cancelRunReminder(notificationId);
      }
      rethrow;
    }
  }

  Future<void> disableReminder(String workoutId) async {
    final notificationId = notificationIdForWorkout(workoutId);
    if (_notificationService.supportsScheduledNotifications) {
      await _notificationService.cancelRunReminder(notificationId);
    }
    await _supabase
        .from('run_reminders')
        .update({
          'enabled': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('workout_id', workoutId);
  }
}
