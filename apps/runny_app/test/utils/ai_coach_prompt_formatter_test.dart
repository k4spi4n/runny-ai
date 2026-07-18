import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/ai_coach_prompt_formatter.dart';

void main() {
  group('formatActivityAnalysisPrompt', () {
    test('uses the complete trimmed activity name', () {
      final prompt = formatActivityAnalysisPrompt(
        template: 'Phân tích hoạt động "%s" của tôi',
        activityName: '  Chạy dài cuối tuần 21 km  ',
        fallbackName: 'Hoạt động chạy bộ',
      );

      expect(prompt, 'Phân tích hoạt động "Chạy dài cuối tuần 21 km" của tôi');
    });

    test('uses the localized fallback when the activity has no name', () {
      final prompt = formatActivityAnalysisPrompt(
        template: 'Phân tích hoạt động "%s" của tôi',
        activityName: '   ',
        fallbackName: 'Hoạt động chạy bộ',
      );

      expect(prompt, 'Phân tích hoạt động "Hoạt động chạy bộ" của tôi');
    });
  });
}
