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

Widget _testApp({required double width, ValueChanged<String>? onSelected}) {
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
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('uses one column on narrow layouts and sends selected prompt', (
    tester,
  ) async {
    String? selectedId;
    await tester.pumpWidget(
      _testApp(width: 390, onSelected: (id) => selectedId = id),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 1);
    expect(find.text('Analyze progress'), findsOneWidget);
    expect(find.text('Analyze my last four weeks'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach_suggestion_progress')));
    await tester.pump();

    expect(selectedId, 'progress');
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
}
