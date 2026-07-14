import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/training_calendar_heatmap.dart';

void main() {
  Widget buildSubject(
    List<TrainingCalendarEntry> workouts, {
    ValueChanged<DateTime?>? onDateSelected,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('vi')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TrainingCalendarHeatmap(
              month: DateTime(2026, 7),
              workouts: workouts,
              totalPlanWorkouts: 4,
              completedPlanWorkouts: 1,
              onDateSelected: onDateSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows monthly volume and completed workouts', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject([
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 3),
            status: 'completed',
            title: 'Completed scheduled run',
            targetDistanceKm: 7,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 3),
            status: 'activity',
            title: 'Recorded activity',
            targetDistanceKm: 7,
            isActivity: true,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 12),
            status: 'planned',
            title: 'Tempo run',
            targetDurationMin: 45,
            isNext: true,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 12),
            status: 'planned',
            title: 'Strength',
            targetDurationMin: 30,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 20),
            status: 'planned',
            title: 'Final long run',
            targetDistanceKm: 20,
            isLast: true,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 8, 1),
            status: 'planned',
            title: 'Outside this month',
          ),
        ]),
      );
      await tester.pumpAndSettle();
    });

    expect(find.text('Training rhythm overview'), findsOneWidget);
    expect(find.text('4 sessions • 1 done'), findsNothing);
    expect(find.text('1 / 4 workouts'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.byKey(const ValueKey('training_calendar_grid_glass')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('training_calendar_day_2026-07-03')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('training_calendar_day_2026-07-12')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('training_calendar_day_2026-07-03')),
        matching: find.byIcon(Icons.directions_run),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('training_calendar_day_2026-07-12')),
        matching: find.byIcon(Icons.directions_run),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('training_calendar_day_2026-07-20')),
        matching: find.byIcon(Icons.military_tech),
      ),
      findsOneWidget,
    );
    expect(find.text('Next workout'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('training_calendar_legend_toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next workout'), findsOneWidget);
    expect(find.text('Final workout'), findsOneWidget);
    expect(find.text('Recorded activity'), findsOneWidget);
    expect(find.text('Rescheduled'), findsNothing);
    expect(find.byIcon(Icons.update), findsNothing);
    expect(
      tester.getTopLeft(find.text('Recorded activity')).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('training_calendar_grid_glass')),
            )
            .dy,
      ),
    );
  });

  testWidgets('moves between months with arrow buttons', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject([
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 3),
            status: 'planned',
            title: 'Planned run',
          ),
        ]),
      );
      await tester.pumpAndSettle();
    });

    final nextMonth = find.byKey(
      const ValueKey('training_calendar_next_month'),
      skipOffstage: false,
    );
    await tester.ensureVisible(nextMonth);
    await tester.tap(nextMonth);
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('training_calendar_previous_month')),
    );
    await tester.pumpAndSettle();
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('selects and clears a calendar day', (tester) async {
    DateTime? selectedDate;
    var selectionChanges = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject(
          [
            TrainingCalendarEntry(
              date: DateTime(2026, 7, 12),
              status: 'planned',
              title: 'Tempo run',
            ),
          ],
          onDateSelected: (date) {
            selectedDate = date;
            selectionChanges++;
          },
        ),
      );
      await tester.pumpAndSettle();
    });

    final day = find.byKey(
      const ValueKey('training_calendar_day_2026-07-12'),
      skipOffstage: false,
    );
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pump();
    expect(selectedDate, DateTime(2026, 7, 12));

    await tester.tap(day);
    await tester.pump();
    expect(selectedDate, isNull);
    expect(selectionChanges, 2);
  });

  testWidgets('uses two columns only when the available width is wide', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Widget buildLayout(double width) {
      return MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const TrainingPlanResponsiveLayout(
                calendar: SizedBox(key: ValueKey('calendar')),
                focus: SizedBox(key: ValueKey('focus')),
                details: SizedBox(key: ValueKey('details')),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildLayout(720));
    expect(
      find.byKey(const ValueKey('training_plan_narrow_layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('training_plan_wide_layout')),
      findsNothing,
    );

    await tester.pumpWidget(buildLayout(1100));
    expect(
      find.byKey(const ValueKey('training_plan_wide_layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('training_plan_narrow_layout')),
      findsNothing,
    );
  });
}
