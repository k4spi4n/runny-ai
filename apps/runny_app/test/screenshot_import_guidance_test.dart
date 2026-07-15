import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/screenshot_import_guidance.dart';

void main() {
  testWidgets('shows the guidance and opens example screenshots', (
    tester,
  ) async {
    var examplesRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenshotImportGuidance(
            intro: 'Nhập hoạt động từ hầu hết các nền tảng.',
            guideTitle: 'Chụp ảnh thế nào để nhận diện tốt?',
            summaryStep: 'Mở trang tổng kết.',
            detailsStep: 'Chụp đủ quãng đường và thời lượng.',
            clarityStep: 'Không che dữ liệu.',
            examplesLabel: 'Xem 3 ảnh mẫu',
            onShowExamples: () => examplesRequested = true,
          ),
        ),
      ),
    );

    expect(find.text('Chụp ảnh thế nào để nhận diện tốt?'), findsOneWidget);
    expect(find.text('Chụp đủ quãng đường và thời lượng.'), findsOneWidget);

    await tester.tap(find.text('Xem 3 ảnh mẫu'));
    await tester.pump();

    expect(examplesRequested, isTrue);
  });
}
