import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/chat_scroll_utils.dart';

void main() {
  testWidgets('scrolls a long response to its beginning instead of its end', (
    tester,
  ) async {
    final controller = ScrollController();
    final responseKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 500),
                SizedBox(
                  key: responseKey,
                  height: 700,
                  child: const Text('Start of AI response'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Start of AI response')).dy,
      lessThan(0),
    );

    scrollChatResponseToStart(responseKey);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Start of AI response')).dy,
      moreOrLessEquals(0, epsilon: 1),
    );
    expect(controller.offset, lessThan(controller.position.maxScrollExtent));
  });
}
