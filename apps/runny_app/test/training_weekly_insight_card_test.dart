import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/training_weekly_insight_card.dart';

void main() {
  testWidgets('shows a concise weekly conclusion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingWeeklyInsightCard(
            title: 'Kết luận tuần từ HLV AI',
            message: 'Bạn đang giữ nhịp tuần tốt và bám sát kế hoạch.',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('training_weekly_ai_insight')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.textContaining('giữ nhịp tuần tốt'), findsOneWidget);
  });

  testWidgets('uses encouragement treatment when no workout exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingWeeklyInsightCard(
            title: 'Kết luận tuần từ HLV AI',
            message: 'Một buổi nhẹ hôm nay là đủ để khởi động tuần này.',
            encouragement: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
