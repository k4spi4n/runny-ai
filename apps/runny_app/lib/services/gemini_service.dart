import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiService {
  final String _modelName;
  final bool _shouldUseProxy = true;

  GeminiService()
      : _modelName = dotenv.env['OPENROUTER_MODEL'] ?? 'meta-llama/llama-3.3-70b-instruct:free' {
    debugPrint('GeminiService: Using Supabase Edge Function proxy for OpenRouter calls.');
  }

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
          'model': _modelName,
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
          'model': _modelName,
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
