/// Converts GitHub-flavored Markdown tables into stacked entries for narrow
/// chat bubbles, where several table columns would otherwise become unreadable.
class MarkdownTableFormatter {
  const MarkdownTableFormatter._();

  /// Replaces every well-formed Markdown table in [markdown] with labelled
  /// entries. Content outside tables, and incomplete tables, is left intact.
  static String toMobileCards(String markdown) {
    final lines = markdown.split('\n');
    final output = <String>[];
    var index = 0;

    while (index < lines.length) {
      if (index + 2 < lines.length &&
          _isTableRow(lines[index]) &&
          _isDividerRow(lines[index + 1])) {
        final headers = _cells(lines[index]);
        final rows = <List<String>>[];
        var rowIndex = index + 2;

        while (rowIndex < lines.length && _isTableRow(lines[rowIndex])) {
          final row = _cells(lines[rowIndex]);
          if (row.length == headers.length) {
            rows.add(row);
          } else {
            break;
          }
          rowIndex++;
        }

        if (rows.isNotEmpty) {
          output.addAll(_asCards(headers, rows));
          index = rowIndex;
          continue;
        }
      }

      output.add(lines[index]);
      index++;
    }

    return output.join('\n');
  }

  static bool _isTableRow(String line) {
    return line.contains('|') && _cells(line).length > 1;
  }

  static bool _isDividerRow(String line) {
    final cells = _cells(line);
    return cells.length > 1 &&
        cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
  }

  static List<String> _cells(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.split('|').map((cell) => cell.trim()).toList();
  }

  static List<String> _asCards(List<String> headers, List<List<String>> rows) {
    final cards = <String>[];
    for (final row in rows) {
      if (cards.isNotEmpty) {
        cards.add('');
        cards.add('---');
        cards.add('');
      }
      for (var column = 0; column < headers.length; column++) {
        cards.add('**${headers[column]}:** ${row[column]}');
      }
    }
    return cards;
  }
}
