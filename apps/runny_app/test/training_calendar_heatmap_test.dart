import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/training_calendar_heatmap.dart';

void main() {
  Widget buildSubject(
    List<TrainingCalendarEntry> workouts, {
    ValueChanged<DateTime?>? onDateSelected,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A82FF),
          brightness: brightness,
        ),
      ),
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

  testWidgets('uses white corner icons and soft gradients in dark mode', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject([
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 8),
            status: 'activity',
            title: 'Recorded activity',
            isActivity: true,
          ),
          TrainingCalendarEntry(
            date: DateTime(2026, 7, 9),
            status: 'completed',
            title: 'Completed workout',
          ),
        ], brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
    });

    final activityDay = find.byKey(
      const ValueKey('training_calendar_day_2026-07-08'),
      skipOffstage: false,
    );
    final completedDay = find.byKey(
      const ValueKey('training_calendar_day_2026-07-09'),
      skipOffstage: false,
    );
    final activityIcon = find.descendant(
      of: activityDay,
      matching: find.byIcon(Icons.check_circle, skipOffstage: false),
    );
    final completedIcon = find.descendant(
      of: completedDay,
      matching: find.byIcon(Icons.directions_run, skipOffstage: false),
    );

    expect(activityDay, findsOneWidget);
    expect(completedDay, findsOneWidget);
    expect(activityIcon, findsOneWidget);
    expect(completedIcon, findsOneWidget);
    expect(tester.widget<Icon>(activityIcon).color, Colors.white);
    expect(tester.widget<Icon>(completedIcon).color, Colors.white);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: activityDay, matching: find.text('8')),
          )
          .style
          ?.color,
      Colors.white,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: completedDay, matching: find.text('9')),
          )
          .style
          ?.color,
      Colors.white,
    );
    expect(
      tester.getCenter(activityIcon).dx,
      greaterThan(tester.getCenter(activityDay).dx),
    );
    expect(
      tester.getCenter(activityIcon).dy,
      greaterThan(tester.getCenter(activityDay).dy),
    );

    final ink = tester.widget<Ink>(
      find.descendant(of: activityDay, matching: find.byType(Ink)),
    );
    final decoration = ink.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.every((color) => color.a == 1), isTrue);
    expect(
      gradient.colors.last.computeLuminance(),
      greaterThan(gradient.colors.first.computeLuminance()),
    );

    await tester.tap(
      find.byKey(const ValueKey('training_calendar_legend_toggle')),
    );
    await tester.pump();
    final activityLegend = find.byKey(
      const ValueKey('training_calendar_legend_activity'),
      skipOffstage: false,
    );
    final legendMarker = find.descendant(
      of: activityLegend,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        skipOffstage: false,
      ),
    );
    expect(legendMarker, findsOneWidget);
    final legendDecoration =
        tester.widget<Container>(legendMarker).decoration! as BoxDecoration;
    expect(gradient.colors.first, legendDecoration.color);
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
                calendar: SizedBox(key: ValueKey('calendar'), height: 320),
                focus: SizedBox(key: ValueKey('focus'), height: 100),
                details: SizedBox(key: ValueKey('details'), height: 400),
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
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('focus'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('calendar'))).dy),
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
    final calendarPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar')),
    );
    final focusPosition = tester.getTopLeft(
      find.byKey(const ValueKey('focus')),
    );
    final detailsPosition = tester.getTopLeft(
      find.byKey(const ValueKey('details')),
    );
    expect(focusPosition.dx, greaterThan(calendarPosition.dx));
    expect(detailsPosition.dx, focusPosition.dx);
    expect(detailsPosition.dy, greaterThan(focusPosition.dy));
  });
}
