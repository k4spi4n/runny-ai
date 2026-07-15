import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'ui_components.dart';

const _activityCalendarColor = Colors.green;
const _plannedCalendarColor = Color(0xFF4A82FF);

Color? _calendarStatusColor(String? status) {
  switch (status) {
    case 'last':
      return Colors.amber;
    case 'next':
      return Colors.orangeAccent;
    case 'completed':
      return Colors.greenAccent;
    case 'planned':
      return _plannedCalendarColor;
    case 'skipped':
      return Colors.grey;
    default:
      return null;
  }
}

/// Dữ liệu tối giản để biểu diễn một buổi tập hoặc hoạt động chạy trong lịch.
class TrainingCalendarEntry {
  const TrainingCalendarEntry({
    required this.date,
    required this.status,
    required this.title,
    this.targetDistanceKm,
    this.targetDurationMin,
    this.isNext = false,
    this.isLast = false,
    this.isActivity = false,
  });

  final DateTime date;
  final String status;
  final String title;
  final double? targetDistanceKm;
  final double? targetDurationMin;
  final bool isNext;
  final bool isLast;
  final bool isActivity;
}

/// Xếp tổng quan + buổi kế tiếp cạnh lịch chi tiết khi đủ chiều rộng.
class TrainingPlanResponsiveLayout extends StatelessWidget {
  const TrainingPlanResponsiveLayout({
    super.key,
    required this.calendar,
    required this.focus,
    required this.details,
    this.breakpoint = 900,
  });

