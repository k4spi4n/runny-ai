import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gemini_service.dart';

class TrainingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GeminiService _gemini = GeminiService();

  void _ensureGeminiReady() {
    if (!_gemini.isConfigured) {
      throw Exception('OPENROUTER_API_KEY not found in .env');
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().split('T')[0];

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
    unawaited(_runGeneration(
      scheduleId: scheduleId,
      userId: user.id,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
    ));
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
        ? 'Ngày kết thúc mong muốn: ${_dateOnly(endDate)} (khoảng ${endDate.difference(startDate).inDays} ngày kể từ ngày bắt đầu). Hãy phân bổ buổi tập trong khoảng này.'
        : 'Người dùng không chỉ định ngày kết thúc — hãy tự chọn số tuần ("weeks") hợp lý cho mục tiêu.';

    final userContext = '''
Mục tiêu người dùng: $goal
Ngày bắt đầu: ${_dateOnly(startDate)}
$durationConstraint
Thông tin thể trạng: Cân nặng ${profile['weight_kg']}kg, Chiều cao ${profile['height_cm']}cm, BMI ${profile['bmi']}, Nhịp tim tối đa ${profile['max_hr'] ?? 'chưa rõ'} bpm.
Dữ liệu ${recentActivities.length} buổi tập gần nhất: ${_summariseActivities(recentActivities)}
''';

    return _gemini.generateStructuredResponse(userContext, systemPrompt);
  }

  String _summariseActivities(List<dynamic> activities) {
    if (activities.isEmpty) return 'Chưa có dữ liệu hoạt động.';
    return activities.map((a) {
      final dist = (a['distance_km'] as num?)?.toDouble() ?? 0;
      final dur = (a['duration_min'] as num?)?.toDouble() ?? 0;
      final pace = dist > 0 ? (dur / dist).toStringAsFixed(2) : 'N/A';
      return 'Quãng đường: ${dist}km, Pace: $pace';
    }).join('; ');
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
      'target_distance_km':
          _safeNumeric(planJson['target_distance_km'], max: 99999.99),
      'target_pace_min_per_km':
          _safeNumeric(planJson['target_pace_min_per_km'], max: 999.99),
      'goal_description': goal,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(computedEnd),
      'status': 'active',
    };

    // Lưu trữ (archive) các lịch active cũ để chỉ còn 1 lịch hiện hành.
    await _supabase
        .from('training_schedules')
        .update({'status': 'archived'})
        .eq('user_id', userId)
        .eq('status', 'active');

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
        'target_distance_km':
            _safeNumeric(w['target_distance_km'], max: 99999.99),
        'target_duration_min':
            _safeNumeric(w['target_duration_min'], max: 99999.99),
        'target_pace_min_per_km':
            _safeNumeric(w['target_pace_min_per_km'], max: 999.99),
        'status': 'planned',
      };
    }).toList();

    await _supabase.from('scheduled_workouts').insert(workouts);
  }

  Future<void> adjustPlanDynamically() async {
    _ensureGeminiReady();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Fetch active schedule and its workouts
    final activeSchedule = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

    if (activeSchedule == null) return;

    final workouts = await _supabase
        .from('scheduled_workouts')
        .select()
        .eq('schedule_id', activeSchedule['id'])
        .order('date', ascending: true);

    // 2. Fetch recent activities
    final recentActivities = await _supabase
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .order('started_at', ascending: false)
        .limit(3);

    // 3. Prepare prompt for adjustment
    const systemPrompt = '''
Bạn là Huấn luyện viên Chạy bộ Ảo. Hãy phân tích tiến độ tập luyện và điều chỉnh lịch tập nếu cần.
Nếu người dùng bỏ lỡ buổi tập hoặc tập quá sức, hãy dời lịch hoặc giảm cường độ.
Phản hồi của bạn PHẢI là một đối tượng JSON chứa danh sách các điều chỉnh:
{
  "adjustments": [
    {
      "workout_id": "uuid",
      "new_date": "YYYY-MM-DD",
      "new_target_distance_km": 5.0,
      "reason": "Giải thích lý do điều chỉnh"
    }
  ]
}
''';

    final context =
        '''
Lịch tập hiện tại: ${activeSchedule['title']}
Các buổi tập sắp tới: ${workouts.where((w) => w['status'] == 'planned').map((w) => '${w['id']}: ${w['title']} vào ${w['date']}').join('; ')}
Các hoạt động thực tế gần đây: ${recentActivities.map((a) => 'Ngày: ${a['started_at']}, KM: ${a['distance_km']}, Pace: ${(a['duration_min'] / a['distance_km']).toStringAsFixed(2)}').join('; ')}
''';

    // 4. Call Gemini
    final adjustmentJson = await _gemini.generateStructuredResponse(
      context,
      systemPrompt,
    );

    // 5. Apply adjustments
    for (final adj in adjustmentJson['adjustments']) {
      await _supabase
          .from('scheduled_workouts')
          .update({
            if (adj['new_date'] != null) 'date': adj['new_date'],
            if (adj['new_target_distance_km'] != null)
              'target_distance_km': adj['new_target_distance_km'],
            'description': 'Đã điều chỉnh bởi AI: ${adj['reason']}',
          })
          .eq('id', adj['workout_id']);
    }
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
    final userPrompt =
        'Buổi tập: ${activity['distance_km']}km, thời gian ${activity['duration_min']} phút, nhịp tim ${activity['avg_hr']} bpm. Ghi chú: ${activity['notes']}';

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
