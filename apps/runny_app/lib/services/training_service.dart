import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import '../models/run_reminder_model.dart';
import 'gemini_service.dart';
import 'notification_service.dart';
import 'readiness_service.dart';
import 'training_refresh_service.dart';

/// Ném ra khi chưa có buổi tập nào hoàn thành (gắn hoạt động thực tế) — HLV AI
/// cần ít nhất một buổi để căn cứ tinh chỉnh lịch.
class NoCompletedWorkoutException implements Exception {}

/// Một đề xuất điều chỉnh cho MỘT buổi tập sắp tới (chưa ghi vào DB). Giữ cả giá
/// trị hiện tại lẫn giá trị mới để màn hình xem trước hiển thị "cũ → mới".
class WorkoutAdjustment {
  final String workoutId;
  final String title;
  final String? currentDate;
  final num? currentDistanceKm;
  final String? newDate;
  final num? newDistanceKm;
  final String reason;

  WorkoutAdjustment({
    required this.workoutId,
    required this.title,
    this.currentDate,
    this.currentDistanceKm,
    this.newDate,
    this.newDistanceKm,
    required this.reason,
  });

  /// Có thay đổi thực sự về ngày hoặc cự ly hay không.
  bool get hasChange =>
      (newDate != null && newDate != currentDate) ||
      (newDistanceKm != null && newDistanceKm != currentDistanceKm);
}

/// Kết quả AI đề xuất tinh chỉnh lịch tập: nhận xét tổng quan + danh sách thay đổi.
class PlanAdjustmentProposal {
  final String? summary;
  final List<WorkoutAdjustment> adjustments;
  const PlanAdjustmentProposal({this.summary, required this.adjustments});

  bool get isEmpty => adjustments.isEmpty;
}

class _LegacyManualMetadata {
  final String? startTime;
  final String? workoutType;
  final String? notes;

  const _LegacyManualMetadata({this.startTime, this.workoutType, this.notes});
}

/// A workout whose date was changed while rescheduling a plan.  The page uses
/// this to keep any existing local notification aligned with the stored date.
class RescheduledWorkout {
  const RescheduledWorkout({required this.workoutId, required this.workoutAt});

  final String workoutId;
  final DateTime workoutAt;
}

class TrainingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GeminiService _gemini = GeminiService();
  static const String _manualMetadataPrefix = 'RUNNY_MANUAL_WORKOUT_V1:';

  // Groq JSON Object Mode co the tra 400 neu model tu sinh JSON sai cu phap.
  // Schema strict rang buoc decoding o cap token va giu output on dinh de luu DB.
  static const Map<String, dynamic> _planResponseFormat = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'training_plan',
      'strict': true,
      'schema': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'title': {'type': 'string'},
          'target_distance_km': {'type': 'number'},
          'target_pace_min_per_km': {'type': 'number'},
          'weeks': {'type': 'integer'},
          'workouts': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'day_offset': {'type': 'integer'},
                'title': {'type': 'string'},
                'description': {'type': 'string'},
                'target_distance_km': {'type': 'number'},
                'target_duration_min': {'type': 'number'},
                'target_pace_min_per_km': {'type': 'number'},
                'source': {
                  'type': 'string',
                  'enum': ['ai', 'manual'],
                },
                'workout_type': {'type': 'string'},
                'start_time': {'type': 'string'},
              },
              'required': [
                'day_offset',
                'title',
                'description',
                'target_distance_km',
                'target_duration_min',
                'target_pace_min_per_km',
                'source',
                'workout_type',
                'start_time',
              ],
            },
          },
        },
        'required': [
          'title',
          'target_distance_km',
          'target_pace_min_per_km',
          'weeks',
          'workouts',
        ],
      },
    },
  };

  Future<void> completeScheduledWorkout({
    required String workoutId,
    required String activityId,
  }) async {
    await _supabase.rpc(
      'complete_scheduled_workout',
      params: {'p_workout_id': workoutId, 'p_activity_id': activityId},
    );
    TrainingRefreshService.instance.notifyTrainingChanged();
  }

  Future<void> skipScheduledWorkout(String workoutId) async {
    await _supabase.rpc(
      'skip_scheduled_workout',
      params: {'p_workout_id': workoutId},
    );
    TrainingRefreshService.instance.notifyTrainingChanged();
  }

  Future<void> activateSchedule(String scheduleId) async {
    await _supabase.rpc(
      'activate_training_schedule',
      params: {'p_schedule_id': scheduleId},
    );
    TrainingRefreshService.instance.notifyTrainingChanged();
  }

  Future<void> discardDraftSchedule(String scheduleId) async {
    await _supabase
        .from('training_schedules')
        .delete()
        .eq('id', scheduleId)
        .eq('status', 'draft');
    TrainingRefreshService.instance.notifyTrainingChanged();
  }

  /// Đặt lại một buổi chưa hoàn thành vào một ngày khác.
  ///
  /// Một buổi AI đã lỡ ngày vẫn phải trở thành buổi `planned` sau khi người
  /// dùng chọn ngày mới; nếu giữ trạng thái cũ (`rescheduled`/`skipped`) thì
  /// giao diện sẽ không nhận nó là buổi tập kế tiếp. Đồng thời nới khoảng ngày
  /// của kế hoạch khi ngày mới nằm sau ngày kết thúc mà AI đã tạo. Khi được
  /// chọn, các buổi `planned`/`rescheduled` phía sau sẽ cùng dời một khoảng.
  Future<List<RescheduledWorkout>> rescheduleWorkout({
    required String workoutId,
    required DateTime workoutAt,
    bool shiftFollowingWorkouts = false,
  }) async {
    final workout = await _supabase
        .from('scheduled_workouts')
        .select('id, schedule_id, status, date')
        .eq('id', workoutId)
        .single();

    if (workout['status'] == 'completed') {
      throw StateError('Completed workouts cannot be rescheduled');
    }

    final originalDate = DateTime.parse(workout['date'] as String);
    final dayShift = workoutAt
        .difference(
          DateTime(originalDate.year, originalDate.month, originalDate.day),
        )
        .inDays;
    final rescheduledWorkouts = <RescheduledWorkout>[
      RescheduledWorkout(workoutId: workoutId, workoutAt: workoutAt),
    ];

    if (shiftFollowingWorkouts && dayShift != 0) {
      final followingWorkouts = List<Map<String, dynamic>>.from(
        await _supabase
            .from('scheduled_workouts')
            .select('id, date, start_time')
            .eq('schedule_id', workout['schedule_id'])
            .gt('date', _dateOnly(originalDate))
            .inFilter('status', ['planned', 'rescheduled']),
      );

      final shiftedWorkouts = followingWorkouts.map((followingWorkout) {
        final followingDate = DateTime.parse(
          followingWorkout['date'] as String,
        );
        final shiftedDate = followingDate.add(Duration(days: dayShift));
        return RescheduledWorkout(
          workoutId: followingWorkout['id'] as String,
          workoutAt: _withStartTime(
            shiftedDate,
            followingWorkout['start_time']?.toString(),
          ),
        );
      }).toList();

      await Future.wait(
        shiftedWorkouts.map((shiftedWorkout) async {
          await _supabase
              .from('scheduled_workouts')
              .update({
                'date': _dateOnly(shiftedWorkout.workoutAt),
                'status': 'planned',
              })
              .eq('id', shiftedWorkout.workoutId);
        }),
      );
      rescheduledWorkouts.addAll(shiftedWorkouts);
    }

    await _supabase
        .from('scheduled_workouts')
        .update({
          'date': _dateOnly(workoutAt),
          'start_time':
              '${workoutAt.hour.toString().padLeft(2, '0')}:${workoutAt.minute.toString().padLeft(2, '0')}:00',
          'status': 'planned',
        })
        .eq('id', workoutId);

    final schedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('id', workout['schedule_id'])
        .maybeSingle();
    if (schedule != null) {
      final affectedDates =
          rescheduledWorkouts
              .map((rescheduled) => rescheduled.workoutAt)
              .toList()
            ..sort();
      await _expandScheduleRangeIfNeeded(
        schedule: schedule,
        earliestWorkoutDate: affectedDates.first,
        latestWorkoutDate: affectedDates.last,
      );
    }
    TrainingRefreshService.instance.notifyTrainingChanged();
    return rescheduledWorkouts;
  }

  void _ensureGeminiReady() {
    if (!_gemini.isConfigured) {
      throw Exception('OPENROUTER_API_KEY not found in .env');
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().split('T')[0];

  DateTime _withStartTime(DateTime date, String? rawTime) {
    final parts = rawTime?.split(':') ?? const <String>[];
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour.clamp(0, 23).toInt(),
      minute.clamp(0, 59).toInt(),
    );
  }

  String _cleanText(String value) => value.trim();

  static Map<String, dynamic> normalizeScheduledWorkout(
    Map<String, dynamic> workout,
  ) {
    final normalized = Map<String, dynamic>.from(workout);
    final metadata = _readLegacyManualMetadata(
      normalized['description']?.toString(),
    );
    if (metadata != null) {
      normalized['source'] = normalized['source'] ?? 'manual';
      normalized['start_time'] = normalized['start_time'] ?? metadata.startTime;
      normalized['workout_type'] =
          normalized['workout_type'] ?? metadata.workoutType;
      normalized['description'] = metadata.notes?.isEmpty == true
          ? null
          : metadata.notes;
    } else {
      normalized['source'] = normalized['source'] ?? 'ai';
    }
    return normalized;
  }

  static _LegacyManualMetadata? _readLegacyManualMetadata(String? description) {
    if (description == null || !description.startsWith(_manualMetadataPrefix)) {
      return null;
    }
    final lineBreak = description.indexOf('\n');
    final encoded = lineBreak == -1
        ? description.substring(_manualMetadataPrefix.length)
        : description.substring(_manualMetadataPrefix.length, lineBreak);
    try {
      final jsonText = utf8.decode(base64Url.decode(encoded));
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final notes = lineBreak == -1 ? '' : description.substring(lineBreak + 1);
      return _LegacyManualMetadata(
        startTime: data['start_time']?.toString(),
        workoutType: data['workout_type']?.toString(),
        notes: notes.trim().isEmpty ? null : notes,
      );
    } catch (_) {
      return null;
    }
  }

  String _weekdayVi(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  String _dateTimeFullStr(DateTime dt) {
    final dateStr = _dateOnly(dt);
    final timeStr = dt.toIso8601String().split('T')[1].substring(0, 5);
    return '$dateStr $timeStr (${_weekdayVi(dt)})';
  }

  /// Ép giá trị số do AI sinh về khoảng an toàn để không làm tràn cột numeric
  /// của DB (numeric(5,2) tối đa 999.99; numeric(7,2) tối đa 99999.99). AI đôi
  /// khi trả pace theo giây hoặc quãng đường theo mét -> nếu không kẹp lại sẽ
  /// gây lỗi 22003 và lịch tập âm thầm bị đánh dấu 'failed'. Trả null nếu không
  /// phải số hợp lệ.
  num? _safeNumeric(dynamic value, {required double max, double min = 0}) {
    final d = value is num ? value.toDouble() : double.tryParse('$value');
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d.clamp(min, max);
  }

  String? _safeTime(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;

    // Match HH:mm:ss or HH:mm
    final regExp = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$');
    if (regExp.hasMatch(s)) {
      return s;
    }

    // Match single hour (e.g. "6" or "18")
    final hourOnly = RegExp(r'^([0-1]?[0-9]|2[0-3])$');
    if (hourOnly.hasMatch(s)) {
      final hour = int.parse(s);
      final pad = hour.toString().padLeft(2, '0');
      return '$pad:00:00';
    }

    // Match pattern like "6 AM", "6PM", "06:00 PM"
    final amPm = RegExp(
      r'^([0-1]?[0-9])(:[0-5][0-9])?\s*(am|pm)$',
      caseSensitive: false,
    );
    final match = amPm.firstMatch(s);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = match.group(2) ?? ':00';
      final isPm = match.group(3)!.toLowerCase() == 'pm';
      if (isPm && hour < 12) {
        hour += 12;
      } else if (!isPm && hour == 12) {
        hour = 0;
      }
      final pad = hour.toString().padLeft(2, '0');
      return '$pad$minute:00';
    }

    final lower = s.toLowerCase();
    if (lower.contains('sáng') || lower.contains('morning')) {
      return '06:00:00';
    }
    if (lower.contains('chiều') ||
        lower.contains('tối') ||
        lower.contains('afternoon') ||
        lower.contains('evening')) {
      return '18:00:00';
    }

    return null;
  }

  double _safeRequiredNumber(double value, {required double max}) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError('Invalid workout number');
    }
    return value.clamp(0, max).toDouble();
  }

  Map<String, dynamic> _manualWorkoutValues(
    ManualWorkoutInput input, {
    String? scheduleId,
    String? userId,
    bool includeStatus = true,
    bool includeExtendedColumns = true,
  }) {
    final notes = input.notes?.trim();
    return {
      'schedule_id': ?scheduleId,
      'user_id': ?userId,
      'date': _dateOnly(input.date),
      if (includeExtendedColumns) 'start_time': input.startTime,
      'title': _cleanText(input.title),
      'description': includeExtendedColumns
          ? (notes?.isEmpty == true ? null : notes)
          : _legacyManualDescription(input),
      'target_distance_km': _safeRequiredNumber(
        input.targetDistanceKm,
        max: 99999.99,
      ),
      'target_duration_min': _safeRequiredNumber(
        input.targetDurationMin,
        max: 99999.99,
      ),
      if (includeExtendedColumns) 'workout_type': input.workoutType,
      if (includeExtendedColumns) 'source': 'manual',
      if (includeStatus) 'status': 'planned',
    };
  }

  Future<Map<String, dynamic>> _ensureEditableSchedule({
    required String userId,
    required ManualWorkoutInput input,
    bool includeSourceColumn = true,
  }) async {
    final activeSchedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeSchedule != null) return activeSchedule;

    return await _supabase
        .from('training_schedules')
        .insert({
          'user_id': userId,
          'title': 'Lịch tập thủ công',
          'goal_description': 'Các buổi tập do bạn tự tạo',
          'start_date': _dateOnly(input.date),
          'end_date': _dateOnly(input.date),
          'status': 'active',
          if (includeSourceColumn) 'source': 'manual',
        })
        .select()
        .single();
  }

  String _legacyManualDescription(ManualWorkoutInput input) {
    final metadata = jsonEncode({
      'source': 'manual',
      'start_time': input.startTime,
      'workout_type': input.workoutType,
    });
    final encoded = base64Url.encode(utf8.encode(metadata));
    final notes = input.notes?.trim() ?? '';
    return '$_manualMetadataPrefix$encoded\n$notes';
  }

  bool _isManualWorkoutSchemaMiss(Object error) {
    if (error is! PostgrestException || error.code != 'PGRST204') {
      return false;
    }
    return error.message.contains("'source'") ||
        error.message.contains("'start_time'") ||
        error.message.contains("'workout_type'");
  }

  Future<void> _expandScheduleRangeIfNeeded({
    required Map<String, dynamic> schedule,
    required DateTime earliestWorkoutDate,
    DateTime? latestWorkoutDate,
  }) async {
    final currentStart = schedule['start_date'] == null
        ? null
        : DateTime.tryParse(schedule['start_date'] as String);
    final currentEnd = schedule['end_date'] == null
        ? null
        : DateTime.tryParse(schedule['end_date'] as String);
    final latest = latestWorkoutDate ?? earliestWorkoutDate;

    final updates = <String, dynamic>{};
    if (currentStart == null || earliestWorkoutDate.isBefore(currentStart)) {
      updates['start_date'] = _dateOnly(earliestWorkoutDate);
    }
    if (currentEnd == null || latest.isAfter(currentEnd)) {
      updates['end_date'] = _dateOnly(latest);
    }
    if (updates.isNotEmpty) {
      await _supabase
          .from('training_schedules')
          .update(updates)
          .eq('id', schedule['id']);
    }
  }

  Future<void> createManualWorkout(ManualWorkoutInput input) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await _createManualWorkout(
        userId: user.id,
        input: input,
        includeExtendedColumns: true,
      );
    } catch (e) {
      if (!_isManualWorkoutSchemaMiss(e)) rethrow;
      await _createManualWorkout(
        userId: user.id,
        input: input,
        includeExtendedColumns: false,
      );
    }
  }

  Future<void> _createManualWorkout({
    required String userId,
    required ManualWorkoutInput input,
    required bool includeExtendedColumns,
  }) async {
    final schedule = await _ensureEditableSchedule(
      userId: userId,
      input: input,
      includeSourceColumn: includeExtendedColumns,
    );

    await _supabase
        .from('scheduled_workouts')
        .insert(
          _manualWorkoutValues(
            input,
            scheduleId: schedule['id'] as String,
            userId: userId,
            includeExtendedColumns: includeExtendedColumns,
          ),
        );

    await _expandScheduleRangeIfNeeded(
      schedule: schedule,
      earliestWorkoutDate: input.date,
    );
  }

  Future<void> updateManualWorkout({
    required String workoutId,
    required ManualWorkoutInput input,
  }) async {
    final workout = await _supabase
        .from('scheduled_workouts')
        .select()
        .eq('id', workoutId)
        .maybeSingle();
    if (workout == null) throw Exception('Workout not found');
    final normalizedWorkout = normalizeScheduledWorkout(workout);
    if (normalizedWorkout['source'] != 'manual') {
      throw Exception('Only manual workouts can be edited');
    }

    try {
      await _supabase
          .from('scheduled_workouts')
          .update(_manualWorkoutValues(input, includeStatus: false))
          .eq('id', workoutId);
    } catch (e) {
      if (!_isManualWorkoutSchemaMiss(e)) rethrow;
      await _supabase
          .from('scheduled_workouts')
          .update(
            _manualWorkoutValues(
              input,
              includeStatus: false,
              includeExtendedColumns: false,
            ),
          )
          .eq('id', workoutId);
    }

    final schedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('id', normalizedWorkout['schedule_id'])
        .single();
    await _expandScheduleRangeIfNeeded(
      schedule: schedule,
      earliestWorkoutDate: input.date,
    );

    // Cập nhật nhắc nhở nếu có để tránh lệch lịch khi sửa đổi buổi tập thủ công
    try {
      final existingReminderRow = await _supabase
          .from('run_reminders')
          .select()
          .eq('workout_id', workoutId)
          .maybeSingle();

      if (existingReminderRow != null) {
        final enabled = existingReminderRow['enabled'] as bool? ?? false;
        final leadMinutes =
            (existingReminderRow['lead_minutes'] as num?)?.toInt() ?? 10;
        final parts = input.startTime.split(':');
        final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 6) : 6;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

        final workoutAt = DateTime(
          input.date.year,
          input.date.month,
          input.date.day,
          hour,
          minute,
        );
        final scheduledFor = workoutAt.subtract(Duration(minutes: leadMinutes));
        final notificationId =
            (existingReminderRow['notification_id'] as num?)?.toInt() ?? 0;

        await _supabase
            .from('run_reminders')
            .update({
              'scheduled_for': scheduledFor.toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('workout_id', workoutId);

        // Đồng thời cập nhật hoặc hủy lịch thông báo local trên thiết bị
        final notificationService = NotificationService.instance;
        if (notificationService.supportsScheduledNotifications) {
          if (enabled) {
            final workoutTitle = input.title;
            final reminder = RunReminder(
              id: existingReminderRow['id'],
              userId: existingReminderRow['user_id'],
              workoutId: workoutId,
              leadMinutes: leadMinutes,
              enabled: enabled,
              notificationId: notificationId,
              scheduledFor: scheduledFor,
            );
            try {
              await notificationService.scheduleRunReminder(
                reminder: reminder,
                workoutTitle: workoutTitle,
              );
            } catch (e) {
              debugPrint('Failed to reschedule local notification: $e');
            }
          } else {
            await notificationService.cancelRunReminder(notificationId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating run reminder: $e');
    }
  }

  Future<void> deleteManualWorkout(String workoutId) async {
    final workout = await _supabase
        .from('scheduled_workouts')
        .select()
        .eq('id', workoutId)
        .maybeSingle();
    if (workout == null) return;
    final normalizedWorkout = normalizeScheduledWorkout(workout);
    if (normalizedWorkout['source'] != 'manual') {
      throw Exception('Only manual workouts can be deleted');
    }

    final scheduleId = normalizedWorkout['schedule_id'] as String;
    await _supabase.from('scheduled_workouts').delete().eq('id', workoutId);

    final remaining = await _supabase
        .from('scheduled_workouts')
        .select('id')
        .eq('schedule_id', scheduleId)
        .limit(1);
    final schedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('id', scheduleId)
        .maybeSingle();

    final isManualOnlySchedule =
        schedule?['source'] == 'manual' ||
        schedule?['goal_description'] == 'Các buổi tập do bạn tự tạo';
    if ((remaining as List).isEmpty && isManualOnlySchedule) {
      await _supabase.from('training_schedules').delete().eq('id', scheduleId);
    }
  }

  /// Bắt đầu tạo lịch tập ở CHẾ ĐỘ NỀN.
  ///
  /// Chèn ngay một bản ghi `training_schedules` ở trạng thái `generating`
  /// (thao tác nhanh, có await) rồi gọi AI bất đồng bộ mà KHÔNG chờ. Nhờ vậy
  /// người dùng có thể rời màn hình ngay; khi AI xong, bản ghi được cập nhật
  /// sang `active` (hoặc `failed` nếu lỗi) và trang Lịch tập sẽ hiển thị.
  Future<void> startPlanGeneration({
    required String goal,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    _ensureGeminiReady();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Dọn các placeholder generating/failed cũ để tránh tồn đọng.
    await _supabase
        .from('training_schedules')
        .delete()
        .eq('user_id', user.id)
        .inFilter('status', ['generating', 'failed', 'draft']);

    final placeholder = await _supabase
        .from('training_schedules')
        .insert({
          'user_id': user.id,
          'title': 'AI đang tạo lịch tập...',
          'goal_description': goal,
          'start_date': _dateOnly(startDate),
          if (endDate != null) 'end_date': _dateOnly(endDate),
          'status': 'generating',
        })
        .select()
        .single();

    final scheduleId = placeholder['id'] as String;

    // Fire-and-forget: chạy nền, không await để người dùng có thể rời màn hình.
    unawaited(
      _runGeneration(
        scheduleId: scheduleId,
        userId: user.id,
        goal: goal,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  Future<void> _runGeneration({
    required String scheduleId,
    required String userId,
    required String goal,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final planJson = await _generatePlanJson(goal, startDate, endDate);
      await _persistPlan(
        userId: userId,
        goal: goal,
        startDate: startDate,
        endDate: endDate,
        planJson: planJson,
        scheduleId: scheduleId,
      );
    } catch (e) {
      debugPrint('Background plan generation failed: $e');
      try {
        await _supabase
            .from('training_schedules')
            .update({'status': 'failed', 'error_message': e.toString()})
            .eq('id', scheduleId);
      } catch (_) {
        // Bỏ qua: không thể đánh dấu thất bại thì trang sẽ vẫn thấy 'generating'.
      }
    }
  }

  /// Tạo lịch tập đồng bộ (chờ AI xong rồi lưu). Dùng cho luồng chat HLV AI.
  Future<String> createGoalBasedPlan(
    String goalPrompt, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _ensureGeminiReady();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase
        .from('training_schedules')
        .delete()
        .eq('user_id', user.id)
        .eq('status', 'draft');

    final start = startDate ?? DateTime.now();
    final planJson = await _generatePlanJson(goalPrompt, start, endDate);
    return _persistPlan(
      userId: user.id,
      goal: goalPrompt,
      startDate: start,
      endDate: endDate,
      planJson: planJson,
    );
  }

  /// Gọi AI sinh JSON lịch tập dựa trên thể trạng + 5 hoạt động gần nhất.
  Future<Map<String, dynamic>> _generatePlanJson(
    String goal,
    DateTime startDate,
    DateTime? endDate,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final profile = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final recentActivities = await _supabase
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .order('started_at', ascending: false)
        .limit(5);
    String readinessContext = 'Dữ liệu readiness chưa sẵn sàng.';
    try {
      final readiness = await ReadinessService().getSnapshot();
      readinessContext =
          'Readiness: ${readiness.score}/100 (${readiness.status}); tải 7 ngày ${readiness.acuteLoad.toStringAsFixed(0)}, tải nền 28 ngày ${readiness.chronicLoad.toStringAsFixed(0)}, ACWR ${readiness.acwr?.toStringAsFixed(2) ?? 'chưa đủ dữ liệu'}, đau bất thường: ${readiness.painFlag ? 'có' : 'không'}. ${readiness.painFlag ? 'KHÔNG tạo bài chạy; ưu tiên nghỉ và khuyên tìm tư vấn y tế phù hợp.' : 'Nếu readiness thấp hoặc caution, giảm cường độ và xen ngày hồi phục.'}';
    } catch (_) {}

    // Truy vấn các buổi tập do người dùng tự đặt trong lịch đang hoạt động (active) mà sắp tới (ngày >= ngày bắt đầu).
    final activeSchedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    List<Map<String, dynamic>> manualWorkouts = [];
    if (activeSchedule != null) {
      final wList = await _supabase
          .from('scheduled_workouts')
          .select()
          .eq('schedule_id', activeSchedule['id'])
          .eq('source', 'manual')
          .gte('date', _dateOnly(startDate))
          .order('date', ascending: true);
      manualWorkouts = List<Map<String, dynamic>>.from(wList);
    }

    const systemPrompt = '''
Bạn là một Huấn luyện viên Chạy bộ Ảo chuyên nghiệp cho Runny AI.
Nhiệm vụ: tạo lịch tập chạy bộ thực tế, an toàn và đủ chi tiết dựa trên mục tiêu, thể trạng và lịch sử tập luyện của người dùng.

QUY TẮC OUTPUT BẮT BUỘC:
- Chỉ trả về MỘT JSON object hợp lệ. Không dùng Markdown, không giải thích ngoài JSON, không thêm comment.
- Tất cả khóa phải đúng như schema bên dưới. Không thêm khóa mới.
- Tất cả chuỗi hiển thị cho người dùng phải viết bằng tiếng Việt tự nhiên.
- Các số phải dùng đơn vị km, phút, phút/km. Không dùng mét, giây, giờ hoặc pace dạng "06:30".
- Nếu không chắc một giá trị số, hãy chọn giá trị bảo thủ và hợp lý thay vì để null.

QUY TẮC THỜI GIAN:
- Mỗi buổi tập dùng "day_offset" là SỐ NGÀY tính từ ngày bắt đầu; day_offset = 0 nghĩa là đúng ngày bắt đầu.
- Nếu người dùng có ngày kết thúc, mọi day_offset phải nằm trong khoảng cho phép và "weeks" phải khớp với khoảng thời gian đó.
- Nếu không có ngày kết thúc, tự chọn "weeks" hợp lý theo mục tiêu; ưu tiên 4-8 tuần cho mục tiêu phổ thông.
- Không tạo quá 1 buổi tập trong cùng một ngày, trừ khi đó là buổi manual đã được cung cấp.
- Mỗi tuần nên có ngày nhẹ hoặc nghỉ ngầm giữa các bài nặng; không xếp interval/tempo/long_run sát nhau nếu không cần thiết.

WORKOUT TYPE BẮT BUỘC:
- Với mọi buổi "source": "ai", "workout_type" CHỈ được là một trong 5 giá trị sau:
  "easy_run", "long_run", "interval", "tempo", "recovery".
- Tuyệt đối không sinh các giá trị khác như "endurance_run", "speed_run", "hill_run", "fartlek", "test_run", "race", "strength", "rest".
- Nếu bài là chạy bền/aerobic/base/endurance/steady nhẹ -> dùng "easy_run".
- Nếu bài là chạy dài cuối tuần hoặc dài nhất tuần -> dùng "long_run".
- Nếu bài là chạy nhanh, biến tốc, fartlek, hill repeats, VO2max, speed work -> dùng "interval".
- Nếu bài là tempo, threshold, kiểm tra thể lực, time trial ngắn, progression run -> dùng "tempo".
- Nếu bài là phục hồi, rất nhẹ sau bài nặng hoặc sau chạy dài -> dùng "recovery".

QUY TẮC NỘI DUNG BÀI TẬP:
- "title" ngắn gọn, dễ hiểu, không lặp lại workout_type dạng key kỹ thuật.
- "description" mô tả mục đích và cách chạy trong 1 câu ngắn; không nhồi quá nhiều chỉ dẫn.
- "target_distance_km" phải thực tế với lịch sử gần đây và mục tiêu.
- "target_duration_min" phải tương thích với distance và pace.
- "target_pace_min_per_km" là số thập phân phút/km, ví dụ 6.5 nghĩa là 6 phút 30 giây/km.
- "start_time" dùng định dạng HH:mm:ss, ưu tiên "06:00:00" hoặc "18:00:00" nếu người dùng không nói rõ.
- "source" của bài AI luôn là "ai".

ĐẶC BIỆT LƯU Ý VỀ CÁC BUỔI TẬP DO NGƯỜI DÙNG TỰ ĐẶT:
- Nếu ngữ cảnh có "LỊCH TẬP DO NGƯỜI DÙNG TỰ ĐẶT", bạn PHẢI đưa toàn bộ các buổi này vào mảng "workouts" của JSON.
- Giữ nguyên tuyệt đối mọi thông tin của các buổi manual: day_offset, ngày tập, cự ly, thời gian, tên, mô tả, start_time, workout_type.
- Với buổi manual, đặt "source": "manual" và copy "start_time", "workout_type" y hệt dữ liệu được cung cấp, kể cả khi workout_type không nằm trong enum AI.
- Không thay đổi, không xóa, không đổi ngày, không đổi cự ly của buổi manual.
- Chỉ phân bổ các buổi "source": "ai" xen kẽ quanh lịch manual để tránh trùng ngày và tránh quá tải.

Phản hồi PHẢI là JSON theo cấu trúc sau:
{
  "title": "Tên lịch tập",
  "target_distance_km": 5.0,
  "target_pace_min_per_km": 6.0,
  "weeks": 4,
  "workouts": [
    {
      "day_offset": 0,
      "title": "Chạy nhẹ nhàng",
      "description": "Chạy chậm để làm quen",
      "target_distance_km": 2.0,
      "target_duration_min": 15.0,
      "target_pace_min_per_km": 7.5,
      "source": "ai",
      "workout_type": "easy_run",
      "start_time": "18:00:00"
    },
    {
      "day_offset": 3,
      "title": "Chạy dài cuối tuần",
      "description": "Duy trì thể lực",
      "target_distance_km": 5.0,
      "target_duration_min": 35.0,
      "target_pace_min_per_km": 7.0,
      "source": "manual",
      "workout_type": "long_run",
      "start_time": "06:00:00"
    }
  ]
}
''';

    final durationConstraint = endDate != null
        ? 'Ngày kết thúc mong muốn: ${_dateOnly(endDate)} (${_weekdayVi(endDate)}) (khoảng ${endDate.difference(startDate).inDays} ngày kể từ ngày bắt đầu). Hãy phân bổ buổi tập trong khoảng này.'
        : 'Người dùng không chỉ định ngày kết thúc — hãy tự chọn số tuần ("weeks") hợp lý cho mục tiêu.';

    String manualWorkoutsSection = '';
    if (manualWorkouts.isNotEmpty) {
      manualWorkoutsSection =
          '\nLỊCH TẬP DO NGƯỜI DÙNG TỰ ĐẶT (BẮT BUỘC giữ nguyên, không thay đổi, chỉ sắp xếp các buổi tập AI xoay quanh các buổi này):\n';
      for (final mw in manualWorkouts) {
        final dateStr = mw['date'] as String;
        final dateVal = DateTime.tryParse(dateStr);
        final offset = dateVal != null
            ? dateVal.difference(startDate).inDays
            : 0;
        final targets = _formatWorkoutTargets(mw);
        manualWorkoutsSection +=
            '- day_offset $offset: ${mw['title']} (${_weekdayVi(dateVal ?? startDate)}, ngày $dateStr), mục tiêu [$targets], source: "manual", start_time: "${mw['start_time'] ?? ''}", workout_type: "${mw['workout_type'] ?? ''}"\n';
      }
    }

    final userContext =
        '''
Thời gian hiện tại: ${_dateTimeFullStr(DateTime.now())}
Mục tiêu người dùng: $goal
Ngày bắt đầu: ${_dateOnly(startDate)} (${_weekdayVi(startDate)})
$durationConstraint
Thông tin thể trạng: Giới tính ${_genderLabel(profile['gender'])}, Cân nặng ${profile['weight_kg']}kg, Chiều cao ${profile['height_cm']}cm, BMI ${profile['bmi']}, Nhịp tim tối đa ${profile['max_hr'] ?? 'chưa rõ'} bpm.
Dữ liệu ${recentActivities.length} buổi tập gần nhất: ${_summariseActivities(recentActivities)}
$readinessContext
$manualWorkoutsSection
''';

    return _gemini.generateStructuredResponse(
      userContext,
      systemPrompt,
      preferredProvider: 'groq',
      preferredModel: 'openai/gpt-oss-120b',
      responseFormat: _planResponseFormat,
    );
  }

  /// Chuyển giá trị giới tính chuẩn ('male'/'female'/'other') sang nhãn tiếng
  /// Việt để đưa vào prompt cho AI.
  String _genderLabel(dynamic gender) {
    switch (gender) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return 'chưa rõ';
    }
  }

  String _summariseActivities(List<dynamic> activities) {
    if (activities.isEmpty) return 'Chưa có dữ liệu hoạt động.';
    return activities
        .map((a) {
          final dist = (a['distance_km'] as num?)?.toDouble() ?? 0;
          final dur = (a['duration_min'] as num?)?.toDouble() ?? 0;
          final pace = dist > 0 ? (dur / dist).toStringAsFixed(2) : 'N/A';
          return 'Quãng đường: ${dist}km, Pace: $pace';
        })
        .join('; ');
  }

  /// Lưu lịch tập vào Supabase. Nếu [scheduleId] có giá trị thì cập nhật bản
  /// ghi placeholder (luồng nền); ngược lại chèn mới (luồng đồng bộ).
  Future<String> _persistPlan({
    required String userId,
    required String goal,
    required DateTime startDate,
    DateTime? endDate,
    required Map<String, dynamic> planJson,
    String? scheduleId,
  }) async {
    final weeks = (planJson['weeks'] as num?)?.toInt() ?? 4;
    final computedEnd = endDate ?? startDate.add(Duration(days: weeks * 7));

    // Truy vấn các buổi tập do người dùng tự đặt (manual) từ lịch hoạt động cũ trước khi lưu trữ
    final activeSchedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    List<Map<String, dynamic>> manualWorkouts = [];
    if (activeSchedule != null) {
      final wList = await _supabase
          .from('scheduled_workouts')
          .select()
          .eq('schedule_id', activeSchedule['id'])
          .eq('source', 'manual')
          .gte('date', _dateOnly(startDate))
          .order('date', ascending: true);
      manualWorkouts = List<Map<String, dynamic>>.from(wList);
    }

    final generatedWorkouts = planJson['workouts'];
    if ((generatedWorkouts is! List || generatedWorkouts.isEmpty) &&
        manualWorkouts.isEmpty) {
      throw const FormatException('AI không trả về buổi tập hợp lệ.');
    }

    final values = {
      'user_id': userId,
      'title': planJson['title'] ?? 'Lịch tập của bạn',
      'target_distance_km': _safeNumeric(
        planJson['target_distance_km'],
        max: 99999.99,
      ),
      'target_pace_min_per_km': _safeNumeric(
        planJson['target_pace_min_per_km'],
        max: 999.99,
      ),
      'goal_description': goal,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(computedEnd),
      'status': 'draft',
    };

    final Map<String, dynamic> schedule;
    if (scheduleId != null) {
      schedule = await _supabase
          .from('training_schedules')
          .update(values)
          .eq('id', scheduleId)
          .select()
          .single();
    } else {
      schedule = await _supabase
          .from('training_schedules')
          .insert(values)
          .select()
          .single();
    }

    final workouts = <Map<String, dynamic>>[];
    if (generatedWorkouts is List) {
      for (final w in generatedWorkouts) {
        final offset = (w['day_offset'] as num?)?.toInt() ?? 0;
        final dateStr = _dateOnly(startDate.add(Duration(days: offset)));

        // Kiểm tra xem ngày này có trùng với buổi tập thủ công nào không để tránh đè hoặc tạo trùng
        final isDuplicateOfManual = manualWorkouts.any(
          (mw) => mw['date'] == dateStr,
        );
        final isAiSourceManual = w['source'] == 'manual';

        if (isDuplicateOfManual || isAiSourceManual) {
          continue;
        }

        workouts.add({
          'schedule_id': schedule['id'],
          'user_id': userId,
          'date': dateStr,
          'title': w['title'] ?? 'Buổi tập',
          'description': w['description'],
          'target_distance_km': _safeNumeric(
            w['target_distance_km'],
            max: 99999.99,
          ),
          'target_duration_min': _safeNumeric(
            w['target_duration_min'],
            max: 99999.99,
          ),
          'target_pace_min_per_km': _safeNumeric(
            w['target_pace_min_per_km'],
            max: 999.99,
          ),
          'status': 'planned',
          'source': 'ai',
          'workout_type': w['workout_type'],
          'start_time': _safeTime(w['start_time']),
        });
      }
    }

    // Thêm lại các buổi tập do người dùng tự đặt gốc (giữ nguyên hoàn toàn thông tin)
    for (final mw in manualWorkouts) {
      workouts.add({
        'schedule_id': schedule['id'],
        'user_id': userId,
        'date': mw['date'],
        'title': mw['title'] ?? 'Buổi tập',
        'description': mw['description'],
        'target_distance_km': mw['target_distance_km'],
        'target_duration_min': mw['target_duration_min'],
        'target_pace_min_per_km': mw['target_pace_min_per_km'],
        'status': mw['status'] ?? 'planned',
        'source': 'manual',
        'workout_type': mw['workout_type'],
        'start_time': _safeTime(mw['start_time']),
        'activity_id': mw['activity_id'],
      });
    }

    if (workouts.isNotEmpty) {
      await _supabase.from('scheduled_workouts').insert(workouts);
    }
    TrainingRefreshService.instance.notifyTrainingChanged();
    return schedule['id'] as String;
  }

  /// Yêu cầu AI đề xuất tinh chỉnh các buổi tập SẮP TỚI dựa trên TẤT CẢ các buổi
  /// đã hoàn thành (đã gắn hoạt động thực tế) trong lịch hiện hành. KHÔNG ghi DB
  /// — trả về đề xuất để người dùng xem trước rồi xác nhận qua
  /// [applyPlanAdjustments].
  ///
  /// Ném [NoCompletedWorkoutException] nếu chưa có buổi tập nào hoàn thành, để UI
  /// nhắc người dùng tập ít nhất một buổi trước. Trả về đề xuất rỗng nếu không có
  /// lịch active hoặc không còn buổi 'planned' nào để điều chỉnh.
  Future<PlanAdjustmentProposal> proposePlanAdjustments() async {
    _ensureGeminiReady();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final readiness = await ReadinessService().getSnapshot();
    if (readiness.painFlag) {
      return const PlanAdjustmentProposal(
        summary:
            'Bạn đang báo đau bất thường. Hãy nghỉ tập, theo dõi triệu chứng và tìm tư vấn y tế phù hợp trước khi điều chỉnh lịch.',
        adjustments: [],
      );
    }

    final activeSchedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeSchedule == null) {
      return const PlanAdjustmentProposal(adjustments: []);
    }

    final workouts = List<Map<String, dynamic>>.from(
      await _supabase
          .from('scheduled_workouts')
          .select()
          .eq('schedule_id', activeSchedule['id'])
          .order('date', ascending: true),
    );

    // Căn cứ điều chỉnh = các buổi đã hoàn thành và có hoạt động thực tế đính kèm.
    final completed = workouts
        .where((w) => w['status'] == 'completed' && w['activity_id'] != null)
        .toList();
    if (completed.isEmpty) {
      throw NoCompletedWorkoutException();
    }

    final upcoming = workouts.where((w) => w['status'] == 'planned').toList();
    if (upcoming.isEmpty) {
      return const PlanAdjustmentProposal(adjustments: []);
    }

    // Nạp hoạt động thực tế của các buổi đã hoàn thành để so sánh kế hoạch vs thực tế.
    final activityIds = completed
        .map((w) => w['activity_id'] as String)
        .toList();
    final activities = List<Map<String, dynamic>>.from(
      await _supabase.from('activities').select().inFilter('id', activityIds),
    );
    final activityById = {for (final a in activities) a['id'] as String: a};

    const systemPrompt = '''
Bạn là Huấn luyện viên Chạy bộ Ảo. Dựa trên KẾT QUẢ THỰC TẾ của các buổi đã tập, hãy tinh chỉnh các buổi tập SẮP TỚI cho phù hợp thể trạng người dùng.
Nếu người dùng tập tốt hơn mục tiêu, có thể tăng nhẹ cường độ; nếu chưa đạt hoặc có dấu hiệu quá sức, hãy giảm cường độ hoặc dời lịch.

ĐẶC BIỆT LƯU Ý VỀ CÁC BUỔI TẬP DO NGƯỜI DÙNG TỰ ĐẶT (nguồn: do người dùng tự đặt (manual)):
- Bạn KHÔNG ĐƯỢC PHÉP thay đổi bất kỳ thông tin nào của các buổi tập do người dùng tự đặt (không thay đổi ngày, quãng đường, mục tiêu và KHÔNG đưa workout_id của chúng vào danh sách "adjustments").
- Bạn chỉ được phép điều chỉnh các buổi tập do AI tạo (nguồn: do AI tự động tạo (ai)) xoay quanh các buổi tập của người dùng để phân bổ hợp lý, tránh trùng lặp ngày tập hoặc quá tải.

CHỈ điều chỉnh các buổi do AI tạo có trong danh sách "buổi tập sắp tới" và CHỈ dùng đúng workout_id được cung cấp. Buổi nào đã hợp lý hoặc là buổi của người dùng thì bỏ qua (không đưa vào danh sách adjustments).
Phản hồi của bạn PHẢI là một đối tượng JSON:
{
  "summary": "Nhận xét tổng quan ngắn gọn về tiến độ và hướng điều chỉnh",
  "adjustments": [
    {
      "workout_id": "uuid của buổi sắp tới do AI tạo",
      "new_date": "YYYY-MM-DD",
      "new_target_distance_km": 5.0,
      "reason": "Giải thích ngắn gọn lý do điều chỉnh buổi này"
    }
  ]
}
''';

    final completedSummary = completed
        .map((w) {
          final act = activityById[w['activity_id']];
          final planned = _formatWorkoutTargets(w);
          final actual = act == null ? 'không rõ' : _formatActivityActual(act);
          return '- ${w['title']} (${w['date']}): kế hoạch [$planned], thực tế [$actual]';
        })
        .join('\n');

    final upcomingSummary = upcoming
        .map((w) {
          final isManual = w['source'] == 'manual';
          final sourceLabel = isManual
              ? 'do người dùng tự đặt (manual)'
              : 'do AI tự động tạo (ai)';
          return '- id ${w['id']}: ${w['title']} vào ${w['date']}, mục tiêu [${_formatWorkoutTargets(w)}], nguồn: $sourceLabel';
        })
        .join('\n');

    final context =
        '''
Thời gian hiện tại: ${_dateTimeFullStr(DateTime.now())}
Lịch tập hiện tại: ${activeSchedule['title']}
Readiness hiện tại: ${readiness.score}/100 (${readiness.status}); tải 7 ngày ${readiness.acuteLoad.toStringAsFixed(0)}, tải nền 28 ngày ${readiness.chronicLoad.toStringAsFixed(0)}, ACWR ${readiness.acwr?.toStringAsFixed(2) ?? 'chưa đủ dữ liệu'}. Khi readiness thấp/caution hoặc ACWR cao, ưu tiên giảm quãng đường hoặc dời buổi AI để có ngày hồi phục.
Các buổi đã hoàn thành (kế hoạch vs thực tế):
$completedSummary

Các buổi tập sắp tới (có thể điều chỉnh):
$upcomingSummary
''';

    final json = await _gemini.generateStructuredResponse(
      context,
      systemPrompt,
    );

    final byId = {for (final w in workouts) w['id'] as String: w};
    final adjustments = <WorkoutAdjustment>[];
    final rawList = json['adjustments'];
    if (rawList is List) {
      for (final adj in rawList) {
        if (adj is! Map) continue;
        final wid = adj['workout_id']?.toString();
        final current = wid == null ? null : byId[wid];
        // Bỏ qua id AI bịa ra hoặc buổi không còn ở trạng thái 'planned'.
        if (current == null || current['status'] != 'planned') continue;
        // BỎ QUA nếu buổi tập này là do người dùng tự đặt (source == 'manual')
        if (current['source'] == 'manual') continue;
        final item = WorkoutAdjustment(
          workoutId: wid!,
          title: current['title'] as String? ?? 'Buổi tập',
          currentDate: current['date'] as String?,
          currentDistanceKm: current['target_distance_km'] as num?,
          newDate: _validDate(adj['new_date']),
          newDistanceKm: _safeNumeric(
            adj['new_target_distance_km'],
            max: 99999.99,
          ),
          reason: adj['reason']?.toString() ?? '',
        );
        // Chỉ giữ buổi có thay đổi thực sự để preview không hiện mục thừa.
        if (item.hasChange) adjustments.add(item);
      }
    }

    return PlanAdjustmentProposal(
      summary: json['summary']?.toString(),
      adjustments: adjustments,
    );
  }

  /// Ghi các điều chỉnh đã được người dùng xác nhận vào DB.
  Future<void> applyPlanAdjustments(List<WorkoutAdjustment> adjustments) async {
    for (final adj in adjustments) {
      await _supabase
          .from('scheduled_workouts')
          .update({
            if (adj.newDate != null) 'date': adj.newDate,
            if (adj.newDistanceKm != null)
              'target_distance_km': adj.newDistanceKm,
            if (adj.reason.isNotEmpty)
              'description': 'Đã điều chỉnh bởi AI: ${adj.reason}',
          })
          .eq('id', adj.workoutId);
    }
    TrainingRefreshService.instance.notifyTrainingChanged();
  }

  /// Ghép mục tiêu của một buổi tập thành chuỗi ngắn cho prompt (an toàn với null).
  String _formatWorkoutTargets(Map<String, dynamic> w) {
    final dist = (w['target_distance_km'] as num?)?.toDouble();
    final dur = (w['target_duration_min'] as num?)?.toDouble();
    final pace = (w['target_pace_min_per_km'] as num?)?.toDouble();
    final parts = <String>[];
    if (dist != null) parts.add('${dist}km');
    if (dur != null) parts.add('$dur phút');
    if (pace != null) parts.add('pace $pace');
    return parts.isEmpty ? 'không rõ' : parts.join(', ');
  }

  /// Ghép kết quả thực tế của một hoạt động; pace tính AN TOÀN (không chia cho 0).
  String _formatActivityActual(Map<String, dynamic> a) {
    final dist = (a['distance_km'] as num?)?.toDouble() ?? 0;
    final dur = (a['duration_min'] as num?)?.toDouble() ?? 0;
    final pace = dist > 0 ? (dur / dist).toStringAsFixed(2) : 'N/A';
    final hr = a['avg_hr'];
    final hrPart = hr == null ? '' : ', nhịp tim ${hr}bpm';
    final cadence = a['avg_cadence'];
    final cadencePart = cadence == null ? '' : ', guồng chân ${cadence}spm';
    return '${dist}km, $dur phút, pace $pace$hrPart$cadencePart';
  }

  /// Xác thực chuỗi ngày do AI trả về; trả null nếu không phải ngày hợp lệ.
  String? _validDate(dynamic value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value.trim());
    return parsed == null ? null : _dateOnly(parsed);
  }

  Future<String> analyzeActivity(String activityId) async {
    _ensureGeminiReady();
    final activity = await _supabase
        .from('activities')
        .select()
        .eq('id', activityId)
        .single();

    final systemPrompt =
        'Bạn là Huấn luyện viên Chạy bộ Ảo. Hãy phân tích buổi tập này và đưa ra nhận xét ngắn gọn, khích lệ.';
    final name = activity['name'] ?? activity['notes'] ?? 'Buổi tập';
    final rawNotes = activity['notes'];
    final notes = rawNotes != null && rawNotes != name ? rawNotes : 'Không có';
    final startedAtRaw = activity['started_at'];
    final startedAtStr = startedAtRaw != null
        ? _dateTimeFullStr(DateTime.parse(startedAtRaw).toLocal())
        : 'chưa rõ';
    final cadence = activity['avg_cadence'];
    final cadenceStr = cadence != null ? ', guồng chân $cadence spm' : '';
    final userPrompt =
        'Thời gian hiện tại: ${_dateTimeFullStr(DateTime.now())}\n'
        'Buổi tập "$name" diễn ra lúc $startedAtStr: ${activity['distance_km']}km, thời gian ${activity['duration_min']} phút, nhịp tim ${activity['avg_hr']} bpm$cadenceStr. Ghi chú: $notes';

    final insight = await _gemini.generateResponse(
      userPrompt,
      history: [
        {'role': 'system', 'content': systemPrompt},
      ],
    );

    await _supabase.from('ai_insights').insert({
      'user_id': activity['user_id'],
      'activity_id': activityId,
      'content': insight,
    });

    return insight;
  }
}
