import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/ai_response_markdown.dart';

void main() {
  const markdown = '''Lịch tập tuần này:

| Ngày | Bài tập | Quãng đường | Pace |
| --- | --- | --- | --- |
| Thứ Hai | Easy run | 5 km | 6:30/km |
| Thứ Tư | Tempo run | 8 km | 5:30/km |''';

  Future<void> pumpTable(WidgetTester tester) async {
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
    await tester.pump();
  }

  Finder horizontalScrollView() => find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  );

  AnimatedOpacity shadow(WidgetTester tester, String key) {
    return tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(AnimatedOpacity),
      ),
    );
  }

  testWidgets(
    'keeps a large Markdown table and makes it horizontally scrollable',
    (tester) async {
      await pumpTable(tester);

      final markdownBodies = tester
          .widgetList<MarkdownBody>(find.byType(MarkdownBody))
          .toList();
      expect(markdownBodies, hasLength(2));
      expect(markdownBodies.first.data, 'Lịch tập tuần này:\n');
      expect(
        markdownBodies.last.data,
        '''| Ngày | Bài tập | Quãng đường | Pace |
| --- | --- | --- | --- |
| Thứ Hai | Easy run | 5 km | 6:30/km |
| Thứ Tư | Tempo run | 8 km | 5:30/km |''',
      );
      expect(markdownBodies.last.selectable, isFalse);
      expect(
        markdownBodies.last.styleSheet?.tableColumnWidth,
        isA<FixedColumnWidth>(),
      );
      expect(horizontalScrollView(), findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(
        horizontalScrollView(),
      );
      expect(scrollView.controller, isNotNull);
      expect(scrollView.controller!.position.maxScrollExtent, greaterThan(0));
    },
  );

  testWidgets('updates edge shadows to show hidden columns', (tester) async {
    await pumpTable(tester);

    final scrollView = tester.widget<SingleChildScrollView>(
      horizontalScrollView(),
    );
    final controller = scrollView.controller!;

    expect(shadow(tester, 'table-overflow-shadow-left').opacity, 0);
    expect(shadow(tester, 'table-overflow-shadow-right').opacity, 1);

    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pump();
    await tester.pump();
    expect(shadow(tester, 'table-overflow-shadow-left').opacity, 1);
    expect(shadow(tester, 'table-overflow-shadow-right').opacity, 1);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(shadow(tester, 'table-overflow-shadow-left').opacity, 1);
    expect(shadow(tester, 'table-overflow-shadow-right').opacity, 0);
  });

  testWidgets('supports horizontal table dragging with a mouse', (
    tester,
  ) async {
    await pumpTable(tester);

    final scrollView = tester.widget<SingleChildScrollView>(
      horizontalScrollView(),
    );
    final controller = scrollView.controller!;
    expect(controller.offset, 0);

    await tester.drag(
      horizontalScrollView(),
      const Offset(-160, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('does not add overflow shadows when every column fits', (
    tester,
  ) async {
    const compactTable = '''| Ngày | Bài tập |
| --- | --- |
| Thứ Hai | Easy run |''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AiResponseMarkdown(
              content: compactTable,
              textColor: Colors.black,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(shadow(tester, 'table-overflow-shadow-left').opacity, 0);
    expect(shadow(tester, 'table-overflow-shadow-right').opacity, 0);
  });

  testWidgets('uses a dark, readable blockquote surface in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: AiResponseMarkdown(
              content: '> Lưu ý: Hãy tăng khối lượng tập từ từ.',
              textColor: Colors.white,
            ),
          ),
        ),
      ),
    );

    final markdownBody = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    final decoration =
        markdownBody.styleSheet?.blockquoteDecoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(decoration.color, isNot(Colors.blue.shade100));
    expect(decoration.color!.computeLuminance(), lessThan(0.25));
    expect(border.left.width, 3);
    expect(markdownBody.styleSheet?.blockquote?.color, isNot(Colors.black));
  });
}
