import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_http_stream.dart';
import '../models/ai_coach_tool_models.dart';
import '../models/coach_persona.dart';
import 'paywall_exception.dart';

class GeminiService {
  static const String _coachGroqModel = 'openai/gpt-oss-120b';
  final String _modelName;
  final List<String> _modelList;
  static _CoachPreference? _cachedCoachPreference;

  GeminiService()
    : _modelName = dotenv.env['OPENROUTER_MODEL'] ?? 'openai/gpt-oss-120b',
      _modelList = _parseModels(dotenv.env['OPENROUTER_MODELS']) {
    debugPrint(
      'GeminiService: Using Supabase Edge Function AI proxy (Groq primary, Cerebras/OpenRouter fallback).',
    );
  }

  /// Tach chuoi model phan tach boi dau phay (vd: "a:free, b:free") thanh danh sach.
  static List<String> _parseModels(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Phan model cho body request: uu tien danh sach fallback (mang `models`)
  /// neu duoc cau hinh, nguoc lai gui `model` don le (Edge Function se tu bao fallback).
  Map<String, dynamic> get _modelPayload =>
      _modelList.isNotEmpty ? {'models': _modelList} : {'model': _modelName};

  bool get isConfigured => true;

  Future<_CoachPreference> _loadCoachPreference() async {
    final user = Supabase.instance.client.auth.currentUser;
    final cached = _cachedCoachPreference;
    if (cached != null &&
        cached.userId == user?.id &&
        DateTime.now().difference(cached.loadedAt) <
            const Duration(minutes: 5)) {
      return cached;
    }

    if (user == null) {
      return _CoachPreference.defaultValue();
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('coach_name, coach_persona')
          .eq('id', user.id)
          .maybeSingle();
      final preference = _CoachPreference.fromProfile(data, user.id);
      _cachedCoachPreference = preference;
      return preference;
    } catch (e) {
      debugPrint('Load coach preference failed: $e');
      return _CoachPreference.defaultValue();
    }
  }

  static void clearCoachPreferenceCache() {
    _cachedCoachPreference = null;
  }

  Future<void> _addCoachPersonaMessage(
    List<Map<String, dynamic>> messages,
  ) async {
    final preference = await _loadCoachPreference();
    messages.insert(0, {
      'role': 'system',
      'content':
          'Bạn là ${preference.coachName}, HLV chạy bộ AI cá nhân của người dùng. '
          'Tính cách huấn luyện: ${preference.persona.promptDescription} '
          'Có thể dùng Markdown đơn giản để câu trả lời dễ đọc. '
          'Không tự nhận là bác sĩ, không chẩn đoán bệnh, không ép tập quá sức. '
          'Khi bàn về dữ liệu buổi tập hoặc bữa ăn cụ thể, hãy dùng tool đọc dữ liệu thay vì đoán. '
          'Khi người dùng muốn sửa, chỉ dùng tool tạo đề xuất và nói rõ thay đổi chưa được lưu cho tới khi họ xác nhận trên thẻ tương tác.',
    });
  }

  /// Trích thông báo lỗi thân thiện từ phản hồi/exception của Edge Function.
  /// Edge Function trả về `{ "error": "..." }` (tiếng Việt) cho các lỗi guardrail
  /// (401 chưa đăng nhập, 400 đầu vào không hợp lệ, 429 quá nhiều yêu cầu).
  String _extractError(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
      if (details is String && details.trim().isNotEmpty) {
        return details;
      }
      return 'Lỗi máy chủ AI (mã ${error.status}).';
    }
    return error.toString();
  }

