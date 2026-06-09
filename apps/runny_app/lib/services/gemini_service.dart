import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  final String? _apiKey;
  final String _modelName;

  GeminiService()
      : _apiKey = dotenv.env['OPENROUTER_API_KEY'],
        _modelName = dotenv.env['OPENROUTER_MODEL'] ?? 'meta-llama/llama-3.3-70b-instruct:free' {
    if (!isConfigured) {
      debugPrint('GeminiService (OpenRouter) disabled: OPENROUTER_API_KEY missing');
    } else {
      debugPrint('GeminiService (OpenRouter) initialized with model: $_modelName');
    }
  }

  bool get isConfigured => _apiKey != null && _apiKey.isNotEmpty;

  Future<String> generateResponse(
    String prompt, {
    List<Map<String, String>>? history,
  }) async {
    if (!isConfigured) {
      throw Exception('OPENROUTER_API_KEY not found in .env');
    }

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

      final response = await http.post(
        Uri.parse('${dotenv.env['OPENROUTER_BASE_URL'] ?? 'https://openrouter.ai/api/v1'}/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/k4spi4n/runny-ai',
          'X-Title': 'Runny AI',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': messages,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenRouter API error: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Invalid response structure from OpenRouter: $decoded');
      }

      final message = choices[0]['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null) {
        throw Exception('No message content returned from OpenRouter');
      }

      return content;
    } catch (e) {
      debugPrint('OpenRouter error: $e');
      throw Exception('Error calling OpenRouter: $e');
    }
  }

  Future<Map<String, dynamic>> generateStructuredResponse(
    String prompt,
    String systemPrompt,
  ) async {
    if (!isConfigured) {
      throw Exception('OPENROUTER_API_KEY not found in .env');
    }

    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final response = await http.post(
        Uri.parse('${dotenv.env['OPENROUTER_BASE_URL'] ?? 'https://openrouter.ai/api/v1'}/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/k4spi4n/runny-ai',
          'X-Title': 'Runny AI',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': messages,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenRouter API error: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Invalid response structure from OpenRouter: $decoded');
      }

      final message = choices[0]['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null) {
        throw Exception('No message content returned from OpenRouter');
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
      debugPrint('OpenRouter structured error: $e');
      throw Exception('Error calling OpenRouter for structured response: $e');
    }
  }
}
