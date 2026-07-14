import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/missed_workout_reschedule_dialog.dart';

void main() {
  testWidgets('returns today when the primary action is selected', (
    tester,
  ) async {
    MissedWorkoutRescheduleChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog<MissedWorkoutRescheduleChoice>(
                  context: context,
                  builder: (_) => const MissedWorkoutRescheduleDialog(
                    title: 'Bạn đã lỡ một buổi tập',
                    message: 'Dời buổi này và các buổi sau?',
                    todayLabel: 'Dời sang hôm nay',
                    tomorrowLabel: 'Dời sang ngày mai',
                    dismissLabel: 'Để sau',
                  ),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('missed_workout_reschedule_dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('missed_workout_today')));
    await tester.pumpAndSettle();
    expect(result, MissedWorkoutRescheduleChoice.today);
  });

  testWidgets('offers tomorrow and a non-destructive dismiss action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MissedWorkoutRescheduleDialog(
            title: 'Bạn đã lỡ một buổi tập',
            message: 'Dời buổi này và các buổi sau?',
            todayLabel: 'Dời sang hôm nay',
            tomorrowLabel: 'Dời sang ngày mai',
            dismissLabel: 'Để sau',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('missed_workout_tomorrow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('missed_workout_dismiss')),
      findsOneWidget,
    );
  });
}
