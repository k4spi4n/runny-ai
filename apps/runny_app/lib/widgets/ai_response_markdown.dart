import 'package:flutter/gestures.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableColumnWidth = constraints.maxWidth < 520 ? 132.0 : 168.0;
        final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: baseStyle,
          strong: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          em: baseStyle?.copyWith(fontStyle: FontStyle.italic),
          listBullet: baseStyle,
          code: baseStyle?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: colorScheme.surface.withValues(alpha: 0.45),
          ),
          blockquote: baseStyle?.copyWith(
            color: isDark ? textColor.withValues(alpha: 0.9) : textColor,
            height: 1.45,
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          blockquoteDecoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            border: Border(
              left: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.82),
                width: 3,
              ),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          tableHead: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          tableBody: baseStyle,
          tableColumnWidth: FixedColumnWidth(tableColumnWidth),
          tableScrollbarThumbVisibility: true,
          tablePadding: const EdgeInsets.only(bottom: 8),
          tableCellsPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          tableBorder: TableBorder.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
          tableVerticalAlignment: TableCellVerticalAlignment.middle,
        );
        final sections = _splitMarkdownSections(content);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in sections)
              if (section.isTable)
                _MarkdownTableViewport(
                  data: section.data,
                  styleSheet: styleSheet,
                  initiallyOverflowing:
                      section.columnCount * tableColumnWidth >
                      constraints.maxWidth,
                )
              else
                MarkdownBody(
                  data: section.data,
                  selectable: true,
                  styleSheet: styleSheet,
                ),
          ],
        );
      },
    );
  }
}

class _MarkdownTableViewport extends StatefulWidget {
  const _MarkdownTableViewport({
    required this.data,
    required this.styleSheet,
    required this.initiallyOverflowing,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final bool initiallyOverflowing;

  @override
  State<_MarkdownTableViewport> createState() => _MarkdownTableViewportState();
}

class _MarkdownTableViewportState extends State<_MarkdownTableViewport> {
  static const _shadowAnimationDuration = Duration(milliseconds: 140);
  static const _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };

  bool _showLeftShadow = false;
  late bool _showRightShadow;
  bool _updateScheduled = false;
  bool _pendingLeftShadow = false;
  bool _pendingRightShadow = false;

  @override
  void initState() {
    super.initState();
    _showRightShadow = widget.initiallyOverflowing;
  }

  @override
  void didUpdateWidget(covariant _MarkdownTableViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _showLeftShadow = false;
      _showRightShadow = widget.initiallyOverflowing;
      _pendingLeftShadow = false;
      _pendingRightShadow = widget.initiallyOverflowing;
    } else if (!widget.initiallyOverflowing) {
      _showLeftShadow = false;
      _showRightShadow = false;
    } else if (!oldWidget.initiallyOverflowing) {
      _showRightShadow = true;
    }
  }

  bool _handleScrollMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;

    _pendingLeftShadow = metrics.extentBefore > 0.5;
    _pendingRightShadow = metrics.extentAfter > 0.5;
    if (_updateScheduled) return false;

    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted ||
          (_showLeftShadow == _pendingLeftShadow &&
              _showRightShadow == _pendingRightShadow)) {
        return;
      }
      setState(() {
        _showLeftShadow = _pendingLeftShadow;
        _showRightShadow = _pendingRightShadow;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scrollBehavior = ScrollConfiguration.of(
      context,
    ).copyWith(dragDevices: _dragDevices);

    return ClipRect(
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) =>
                _handleScrollMetrics(notification.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _handleScrollMetrics(notification.metrics),
              child: ScrollbarTheme(
                data: ScrollbarTheme.of(context).copyWith(
                  thumbColor: WidgetStatePropertyAll(
                    colors.primary.withValues(alpha: 0.55),
                  ),
                  thickness: const WidgetStatePropertyAll(5),
                  radius: const Radius.circular(999),
                  interactive: true,
                ),
                child: ScrollConfiguration(
                  behavior: scrollBehavior,
                  child: MarkdownBody(
                    data: widget.data,
                    selectable: false,
                    styleSheet: widget.styleSheet,
                  ),
                ),
              ),
            ),
          ),
          _TableEdgeShadow(
            key: const ValueKey('table-overflow-shadow-left'),
            visible: _showLeftShadow,
            alignment: Alignment.centerLeft,
            color: colors.shadow,
            duration: _shadowAnimationDuration,
          ),
          _TableEdgeShadow(
            key: const ValueKey('table-overflow-shadow-right'),
            visible: _showRightShadow,
            alignment: Alignment.centerRight,
            color: colors.shadow,
            duration: _shadowAnimationDuration,
          ),
        ],
      ),
    );
  }
}

