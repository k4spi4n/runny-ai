import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/training_calendar_heatmap.dart';

void main() {
  Widget buildSubject(List<TrainingCalendarEntry> workouts) {
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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TrainingCalendarHeatmap(
            month: DateTime(2026, 7),
            workouts: workouts,
          ),
        ),
      ),
    );
  }

  testWidgets('shows monthly volume and completed workouts', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        TrainingCalendarEntry(
          date: DateTime(2026, 7, 3),
          status: 'completed',
          title: 'Completed run',
          targetDistanceKm: 7,
        ),
        TrainingCalendarEntry(
          date: DateTime(2026, 7, 12),
          status: 'planned',
          title: 'Tempo run',
          targetDurationMin: 45,
        ),
        TrainingCalendarEntry(
          date: DateTime(2026, 7, 12),
          status: 'planned',
          title: 'Strength',
          targetDurationMin: 30,
        ),
        TrainingCalendarEntry(
          date: DateTime(2026, 8, 1),
          status: 'planned',
          title: 'Outside this month',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text("This month's training rhythm"), findsOneWidget);
    expect(find.text('3 workouts • 1 completed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('training_calendar_day_2026-07-03')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('training_calendar_day_2026-07-12')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
