import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Dữ liệu tối giản để biểu diễn một buổi tập hoặc hoạt động chạy trong lịch.
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
}

/// Tổng quan lịch tập theo tháng, dùng cùng màu trạng thái với lịch chi tiết.
class TrainingCalendarHeatmap extends StatefulWidget {
  const TrainingCalendarHeatmap({
    super.key,
    required this.workouts,
    required this.totalPlanWorkouts,
    required this.completedPlanWorkouts,
    this.month,
  });

  final List<TrainingCalendarEntry> workouts;
  final int totalPlanWorkouts;
  final int completedPlanWorkouts;
  final DateTime? month;

  @override
  State<TrainingCalendarHeatmap> createState() =>
      _TrainingCalendarHeatmapState();
}

class _TrainingCalendarHeatmapState extends State<TrainingCalendarHeatmap> {
  late DateTime _visibleMonth = _monthStart(widget.month ?? DateTime.now());

  @override
  void didUpdateWidget(covariant TrainingCalendarHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != null && widget.month != oldWidget.month) {
      _visibleMonth = _monthStart(widget.month!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstDay = _visibleMonth;
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthWorkouts = widget.workouts
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
                    InkWell(
                      key: const ValueKey('training_calendar_month_picker'),
                      onTap: _pickMonth,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy', locale).format(firstDay),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                decoration: TextDecoration.underline,
                                decorationColor: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.expand_more_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                          ],
                        ),
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
          if (widget.totalPlanWorkouts > 0) ...[
            const SizedBox(height: 16),
            _PlanProgress(
              completedWorkouts: widget.completedPlanWorkouts,
              totalWorkouts: widget.totalPlanWorkouts,
            ),
          ],
          const SizedBox(height: 14),
          const _CalendarLegend(),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final selection = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: context.translate('training_calendar_pick_month'),
    );
    if (selection != null && mounted) {
      setState(() => _visibleMonth = _monthStart(selection));
    }
  }

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);
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
    final status = _statusFor(entries);
    final fill = _fillColor(status);
    final foreground = status == 'completed' ? Colors.black87 : Colors.white;
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
            color:
                fill ??
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
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
                      color: fill == null ? colorScheme.onSurface : foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (status != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _statusIcon(status),
                      color: foreground,
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

  String? _statusFor(List<TrainingCalendarEntry> entries) {
    if (entries.isEmpty) return null;
    const priority = ['completed', 'rescheduled', 'planned', 'skipped'];
    for (final status in priority) {
      if (entries.any((entry) => entry.status == status)) return status;
    }
    return 'planned';
  }

  Color? _fillColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'rescheduled':
        return Colors.orangeAccent;
      case 'planned':
        return const Color(0xFF4A82FF);
      case 'skipped':
        return Colors.grey;
      default:
        return null;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'rescheduled':
        return Icons.update;
      case 'skipped':
        return Icons.pause_circle;
      default:
        return Icons.directions_run;
    }
  }
}

class _PlanProgress extends StatelessWidget {
  const _PlanProgress({
    required this.completedWorkouts,
    required this.totalWorkouts,
  });

  final int completedWorkouts;
  final int totalWorkouts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (completedWorkouts / totalWorkouts)
        .clamp(0.0, 1.0)
        .toDouble();
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_run,
              color: const Color(0xFF4A82FF),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              context.translate('workout_progress', [
                completedWorkouts.toString(),
                totalWorkouts.toString(),
              ]),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: const Color(0xFF4A82FF),
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

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
          color: const Color(0xFF4A82FF),
          icon: Icons.directions_run,
          label: context.translate('status_planned'),
          style: textStyle,
        ),
        _LegendItem(
          color: Colors.orangeAccent,
          icon: Icons.update,
          label: context.translate('status_rescheduled'),
          style: textStyle,
        ),
        _LegendItem(
          color: Colors.greenAccent,
          icon: Icons.check_circle,
          label: context.translate('status_completed'),
          style: textStyle,
        ),
        _LegendItem(
          color: Colors.grey,
          icon: Icons.pause_circle,
          label: context.translate('status_skipped'),
          style: textStyle,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    this.style,
  });

  final Color color;
  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.black87, size: 12),
        ),
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );
  }
}

@Preview(
  name: 'Training calendar overview',
  group: 'Training',
  size: Size(430, 520),
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
          totalPlanWorkouts: 8,
          completedPlanWorkouts: 3,
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
              status: 'rescheduled',
              title: 'Long run',
              targetDistanceKm: 18,
            ),
          ],
        ),
      ),
    ),
  );
}
