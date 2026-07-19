import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/coach_suggestion_panel.dart';

List<CoachSuggestionItem> _items() => const [
  CoachSuggestionItem(
    id: 'progress',
    icon: Icons.insights,
    title: 'Analyze progress',
    description: 'Review recent training trends.',
    prompt: 'Analyze my last four weeks',
    accentColor: Colors.blue,
  ),
  CoachSuggestionItem(
    id: 'workout',
    icon: Icons.fitness_center,
    title: 'Choose a workout',
    description: 'Recommend the next session.',
    prompt: 'What should I run today?',
    accentColor: Colors.orange,
  ),
];

Widget _testApp({
  required double width,
  ValueChanged<String>? onSelected,
  VoidCallback? onRefresh,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: CoachSuggestionPanel(
            title: 'How can your coach help?',
            subtitle: 'Choose a suggestion or ask your own question.',
            items: _items(),
            onSelected: (item) => onSelected?.call(item.id),
            knowledgeTitle: 'Running knowledge',
            knowledgePrompts: const [
              CoachKnowledgePrompt(
                id: 'cadence',
                prompt: 'What cadence should I aim for?',
              ),
            ],
            onKnowledgeSelected: (item) => onSelected?.call(item.id),
            refreshTooltip: 'Show different questions',
            onRefresh: onRefresh ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('uses compact horizontal lists and sends selected prompt', (
    tester,
  ) async {
    String? selectedId;
    await tester.pumpWidget(
      _testApp(width: 390, onSelected: (id) => selectedId = id),
    );

    expect(
      find.byKey(const ValueKey('coach_suggestion_mobile_list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach_knowledge_mobile_list')),
      findsOneWidget,
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Analyze progress'), findsOneWidget);
    expect(find.text('Analyze my last four weeks'), findsOneWidget);
    expect(find.text('Running knowledge'), findsOneWidget);
    expect(find.text('What cadence should I aim for?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach_suggestion_progress')));
    await tester.pump();

    expect(selectedId, 'progress');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('coach_knowledge_cadence')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('coach_knowledge_cadence')));
    await tester.pump();
    expect(selectedId, 'cadence');
  });

  testWidgets('uses two columns when enough width is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(width: 800));

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('offers a control to rotate question examples', (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      _testApp(width: 390, onRefresh: () => refreshCount++),
    );

    await tester.tap(find.byKey(const ValueKey('refresh_coach_suggestions')));
    await tester.pump();

    expect(refreshCount, 1);
  });
}
