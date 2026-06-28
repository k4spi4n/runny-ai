import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_recognition_models.dart';

class FoodRecognitionException implements Exception {
  final String message;

  const FoodRecognitionException(this.message);

  @override
  String toString() => message;
}

class FoodRecognitionService {
  // Khop gioi han server: Groq nhan anh base64 <= 4MB (~2.8MB raw sau khi phinh).
  static const int maxImageBytes = 2900000;

  final SupabaseClient _supabase;
  final http.Client _httpClient;

  FoodRecognitionService({
    SupabaseClient? supabase,
    http.Client? httpClient,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client();

  Future<FoodRecognitionResult> analyzeImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw const FoodRecognitionException('Vui long chon anh mon an.');
    }

    final imageType = _detectImageType(bytes, filename);
    if (imageType == null) {
      throw const FoodRecognitionException('Tep da chon khong phai la anh.');
    }

    if (bytes.length > maxImageBytes) {
      throw const FoodRecognitionException('Anh qua lon. Vui long chon anh nho hon 2.8MB.');
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null || anonKey == null) {
      throw const FoodRecognitionException('Thieu cau hinh Supabase.');
    }

    final normalizedSupabaseUrl = supabaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$normalizedSupabaseUrl/functions/v1/food-recognition/analyze');
    final request = http.MultipartRequest('POST', uri);
    request.headers['apikey'] = anonKey;
    request.headers['Authorization'] =
        'Bearer ${_supabase.auth.currentSession?.accessToken ?? anonKey}';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: _normalizedImageFilename(filename, imageType.extension),
        contentType: MediaType('image', imageType.mediaSubtype),
      ),
    );

    http.Response response;
    Object decodedBody = <String, dynamic>{};
    try {
      final streamedResponse = await _httpClient.send(request);
      response = await http.Response.fromStream(streamedResponse);
      decodedBody = _decodeResponseBody(response);
    } catch (e) {
      if (_shouldUseMockFallback) {
        return _mockAnalyze(filename);
      }

      throw FoodRecognitionException(
        'Khong the ket noi dich vu nhan dang mon an. Hay kiem tra Edge Function food-recognition da duoc deploy.',
      );
    }

    if (response.statusCode != 200) {
      if (_shouldUseMockFallback) {
        return _mockAnalyze(filename);
      }

      final message = decodedBody is Map ? decodedBody['error']?.toString() : null;
      final rawBody = decodedBody is String ? decodedBody.trim() : '';
      final suffix = rawBody.isNotEmpty && rawBody.length < 180 ? ' ($rawBody)' : '';
      throw FoodRecognitionException(
        message ??
            'Khong the phan tich anh mon an. HTTP ${response.statusCode}$suffix',
      );
    }

    if (decodedBody is! Map<String, dynamic>) {
      throw const FoodRecognitionException('Phan hoi AI khong hop le.');
    }

    return FoodRecognitionResult.fromJson(decodedBody);
  }

  Object _decodeResponseBody(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  _ImageType? _detectImageType(Uint8List bytes, String filename) {
    if (bytes.length >= 12) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return const _ImageType('jpeg', 'jpg');
      }
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return const _ImageType('png', 'png');
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return const _ImageType('gif', 'gif');
      }
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return const _ImageType('webp', 'webp');
      }
      if (bytes.length >= 12 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return const _ImageType('heic', 'heic');
      }
    }

    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return const _ImageType('jpeg', 'jpg');
    }
    if (lower.endsWith('.png')) {
      return const _ImageType('png', 'png');
    }
    if (lower.endsWith('.webp')) {
      return const _ImageType('webp', 'webp');
    }
    if (lower.endsWith('.gif')) {
      return const _ImageType('gif', 'gif');
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return const _ImageType('heic', 'heic');
    }
    return null;
  }

  String _normalizedImageFilename(String filename, String extension) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty || !trimmed.contains('.')) {
      return 'food-image.$extension';
    }

    return trimmed;
  }

  // Mock chi bat khi dev co tinh dat FOOD_RECOGNITION_MOCK=true trong .env client.
  // Mac dinh TAT: de loi that tu server (chua dang nhap / vuot han muc / khong phai
  // mon an) duoc hien thi cho nguoi dung thay vi bi thay bang du lieu gia.
  bool get _shouldUseMockFallback {
    return (dotenv.env['FOOD_RECOGNITION_MOCK'] ?? 'false').toLowerCase() == 'true';
  }

  FoodRecognitionResult _mockAnalyze(String filename) {
    final lower = filename.toLowerCase();

    if (lower.contains('pho') || lower.contains('noodle') || lower.contains('bo')) {
      return const FoodRecognitionResult(
        foodName: 'Pho bo',
        confidence: 0.88,
        nutrition: FoodRecognitionNutrition(
          calories: 430,
          protein: 28,
          carbs: 52,
          fat: 12,
        ),
      );
    }

    if (lower.contains('salad') || lower.contains('rau')) {
      return const FoodRecognitionResult(
        foodName: 'Salad uc ga',
        confidence: 0.86,
        nutrition: FoodRecognitionNutrition(
          calories: 310,
          protein: 32,
          carbs: 18,
          fat: 12,
        ),
      );
    }

    if (lower.contains('pasta') || lower.contains('spaghetti')) {
      return const FoodRecognitionResult(
        foodName: 'Mi Y sot bo bam',
        confidence: 0.82,
        nutrition: FoodRecognitionNutrition(
          calories: 610,
          protein: 24,
          carbs: 78,
          fat: 22,
        ),
      );
    }

    return const FoodRecognitionResult(
      foodName: 'Com ga',
      confidence: 0.74,
      nutrition: FoodRecognitionNutrition(
        calories: 520,
        protein: 35,
        carbs: 55,
        fat: 15,
      ),
    );
  }
}

class _ImageType {
  final String mediaSubtype;
  final String extension;

  const _ImageType(this.mediaSubtype, this.extension);
}
