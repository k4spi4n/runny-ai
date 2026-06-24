import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiService {
  final String _modelName;
  final List<String> _modelList;

  GeminiService()
      : _modelName = dotenv.env['OPENROUTER_MODEL'] ?? 'meta-llama/llama-3.3-70b-instruct:free',
        _modelList = _parseModels(dotenv.env['OPENROUTER_MODELS']) {
    debugPrint('GeminiService: Using Supabase Edge Function proxy for OpenRouter calls.');
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

  Future<String> generateResponse(
    String prompt, {
    List<Map<String, String>>? history,
  }) async {
    try {
      final messages = <Map<String, String>>[];

      if (history != null) {
        for (final m in history) {
          final role = m['role'] == 'model' ? 'assistant' : (m['role'] ?? 'user');
          messages.add({
            'role': role,
            'content': m['content'] ?? '',
          });
        }
      }

      messages.add({
        'role': 'user',
        'content': prompt,
      });

      final response = await Supabase.instance.client.functions.invoke(
        'openrouter',
        body: {
          ..._modelPayload,
          'messages': messages,
        },
      );

      if (response.status != 200) {
        throw Exception('OpenRouter proxy error: ${response.status} ${response.data}');
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : (response.data as Map);
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Invalid response structure from OpenRouter proxy: $decoded');
      }

      final message = choices[0]['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null) {
        throw Exception('No message content returned from OpenRouter proxy');
      }

      return content;
    } catch (e) {
      debugPrint('OpenRouter proxy call failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateStructuredResponse(
    String prompt,
    String systemPrompt,
  ) async {
    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final response = await Supabase.instance.client.functions.invoke(
        'openrouter',
        body: {
          ..._modelPayload,
          'messages': messages,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.status != 200) {
        throw Exception('OpenRouter proxy error: ${response.status} ${response.data}');
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : (response.data as Map);
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Invalid response structure from OpenRouter proxy: $decoded');
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
        cleanedContent = cleanedContent.replaceFirst(RegExp(r'^```json\s*'), '').trim();
      }

      return jsonDecode(cleanedContent);
    } catch (e) {
      debugPrint('OpenRouter proxy structured call failed: $e');
      rethrow;
    }
  }
}
