import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/ui_components.dart';

void main() {
  testWidgets('compact app bar actions use adjacent 44px touch targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (index) => CompactAppBarAction(
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.circle_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final actions = find.byType(CompactAppBarAction);
    expect(actions, findsNWidgets(5));

    final firstRect = tester.getRect(actions.at(0));
    final secondRect = tester.getRect(actions.at(1));
    final lastRect = tester.getRect(actions.at(4));
    expect(firstRect.size, const Size.square(CompactAppBarAction.extent));
    expect(secondRect.left, firstRect.right);
    expect(lastRect.right - firstRect.left, 5 * CompactAppBarAction.extent);
  });
}
