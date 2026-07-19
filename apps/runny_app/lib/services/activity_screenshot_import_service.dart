import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/activity_parser.dart';
import 'ai_request_builder.dart';
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
    final referenceTime = DateTime.now();

    try {
      final response = await _supabase.functions.invoke(
        'openrouter',
        body: {
          'feature': 'activity_screenshot',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': AiRequestBuilder.activityScreenshot(
                    referenceTime: referenceTime,
                  ),
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
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
    final startedAtRaw = parsed['started_at']?.toString().trim();
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
    final avgCadence =
        avgCadenceRaw != null && avgCadenceRaw >= 30 && avgCadenceRaw <= 300
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
}

class ImageType {
  final String mediaSubtype;
  final String extension;

  const ImageType(this.mediaSubtype, this.extension);
}
