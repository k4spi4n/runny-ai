import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/date_time_utils.dart';

void main() {
  test('dateWithTime preserves the selected calendar day', () {
    final result = dateWithTime(
      DateTime(2026, 6, 1),
      DateTime(2026, 7, 16, 18, 42, 10),
    );

    expect(result, DateTime(2026, 6, 1, 18, 42, 10));
  });

  test('dateWithTime preserves UTC intent', () {
    final result = dateWithTime(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 7, 16, 18, 42),
    );

    expect(result, DateTime.utc(2026, 6, 1, 18, 42));
    expect(result.isUtc, isTrue);
  });
}
