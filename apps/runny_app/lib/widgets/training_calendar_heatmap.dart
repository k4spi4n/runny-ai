import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Dữ liệu tối giản để biểu diễn một buổi tập trong lịch nhiệt theo tháng.
class TrainingCalendarEntry {
  const TrainingCalendarEntry({
    required this.date,
    required this.status,
    required this.title,
    this.targetDistanceKm,
    this.targetDurationMin,
  });

  final DateTime date;
  final String status;
  final String title;
  final double? targetDistanceKm;
  final double? targetDurationMin;

  int get loadLevel {
    final distance = targetDistanceKm ?? 0;
    final duration = targetDurationMin ?? 0;
    if (distance >= 16 || duration >= 100) return 4;
    if (distance >= 10 || duration >= 60) return 3;
    if (distance >= 5 || duration >= 30) return 2;
    return 1;
  }
}

/// Một lịch tháng gọn như heatmap, nhưng ưu tiên tải tập và tiến độ runner.
class TrainingCalendarHeatmap extends StatelessWidget {
  const TrainingCalendarHeatmap({
    super.key,
    required this.workouts,
    this.month,
  });

  final List<TrainingCalendarEntry> workouts;
  final DateTime? month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMonth = month ?? DateTime.now();
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthWorkouts = workouts
        .where(
          (workout) =>
              workout.date.year == firstDay.year &&
              workout.date.month == firstDay.month,
        )
        .toList();
    final completedCount = monthWorkouts
        .where((workout) => workout.status == 'completed')
        .length;
    final workoutsByDay = <DateTime, List<TrainingCalendarEntry>>{};
    for (final workout in monthWorkouts) {
      final day = DateUtils.dateOnly(workout.date);
      workoutsByDay.putIfAbsent(day, () => []).add(workout);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: colorScheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('training_calendar_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMMM yyyy', locale).format(firstDay),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.translate('training_calendar_summary', [
                  monthWorkouts.length.toString(),
                  completedCount.toString(),
                ]),
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 5.0;
              final cellWidth = ((constraints.maxWidth - (spacing * 6)) / 7)
                  .clamp(0.0, 48.0);
              final calendarWidth = (cellWidth * 7) + (spacing * 6);
              final cells = <Widget>[];
              for (var index = 0; index < firstDay.weekday - 1; index++) {
                cells.add(SizedBox(width: cellWidth, height: cellWidth));
              }
              for (var day = 1; day <= lastDay.day; day++) {
                final date = DateTime(firstDay.year, firstDay.month, day);
                cells.add(
                  _CalendarDay(
                    date: date,
                    entries: workoutsByDay[date] ?? const [],
                    size: cellWidth,
                  ),
                );
              }
              return SizedBox(
                width: calendarWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WeekdayHeader(
                      languageCode: Localizations.localeOf(
                        context,
                      ).languageCode,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: cells,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _CalendarLegend(),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final labels = languageCode == 'vi'
        ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Text(label, textAlign: TextAlign.center, style: style),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.entries,
    required this.size,
  });

  final DateTime date;
  final List<TrainingCalendarEntry> entries;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final isCompleted =
        entries.isNotEmpty &&
        entries.every((entry) => entry.status == 'completed');
    final isSkipped =
        entries.isNotEmpty &&
        entries.every((entry) => entry.status == 'skipped');
    final level = entries.isEmpty
        ? 0
        : entries
              .fold<int>(0, (total, entry) => total + entry.loadLevel)
              .clamp(1, 4);
    final fill = _fillColor(
      colorScheme: colorScheme,
      level: level,
      isCompleted: isCompleted,
      isSkipped: isSkipped,
    );
    final dateText = DateFormat(
      'EEE, d MMM',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
    final details = entries.isEmpty
        ? context.translate('training_calendar_rest')
        : entries.map((entry) => entry.title).join(' • ');

    return Tooltip(
      message: '$dateText: $details',
      child: Semantics(
        label: '$dateText: $details',
        child: Container(
          key: ValueKey(
            'training_calendar_day_${DateFormat('yyyy-MM-dd').format(date)}',
          ),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday
                  ? colorScheme.primary
                  : entries.isEmpty
                  ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: isToday ? 1.8 : 1,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    '${date.day}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: level >= 3 && !isSkipped
                          ? Colors.white
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (isCompleted)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                )
              else if (isSkipped)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.remove_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fillColor({
    required ColorScheme colorScheme,
    required int level,
    required bool isCompleted,
    required bool isSkipped,
  }) {
    if (level == 0) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    }
    if (isSkipped) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    }
    final base = isCompleted ? const Color(0xFF1DAA77) : colorScheme.primary;
    const opacities = [0.0, 0.24, 0.42, 0.66, 0.9];
    return base.withValues(alpha: opacities[level]);
  }
}

class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
          label: context.translate('training_calendar_rest'),
          style: textStyle,
        ),
        _LegendItem(
          color: colorScheme.primary.withValues(alpha: 0.3),
          label: context.translate('training_calendar_light'),
          style: textStyle,
        ),
        _LegendItem(
          color: colorScheme.primary.withValues(alpha: 0.9),
          label: context.translate('training_calendar_heavy'),
          style: textStyle,
        ),
        _LegendItem(
          color: const Color(0xFF1DAA77).withValues(alpha: 0.76),
          label: context.translate('training_calendar_completed'),
          style: textStyle,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.style});

  final Color color;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );
  }
}

@Preview(
  name: 'Training calendar heatmap',
  group: 'Training',
  size: Size(430, 470),
)
Widget trainingCalendarHeatmapPreview() {
  final today = DateTime.now();
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TrainingCalendarHeatmap(
          workouts: [
            TrainingCalendarEntry(
              date: today.subtract(const Duration(days: 3)),
              status: 'completed',
              title: 'Easy run',
              targetDistanceKm: 6,
            ),
            TrainingCalendarEntry(
              date: today.add(const Duration(days: 2)),
              status: 'planned',
              title: 'Tempo run',
              targetDurationMin: 50,
            ),
            TrainingCalendarEntry(
              date: today.add(const Duration(days: 5)),
              status: 'planned',
              title: 'Long run',
              targetDistanceKm: 18,
            ),
          ],
        ),
      ),
    ),
  );
}
