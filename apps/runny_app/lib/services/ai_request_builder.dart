import 'dart:convert';

/// Builds compact, locale-aware data payloads for server-owned AI tasks.
///
/// Task instructions and response schemas intentionally live on the server.
abstract final class AiRequestBuilder {
  /// Selects only context that cannot already be fetched through coach tools.
  /// Explicit UI selections still take precedence in the page.
  static Set<String> inferredCoachContext(String question) {
    final normalized = question.toLowerCase();
    return {
      if (RegExp(
        r'tiến bộ|xu hướng|gần đây|các buổi chạy|pace|cự ly|progress|trend|recent runs|last runs|performance',
      ).hasMatch(normalized))
        'activities',
      if (RegExp(
        r'nhịp tim|guồng chân|cadence|cân nặng|thể trạng|vo₂|max hr|heart.?rate|weight|fitness metrics',
      ).hasMatch(normalized))
        'metrics',
    };
  }

  static String onboardingGoals({
    required String locale,
    String? gender,
    num? weightKg,
    num? heightCm,
    num? maxHr,
    String? goal,
    required DateTime startDate,
    DateTime? endDate,
    required int trainingDaysPerWeek,
    required String preferredTime,
    String? constraints,
  }) {
    final normalizedGender = _trimmedOrNull(gender);
    final normalizedWeight = _finiteOrNull(weightKg);
    final normalizedHeight = _finiteOrNull(heightCm);
    final normalizedMaxHr = _finiteOrNull(maxHr);
    final normalizedGoal = _trimmedOrNull(goal);
    final normalizedEndDate = endDate == null ? null : dateOnly(endDate);
    final normalizedConstraints = _trimmedOrNull(constraints);
    final profile = <String, Object?>{
      'gender': ?normalizedGender,
      'weight_kg': ?normalizedWeight,
      'height_cm': ?normalizedHeight,
      'max_hr': ?normalizedMaxHr,
    };
    return jsonEncode({
      'locale': normalizeLocale(locale),
      if (profile.isNotEmpty) 'profile': profile,
      'goal': ?normalizedGoal,
      'start_date': dateOnly(startDate),
      'end_date': ?normalizedEndDate,
      'training_days_per_week': trainingDaysPerWeek,
      'preferred_time': preferredTime.trim(),
      'constraints': ?normalizedConstraints,
    });
  }

  static String nutritionSuggestions({
    required String locale,
    required DateTime date,
    required String mealType,
    required num remainingCalories,
    required num remainingProtein,
    required num remainingCarbs,
    required num remainingFat,
  }) => jsonEncode({
    'locale': normalizeLocale(locale),
    'date': dateOnly(date),
    'meal_type': mealType,
    'remaining': {
      'calories_kcal': _nonNegative(remainingCalories),
      'protein_g': _nonNegative(remainingProtein),
      'carbs_g': _nonNegative(remainingCarbs),
      'fat_g': _nonNegative(remainingFat),
    },
  });

  static String activityScreenshot({required DateTime referenceTime}) =>
      jsonEncode({
        'reference_time': referenceTime.toIso8601String(),
        'utc_offset_minutes': referenceTime.timeZoneOffset.inMinutes,
        'output_units': {'distance': 'km', 'duration': 'min'},
        'pace_is_duration': false,
      });

  static String normalizeLocale(String locale) =>
      locale.trim().toLowerCase().startsWith('en') ? 'en' : 'vi';

  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static num? _finiteOrNull(num? value) {
    if (value == null || !value.isFinite) return null;
    return _compactNumber(value);
  }

  static num _nonNegative(num value) {
    if (!value.isFinite || value <= 0) return 0;
    return _compactNumber(value);
  }

  static num _compactNumber(num value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
  }
}

/// Defensive parsing for structured AI responses before values reach the UI.
abstract final class AiStructuredResponseParser {
  static const int _maxGoalLength = 240;
  static const int _maxFoodNameLength = 160;
  static const int _maxUnitLength = 40;

  static List<String> goalSuggestions(Map<String, dynamic> response) {
    final rawGoals = response['goals'];
    if (rawGoals is! List) return const [];

    final goals = <String>[];
    final seen = <String>{};
    for (final item in rawGoals) {
      if (item is! String) continue;
      final value = item.trim();
      if (value.isEmpty || value.length > _maxGoalLength || !seen.add(value)) {
        continue;
      }
      goals.add(value);
      if (goals.length == 4) break;
    }
    return goals;
  }

  static List<Map<String, dynamic>> nutritionSuggestions(
    Map<String, dynamic> response,
  ) {
    final rawItems = response['items'];
    if (rawItems is! List || rawItems.length != 3) {
      throw const FormatException(
        'Nutrition response must contain exactly three items.',
      );
    }

    return rawItems
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Nutrition item must be an object.');
          }
          final item = Map<String, dynamic>.from(raw);
          final foodName = _requiredString(
            item['foodName'],
            'foodName',
            _maxFoodNameLength,
          );
          final unit = _requiredString(item['unit'], 'unit', _maxUnitLength);
          return <String, dynamic>{
            'foodName': foodName,
            'calories': _requiredNumber(item['calories'], 'calories'),
            'protein': _requiredNumber(item['protein'], 'protein'),
            'carbs': _requiredNumber(item['carbs'], 'carbs'),
            'fat': _requiredNumber(item['fat'], 'fat'),
            'amount': _requiredNumber(item['amount'], 'amount', positive: true),
            'unit': unit,
          };
        })
        .toList(growable: false);
  }

  static String _requiredString(Object? raw, String field, int maxLength) {
    if (raw is! String) throw FormatException('$field must be a string.');
    final value = raw.trim();
    if (value.isEmpty || value.length > maxLength) {
      throw FormatException('$field has an invalid length.');
    }
    return value;
  }

  static double _requiredNumber(
    Object? raw,
    String field, {
    bool positive = false,
  }) {
    if (raw is! num || !raw.isFinite || raw < 0 || (positive && raw <= 0)) {
      throw FormatException('$field must be a valid non-negative number.');
    }
    return raw.toDouble();
  }
}
