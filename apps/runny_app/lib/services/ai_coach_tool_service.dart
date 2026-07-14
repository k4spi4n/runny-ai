import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_coach_tool_models.dart';

/// Các tool dữ liệu dành riêng cho HLV AI. Tool đọc có thể chạy ngay; tool sửa
/// chỉ tạo đề xuất. [applyAction] chỉ được UI gọi sau thao tác xác nhận rõ ràng.
class AICoachToolService {
  AICoachToolService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const List<Map<String, dynamic>> definitions = [
    {
      'type': 'function',
      'function': {
        'name': 'get_scheduled_workouts',
        'description':
            'Lấy các buổi tập của người dùng để trả lời, phân tích hoặc chuẩn bị đề xuất chỉnh sửa. Hãy gọi tool này trước khi đề xuất sửa buổi tập.',
        'parameters': {
          'type': 'object',
          'properties': {
            'date_from': {
              'type': 'string',
              'description': 'Ngày bắt đầu YYYY-MM-DD; mặc định hôm nay.',
            },
            'date_to': {
              'type': 'string',
              'description': 'Ngày kết thúc YYYY-MM-DD; mặc định sau 14 ngày.',
            },
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 20},
          },
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_meal_logs',
        'description':
            'Lấy nhật ký bữa ăn để trả lời, phân tích hoặc chuẩn bị đề xuất chỉnh sửa. Hãy gọi tool này trước khi đề xuất sửa bữa ăn.',
        'parameters': {
          'type': 'object',
          'properties': {
            'date_from': {
              'type': 'string',
              'description': 'Ngày bắt đầu YYYY-MM-DD; mặc định hôm nay.',
            },
            'date_to': {
              'type': 'string',
              'description': 'Ngày kết thúc YYYY-MM-DD; mặc định hôm nay.',
            },
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 30},
          },
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'propose_workout_update',
        'description':
            'Tạo thẻ đề xuất chỉnh sửa một buổi tập. Không tự lưu. Người dùng phải xác nhận trên thẻ tương tác. Chỉ gọi sau khi đã lấy đúng buổi tập.',
        'parameters': {
          'type': 'object',
          'properties': {
            'workout_id': {'type': 'string'},
            'title': {'type': 'string'},
            'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
            'start_time': {'type': 'string', 'description': 'HH:mm'},
            'description': {'type': 'string'},
            'target_distance_km': {'type': 'number', 'minimum': 0},
            'target_duration_min': {'type': 'number', 'minimum': 0},
            'workout_type': {'type': 'string'},
          },
          'required': ['workout_id'],
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'propose_meal_update',
        'description':
            'Tạo thẻ đề xuất chỉnh sửa một món trong nhật ký ăn uống. Không tự lưu. Người dùng phải xác nhận trên thẻ tương tác. Chỉ gọi sau khi đã lấy đúng bữa ăn.',
        'parameters': {
          'type': 'object',
          'properties': {
            'meal_id': {'type': 'string'},
            'food_name': {'type': 'string'},
            'calories': {'type': 'number', 'minimum': 0},
            'protein': {'type': 'number', 'minimum': 0},
            'carbs': {'type': 'number', 'minimum': 0},
            'fat': {'type': 'number', 'minimum': 0},
            'amount': {'type': 'number', 'minimum': 0},
            'unit': {'type': 'string'},
            'meal_type': {
              'type': 'string',
              'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
            },
            'consumed_at': {
              'type': 'string',
              'description': 'Thời điểm ISO-8601 có múi giờ.',
            },
          },
          'required': ['meal_id'],
          'additionalProperties': false,
        },
      },
    },
  ];

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Bạn cần đăng nhập để dùng tool HLV.');
    return id;
  }

  Future<CoachToolExecution> execute(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    switch (name) {
      case 'get_scheduled_workouts':
        return CoachToolExecution(output: await _getWorkouts(arguments));
      case 'get_meal_logs':
        return CoachToolExecution(output: await _getMeals(arguments));
      case 'propose_workout_update':
        return _proposeWorkout(arguments);
      case 'propose_meal_update':
        return _proposeMeal(arguments);
      default:
        return CoachToolExecution(
          output: {'error': 'Tool không được hỗ trợ: $name'},
        );
    }
  }

  Future<Map<String, dynamic>> _getWorkouts(Map<String, dynamic> args) async {
    final today = DateTime.now();
    final from = _dateArg(args['date_from'], today);
    final to = _dateArg(args['date_to'], today.add(const Duration(days: 14)));
    final limit = _limit(args['limit'], 10, 20);
    final rows = await _supabase
        .from('scheduled_workouts')
        .select(
          'id,date,start_time,title,description,target_distance_km,'
          'target_duration_min,target_pace_min_per_km,workout_type,status,source',
        )
        .eq('user_id', _userId)
        .gte('date', _dateOnly(from))
        .lte('date', _dateOnly(to))
        .order('date')
        .order('start_time')
        .limit(limit);
    return {'workouts': rows, 'count': (rows as List).length};
  }

  Future<Map<String, dynamic>> _getMeals(Map<String, dynamic> args) async {
    final today = DateTime.now();
    final from = _dateArg(args['date_from'], today);
    final to = _dateArg(args['date_to'], today);
    final limit = _limit(args['limit'], 20, 30);
    final start = DateTime(from.year, from.month, from.day).toIso8601String();
    final end = DateTime(to.year, to.month, to.day + 1).toIso8601String();
    final rows = await _supabase
        .from('meal_logs')
        .select(
          'id,food_name,calories,protein,carbs,fat,amount,unit,'
          'meal_type,consumed_at',
        )
        .eq('user_id', _userId)
        .gte('consumed_at', start)
        .lt('consumed_at', end)
        .order('consumed_at', ascending: false)
        .limit(limit);
    return {'meals': rows, 'count': (rows as List).length};
  }

