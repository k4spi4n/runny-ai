import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import 'gemini_service.dart';

class TrainingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GeminiService _gemini = GeminiService();

  Future<void> createGoalBasedPlan(String goalPrompt) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Fetch user profile and recent activities for context
    final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
    final recentActivities = await _supabase
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .order('started_at', ascending: false)
        .limit(5);

    // 2. Prepare system prompt for Gemini
    const systemPrompt = '''
Bạn là một Huấn luyện viên Chạy bộ Ảo chuyên nghiệp. 
Nhiệm vụ của bạn là tạo ra một lịch tập luyện chi tiết dựa trên mục tiêu của người dùng.
Phản hồi của bạn PHẢI là một đối tượng JSON có cấu trúc như sau:
{
  "title": "Tên lịch tập",
  "target_distance_km": 5.0,
  "target_pace_min_per_km": 6.0,
  "weeks": 4,
  "workouts": [
    {
      "day_offset": 1, 
      "title": "Chạy nhẹ nhàng",
      "description": "Chạy chậm để làm quen",
      "target_distance_km": 2.0,
      "target_duration_min": 15.0,
      "target_pace_min_per_km": 7.5
    }
  ]
}
''';

    final userContext = '''
Mục tiêu người dùng: $goalPrompt
Thông tin người dùng: Cân nặng ${profile['weight_kg']}kg, BMI ${profile['bmi']}.
Dữ liệu 5 buổi tập gần nhất: ${recentActivities.map((a) => 'Quãng đường: ${a['distance_km']}km, Pace: ${(a['duration_min'] / a['distance_km']).toStringAsFixed(2)}').join('; ')}
''';

    // 3. Call Gemini
    final planJson = await _gemini.generateStructuredResponse(userContext, systemPrompt);

    // 4. Save to Supabase
    final schedule = await _supabase.from('training_schedules').insert({
      'user_id': user.id,
      'title': planJson['title'],
      'target_distance_km': planJson['target_distance_km'],
      'target_pace_min_per_km': planJson['target_pace_min_per_km'],
      'goal_description': goalPrompt,
      'start_date': DateTime.now().toIso8601String().split('T')[0],
      'end_date': DateTime.now()
          .add(Duration(days: (planJson['weeks'] as int) * 7))
          .toIso8601String()
          .split('T')[0],
      'status': 'active',
    }).select().single();

    final workouts = (planJson['workouts'] as List).map((w) {
      return {
        'schedule_id': schedule['id'],
        'user_id': user.id,
        'date': DateTime.now()
            .add(Duration(days: w['day_offset'] as int))
            .toIso8601String()
            .split('T')[0],
        'title': w['title'],
        'description': w['description'],
        'target_distance_km': w['target_distance_km'],
        'target_duration_min': w['target_duration_min'],
        'target_pace_min_per_km': w['target_pace_min_per_km'],
        'status': 'planned',
      };
    }).toList();

    await _supabase.from('scheduled_workouts').insert(workouts);
  }

  Future<void> adjustPlanDynamically() async {
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

    final context = '''
Lịch tập hiện tại: ${activeSchedule['title']}
Các buổi tập sắp tới: ${workouts.where((w) => w['status'] == 'planned').map((w) => '${w['id']}: ${w['title']} vào ${w['date']}').join('; ')}
Các hoạt động thực tế gần đây: ${recentActivities.map((a) => 'Ngày: ${a['started_at']}, KM: ${a['distance_km']}, Pace: ${(a['duration_min'] / a['distance_km']).toStringAsFixed(2)}').join('; ')}
''';

    // 4. Call Gemini
    final adjustmentJson = await _gemini.generateStructuredResponse(context, systemPrompt);

    // 5. Apply adjustments
    for (final adj in adjustmentJson['adjustments']) {
      await _supabase.from('scheduled_workouts').update({
        if (adj['new_date'] != null) 'date': adj['new_date'],
        if (adj['new_target_distance_km'] != null) 'target_distance_km': adj['new_target_distance_km'],
        'description': 'Đã điều chỉnh bởi AI: ${adj['reason']}',
      }).eq('id', adj['workout_id']);
    }
  }

  Future<String> analyzeActivity(String activityId) async {
    final activity = await _supabase.from('activities').select().eq('id', activityId).single();
    
    final systemPrompt = 'Bạn là Huấn luyện viên Chạy bộ Ảo. Hãy phân tích buổi tập này và đưa ra nhận xét ngắn gọn, khích lệ.';
    final userPrompt = 'Buổi tập: ${activity['distance_km']}km, thời gian ${activity['duration_min']} phút, nhịp tim ${activity['avg_hr']} bpm. Ghi chú: ${activity['notes']}';
    
    final insight = await _gemini.generateResponse(userPrompt, history: [{'role': 'system', 'content': systemPrompt}]);
    
    await _supabase.from('ai_insights').insert({
      'user_id': activity['user_id'],
      'activity_id': activityId,
      'content': insight,
    });
    
    return insight;
  }
}

