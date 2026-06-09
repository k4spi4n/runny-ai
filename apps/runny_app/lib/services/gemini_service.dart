import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiService {
  final String? _apiKey;
  final String _modelName;
  final bool _shouldUseProxy;

  // Fallback Gemini API properties
  final String _geminiFallbackKey;
  final String _geminiFallbackModel;

  GeminiService()
      : _apiKey = dotenv.env['OPENROUTER_API_KEY'],
        _modelName = dotenv.env['OPENROUTER_MODEL'] ?? 'meta-llama/llama-3.3-70b-instruct:free',
        _shouldUseProxy = kIsWeb || dotenv.env['OPENROUTER_API_KEY'] == null || dotenv.env['OPENROUTER_API_KEY']!.isEmpty,
        _geminiFallbackKey = dotenv.env['GEMINI_API_KEY'] ?? '',
        _geminiFallbackModel = dotenv.env['GEMINI_MODEL'] ?? 'gemini-3.1-flash-lite' {
    if (_shouldUseProxy) {
      debugPrint('GeminiService: Using Supabase Edge Function proxy for OpenRouter calls.');
    } else {
      debugPrint('GeminiService (OpenRouter) initialized with model: $_modelName');
    }
    debugPrint('GeminiService: Fallback Gemini API configured with model: $_geminiFallbackModel');
  }

  bool get isConfigured =>
      _shouldUseProxy ||
      (_apiKey != null && _apiKey.isNotEmpty) ||
      _geminiFallbackKey.isNotEmpty;

  Future<String> generateResponse(
    String prompt, {
    List<Map<String, String>>? history,
  }) async {
    if (!isConfigured) {
      throw Exception('GeminiService is not configured (neither OpenRouter nor Gemini fallback API is available)');
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

      if (_shouldUseProxy) {
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
      } else {
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
      }
    } catch (e) {
      debugPrint('OpenRouter call failed: $e. Falling back to Google Gemini API...');
      try {
        return await _fallbackToGeminiResponse(prompt, history);
      } catch (geminiError) {
        debugPrint('Gemini API fallback failed: $geminiError');
        throw Exception('Error calling OpenRouter: $e. Fallback to Gemini failed: $geminiError');
      }
    }
  }

  Future<Map<String, dynamic>> generateStructuredResponse(
    String prompt,
    String systemPrompt,
  ) async {
    if (!isConfigured) {
      throw Exception('GeminiService is not configured (neither OpenRouter nor Gemini fallback API is available)');
    }

    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      String content;

      if (_shouldUseProxy) {
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
        content = message?['content'] as String? ?? '';
        if (content.isEmpty) {
          throw Exception('No message content returned from OpenRouter proxy');
        }
      } else {
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
        content = message?['content'] as String? ?? '';
        if (content.isEmpty) {
          throw Exception('No message content returned from OpenRouter');
        }
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
      debugPrint('OpenRouter structured call failed: $e. Falling back to Google Gemini API...');
      try {
        return await _fallbackToGeminiStructuredResponse(prompt, systemPrompt);
      } catch (geminiError) {
        debugPrint('Gemini API fallback structured failed: $geminiError');
        throw Exception('Error calling OpenRouter for structured response: $e. Fallback to Gemini failed: $geminiError');
      }
    }
  }

  // --- Gemini API Direct Fallback ---

  Future<String> _fallbackToGeminiResponse(
    String prompt,
    List<Map<String, String>>? history,
  ) async {
    if (_geminiFallbackKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    debugPrint('Calling Gemini API fallback ($_geminiFallbackModel)...');
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiFallbackModel:generateContent?key=$_geminiFallbackKey',
    );

    final geminiContents = <Map<String, dynamic>>[];
    if (history != null) {
      for (final m in history) {
        final role = m['role'] == 'assistant' || m['role'] == 'model' ? 'model' : 'user';
        geminiContents.add({
          'role': role,
          'parts': [
            {'text': m['content'] ?? ''}
          ],
        });
      }
    }
    geminiContents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': geminiContents,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API fallback error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Invalid response structure from Gemini API: $decoded');
    }
    final candidate = candidates[0] as Map;
    final contentMap = candidate['content'] as Map?;
    final parts = contentMap?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('No parts in Gemini API response');
    }
    final text = parts[0]['text'] as String?;
    if (text == null) {
      throw Exception('No text in Gemini API response part');
    }
    return text;
  }

  Future<Map<String, dynamic>> _fallbackToGeminiStructuredResponse(
    String prompt,
    String systemPrompt,
  ) async {
    if (_geminiFallbackKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    debugPrint('Calling Gemini API fallback for structured response ($_geminiFallbackModel)...');
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiFallbackModel:generateContent?key=$_geminiFallbackKey',
    );

    final geminiContents = [
      {
        'role': 'user',
        'parts': [
          {'text': '$systemPrompt\n\n$prompt'}
        ],
      }
    ];

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': geminiContents,
        'generationConfig': {
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API fallback structured error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Invalid response structure from Gemini API: $decoded');
    }
    final candidate = candidates[0] as Map;
    final contentMap = candidate['content'] as Map?;
    final parts = contentMap?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('No parts in Gemini API response');
    }
    final text = parts[0]['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('No text in Gemini API response part');
    }

    var cleanedContent = text.trim();
    if (cleanedContent.startsWith('```')) {
      final lastBackticks = cleanedContent.lastIndexOf('```');
      if (lastBackticks > 0) {
        cleanedContent = cleanedContent.substring(0, lastBackticks);
      }
      cleanedContent = cleanedContent.replaceFirst(RegExp(r'^```json\s*'), '').trim();
    }

    return jsonDecode(cleanedContent);
  }
}
