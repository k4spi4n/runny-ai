import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'ui_components.dart';

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

    return glassCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.2),
                    colorScheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -95,
            left: -60,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.14),
                    colorScheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackSummary = constraints.maxWidth < 340;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: secondaryPulseGradient,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4A82FF,
                                    ).withValues(alpha: 0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.translate(
                                      'training_calendar_title',
                                    ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    decoration: _innerGlassDecoration(
                                      context,
                                      borderRadius: BorderRadius.circular(10),
                                      showShadow: false,
                                    ),
                                    child: InkWell(
                                      key: const ValueKey(
                                        'training_calendar_month_picker',
                                      ),
                                      onTap: _pickMonth,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                          horizontal: 8,
                                        ),
                                        child: FittedBox(
                                          alignment: Alignment.centerLeft,
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                DateFormat(
                                                  'MMMM yyyy',
                                                  locale,
                                                ).format(firstDay),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(
                                                Icons.expand_more_rounded,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!stackSummary) ...[
                              const SizedBox(width: 8),
                              _CalendarSummary(
                                workoutCount: monthWorkouts.length,
                                completedCount: completedCount,
                              ),
                            ],
                          ],
                        ),
                        if (stackSummary) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _CalendarSummary(
                              workoutCount: monthWorkouts.length,
                              completedCount: completedCount,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _GlassSurface(
                  key: const ValueKey('training_calendar_grid_glass'),
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 5.0;
                      final cellWidth =
                          ((constraints.maxWidth - (spacing * 6)) / 7).clamp(
                            0.0,
                            48.0,
                          );
                      final calendarWidth = (cellWidth * 7) + (spacing * 6);
                      final cells = <Widget>[];
                      for (
                        var index = 0;
                        index < firstDay.weekday - 1;
                        index++
                      ) {
                        cells.add(
                          SizedBox(width: cellWidth, height: cellWidth),
                        );
                      }
                      for (var day = 1; day <= lastDay.day; day++) {
                        final date = DateTime(
                          firstDay.year,
                          firstDay.month,
                          day,
                        );
                        cells.add(
                          _CalendarDay(
                            date: date,
                            entries: workoutsByDay[date] ?? const [],
                            size: cellWidth,
                          ),
                        );
                      }
                      return Align(
                        alignment: Alignment.center,
                        child: SizedBox(
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
                        ),
                      );
                    },
                  ),
                ),
                if (widget.totalPlanWorkouts > 0) ...[
                  const SizedBox(height: 12),
                  _GlassSurface(
                    padding: const EdgeInsets.all(12),
                    child: _PlanProgress(
                      completedWorkouts: widget.completedPlanWorkouts,
                      totalWorkouts: widget.totalPlanWorkouts,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const _CalendarLegend(),
              ],
            ),
          ),
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

BoxDecoration _innerGlassDecoration(
  BuildContext context, {
  required BorderRadius borderRadius,
  bool showShadow = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.045),
            ]
          : [
              Colors.white.withValues(alpha: 0.88),
              Colors.white.withValues(alpha: 0.5),
            ],
    ),
    borderRadius: borderRadius,
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.72),
      width: 1,
    ),
    boxShadow: showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.13 : 0.055),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ]
        : null,
  );
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: _innerGlassDecoration(
        context,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({
    required this.workoutCount,
    required this.completedCount,
  });

  final int workoutCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _innerGlassDecoration(
        context,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        context.translate('training_calendar_summary', [
          workoutCount.toString(),
          completedCount.toString(),
        ]),
        textAlign: TextAlign.end,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fill == null
                  ? [
                      Colors.white.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.07 : 0.5,
                      ),
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.18
                            : 0.32,
                      ),
                    ]
                  : [
                      fill.withValues(alpha: 0.96),
                      Color.lerp(fill, Colors.black, 0.14)!,
                    ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday
                  ? colorScheme.primary
                  : entries.isEmpty
                  ? Colors.white.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.09 : 0.62,
                    )
                  : Colors.white.withValues(alpha: 0.2),
              width: isToday ? 1.8 : 1,
            ),
            boxShadow: fill == null
                ? null
                : [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
            Expanded(
              child: Text(
                context.translate('workout_progress', [
                  completedWorkouts.toString(),
                  totalWorkouts.toString(),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
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
    final iconColor = color.computeLuminance() > 0.58
        ? Colors.black87
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: _innerGlassDecoration(
        context,
        borderRadius: BorderRadius.circular(99),
        showShadow: false,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 6),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 12),
          ),
          const SizedBox(width: 6),
          Text(label, style: style),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Training calendar glass - Light',
  group: 'Training',
  size: Size(430, 620),
  brightness: Brightness.light,
)
@Preview(
  name: 'Training calendar glass - Dark',
  group: 'Training',
  size: Size(430, 620),
  brightness: Brightness.dark,
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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A82FF)),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A82FF),
        brightness: Brightness.dark,
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
          child: Padding(
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
      ),
    ),
  );
}
