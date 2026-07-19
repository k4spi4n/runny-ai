import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/onboarding_metrics.dart';

void main() {
  group('OnboardingMetrics.tryParse', () {
    test('parses valid metrics and produces the profile update payload', () {
      final metrics = OnboardingMetrics.tryParse(
        weight: '70,5',
        height: '175',
        maxHr: '190',
      );

      expect(metrics, isNotNull);
      expect(metrics!.toProfileUpdate(gender: 'male'), {
        'weight_kg': 70.5,
        'height_cm': 175.0,
        'bmi': 23.02,
        'max_hr': 190,
        'gender': 'male',
      });
    });

    test('returns null when required metrics are absent or out of range', () {
      expect(
        OnboardingMetrics.tryParse(weight: '', height: '175', maxHr: ''),
        isNull,
      );
      expect(
        OnboardingMetrics.tryParse(weight: '70', height: '300', maxHr: ''),
        isNull,
      );
    });
  });
}
