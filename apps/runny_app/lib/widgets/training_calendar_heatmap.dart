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
    this.isNext = false,
    this.isLast = false,
  });

  final DateTime date;
  final String status;
  final String title;
  final double? targetDistanceKm;
  final double? targetDurationMin;
  final bool isNext;
  final bool isLast;
}

/// Tổng quan lịch tập theo tháng, dùng cùng màu trạng thái với lịch chi tiết.
class TrainingCalendarHeatmap extends StatefulWidget {
  const TrainingCalendarHeatmap({
    super.key,
    required this.workouts,
    required this.totalPlanWorkouts,
    required this.completedPlanWorkouts,
    this.month,
    this.selectedDate,
    this.onDateSelected,
  });

  final List<TrainingCalendarEntry> workouts;
  final int totalPlanWorkouts;
  final int completedPlanWorkouts;
  final DateTime? month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?>? onDateSelected;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.translate('training_calendar_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        decoration: _innerGlassDecoration(
                          context,
                          borderRadius: BorderRadius.circular(10),
                          showShadow: false,
                        ),
                        child: InkWell(
                          key: const ValueKey('training_calendar_month_picker'),
                          onTap: _pickMonth,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    DateFormat(
                                      'MMMM yyyy',
                                      locale,
                                    ).format(firstDay),
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.expand_more_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
            const SizedBox(height: 16),
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
                ),
              ),
            ],
            if (_showLegend)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _CalendarLegend(),
              ),
          ],
        ),
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
      setState(() {
        _visibleMonth = _monthStart(selection);
        _selectedDate = null;
      });
      widget.onDateSelected?.call(null);
    }
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
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final status = _statusFor(entries);
    final fill = _fillColor(status);
    final foreground = status == 'completed' || status == 'last'
        ? Colors.black87
        : Colors.white;
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
                          Colors.white.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.07
                                : 0.5,
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
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : isToday
                      ? colorScheme.primary.withValues(alpha: 0.72)
                      : entries.isEmpty
                      ? Colors.white.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.09
                              : 0.62,
                        )
                      : Colors.white.withValues(alpha: 0.2),
                  width: isSelected ? 2.4 : (isToday ? 1.8 : 1),
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
                      padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
                      child: Text(
                        '${date.day}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fill == null
                              ? colorScheme.onSurface
                              : foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (status != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 5, 5),
                        child: Icon(
                          _statusIcon(status),
                          color: foreground,
                          size: 15,
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
    if (entries.any((entry) => entry.isLast)) return 'last';
    if (entries.any((entry) => entry.status == 'completed')) {
      return 'completed';
    }
    if (entries.any((entry) => entry.isNext)) return 'next';
    const priority = ['completed', 'rescheduled', 'planned', 'skipped'];
    for (final status in priority) {
      if (entries.any((entry) => entry.status == status)) return status;
    }
    return 'planned';
  }

  Color? _fillColor(String? status) {
    switch (status) {
      case 'last':
        return Colors.amber;
      case 'next':
        return Colors.orangeAccent;
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
      case 'last':
        return Icons.military_tech;
      case 'next':
        return Icons.directions_run;
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
          color: Colors.orangeAccent,
          icon: Icons.directions_run,
          label: context.translate('training_calendar_next_workout'),
          style: textStyle,
        ),
        _LegendItem(
          color: Colors.amber,
          icon: Icons.military_tech,
          label: context.translate('training_calendar_last_workout'),
          style: textStyle,
        ),
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
