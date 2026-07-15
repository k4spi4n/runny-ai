import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class ScreenshotImportGuidance extends StatelessWidget {
  const ScreenshotImportGuidance({
    super.key,
    required this.intro,
    required this.examplesLabel,
    this.onShowExamples,
  });

  final String intro;
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
        Align(
          alignment: Alignment.center,
          child: FilledButton.icon(
            onPressed: onShowExamples,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(examplesLabel),
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
        examplesLabel: 'Hướng dẫn chụp và ví dụ',
      ),
    ),
  ),
);
