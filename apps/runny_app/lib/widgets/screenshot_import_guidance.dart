import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class ScreenshotImportGuidance extends StatelessWidget {
  const ScreenshotImportGuidance({
    super.key,
    required this.intro,
    required this.guideTitle,
    required this.summaryStep,
    required this.detailsStep,
    required this.clarityStep,
    required this.examplesLabel,
    this.onShowExamples,
  });

  final String intro;
  final String guideTitle;
  final String summaryStep;
  final String detailsStep;
  final String clarityStep;
  final String examplesLabel;
  final VoidCallback? onShowExamples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          intro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guideTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _GuideStep(text: summaryStep),
              const SizedBox(height: 6),
              _GuideStep(text: detailsStep),
              const SizedBox(height: 6),
              _GuideStep(text: clarityStep),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: onShowExamples,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(examplesLabel),
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

@Preview(name: 'Screenshot import guidance', group: 'Activity import')
Widget screenshotImportGuidancePreview() => MaterialApp(
  theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
  home: const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(24),
      child: ScreenshotImportGuidance(
        intro:
            'Nhập hoạt động từ hầu hết các nền tảng. Ảnh cần hiển thị rõ thông tin buổi tập để AI đọc chính xác.',
        guideTitle: 'Chụp ảnh thế nào để nhận diện tốt?',
        summaryStep: 'Mở trang tổng kết của một hoạt động.',
        detailsStep:
            'Chụp đủ ngày, quãng đường và thời lượng; nhịp tim, cadence và độ cao nếu có.',
        clarityStep:
            'Không cắt mất dữ liệu, làm mờ hoặc che nội dung quan trọng.',
        examplesLabel: 'Xem 3 ảnh mẫu',
      ),
    ),
  ),
);
