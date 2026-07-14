import 'package:flutter_lucide/flutter_lucide.dart';
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
}
