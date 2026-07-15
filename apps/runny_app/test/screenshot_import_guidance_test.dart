import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/screenshot_import_guidance.dart';

void main() {
  testWidgets('shows the capture guide button and opens examples', (
    tester,
  ) async {
    var examplesRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenshotImportGuidance(
            intro: 'Nhập hoạt động từ hầu hết các nền tảng.',
            examplesLabel: 'Hướng dẫn chụp và ví dụ',
            onShowExamples: () => examplesRequested = true,
          ),
        ),
      ),
    );

    expect(find.text('Hướng dẫn chụp và ví dụ'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);

    await tester.tap(find.text('Hướng dẫn chụp và ví dụ'));
    await tester.pump();

    expect(examplesRequested, isTrue);
  });
}
