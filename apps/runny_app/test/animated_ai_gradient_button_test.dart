import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/animated_ai_gradient_button.dart';

void main() {
  testWidgets('renders animated gradient and handles taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedAiGradientButton(
            label: 'Phân tích với AI',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('animated_ai_gradient_surface')),
      findsOneWidget,
    );
    expect(find.text('Phân tích với AI'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('animated_ai_gradient_button')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
