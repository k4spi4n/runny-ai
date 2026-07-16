import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../models/workout_models.dart';
import '../theme/app_theme.dart';
import '../utils/activity_formatters.dart';
import 'ui_components.dart';

/// Hero summary for an activity, inspired by the information hierarchy of
/// modern running apps while retaining Runny AI's glass-and-gradient identity.
class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({
    super.key,
    required this.activity,
    required this.timeRange,
  });

  final Activity activity;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return glassCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colors.primary.withValues(alpha: 0.32),
                        colors.secondary.withValues(alpha: 0.16),
                        colors.surface.withValues(alpha: 0.34),
                      ]
                    : [
                        colors.primary.withValues(alpha: 0.18),
                        colors.secondary.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.40),
                      ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: colors.outline.withValues(alpha: 0.28),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: colors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.translate('run_activity').toUpperCase(),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final titleSize = constraints.maxWidth >= 680 ? 34.0 : 28.0;
                    return Text(
                      activity.name ??
                          activity.notes ??
                          context.translate('activity_details'),
                      key: const ValueKey('activity_summary_title'),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: titleSize,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        timeRange,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 3 : 2;
                const gap = 12.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                final metrics = _metrics(context);

                return Wrap(
                  key: ValueKey('activity_summary_grid_$columns'),
                  spacing: gap,
                  runSpacing: gap,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: tileWidth,
                          child: _ActivityMetricTile(metric: metric),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_ActivityMetric> _metrics(BuildContext context) {
    final pace = activity.distanceKm > 0
        ? formatPace(activity.durationMin / activity.distanceKm)
        : '-:--';
    return [
      _ActivityMetric(
        keyName: 'distance',
        icon: Icons.straighten_rounded,
        label: context.translate('distance'),
        value:
            '${activity.distanceKm.toStringAsFixed(2)} ${context.translate('km')}',
      ),
      _ActivityMetric(
        keyName: 'pace',
        icon: Icons.speed_rounded,
        label: context.translate('avg_pace'),
        value: '$pace ${context.translate('min_km')}',
      ),
      _ActivityMetric(
        keyName: 'duration',
        icon: Icons.timer_outlined,
        label: context.translate('duration'),
        value: formatDurationMinutes(activity.durationMin),
      ),
      _ActivityMetric(
        keyName: 'elevation',
        icon: Icons.terrain_rounded,
        label: context.translate('elevation_gain'),
        value:
            '${activity.elevationGainM?.toStringAsFixed(0) ?? '--'} ${context.translate('m')}',
      ),
      _ActivityMetric(
        keyName: 'heart_rate',
        icon: Icons.favorite_outline_rounded,
        label: context.translate('avg_hr'),
        value: activity.avgHr == null
            ? '--'
            : '${activity.avgHr} ${context.translate('bpm')}',
      ),
      _ActivityMetric(
        keyName: 'cadence',
        icon: Icons.directions_run_outlined,
        label: context.translate('avg_cadence'),
        value: activity.avgCadence == null
            ? '--'
            : '${activity.avgCadence} ${context.translate('spm')}',
      ),
    ];
  }
}

class _ActivityMetric {
  const _ActivityMetric({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final String value;
}

class _ActivityMetricTile extends StatelessWidget {
  const _ActivityMetricTile({required this.metric});

  final _ActivityMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: ValueKey('activity_metric_${metric.keyName}'),
      height: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outline.withValues(alpha: isDark ? 0.70 : 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(metric.icon, size: 16, color: colors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Activity summary - mobile light',
  group: 'Activity details',
  size: Size(390, 720),
  brightness: Brightness.light,
)
@Preview(
  name: 'Activity summary - mobile dark',
  group: 'Activity details',
  size: Size(390, 720),
  brightness: Brightness.dark,
)
@Preview(
  name: 'Activity summary - desktop',
  group: 'Activity details',
  size: Size(980, 540),
  brightness: Brightness.dark,
)
Widget activitySummaryCardPreview() {
  final activity = Activity(
    userId: 'preview-user',
    startedAt: DateTime(2026, 7, 15, 19, 36),
    distanceKm: 7.89,
    durationMin: 42 + 28 / 60,
    avgHr: 152,
    avgCadence: 178,
    elevationGainM: 36,
    name: 'Chạy bộ buổi tối',
  );

  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: _ActivitySummaryPreviewShell(activity: activity),
  );
}

class _ActivitySummaryPreviewShell extends StatelessWidget {
  const _ActivitySummaryPreviewShell({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ActivitySummaryCard(
            activity: activity,
            timeRange: '19:36 - 20:18 15/07/2026',
          ),
        ),
      ),
    );
  }
}
