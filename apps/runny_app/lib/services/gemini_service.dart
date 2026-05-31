import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final String _apiKey;
  final String _modelName = 'gemini-3.5-flash';

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _apiKey = apiKey;
    debugPrint('GeminiService initialized with model: $_modelName');
  }

  GenerativeModel _createModel({String? systemInstruction}) {
    return GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
    );
  }

  GenerativeModel _createStructuredModel({String? systemInstruction}) {
    return GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<String> generateResponse(String prompt, {List<Map<String, String>>? history}) async {
    try {
      // Separate system prompt if present in history
      String? systemInstruction;
      final chatHistory = <Content>[];

      if (history != null) {
        for (final m in history) {
          if (m['role'] == 'system') {
            systemInstruction = m['content'];
          } else {
            final role = m['role'] == 'user' ? 'user' : 'model';
            chatHistory.add(Content(role, [TextPart(m['content'] ?? '')]));
          }
        }
      }

      final model = _createModel(systemInstruction: systemInstruction);
      final chat = model.startChat(history: chatHistory);
      final response = await chat.sendMessage(Content.text(prompt));
      
      return response.text ?? 'No response from Gemini';
    } catch (e) {
      debugPrint('Gemini error: $e');
      throw Exception('Error calling Gemini: $e');
    }
  }

  Future<Map<String, dynamic>> generateStructuredResponse(String prompt, String systemPrompt) async {
    try {
      final model = _createStructuredModel(systemInstruction: systemPrompt);
      final response = await model.generateContent([Content.text(prompt)]);
      
      final content = response.text;
      if (content == null) throw Exception('Empty response from Gemini');
      
      return jsonDecode(content);
    } catch (e) {
      debugPrint('Gemini structured error: $e');
      throw Exception('Error calling Gemini for structured response: $e');
    }
  }
}
