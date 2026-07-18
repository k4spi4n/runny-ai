import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/pages/training_plan_page.dart';

void main() {
  Widget buildDialog({
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlanOptimizationConfirmationDialog(
          title: 'Tối ưu kế hoạch với HLV AI?',
          description: 'Giải thích cách HLV AI đề xuất điều chỉnh.',
          cancelLabel: 'Hủy',
          confirmLabel: 'Kích hoạt',
          onCancel: onCancel,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  testWidgets('explains plan optimization and allows cancellation', (
    tester,
  ) async {
    var cancelled = false;

    await tester.pumpWidget(
      buildDialog(onCancel: () => cancelled = true, onConfirm: () {}),
    );

    expect(
      find.byKey(const ValueKey('optimize_plan_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.text('Tối ưu kế hoạch với HLV AI?'), findsOneWidget);
    expect(
      find.text('Giải thích cách HLV AI đề xuất điều chỉnh.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('optimize_plan_cancel')));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets('activates plan optimization only after confirmation', (
    tester,
  ) async {
    var confirmed = false;

    await tester.pumpWidget(
      buildDialog(onCancel: () {}, onConfirm: () => confirmed = true),
    );

    expect(confirmed, isFalse);
    await tester.tap(find.byKey(const ValueKey('optimize_plan_confirm')));
    await tester.pump();

    expect(confirmed, isTrue);
  });
}
