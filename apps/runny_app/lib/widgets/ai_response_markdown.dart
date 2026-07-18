import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders an AI response without rewriting its Markdown table structure.
///
/// Tables keep readable column widths and get their own horizontal viewport,
/// so only the columns that fit the message bubble are visible at once.
class AiResponseMarkdown extends StatelessWidget {
  const AiResponseMarkdown({
    super.key,
    required this.content,
    required this.textColor,
  });

  final String content;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(color: textColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableColumnWidth = constraints.maxWidth < 520 ? 132.0 : 168.0;

        return MarkdownBody(
          data: content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: baseStyle,
            strong: baseStyle?.copyWith(fontWeight: FontWeight.w700),
            em: baseStyle?.copyWith(fontStyle: FontStyle.italic),
            listBullet: baseStyle,
            code: baseStyle?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colorScheme.surface.withValues(alpha: 0.45),
            ),
            tableHead: baseStyle?.copyWith(fontWeight: FontWeight.w700),
            tableBody: baseStyle,
            tableColumnWidth: FixedColumnWidth(tableColumnWidth),
            tableScrollbarThumbVisibility: true,
            tableCellsPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            tableBorder: TableBorder.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
            tableVerticalAlignment: TableCellVerticalAlignment.middle,
          ),
        );
      },
    );
  }
}