  final Widget calendar;
  final Widget focus;
  final Widget details;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            key: const ValueKey('training_plan_narrow_layout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              calendar,
              const SizedBox(height: 22),
              focus,
              const SizedBox(height: 24),
              details,
            ],
          );
        }
        return Row(
          key: const ValueKey('training_plan_wide_layout'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: calendar),
            const SizedBox(width: 22),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [focus, const SizedBox(height: 24), details],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tổng quan lịch tập theo tháng, dùng cùng màu trạng thái với lịch chi tiết.
class TrainingCalendarHeatmap extends StatefulWidget {
  const TrainingCalendarHeatmap({
    super.key,
    required this.workouts,
    required this.totalPlanWorkouts,
    required this.completedPlanWorkouts,
    this.lastAiAdjustedAt,
    this.month,
    this.selectedDate,
    this.onDateSelected,
    this.progressFooter,
  });

  final List<TrainingCalendarEntry> workouts;
  final int totalPlanWorkouts;
  final int completedPlanWorkouts;
  final DateTime? lastAiAdjustedAt;
  final DateTime? month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?>? onDateSelected;
  final Widget? progressFooter;

  @override
  State<TrainingCalendarHeatmap> createState() =>
      _TrainingCalendarHeatmapState();
}

class _TrainingCalendarHeatmapState extends State<TrainingCalendarHeatmap> {
  late DateTime _visibleMonth = _monthStart(widget.month ?? DateTime.now());
  late DateTime? _selectedDate = widget.selectedDate;
  bool _showLegend = false;

  @override
  void didUpdateWidget(covariant TrainingCalendarHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != null && widget.month != oldWidget.month) {
      _visibleMonth = _monthStart(widget.month!);
    }
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate;
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
    final workoutsByDay = <DateTime, List<TrainingCalendarEntry>>{};
    for (final workout in monthWorkouts) {
      final day = DateUtils.dateOnly(workout.date);
      workoutsByDay.putIfAbsent(day, () => []).add(workout);
    }

    return glassCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: _innerGlassDecoration(
                    context,
                    borderRadius: BorderRadius.circular(15),
                    showShadow: false,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: colorScheme.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    context.translate('training_calendar_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: _innerGlassDecoration(
                    context,
                    borderRadius: BorderRadius.circular(12),
                    showShadow: false,
                  ),
                  child: IconButton(
                    key: const ValueKey('training_calendar_legend_toggle'),
                    onPressed: () => setState(() => _showLegend = !_showLegend),
                    tooltip: context.translate(
                      _showLegend
                          ? 'training_calendar_hide_legend'
                          : 'training_calendar_show_legend',
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _showLegend
                          ? Icons.visibility_off_outlined
                          : Icons.info_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (_showLegend)
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: _CalendarLegend(),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MonthArrowButton(
                  key: const ValueKey('training_calendar_previous_month'),
                  icon: Icons.chevron_left_rounded,
                  onPressed: () => _changeMonth(-1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', locale).format(firstDay),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MonthArrowButton(
                  key: const ValueKey('training_calendar_next_month'),
                  icon: Icons.chevron_right_rounded,
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GlassSurface(
              key: const ValueKey('training_calendar_grid_glass'),
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 5.0;
                  final cellWidth = ((constraints.maxWidth - (spacing * 6)) / 7)
                      .clamp(0.0, 50.0);
                  final calendarWidth = (cellWidth * 7) + (spacing * 6);
                  final cells = <Widget>[];
                  for (var index = 0; index < firstDay.weekday - 1; index++) {
                    cells.add(
                      SizedBox(width: cellWidth, height: cellWidth + 7),
                    );
                  }
                  for (var day = 1; day <= lastDay.day; day++) {
                    final date = DateTime(firstDay.year, firstDay.month, day);
                    cells.add(
                      _CalendarDay(
                        date: date,
                        entries: workoutsByDay[date] ?? const [],
                        size: cellWidth,
                        isSelected: DateUtils.isSameDay(date, _selectedDate),
                        onTap: () => _selectDate(date),
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
                  lastAiAdjustedAt: widget.lastAiAdjustedAt,
                ),
              ),
              if (widget.progressFooter != null) ...[
                const SizedBox(height: 10),
                widget.progressFooter!,
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      _selectedDate = null;
    });
    widget.onDateSelected?.call(null);
  }

  void _selectDate(DateTime date) {
    final selection = DateUtils.isSameDay(date, _selectedDate) ? null : date;
    setState(() => _selectedDate = selection);
    widget.onDateSelected?.call(selection);
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
    color: isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.36),
    borderRadius: borderRadius,
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.11)
          : Colors.white.withValues(alpha: 0.56),
      width: 1,
    ),
    boxShadow: showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.025),
              blurRadius: 8,
              offset: const Offset(0, 4),
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

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: _innerGlassDecoration(
        context,
        borderRadius: BorderRadius.circular(12),
        showShadow: false,
      ),
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: colorScheme.onSurfaceVariant),
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
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final List<TrainingCalendarEntry> entries;
  final double size;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final scheduledEntries = entries
        .where((entry) => !entry.isActivity)
        .toList();
    final hasActivity = entries.any((entry) => entry.isActivity);
    final status = _statusFor(scheduledEntries);
    final statusFill = _calendarStatusColor(status);
    final fill =
        statusFill ?? (isDark && hasActivity ? _activityCalendarColor : null);
    final foreground = isDark
        ? Colors.white
        : status == 'completed' || status == 'last'
        ? Colors.black87
        : Colors.white;
    final activityForeground = isDark
        ? Colors.white
        : statusFill == null
        ? Colors.green
        : foreground;
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
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey(
              'training_calendar_day_${DateFormat('yyyy-MM-dd').format(date)}',
            ),
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Ink(
              width: size,
              height: size + 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: fill == null
                      ? [
                          Colors.white.withValues(alpha: isDark ? 0.07 : 0.5),
                          colorScheme.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.18 : 0.32,
                          ),
                        ]
                      : isDark
                      ? [fill, Color.lerp(fill, Colors.white, 0.18)!]
                      : [
                          fill.withValues(alpha: 0.96),
                          Color.lerp(fill, Colors.black, 0.14)!,
                        ],
                ),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : isToday
                      ? colorScheme.primary.withValues(alpha: 0.72)
                      : entries.isEmpty
                      ? Colors.white.withValues(alpha: isDark ? 0.09 : 0.62)
                      : Colors.white.withValues(alpha: 0.2),
                  width: isSelected ? 2.4 : (isToday ? 1.8 : 1),
                ),
                boxShadow: fill == null
                    ? null
                    : [
                        BoxShadow(
                          color: fill.withValues(alpha: isDark ? 0.12 : 0.22),
                          blurRadius: isDark ? 6 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
                      child: Text(
                        '${date.day}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? Colors.white
                              : fill == null
                              ? colorScheme.onSurface
                              : foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (status != null || hasActivity)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 5, 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasActivity)
                              Icon(
                                Icons.check_circle,
                                color: activityForeground,
                                size: 15,
                              ),
                            if (hasActivity && status != null)
                              const SizedBox(width: 1),
                            if (status != null)
                              Icon(
                                _statusIcon(status),
                                color: foreground,
                                size: 15,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _statusFor(List<TrainingCalendarEntry> entries) {
    if (entries.isEmpty) return null;
    if (entries.any((entry) => entry.status == 'completed')) {
      return 'completed';
    }
    if (entries.any((entry) => entry.isLast)) return 'last';
    if (entries.any((entry) => entry.isNext)) return 'next';
    if (entries.every((entry) => entry.status == 'skipped')) return 'skipped';
    return 'planned';
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'last':
        return Icons.military_tech;
      case 'next':
        return Icons.directions_run;
      case 'completed':
        return Icons.directions_run;
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
    this.lastAiAdjustedAt,
  });

  final int completedWorkouts;
  final int totalWorkouts;
  final DateTime? lastAiAdjustedAt;

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
        if (lastAiAdjustedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.translate('last_ai_plan_adjustment', [
                    DateFormat.yMd(
                      Localizations.localeOf(context).languageCode,
                    ).add_Hm().format(lastAiAdjustedAt!.toLocal()),
                  ]),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
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
          key: const ValueKey('training_calendar_legend_activity'),
          color: _activityCalendarColor,
          icon: Icons.check_circle,
          label: context.translate('training_calendar_has_activity'),
          style: textStyle,
        ),
        _LegendItem(
          key: const ValueKey('training_calendar_legend_next'),
          color: _calendarStatusColor('next')!,
          icon: Icons.directions_run,
          label: context.translate('training_calendar_next_workout'),
          style: textStyle,
        ),
        _LegendItem(
          key: const ValueKey('training_calendar_legend_last'),
          color: _calendarStatusColor('last')!,
          icon: Icons.military_tech,
          label: context.translate('training_calendar_last_workout'),
          style: textStyle,
        ),
        _LegendItem(
          key: const ValueKey('training_calendar_legend_planned'),
          color: _calendarStatusColor('planned')!,
          icon: Icons.directions_run,
          label: context.translate('status_planned'),
          style: textStyle,
        ),
        _LegendItem(
          key: const ValueKey('training_calendar_legend_completed'),
          color: _calendarStatusColor('completed')!,
          icon: Icons.directions_run,
          label: context.translate('status_completed'),
          style: textStyle,
        ),
        _LegendItem(
          key: const ValueKey('training_calendar_legend_skipped'),
          color: _calendarStatusColor('skipped')!,
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
    super.key,
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
              lastAiAdjustedAt: today.subtract(const Duration(hours: 2)),
              workouts: [
                TrainingCalendarEntry(
                  date: today.subtract(const Duration(days: 3)),
                  status: 'completed',
                  title: 'Easy run',
                  targetDistanceKm: 6,
                ),
                TrainingCalendarEntry(
                  date: today.subtract(const Duration(days: 3)),
                  status: 'activity',
                  title: 'Recorded activity',
                  targetDistanceKm: 6,
                  isActivity: true,
                ),
                TrainingCalendarEntry(
                  date: today,
                  status: 'activity',
                  title: 'Activity without a linked workout',
                  targetDistanceKm: 5,
                  isActivity: true,
                ),
                TrainingCalendarEntry(
                  date: today.add(const Duration(days: 2)),
                  status: 'planned',
                  title: 'Tempo run',
                  targetDurationMin: 50,
                  isNext: true,
                ),
                TrainingCalendarEntry(
                  date: today.add(const Duration(days: 5)),
                  status: 'rescheduled',
                  title: 'Long run',
                  targetDistanceKm: 18,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

@Preview(
  name: 'Training plan two-column - Dark',
  group: 'Training',
  size: Size(1180, 760),
  brightness: Brightness.dark,
)
Widget trainingPlanWideLayoutPreview() {
  final today = DateTime.now();
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A82FF),
        brightness: Brightness.dark,
      ),
    ),
    themeMode: ThemeMode.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: TrainingPlanResponsiveLayout(
            calendar: TrainingCalendarHeatmap(
              month: today,
              totalPlanWorkouts: 8,
              completedPlanWorkouts: 3,
              workouts: [
                TrainingCalendarEntry(
                  date: today,
                  status: 'activity',
                  title: 'Chạy tự do 5 km',
                  isActivity: true,
                ),
                TrainingCalendarEntry(
                  date: today.add(const Duration(days: 2)),
                  status: 'planned',
                  title: 'Tempo 45 phút',
                  isNext: true,
                ),
              ],
            ),
            focus: _TrainingPlanPreviewPanel(
              title: 'Buổi tập tiếp theo',
              subtitle: 'Tempo 45 phút · 8 km',
              color: Colors.orangeAccent,
            ),
            details: const _TrainingPlanPreviewPanel(
              title: 'Lịch trình chi tiết',
              subtitle: 'Các buổi tập còn lại trong kế hoạch',
              color: Color(0xFF4A82FF),
              height: 360,
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrainingPlanPreviewPanel extends StatelessWidget {
  const _TrainingPlanPreviewPanel({
    required this.title,
    required this.subtitle,
    required this.color,
    this.height = 150,
  });

  final String title;
  final String subtitle;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return glassCard(
      context: context,
      child: SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.directions_run, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
