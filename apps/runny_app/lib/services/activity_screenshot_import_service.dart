import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/activity_parser.dart';
import 'paywall_exception.dart';

class ActivityScreenshotImportException implements Exception {
  final String message;

  const ActivityScreenshotImportException(this.message);

  @override
  String toString() => message;
}

class ScreenshotActivityResult {
  final ParsedActivity activity;
  final double confidence;
  final String? sourceApp;
  final String? notes;

  const ScreenshotActivityResult({
    required this.activity,
    required this.confidence,
    this.sourceApp,
    this.notes,
  });
}

class ActivityScreenshotImportService {
  static const int maxImageBytes = 2900000;
  static const String groqVisionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';

  final SupabaseClient _supabase;

  ActivityScreenshotImportService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<ScreenshotActivityResult> analyzeImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw const ActivityScreenshotImportException(
        'Vui lòng chọn ảnh chụp màn hình buổi tập.',
      );
    }

    final imageType = detectImageType(bytes, filename);
    if (imageType == null) {
      throw const ActivityScreenshotImportException(
        'Tệp đã chọn không phải là ảnh hợp lệ.',
      );
    }

    if (bytes.length > maxImageBytes) {
      throw const ActivityScreenshotImportException(
        'Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn 2.8MB.',
      );
    }

    final dataUrl =
        'data:image/${imageType.mediaSubtype};base64,${base64Encode(bytes)}';
    final today = DateTime.now().toIso8601String();

    try {
      final response = await _supabase.functions.invoke(
        'openrouter',
        body: {
          'provider_preference': 'groq',
          'preferred_model': groqVisionModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': _userPrompt(today)},
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
          'temperature': 0.1,
          'max_tokens': 800,
        },
      );

      if (response.status != 200) {
        if (PaywallException.isUpgradeSignal(response.status, response.data)) {
          throw PaywallException(_errorFromData(response.data));
        }
        throw ActivityScreenshotImportException(_errorFromData(response.data));
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final choices = decoded is Map ? decoded['choices'] as List? : null;
      final message = choices?.isNotEmpty == true
          ? choices!.first['message'] as Map?
          : null;
      final content = message?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const ActivityScreenshotImportException(
          'AI không đọc được thông tin buổi tập từ ảnh này.',
        );
      }

      return parseModelContent(content);
    } on FunctionException catch (e) {
      if (PaywallException.isUpgradeSignal(e.status, e.details)) {
        throw PaywallException(_errorFromData(e.details));
      }
      throw ActivityScreenshotImportException(_errorFromData(e.details));
    } on PaywallException {
      rethrow;
    } on ActivityScreenshotImportException {
      rethrow;
    } catch (e) {
      debugPrint('Activity screenshot import failed: $e');
      throw const ActivityScreenshotImportException(
        'Không thể phân tích ảnh buổi tập. Vui lòng thử ảnh rõ hơn.',
      );
    }
  }

  @visibleForTesting
  static ScreenshotActivityResult parseModelContent(String content) {
    final parsed = extractJsonObject(content);
    if (parsed == null) {
      throw const ActivityScreenshotImportException(
        'AI trả về dữ liệu buổi tập không hợp lệ.',
      );
    }

    if (parsed['is_activity'] == false) {
      throw const ActivityScreenshotImportException(
        'Ảnh không chứa thông tin buổi chạy có thể nhập.',
      );
    }

    final distanceKm = _number(parsed['distance_km']);
    final durationMin = _number(parsed['duration_min']);
    if (distanceKm == null ||
        distanceKm <= 0 ||
        distanceKm > 500 ||
        durationMin == null ||
        durationMin <= 0 ||
        durationMin > 1440) {
      throw const ActivityScreenshotImportException(
        'AI không tìm thấy quãng đường và thời lượng hợp lệ trong ảnh.',
      );
    }

    final defaultStartedAt = _defaultStartedAtToday();
    var startedAtRaw = parsed['started_at']?.toString().trim();
    if (startedAtRaw != null && startedAtRaw.isNotEmpty) {
      if (startedAtRaw.endsWith('Z')) {
        startedAtRaw = startedAtRaw.substring(0, startedAtRaw.length - 1);
      } else if (startedAtRaw.endsWith('+00:00') || startedAtRaw.endsWith('-00:00')) {
        startedAtRaw = startedAtRaw.substring(0, startedAtRaw.length - 6);
      } else if (startedAtRaw.endsWith('+00') || startedAtRaw.endsWith('-00')) {
        startedAtRaw = startedAtRaw.substring(0, startedAtRaw.length - 3);
      }
    }
    var startedAt = startedAtRaw == null || startedAtRaw.isEmpty
        ? defaultStartedAt
        : DateTime.tryParse(startedAtRaw) ?? defaultStartedAt;

    final now = DateTime.now();
    if (startedAt.year < 2020 || startedAt.year > now.year + 1) {
      if (startedAt.isUtc) {
        startedAt = DateTime.utc(
          now.year,
          startedAt.month,
          startedAt.day,
          startedAt.hour,
          startedAt.minute,
          startedAt.second,
        );
      } else {
        startedAt = DateTime(
          now.year,
          startedAt.month,
          startedAt.day,
          startedAt.hour,
          startedAt.minute,
          startedAt.second,
        );
      }
    }

    final avgHrRaw = _number(parsed['avg_hr']);
    final avgHr = avgHrRaw != null && avgHrRaw >= 30 && avgHrRaw <= 240
        ? avgHrRaw.round()
        : null;
    final avgCadenceRaw = _number(parsed['avg_cadence']);
    final avgCadence = avgCadenceRaw != null && avgCadenceRaw >= 30 && avgCadenceRaw <= 300
        ? avgCadenceRaw.round()
        : null;
    final elevationRaw = _number(parsed['elevation_gain_m']);
    final elevationGainM =
        elevationRaw != null && elevationRaw >= 0 && elevationRaw <= 10000
        ? elevationRaw
        : null;

    return ScreenshotActivityResult(
      activity: ParsedActivity(
        startedAt: startedAt,
        distanceKm: distanceKm,
        durationMin: durationMin,
        avgHr: avgHr,
        avgCadence: avgCadence,
        elevationGainM: elevationGainM,
      ),
      confidence: (_number(parsed['confidence']) ?? 0).clamp(0, 1).toDouble(),
      sourceApp: _cleanOptionalString(parsed['source_app']),
      notes: _cleanOptionalString(parsed['notes']),
    );
  }

  @visibleForTesting
  static Map<String, dynamic>? extractJsonObject(String content) {
    final trimmed = content
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // Thu trich JSON tu noi dung co markdown fence hoac chu thua.
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static ImageType? detectImageType(Uint8List bytes, String filename) {
    if (bytes.length >= 12) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return const ImageType('jpeg', 'jpg');
      }
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return const ImageType('png', 'png');
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return const ImageType('gif', 'gif');
      }
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return const ImageType('webp', 'webp');
      }
    }

    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return const ImageType('jpeg', 'jpg');
    }
    if (lower.endsWith('.png')) {
      return const ImageType('png', 'png');
    }
    if (lower.endsWith('.webp')) {
      return const ImageType('webp', 'webp');
    }
    if (lower.endsWith('.gif')) {
      return const ImageType('gif', 'gif');
    }
    return null;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static String? _cleanOptionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _defaultStartedAtToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12);
  }

  String _errorFromData(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Bo qua, dung fallback.
    }
    return 'Dịch vụ AI đang bận. Vui lòng thử lại sau.';
  }

  static const String _systemPrompt =
      'Bạn là bộ đọc ảnh chụp màn hình hoạt động chạy bộ cho Runny AI. '
      'Chỉ trích xuất dữ liệu buổi chạy/đi bộ/tập cardio hiển thị trong ảnh. '
      'Không bịa số liệu không có trong ảnh, nhưng có thể quy đổi đơn vị phổ biến. '
      'Nếu ảnh không phải màn hình kết quả buổi tập, trả về is_activity=false. '
      'CHỈ trả về JSON hợp lệ, không markdown, không giải thích.';

  static String _userPrompt(String todayIso) =>
      'Đọc ảnh chụp màn hình buổi tập và trả về JSON theo schema: '
      '{"is_activity": boolean, "activity_type": "run|walk|cardio|other", '
      '"started_at": string ISO-8601, "distance_km": number, '
      '"duration_min": number, "avg_hr": number|null, '
      '"avg_cadence": number|null, '
      '"elevation_gain_m": number|null, "confidence": number, '
      '"source_app": string|null, "notes": string|null}. '
      'Quy đổi mile sang km, giờ:phút:giây sang phút, pace không dùng làm duration. '
      'Nếu ảnh ghi Today/Yesterday, quy đổi tương đối theo thời điểm hiện tại $todayIso. '
      'Nếu thiếu ngày chính xác nhưng các chỉ số tập hợp lệ, để started_at là chuỗi rỗng. '
      'distance_km và duration_min là bắt buộc khi is_activity=true.';
}

class ImageType {
  final String mediaSubtype;
  final String extension;

  const ImageType(this.mediaSubtype, this.extension);
}