  Future<CoachToolExecution> _proposeWorkout(Map<String, dynamic> args) async {
    final id = args['workout_id'] as String?;
    if (id == null || id.isEmpty) {
      return const CoachToolExecution(output: {'error': 'Thiếu workout_id.'});
    }
    final row = await _supabase
        .from('scheduled_workouts')
        .select(
          'id,date,start_time,title,description,target_distance_km,'
          'target_duration_min,workout_type,status',
        )
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) {
      return const CoachToolExecution(
        output: {'error': 'Không tìm thấy buổi tập thuộc người dùng.'},
      );
    }
    if (row['status'] == 'completed') {
      return const CoachToolExecution(
        output: {
          'error':
              'Buổi tập đã hoàn thành nên không thể sửa lịch; hãy thảo luận về hoạt động thực tế thay vì thay đổi kế hoạch.',
        },
      );
    }
    final changes = _validatedChanges(args, const {
      'title',
      'date',
      'start_time',
      'description',
      'target_distance_km',
      'target_duration_min',
      'workout_type',
    });
    _removeUnchanged(changes, row);
    if (changes.isEmpty) {
      return const CoachToolExecution(
        output: {'error': 'Đề xuất chưa có trường nào thay đổi.'},
      );
    }
    final action = CoachInteractiveAction(
      kind: 'workout_update',
      targetId: id,
      title: row['title'] as String? ?? 'Buổi tập',
      before: Map<String, dynamic>.from(row),
      changes: changes,
    );
    return CoachToolExecution(
      output: {
        'status': 'pending_confirmation',
        'message': 'Đã tạo thẻ đề xuất; chưa lưu thay đổi.',
        'proposal': action.toJson(),
      },
      action: action,
    );
  }

  Future<CoachToolExecution> _proposeMeal(Map<String, dynamic> args) async {
    final id = args['meal_id'] as String?;
    if (id == null || id.isEmpty) {
      return const CoachToolExecution(output: {'error': 'Thiếu meal_id.'});
    }
    final row = await _supabase
        .from('meal_logs')
        .select(
          'id,food_name,calories,protein,carbs,fat,amount,unit,'
          'meal_type,consumed_at',
        )
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) {
      return const CoachToolExecution(
        output: {'error': 'Không tìm thấy bữa ăn thuộc người dùng.'},
      );
    }
    final changes = _validatedChanges(args, const {
      'food_name',
      'calories',
      'protein',
      'carbs',
      'fat',
      'amount',
      'unit',
      'meal_type',
      'consumed_at',
    });
    _removeUnchanged(changes, row);
    if (changes.isEmpty) {
      return const CoachToolExecution(
        output: {'error': 'Đề xuất chưa có trường nào thay đổi.'},
      );
    }
    final action = CoachInteractiveAction(
      kind: 'meal_update',
      targetId: id,
      title: row['food_name'] as String? ?? 'Bữa ăn',
      before: Map<String, dynamic>.from(row),
      changes: changes,
    );
    return CoachToolExecution(
      output: {
        'status': 'pending_confirmation',
        'message': 'Đã tạo thẻ đề xuất; chưa lưu thay đổi.',
        'proposal': action.toJson(),
      },
      action: action,
    );
  }

  Future<void> applyAction(CoachInteractiveAction action) async {
    if (!action.isPending) return;
    final table = switch (action.kind) {
      'workout_update' => 'scheduled_workouts',
      'meal_update' => 'meal_logs',
      _ => throw Exception('Loại chỉnh sửa không được hỗ trợ.'),
    };
    await _supabase
        .from(table)
        .update(action.changes)
        .eq('id', action.targetId)
        .eq('user_id', _userId)
        .select('id')
        .single();
  }

  Map<String, dynamic> _validatedChanges(
    Map<String, dynamic> args,
    Set<String> allowed,
  ) {
    final changes = <String, dynamic>{};
    for (final key in allowed) {
      if (!args.containsKey(key) || args[key] == null) continue;
      final value = args[key];
      if (value is String && value.trim().isEmpty) continue;
      if (value is num && (!value.isFinite || value < 0)) continue;
      if (key == 'meal_type' &&
          !const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(value)) {
        continue;
      }
      if (key == 'date' &&
          (value is! String || DateTime.tryParse(value) == null)) {
        continue;
      }
      if (key == 'consumed_at' &&
          (value is! String || DateTime.tryParse(value) == null)) {
        continue;
      }
      if (key == 'start_time' &&
          (value is! String ||
              !RegExp(
                r'^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$',
              ).hasMatch(value))) {
        continue;
      }
      changes[key] = value is String ? value.trim() : value;
    }
    return changes;
  }

  void _removeUnchanged(
    Map<String, dynamic> changes,
    Map<String, dynamic> before,
  ) {
    changes.removeWhere((key, value) {
      final oldValue = before[key];
      if (oldValue is num && value is num) return oldValue == value;
      return oldValue?.toString() == value?.toString();
    });
  }

  DateTime _dateArg(dynamic value, DateTime fallback) =>
      value is String ? (DateTime.tryParse(value) ?? fallback) : fallback;

  int _limit(dynamic value, int fallback, int max) =>
      value is num ? value.toInt().clamp(1, max) : fallback;

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
