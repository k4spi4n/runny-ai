import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/workout_models.dart';
import 'package:runny_app/widgets/activity_summary_card.dart';

void main() {
  final activity = Activity(
    userId: 'user-1',
    startedAt: DateTime(2026, 7, 15, 19, 36),
    distanceKm: 7.89,
    durationMin: 42 + 28 / 60,
    avgHr: 152,
    avgCadence: 178,
    elevationGainM: 36,
    name: 'Chạy bộ buổi tối',
  );

  Widget buildCard({required double width, Activity? data}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: ActivitySummaryCard(
                activity: data ?? activity,
                timeRange: '19:36 - 20:18 15/07/2026',
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses a two-column metric grid on a narrow layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCard(width: 390));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity_summary_grid_2')), findsOne);
    expect(find.byKey(const ValueKey('activity_summary_grid_3')), findsNothing);
    expect(find.text('Chạy bộ buổi tối'), findsOne);
    expect(find.text('7.89 km'), findsOne);
    expect(find.text('178 spm'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a three-column metric grid on a wide layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCard(width: 920));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity_summary_grid_3')), findsOne);
    expect(find.byKey(const ValueKey('activity_metric_cadence')), findsOne);
    expect(find.byKey(const ValueKey('activity_metric_heart_rate')), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carries rounded pace seconds into the next minute', (
    tester,
  ) async {
    final roundingActivity = Activity(
      userId: 'user-1',
      startedAt: DateTime(2026, 7, 15, 6),
      distanceKm: 1,
      durationMin: 5.999,
      name: 'Morning Run',
    );

    await tester.pumpWidget(buildCard(width: 390, data: roundingActivity));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity_metric_pace')),
        matching: find.textContaining('6:00'),
      ),
      findsOne,
    );
    expect(find.textContaining('5:60'), findsNothing);
  });
}
