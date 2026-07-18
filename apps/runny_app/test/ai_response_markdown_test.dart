import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/ai_response_markdown.dart';

void main() {
  testWidgets('keeps a large Markdown table and scrolls it horizontally', (
    tester,
  ) async {
    const markdown = '''Lịch tập tuần này:

| Ngày | Bài tập | Quãng đường | Pace |
| --- | --- | --- | --- |
| Thứ Hai | Easy run | 5 km | 6:30/km |
| Thứ Tư | Tempo run | 8 km | 5:30/km |''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: Key('message-viewport'),
            width: 300,
            child: AiResponseMarkdown(
              content: markdown,
              textColor: Colors.black,
            ),
          ),
        ),
      ),
    );

    final markdownBody = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdownBody.data, markdown);
    expect(markdownBody.styleSheet?.tableColumnWidth, isA<FixedColumnWidth>());
    expect(find.text('Quãng đường'), findsOneWidget);
    expect(find.text('6:30/km'), findsOneWidget);

    final horizontalScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView, findsOneWidget);

    final scrollView = tester.widget<SingleChildScrollView>(
      horizontalScrollView,
    );
    expect(scrollView.controller, isNotNull);
    expect(scrollView.controller!.offset, 0);
    expect(scrollView.controller!.position.maxScrollExtent, greaterThan(0));
  });
}
