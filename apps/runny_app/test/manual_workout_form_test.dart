import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/manual_workout_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget buildSubject({
    required Future<void> Function(ManualWorkoutFormValue value) onSubmit,
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
            child: ManualWorkoutForm(
              submitLabel: 'Save workout',
              onSubmit: onSubmit,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('validates required manual workout fields', (tester) async {
    var submitted = false;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject(
          onSubmit: (_) async {
            submitted = true;
          },
        ),
      );
      await tester.pumpAndSettle();
    });

    final submitButton = find.text('Save workout');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a workout name.'), findsOneWidget);
    expect(
      find.text('Please enter a valid non-negative number.'),
      findsOneWidget,
    );
    expect(
      find.text('Please enter a valid pace, for example 5:30.'),
      findsOneWidget,
    );
    expect(submitted, isFalse);
  });

  testWidgets('submits a valid manual workout', (tester) async {
    ManualWorkoutFormValue? submitted;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject(
          onSubmit: (value) async {
            submitted = value;
          },
        ),
      );
      await tester.pumpAndSettle();
    });

    final titleField = find.byKey(const ValueKey('manual_workout_title_field'));
    await tester.tap(find.byKey(const ValueKey('manual_workout_pace_toggle')));
    await tester.pumpAndSettle();
    final durationField = find.byKey(
      const ValueKey('manual_workout_duration_field'),
    );
    final distanceField = find.byKey(
      const ValueKey('manual_workout_distance_field'),
    );
    expect(titleField, findsOneWidget);
    expect(durationField, findsOneWidget);
    expect(distanceField, findsOneWidget);

    await tester.enterText(titleField, 'Morning easy run');
    await tester.enterText(durationField, '45');
    await tester.enterText(distanceField, '7.5');

    final submitButton = find.text('Save workout');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.title, 'Morning easy run');
    expect(submitted!.targetDurationMin, 45);
    expect(submitted!.targetDistanceKm, 7.5);
    expect(submitted!.workoutType, 'easy_run');
  });

  testWidgets('uses pace by default and calculates duration', (tester) async {
    ManualWorkoutFormValue? submitted;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildSubject(
          onSubmit: (value) async {
            submitted = value;
          },
        ),
      );
      await tester.pumpAndSettle();
    });

    await tester.enterText(
      find.byKey(const ValueKey('manual_workout_title_field')),
      'Pace run',
    );
    await tester.enterText(
      find.byKey(const ValueKey('manual_workout_distance_field')),
      '7.5',
    );
    expect(
      find.byKey(const ValueKey('manual_workout_pace_field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('manual_workout_pace_field')),
      '5:30',
    );

    await tester.tap(find.text('Save workout'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.targetDurationMin, 41.25);
    expect(submitted!.targetPaceMinPerKm, 5.5);
  });
}
