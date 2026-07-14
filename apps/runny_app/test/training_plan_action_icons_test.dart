import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/pages/training_plan_page.dart';

void main() {
  testWidgets('uses Lucide calendar icons for training plan actions', (
    tester,
  ) async {
    await tester.pumpWidget(trainingPlanActionIconsPreview());

    expect(find.byIcon(LucideIcons.calendar_sync), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendar_plus), findsOneWidget);
  });

  testWidgets('future workout exposes only the reschedule action', (
    tester,
  ) async {
    var rescheduled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FutureWorkoutScheduleAction(
            label: 'Đặt lịch',
            onReschedule: () => rescheduled = true,
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Đặt lịch'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(rescheduled, isTrue);
  });
}
