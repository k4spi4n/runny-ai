import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/services/ai_service.dart';

void main() {
  group('AiService.compactHistory', () {
    test(
      'keeps the newest complete turns within count and character budgets',
      () {
        final history = <Map<String, dynamic>>[
          for (var index = 0; index < 20; index++) ...[
            {'role': 'user', 'content': 'question-$index-${'x' * 40}'},
            {'role': 'assistant', 'content': 'answer-$index-${'y' * 40}'},
          ],
        ];

        final compact = AiService.compactHistory(
          history,
          maxMessages: 8,
          maxChars: 500,
        );

        expect(compact, hasLength(8));
        expect(compact.first['role'], 'user');
        expect(compact.first['content'], startsWith('question-16-'));
        expect(compact.last['content'], startsWith('answer-19-'));
        expect(
          compact.fold<int>(
            0,
            (total, item) => total + (item['content'] as String).length,
          ),
          lessThanOrEqualTo(500),
        );
      },
    );

    test('drops invalid roles, empty messages, and an orphan assistant', () {
      final compact = AiService.compactHistory([
        {'role': 'assistant', 'content': 'old orphan'},
        {'role': 'system', 'content': 'untrusted policy'},
        {'role': 'user', 'content': '   '},
        {'role': 'user', 'content': 'new question'},
        {'role': 'assistant', 'content': 'new answer'},
      ]);

      expect(compact, [
        {'role': 'user', 'content': 'new question'},
        {'role': 'assistant', 'content': 'new answer'},
      ]);
    });

    test('clips one oversized newest user message to the exact budget', () {
      final compact = AiService.compactHistory([
        {'role': 'user', 'content': 'x' * 300},
      ], maxChars: 100);

      expect(compact, hasLength(1));
      expect((compact.single['content'] as String).length, 100);
      expect(compact.single['content'], endsWith('[truncated]'));
    });
  });
}
