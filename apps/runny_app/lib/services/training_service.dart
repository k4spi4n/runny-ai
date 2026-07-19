import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import '../models/run_reminder_model.dart';
import 'edge_function_result.dart';
import 'ai_service.dart';
import 'notification_service.dart';
import 'paywall_exception.dart';
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

abstract interface class TrainingPlanJobClient {
  String? get currentUserId;

  Future<EdgeFunctionResult> enqueue(Map<String, Object?> body);
}

class SupabaseTrainingPlanJobClient implements TrainingPlanJobClient {
  SupabaseTrainingPlanJobClient(this._supabase);

  final SupabaseClient _supabase;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<EdgeFunctionResult> enqueue(Map<String, Object?> body) async {
    final response = await _supabase.functions.invoke(
      'training-plan',
      body: body,
    );
    return EdgeFunctionResult(status: response.status, data: response.data);
  }
}

class TrainingService {
  TrainingService({
    SupabaseClient? supabase,
    TrainingPlanJobClient? planJobClient,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _planJobClient =
           planJobClient ??
           SupabaseTrainingPlanJobClient(supabase ?? Supabase.instance.client);

  final SupabaseClient _supabase;
  final TrainingPlanJobClient _planJobClient;
  final AiService _ai = AiService();
  static const String _manualMetadataPrefix = 'RUNNY_MANUAL_WORKOUT_V1:';

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
    final rows = List<Map<String, dynamic>>.from(
      await _supabase.rpc(
            'reschedule_scheduled_workout',
            params: {
              'p_workout_id': workoutId,
              'p_new_date': _dateOnly(workoutAt),
              'p_start_time':
                  '${workoutAt.hour.toString().padLeft(2, '0')}:'
                  '${workoutAt.minute.toString().padLeft(2, '0')}:00',
              'p_shift_following': shiftFollowingWorkouts,
            },
          )
          as List,
    );
    final rescheduledWorkouts = rows.map((row) {
      final date = DateTime.parse(row['workout_date'] as String);
      return RescheduledWorkout(
        workoutId: row['workout_id'] as String,
        workoutAt: _withStartTime(date, row['workout_start_time']?.toString()),
      );
    }).toList();
    TrainingRefreshService.instance.notifyTrainingChanged();
    return rescheduledWorkouts;
  }

  void _ensureAiReady() {
    if (!_ai.isConfigured) {
      throw Exception('AI gateway is not configured');
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
      if (includeExtendedColumns)
        'target_pace_min_per_km': input.targetPaceMinPerKm == null
            ? null
            : _safeRequiredNumber(input.targetPaceMinPerKm!, max: 999.99),
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

  /// Enqueue a durable server-side plan job and return its placeholder schedule.
  Future<String> startPlanGeneration({
    required String goal,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (_planJobClient.currentUserId == null) {
      throw Exception('User not logged in');
    }
    final random = Random.secure();
    final nonce = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final idempotencyKey =
        'plan:${DateTime.now().microsecondsSinceEpoch}:$nonce';
    try {
      final response = await _planJobClient.enqueue({
        'idempotency_key': idempotencyKey,
        'goal': goal,
        'start_date': _dateOnly(startDate),
        if (endDate != null) 'end_date': _dateOnly(endDate),
      });
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (response.status != 200 && response.status != 202) {
        final message = data['error']?.toString() ?? 'Unable to create plan.';
        if (PaywallException.isUpgradeSignal(response.status, data)) {
          throw PaywallException(message);
        }
        throw Exception(message);
      }
      final scheduleId = data['schedule_id']?.toString();
      if (scheduleId == null || scheduleId.isEmpty) {
        throw Exception('Training plan service returned no schedule.');
      }
      TrainingRefreshService.instance.notifyTrainingChanged();
      return scheduleId;
    } on FunctionException catch (error) {
      if (PaywallException.isUpgradeSignal(error.status, error.details)) {
        final details = error.details;
        final message = details is Map && details['error'] is String
            ? details['error'] as String
            : 'Tính năng này dành cho gói trả phí.';
        throw PaywallException(message);
      }
      rethrow;
    } catch (e) {
      debugPrint('Training plan enqueue failed: $e');
      rethrow;
    }
  }

  /// Compatibility entry point; generation is still queued on the server.
  Future<String> createGoalBasedPlan(
    String goalPrompt, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return startPlanGeneration(
      goal: goalPrompt,
      startDate: startDate ?? DateTime.now(),
      endDate: endDate,
    );
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
    _ensureAiReady();
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

    final json = await _ai.generateStructuredResponse(
      context,
      systemPrompt,
      feature: AiFeature.trainingAdjustment,
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
    if (adjustments.isEmpty) return;
    await _supabase.rpc(
      'apply_training_plan_adjustments',
      params: {
        'p_adjustments': adjustments
            .map(
              (adjustment) => {
                'workout_id': adjustment.workoutId,
                'new_date': adjustment.newDate,
                'new_distance_km': adjustment.newDistanceKm,
                'reason': adjustment.reason,
              },
            )
            .toList(),
      },
    );
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
    _ensureAiReady();
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

    final insight = await _ai.generateResponse(
      '$systemPrompt\n\n$userPrompt',
      feature: AiFeature.activityInsight,
    );

    await _supabase.from('ai_insights').insert({
      'user_id': activity['user_id'],
      'activity_id': activityId,
      'content': insight,
    });

    return insight;
  }
}
