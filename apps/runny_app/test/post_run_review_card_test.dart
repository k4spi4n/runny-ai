import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/post_run_review_card.dart';

void main() {
  testWidgets('captures RPE and exposes both AI follow-up actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selectedRpe;
    var analyzed = false;
    var optimized = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostRunReviewCard(
            workoutTitle: 'Chạy nhẹ 5K',
            plannedDistanceKm: 5,
            plannedDurationMin: 32,
            actualDistanceKm: 5.2,
            actualDurationMin: 31,
            selectedRpe: selectedRpe,
            savingRpe: false,
            onRpeSelected: (value) => selectedRpe = value,
            onAnalyzeWithAi: () => analyzed = true,
            onOptimizePlan: () => optimized = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PostRunReviewCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post_run_completed_title')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('post_run_rpe_6')));
    expect(selectedRpe, 6);

    final analyze = find.byKey(const ValueKey('post_run_analyze_ai'));
    await tester.ensureVisible(analyze);
    await tester.tap(analyze);
    expect(analyzed, isTrue);

    final optimize = find.byKey(const ValueKey('post_run_optimize_plan'));
    await tester.ensureVisible(optimize);
    await tester.tap(optimize);
    expect(optimized, isTrue);
  });
}
