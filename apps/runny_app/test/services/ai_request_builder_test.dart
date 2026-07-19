import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/services/ai_request_builder.dart';

void main() {
  group('AiRequestBuilder', () {
    test('infers only relevant non-tool coach context', () {
      expect(AiRequestBuilder.inferredCoachContext('What is VO₂ max?'), {
        'metrics',
      });
      expect(
        AiRequestBuilder.inferredCoachContext(
          'Phân tích xu hướng pace các buổi chạy gần đây',
        ),
        {'activities'},
      );
      expect(
        AiRequestBuilder.inferredCoachContext('How should I breathe?'),
        isEmpty,
      );
      expect(
        AiRequestBuilder.inferredCoachContext('Move my long run to Sunday'),
        isEmpty,
        reason: 'plan data is fetched by a server-defined coach tool',
      );
    });

    test('builds compact onboarding data and omits absent values', () {
      final input = AiRequestBuilder.onboardingGoals(
        locale: 'en-US',
        gender: ' ',
        weightKg: 62.04,
        heightCm: 170,
        goal: '  Finish a safe 10K  ',
        startDate: DateTime(2026, 7, 19, 15),
        trainingDaysPerWeek: 4,
        preferredTime: 'morning',
        constraints: '',
      );
      final data = jsonDecode(input) as Map<String, dynamic>;

      expect(data, {
        'locale': 'en',
        'profile': {'weight_kg': 62, 'height_cm': 170},
        'goal': 'Finish a safe 10K',
        'start_date': '2026-07-19',
        'training_days_per_week': 4,
        'preferred_time': 'morning',
      });
      expect(input.length, lessThan(220));
      expect(input, isNot(contains('Yeu cau')));
      expect(input, isNot(contains('schema')));
    });

    test('keeps relevant plan dates and normalizes supported locale', () {
      final input = AiRequestBuilder.onboardingGoals(
        locale: 'vi_VN',
        gender: 'female',
        weightKg: 55.5,
        heightCm: 162,
        maxHr: 190,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 9, 12),
        trainingDaysPerWeek: 3,
        preferredTime: 'flexible',
        constraints: '  Nghỉ thứ Tư  ',
      );
      final data = jsonDecode(input) as Map<String, dynamic>;

      expect(data['locale'], 'vi');
      expect(data['start_date'], '2026-08-01');
      expect(data['end_date'], '2026-09-12');
      expect(data['constraints'], 'Nghỉ thứ Tư');
      expect(data['profile'], {
        'gender': 'female',
        'weight_kg': 55.5,
        'height_cm': 162,
        'max_hr': 190,
      });
    });

    test('builds compact nutrition deficits with locale and selected date', () {
      final input = AiRequestBuilder.nutritionSuggestions(
        locale: 'en',
        date: DateTime(2026, 7, 18, 23),
        mealType: 'dinner',
        remainingCalories: 480.04,
        remainingProtein: 22.16,
        remainingCarbs: -3,
        remainingFat: 0,
      );
      final data = jsonDecode(input) as Map<String, dynamic>;

      expect(data, {
        'locale': 'en',
        'date': '2026-07-18',
        'meal_type': 'dinner',
        'remaining': {
          'calories_kcal': 480,
          'protein_g': 22.2,
          'carbs_g': 0,
          'fat_g': 0,
        },
      });
      expect(input.length, lessThan(180));
    });

    test('screenshot context is short and does not repeat response schema', () {
      final input = AiRequestBuilder.activityScreenshot(
        referenceTime: DateTime.utc(2026, 7, 19, 4, 30),
      );
      final data = jsonDecode(input) as Map<String, dynamic>;

      expect(data['reference_time'], '2026-07-19T04:30:00.000Z');
      expect(data['utc_offset_minutes'], 0);
      expect(data['output_units'], {'distance': 'km', 'duration': 'min'});
      expect(data['pace_is_duration'], isFalse);
      expect(input, isNot(contains('is_activity')));
      expect(input, isNot(contains('confidence')));
      expect(input.length, lessThan(180));
    });
  });

  group('AiStructuredResponseParser', () {
    test('normalizes, deduplicates, and bounds goal suggestions', () {
      final goals = AiStructuredResponseParser.goalSuggestions({
        'goals': [
          '  Run 5K safely  ',
          42,
          '',
          'Run 5K safely',
          'Build to three weekly runs',
          'Improve easy-run consistency',
          'Add one recovery session',
          'Ignored fifth valid goal',
        ],
      });

      expect(goals, [
        'Run 5K safely',
        'Build to three weekly runs',
        'Improve easy-run consistency',
        'Add one recovery session',
      ]);
      expect(
        AiStructuredResponseParser.goalSuggestions({
          'goals': [List.filled(241, 'x').join()],
        }),
        isEmpty,
      );
      expect(AiStructuredResponseParser.goalSuggestions({}), isEmpty);
    });

    test('accepts exactly three valid nutrition items', () {
      final suggestions = AiStructuredResponseParser.nutritionSuggestions({
        'items': [
          _nutritionItem('Oats', 350),
          _nutritionItem('Rice bowl', 520),
          _nutritionItem('Yogurt', 180),
        ],
      });

      expect(suggestions, hasLength(3));
      expect(suggestions.first, {
        'foodName': 'Oats',
        'calories': 350.0,
        'protein': 20.0,
        'carbs': 45.0,
        'fat': 8.0,
        'amount': 1.0,
        'unit': 'bowl',
      });
    });

    test('rejects wrong item counts and unsafe field values', () {
      expect(
        () => AiStructuredResponseParser.nutritionSuggestions({
          'items': [_nutritionItem('Only one', 200)],
        }),
        throwsFormatException,
      );
      expect(
        () => AiStructuredResponseParser.nutritionSuggestions({
          'items': [
            _nutritionItem('Valid', 200),
            _nutritionItem('Invalid', -1),
            _nutritionItem('Valid', 300),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => AiStructuredResponseParser.nutritionSuggestions({
          'items': [
            _nutritionItem(List.filled(161, 'x').join(), 200),
            _nutritionItem('Valid', 250),
            _nutritionItem('Valid', 300),
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _nutritionItem(String name, num calories) => {
  'foodName': name,
  'calories': calories,
  'protein': 20,
  'carbs': 45,
  'fat': 8,
  'amount': 1,
  'unit': 'bowl',
};
