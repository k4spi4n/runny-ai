import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import 'gemini_service.dart';

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

  const _LegacyManualMetadata({
    this.startTime,
    this.workoutType,
    this.notes,
  });
}

class TrainingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GeminiService _gemini = GeminiService();
  static const String _manualMetadataPrefix = 'RUNNY_MANUAL_WORKOUT_V1:';

  void _ensureGeminiReady() {
    if (!_gemini.isConfigured) {
      throw Exception('OPENROUTER_API_KEY not found in .env');
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().split('T')[0];

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

  static _LegacyManualMetadata? _readLegacyManualMetadata(
    String? description,
  ) {
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
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (userId != null) 'user_id': userId,
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
    required DateTime workoutDate,
  }) async {
    final currentStart = schedule['start_date'] == null
        ? null
        : DateTime.tryParse(schedule['start_date'] as String);
    final currentEnd = schedule['end_date'] == null
        ? null
        : DateTime.tryParse(schedule['end_date'] as String);

    final updates = <String, dynamic>{};
    if (currentStart == null || workoutDate.isBefore(currentStart)) {
      updates['start_date'] = _dateOnly(workoutDate);
    }
    if (currentEnd == null || workoutDate.isAfter(currentEnd)) {
      updates['end_date'] = _dateOnly(workoutDate);
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

    await _supabase.from('scheduled_workouts').insert(
          _manualWorkoutValues(
            input,
            scheduleId: schedule['id'] as String,
            userId: userId,
            includeExtendedColumns: includeExtendedColumns,
          ),
        );

    await _expandScheduleRangeIfNeeded(
      schedule: schedule,
      workoutDate: input.date,
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
      workoutDate: input.date,
    );
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
    await _supabase
        .from('scheduled_workouts')
        .delete()
        .eq('id', workoutId);

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
        .inFilter('status', ['generating', 'failed']);

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
            .update({'status': 'failed'})
            .eq('id', scheduleId);
      } catch (_) {
        // Bỏ qua: không thể đánh dấu thất bại thì trang sẽ vẫn thấy 'generating'.
      }
    }
  }

  /// Tạo lịch tập đồng bộ (chờ AI xong rồi lưu). Dùng cho luồng chat HLV AI.
  Future<void> createGoalBasedPlan(
    String goalPrompt, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _ensureGeminiReady();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final start = startDate ?? DateTime.now();
    final planJson = await _generatePlanJson(goalPrompt, start, endDate);
    await _persistPlan(
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

    const systemPrompt = '''
Bạn là một Huấn luyện viên Chạy bộ Ảo chuyên nghiệp.
Nhiệm vụ của bạn là tạo ra một lịch tập luyện chi tiết dựa trên mục tiêu, thể trạng và lịch sử tập luyện của người dùng.
Mỗi buổi tập dùng "day_offset" là SỐ NGÀY tính từ ngày bắt đầu (day_offset = 0 nghĩa là đúng ngày bắt đầu).
Nếu người dùng có ngày kết thúc, toàn bộ buổi tập phải nằm trong khoảng từ ngày bắt đầu đến ngày kết thúc và trường "weeks" phải khớp với khoảng thời gian đó.
Nếu không có ngày kết thúc, hãy tự chọn số tuần ("weeks") hợp lý cho mục tiêu.
Phản hồi của bạn PHẢI là một đối tượng JSON có cấu trúc như sau:
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
      "target_pace_min_per_km": 7.5
    }
  ]
}
''';

    final durationConstraint = endDate != null
        ? 'Ngày kết thúc mong muốn: ${_dateOnly(endDate)} (${_weekdayVi(endDate)}) (khoảng ${endDate.difference(startDate).inDays} ngày kể từ ngày bắt đầu). Hãy phân bổ buổi tập trong khoảng này.'
        : 'Người dùng không chỉ định ngày kết thúc — hãy tự chọn số tuần ("weeks") hợp lý cho mục tiêu.';

    final userContext =
        '''
Thời gian hiện tại: ${_dateTimeFullStr(DateTime.now())}
Mục tiêu người dùng: $goal
Ngày bắt đầu: ${_dateOnly(startDate)} (${_weekdayVi(startDate)})
$durationConstraint
Thông tin thể trạng: Giới tính ${_genderLabel(profile['gender'])}, Cân nặng ${profile['weight_kg']}kg, Chiều cao ${profile['height_cm']}cm, BMI ${profile['bmi']}, Nhịp tim tối đa ${profile['max_hr'] ?? 'chưa rõ'} bpm.
Dữ liệu ${recentActivities.length} buổi tập gần nhất: ${_summariseActivities(recentActivities)}
''';

    return _gemini.generateStructuredResponse(userContext, systemPrompt);
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
  Future<void> _persistPlan({
    required String userId,
    required String goal,
    required DateTime startDate,
    DateTime? endDate,
    required Map<String, dynamic> planJson,
    String? scheduleId,
  }) async {
    final weeks = (planJson['weeks'] as num?)?.toInt() ?? 4;
    final computedEnd = endDate ?? startDate.add(Duration(days: weeks * 7));

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
      'status': 'active',
    };

    // Lưu trữ (archive) các lịch cũ (active/completed) để chỉ còn 1 lịch hiện hành.
    await _supabase
        .from('training_schedules')
        .update({'status': 'archived'})
        .eq('user_id', userId)
        .inFilter('status', ['active', 'completed']);

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

    final workouts = (planJson['workouts'] as List).map((w) {
      final offset = (w['day_offset'] as num?)?.toInt() ?? 0;
      return {
        'schedule_id': schedule['id'],
        'user_id': userId,
        'date': _dateOnly(startDate.add(Duration(days: offset))),
        'title': w['title'],
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
      };
    }).toList();

    await _supabase.from('scheduled_workouts').insert(workouts);
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
CHỈ điều chỉnh các buổi có trong danh sách "buổi tập sắp tới" và CHỈ dùng đúng workout_id được cung cấp. Buổi nào đã hợp lý thì bỏ qua (không cần liệt kê).
Phản hồi của bạn PHẢI là một đối tượng JSON:
{
  "summary": "Nhận xét tổng quan ngắn gọn về tiến độ và hướng điều chỉnh",
  "adjustments": [
    {
      "workout_id": "uuid của buổi sắp tới",
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
          return '- id ${w['id']}: ${w['title']} vào ${w['date']}, mục tiêu [${_formatWorkoutTargets(w)}]';
        })
        .join('\n');

    final context =
        '''
Thời gian hiện tại: ${_dateTimeFullStr(DateTime.now())}
Lịch tập hiện tại: ${activeSchedule['title']}
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
    final startedAtStr = startedAtRaw != null ? _dateTimeFullStr(DateTime.parse(startedAtRaw).toLocal()) : 'chưa rõ';
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