  String _errorFromData(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // bỏ qua, dùng fallback bên dưới
    }
    return 'Lỗi máy chủ AI.';
  }

  Future<String> generateResponse(
    String prompt, {
    List<Map<String, String>>? history,
    String? preferredProvider,
    String? preferredModel,
    bool includeCoachPersona = false,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[];

      if (history != null) {
        for (final m in history) {
          final role = m['role'] == 'model'
              ? 'assistant'
              : (m['role'] ?? 'user');
          messages.add({'role': role, 'content': m['content'] ?? ''});
        }
      }

      messages.add({'role': 'user', 'content': prompt});
      if (includeCoachPersona) {
        await _addCoachPersonaMessage(messages);
      }

      final providerPayload = <String, dynamic>{};
      if (preferredProvider != null) {
        providerPayload['provider_preference'] = preferredProvider;
      }
      if (preferredModel != null) {
        providerPayload['preferred_model'] = preferredModel;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'openrouter',
        body: {..._modelPayload, ...providerPayload, 'messages': messages},
      );

      if (response.status != 200) {
        if (PaywallException.isUpgradeSignal(response.status, response.data)) {
          throw PaywallException(_errorFromData(response.data));
        }
        throw Exception(_errorFromData(response.data));
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : (response.data as Map);
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception(
          'Invalid response structure from OpenRouter proxy: $decoded',
        );
      }

      final message = choices[0]['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null) {
        throw Exception('No message content returned from OpenRouter proxy');
      }

      return content;
    } catch (e) {
      debugPrint('OpenRouter proxy call failed: $e');
      if (e is FunctionException) {
        if (PaywallException.isUpgradeSignal(e.status, e.details)) {
          throw PaywallException(_extractError(e));
        }
        throw Exception(_extractError(e));
      }
      rethrow;
    }
  }

  /// Hoàn tất một lượt chat có OpenAI-compatible function tools. Các tool đọc
  /// được thực thi ở client bằng session Supabase hiện tại; tool chỉnh sửa chỉ
  /// trả về [CoachInteractiveAction] để UI yêu cầu người dùng xác nhận.
  Future<CoachTurnResult> generateCoachTurn(
    String prompt, {
    List<Map<String, dynamic>>? history,
    required List<Map<String, dynamic>> tools,
    required Future<CoachToolExecution> Function(
      String name,
      Map<String, dynamic> arguments,
    )
    executeTool,
  }) async {
    final messages = <Map<String, dynamic>>[];
    if (history != null) {
      for (final item in history) {
        final role = item['role'] == 'model'
            ? 'assistant'
            : (item['role'] as String? ?? 'user');
        if (role != 'user' && role != 'assistant' && role != 'system') {
          continue;
        }
        messages.add({
          'role': role,
          'content': item['content'] as String? ?? '',
        });
      }
    }
    messages.add({'role': 'user', 'content': prompt});
    await _addCoachPersonaMessage(messages);

    final actions = <CoachInteractiveAction>[];
    try {
      // Một lượt thường là: đọc dữ liệu -> đề xuất -> giải thích. Giới hạn để
      // tránh model lặp tool vô tận nếu provider trả kết quả bất thường.
      for (var round = 0; round < 5; round++) {
        final response = await Supabase.instance.client.functions.invoke(
          'openrouter',
          body: {
            ..._modelPayload,
            'provider_preference': 'groq',
            'preferred_model': _coachGroqModel,
            'messages': messages,
            'tools': tools,
            'tool_choice': 'auto',
          },
        );
        if (response.status != 200) {
          if (PaywallException.isUpgradeSignal(
            response.status,
            response.data,
          )) {
            throw PaywallException(_errorFromData(response.data));
          }
          throw Exception(_errorFromData(response.data));
        }

        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final choices = decoded is Map ? decoded['choices'] as List? : null;
        if (choices == null || choices.isEmpty) {
          throw Exception('Phản hồi tool của HLV không đúng định dạng.');
        }
        final rawMessage = (choices.first as Map)['message'];
        if (rawMessage is! Map) {
          throw Exception('Phản hồi tool của HLV thiếu message.');
        }
        final message = Map<String, dynamic>.from(rawMessage);
        final content = message['content'] as String? ?? '';
        final rawCalls = message['tool_calls'] as List?;
        if (rawCalls == null || rawCalls.isEmpty) {
          return CoachTurnResult(
            content: content.trim().isEmpty
                ? (actions.isEmpty
                      ? 'Mình chưa có đủ dữ liệu để trả lời.'
                      : 'Mình đã tạo đề xuất bên dưới. Thay đổi chỉ được lưu khi bạn xác nhận.')
                : content,
            actions: actions,
          );
        }

        // Provider cần nhận lại nguyên tool_calls trong message assistant để
        // ghép đúng tool_call_id ở vòng tiếp theo.
        messages.add({
          'role': 'assistant',
          'content': content,
          'tool_calls': rawCalls,
        });
        for (final rawCall in rawCalls) {
          if (rawCall is! Map) continue;
          CoachToolExecution execution;
          CoachToolCall call;
          try {
            call = CoachToolCall.fromJson(Map<String, dynamic>.from(rawCall));
            execution = await executeTool(call.name, call.arguments);
          } catch (e) {
            final raw = Map<String, dynamic>.from(rawCall);
            call = CoachToolCall(
              id: raw['id'] as String? ?? '',
              name: '',
              arguments: const {},
              raw: raw,
            );
            execution = CoachToolExecution(
              output: {'error': 'Không thể thực thi tool: $e'},
            );
          }
          if (execution.action != null) {
            final action = execution.action!;
            final existingIndex = actions.indexWhere(
              (item) =>
                  item.kind == action.kind && item.targetId == action.targetId,
            );
            if (existingIndex < 0) {
              actions.add(action);
            } else {
              actions[existingIndex] = action;
            }
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'name': call.name,
            'content': jsonEncode(execution.output),
          });
        }
      }
      return CoachTurnResult(
        content: actions.isEmpty
            ? 'HLV chưa thể hoàn tất yêu cầu tool. Vui lòng thử diễn đạt cụ thể hơn.'
            : 'Mình đã chuẩn bị đề xuất bên dưới. Hãy kiểm tra trước khi xác nhận.',
        actions: actions,
      );
    } catch (e) {
      debugPrint('AI coach tool call failed: $e');
      if (e is FunctionException) {
        if (PaywallException.isUpgradeSignal(e.status, e.details)) {
          throw PaywallException(_extractError(e));
        }
        throw Exception(_extractError(e));
      }
      rethrow;
    }
  }

  /// Phiên bản streaming của [generateResponse]: gọi thẳng Edge Function
  /// `openrouter` với `stream: true` và phát từng đoạn văn bản (`delta.content`)
  /// ngay khi tới, để UI hiển thị chữ chạy dần thay vì đợi phản hồi đầy đủ.
  ///
  /// SSE (OpenAI-compatible): mỗi sự kiện là một dòng `data: {json}`; kết thúc
  /// bằng `data: [DONE]`. Nếu server trả mã != 200 thì body là JSON lỗi
  /// (guardrail/paywall) — gom lại và ném đúng loại ngoại lệ như bản không stream.
  Stream<String> streamResponse(
    String prompt, {
    List<Map<String, String>>? history,
    bool includeCoachPersona = false,
  }) async* {
    final messages = <Map<String, dynamic>>[];
    if (history != null) {
      for (final m in history) {
        final role = m['role'] == 'model' ? 'assistant' : (m['role'] ?? 'user');
        messages.add({'role': role, 'content': m['content'] ?? ''});
      }
    }
    messages.add({'role': 'user', 'content': prompt});
    if (includeCoachPersona) {
      await _addCoachPersonaMessage(messages);
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null || anonKey == null) {
      throw Exception('Thiếu cấu hình SUPABASE_URL / SUPABASE_ANON_KEY.');
    }
    final url = Uri.parse('$supabaseUrl/functions/v1/openrouter');
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? anonKey;

    final result = await postStreaming(url, {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'apikey': anonKey,
    }, jsonEncode({..._modelPayload, 'messages': messages, 'stream': true}));

    if (result.statusCode != 200) {
      final errText = await _collectText(result.stream);
      if (PaywallException.isUpgradeSignal(result.statusCode, errText)) {
        throw PaywallException(_errorFromData(errText));
      }
      throw Exception(_errorFromData(errText));
    }

    final lines = result.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        final choices = decoded['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices[0] as Map)['delta'] as Map?;
        final content = delta?['content'];
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {
        // Bỏ qua dòng không phải JSON hợp lệ (comment/keep-alive của SSE).
      }
    }
  }

  Future<String> _collectText(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<Map<String, dynamic>> generateStructuredResponse(
    String prompt,
    String systemPrompt, {
    String? preferredProvider,
    String? preferredModel,
    Map<String, dynamic>? responseFormat,
  }) async {
    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final response = await Supabase.instance.client.functions.invoke(
        'openrouter',
        body: {
          ..._modelPayload,
          'provider_preference': ?preferredProvider,
          'preferred_model': ?preferredModel,
          'messages': messages,
          'response_format': responseFormat ?? {'type': 'json_object'},
        },
      );

      if (response.status != 200) {
        if (PaywallException.isUpgradeSignal(response.status, response.data)) {
          throw PaywallException(_errorFromData(response.data));
        }
        throw Exception(_errorFromData(response.data));
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : (response.data as Map);
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception(
          'Invalid response structure from OpenRouter proxy: $decoded',
        );
      }

      final message = choices[0]['message'] as Map?;
      final content = message?['content'] as String? ?? '';
      if (content.isEmpty) {
        throw Exception('No message content returned from OpenRouter proxy');
      }

      // Cleanup code blocks if returned
      var cleanedContent = content.trim();
      if (cleanedContent.startsWith('```')) {
        final lastBackticks = cleanedContent.lastIndexOf('```');
        if (lastBackticks > 0) {
          cleanedContent = cleanedContent.substring(0, lastBackticks);
        }
        cleanedContent = cleanedContent
            .replaceFirst(RegExp(r'^```json\s*'), '')
            .trim();
      }

      return jsonDecode(cleanedContent);
    } catch (e) {
      debugPrint('OpenRouter proxy structured call failed: $e');
      if (e is FunctionException) {
        if (PaywallException.isUpgradeSignal(e.status, e.details)) {
          throw PaywallException(_extractError(e));
        }
        throw Exception(_extractError(e));
      }
      rethrow;
    }
  }
}

class _CoachPreference {
  final String? userId;
  final String coachName;
  final CoachPersona persona;
  final DateTime loadedAt;

  const _CoachPreference({
    required this.userId,
    required this.coachName,
    required this.persona,
    required this.loadedAt,
  });

  factory _CoachPreference.defaultValue() => _CoachPreference(
    userId: null,
    coachName: 'Runny',
    persona: CoachPersona.calm,
    loadedAt: DateTime.now(),
  );

  factory _CoachPreference.fromProfile(
    Map<String, dynamic>? data,
    String userId,
  ) {
    final rawName = (data?['coach_name'] as String?)?.trim();
    return _CoachPreference(
      userId: userId,
      coachName: rawName == null || rawName.isEmpty ? 'Runny' : rawName,
      persona: CoachPersona.byId(data?['coach_persona'] as String?),
      loadedAt: DateTime.now(),
    );
  }
}