class _TableEdgeShadow extends StatelessWidget {
  const _TableEdgeShadow({
    super.key,
    required this.visible,
    required this.alignment,
    required this.color,
    required this.duration,
  });

  final bool visible;
  final Alignment alignment;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Positioned(
      top: 0,
      bottom: 10,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      width: 28,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                colors: [
                  color.withValues(alpha: 0),
                  color.withValues(alpha: 0.24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownSection {
  const _MarkdownSection(this.data, {required this.isTable});

  final String data;
  final bool isTable;

  int get columnCount =>
      isTable ? _tableCells(data.split('\n').first).length : 0;
}

/// Separates top-level GFM tables without modifying their source Markdown.
/// Fenced code stays in prose so table-like examples are never made scrollable.
List<_MarkdownSection> _splitMarkdownSections(String markdown) {
  final lines = markdown.split('\n');
  final sections = <_MarkdownSection>[];
  final prose = <String>[];
  String? fenceCharacter;
  var fenceLength = 0;
  var index = 0;

  void flushProse() {
    if (prose.isEmpty) return;
    sections.add(_MarkdownSection(prose.join('\n'), isTable: false));
    prose.clear();
  }

  while (index < lines.length) {
    final fence = _fenceAt(lines[index]);
    if (fence != null) {
      if (fenceCharacter == null) {
        fenceCharacter = fence.$1;
        fenceLength = fence.$2;
      } else if (fence.$1 == fenceCharacter && fence.$2 >= fenceLength) {
        fenceCharacter = null;
        fenceLength = 0;
      }
      prose.add(lines[index]);
      index++;
      continue;
    }

    final isTableStart =
        fenceCharacter == null &&
        index + 1 < lines.length &&
        _isTableRow(lines[index]) &&
        _isDividerRow(lines[index + 1]);
    if (!isTableStart) {
      prose.add(lines[index]);
      index++;
      continue;
    }

    flushProse();
    final table = <String>[lines[index], lines[index + 1]];
    index += 2;
    while (index < lines.length && _isTableRow(lines[index])) {
      table.add(lines[index]);
      index++;
    }
    sections.add(_MarkdownSection(table.join('\n'), isTable: true));
  }

  flushProse();
  return sections;
}

(String, int)? _fenceAt(String line) {
  final trimmed = line.trimLeft();
  if (line.length - trimmed.length > 3 || trimmed.length < 3) return null;

  final character = trimmed[0];
  if (character != '`' && character != '~') return null;
  var length = 0;
  while (length < trimmed.length && trimmed[length] == character) {
    length++;
  }
  return length >= 3 ? (character, length) : null;
}

bool _isTableRow(String line) => _tableCells(line).length > 1;

bool _isDividerRow(String line) {
  final cells = _tableCells(line);
  return cells.length > 1 &&
      cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
}

List<String> _tableCells(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return const [];

  final cells = <String>[];
  final cell = StringBuffer();
  for (var index = 0; index < trimmed.length; index++) {
    final character = trimmed[index];
    if (character == '|' && !_isEscaped(trimmed, index)) {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(character);
    }
  }
  cells.add(cell.toString().trim());

  if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
  if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
  return cells;
}

bool _isEscaped(String text, int index) {
  var slashCount = 0;
  for (
    var current = index - 1;
    current >= 0 && text[current] == r'\';
    current--
  ) {
    slashCount++;
  }
  return slashCount.isOdd;
}
