import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/markdown_table_formatter.dart';

void main() {
  group('MarkdownTableFormatter.toMobileCards', () {
    test('converts a Markdown table into labelled, stacked entries', () {
      const markdown = '''Lịch tập tuần này:

| Lựa chọn | Khoảng cách | Pace |
| --- | --- | --- |
| Chạy nhẹ | 4-5 km | 6:30-7:00 phút/km |
''';

      expect(
        MarkdownTableFormatter.toMobileCards(markdown),
        '''Lịch tập tuần này:

**Lựa chọn:** Chạy nhẹ
**Khoảng cách:** 4-5 km
**Pace:** 6:30-7:00 phút/km
''',
      );
    });

    test('separates table rows and keeps surrounding Markdown', () {
      const markdown = '''Trước bảng

| Ngày | Bài tập |
| :--- | ---: |
| Thứ Hai | Easy run |
| Thứ Ba | Nghỉ |

Sau bảng''';

      expect(MarkdownTableFormatter.toMobileCards(markdown), '''Trước bảng

**Ngày:** Thứ Hai
**Bài tập:** Easy run

---

**Ngày:** Thứ Ba
**Bài tập:** Nghỉ

Sau bảng''');
    });

    test('leaves ordinary text and incomplete tables unchanged', () {
      const markdown = 'Chỉ có | ký tự phân cách, không phải bảng.';

      expect(MarkdownTableFormatter.toMobileCards(markdown), markdown);
    });
  });
}
