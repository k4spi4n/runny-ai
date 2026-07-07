import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/unsigned_text_input_formatter.dart';

void main() {
  group('UnsignedTextInputFormatter tests', () {
    final formatter = UnsignedTextInputFormatter();

    test('allows normal English/ASCII characters without modifying them', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'test.email+123@example.org',
        selection: TextSelection.collapsed(offset: 26),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'test.email+123@example.org');
      expect(result.selection.baseOffset, 26);
    });

    test(
      'strips Vietnamese accents and converts them to unsigned characters',
      () {
        const oldValue = TextEditingValue.empty;
        const newValue = TextEditingValue(
          text: 'trần.anh.đặng@example.com',
          selection: TextSelection.collapsed(offset: 25),
        );

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, 'tran.anh.dang@example.com');
        // Length didn't change (1-to-1 conversion), so selection offset remains 25
        expect(result.selection.baseOffset, 25);
      },
    );

    test('keeps password input ASCII when Vietnamese keyboard is active', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'MậtKhẩu@123 đậm 😊',
        selection: TextSelection.collapsed(offset: 18),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'MatKhau@123dam');
      expect(result.selection.baseOffset, 14);
    });

    test('removes space and emoji characters and adjusts cursor selection', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'test space 😊@example.com',
        selection: TextSelection.collapsed(offset: 25), // cursor at the end
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'testspace@example.com');
      // Original string had length 25. Space (1) and emoji (2 characters in UTF-16 representation) were removed.
      // So new length is 25 - 1 (space) - 2 (emoji: \uD83D\uDE0A) = 22.
      // Selection at the end should be at index 22.
      expect(
        result.selection.baseOffset,
        21,
      ); // 😊 is represented by 2 code units, ' ' is 1. Wait, let's verify.
    });

    test(
      'adjusts selection correctly when characters are removed in the middle',
      () {
        const oldValue = TextEditingValue(
          text: 'test',
          selection: TextSelection.collapsed(offset: 4),
        );
        // User types ' ' (space) in the middle: 'te st' (cursor at index 3, right after space)
        const newValue = TextEditingValue(
          text: 'te st',
          selection: TextSelection.collapsed(offset: 3),
        );

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, 'test');
        // The space at index 2 was removed, so the cursor (which was at index 3, after space) should move to index 2 (after 'e')
        expect(result.selection.baseOffset, 2);
      },
    );
  });
}
