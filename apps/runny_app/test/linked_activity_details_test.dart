import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/workout_models.dart';
import 'package:runny_app/widgets/linked_activity_details.dart';

void main() {
  testWidgets('opens details from a linked activity name', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkedActivityDetails(
            activity: Activity(
              id: 'activity-1',
              userId: 'user-1',
              startedAt: DateTime(2026, 7, 15, 6),
              distanceKm: 5.2,
              durationMin: 31.5,
              name: 'Morning Run',
            ),
            onOpenDetails: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('Morning Run'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open_linked_activity_details')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('open_linked_activity_details')),
    );
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('carries rounded pace seconds into the next minute', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkedActivityDetails(
            activity: Activity(
              userId: 'user-1',
              startedAt: DateTime(2026, 7, 15, 6),
              distanceKm: 1,
              durationMin: 5.999,
            ),
            onOpenDetails: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('6:00'), findsOneWidget);
    expect(find.textContaining('5:60'), findsNothing);
  });
}
