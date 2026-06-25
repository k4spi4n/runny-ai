import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/weight_models.dart';
import '../services/weight_service.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';

class WeightTrackingPage extends StatefulWidget {
  const WeightTrackingPage({super.key});

  @override
  State<WeightTrackingPage> createState() => _WeightTrackingPageState();
}

class _WeightTrackingPageState extends State<WeightTrackingPage> {
  final _service = WeightService();
  late Future<_WeightData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WeightData> _load() async {
    final results = await Future.wait([
      _service.fetchGoal(),
      _service.fetchLogs(),
    ]);
    return _WeightData(
      goal: results[0] as WeightGoal,
      logs: results[1] as List<WeightLog>,
    );
  }

  void _refresh() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.translate('weight_tracking'))),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: sportPlatformGradient(context),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<_WeightData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${context.translate('error')}: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                final data = snapshot.data!;
                final onSurface = Theme.of(context).colorScheme.onSurface;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GoalCard(goal: data.goal, onEditGoal: _editGoal),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logWeight,
                          style: primaryActionButton(context),
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(context.translate('log_weight_today')),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (data.logs.length >= 2) ...[
                        Text(
                          context.translate('weight_trend'),
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _WeightChart(logs: data.logs, target: data.goal.target),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        context.translate('history'),
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (data.logs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              context.translate('empty_weight_logs'),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ...data.logs.reversed.map(
                          (log) => _LogTile(
                            log: log,
                            onDelete: () => _deleteLog(log),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logWeight() async {
    final result = await _showWeightDialog(
      title: context.translate('log_weight'),
      label: context.translate('weight'),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.translate('weight_saved');
    final errorPrefix = context.translate('error');
    try {
      await _service.logWeight(result);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
    }
  }

  Future<void> _editGoal(WeightGoal goal) async {
    final result = await _showGoalDialog(goal);
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.translate('goal_updated');
    final errorPrefix = context.translate('error');
    try {
      await _service.setGoal(targetWeight: result.$1, startWeight: result.$2);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
    }
  }

  Future<void> _deleteLog(WeightLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.translate('weight_log_deleted');
    final errorPrefix = context.translate('error');
    try {
      await _service.deleteLog(log.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
    }
  }

  Future<double?> _showWeightDialog({
    required String title,
    required String label,
  }) {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: themedInputDecoration(
            context,
            label,
            suffixText: 'kg',
            icon: Icons.monitor_weight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            style: primaryActionButton(context),
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(context.translate('save')),
          ),
        ],
      ),
    );
  }

  Future<(double, double?)?> _showGoalDialog(WeightGoal goal) {
    final targetController = TextEditingController(
      text: goal.target?.toStringAsFixed(1) ?? '',
    );
    final startController = TextEditingController(
      text: (goal.start ?? goal.current)?.toStringAsFixed(1) ?? '',
    );
    return showDialog<(double, double?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('weight_goal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: themedInputDecoration(
                context,
                context.translate('start_weight'),
                suffixText: 'kg',
                icon: Icons.flag,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: themedInputDecoration(
                context,
                context.translate('target_weight'),
                suffixText: 'kg',
                icon: Icons.emoji_events,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            style: primaryActionButton(context),
            onPressed: () {
              final target = double.tryParse(targetController.text);
              final start = double.tryParse(startController.text);
              if (target == null) return;
              Navigator.pop(context, (target, start));
            },
            child: Text(context.translate('save_goal')),
          ),
        ],
      ),
    );
  }
}

class _WeightData {
  final WeightGoal goal;
  final List<WeightLog> logs;
  _WeightData({required this.goal, required this.logs});
}

class _GoalCard extends StatelessWidget {
  final WeightGoal goal;
  final void Function(WeightGoal) onEditGoal;
  const _GoalCard({required this.goal, required this.onEditGoal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!goal.hasGoal) {
      return glassCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate('no_weight_goal'),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.translate('weight_goal_empty_desc'),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onEditGoal(goal),
                style: primaryActionButton(context),
                icon: const Icon(Icons.flag, size: 18),
                label: Text(context.translate('create_goal')),
              ),
            ),
          ],
        ),
      );
    }

    final reached = goal.reached;
    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.translate('goal_progress'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onEditGoal(goal),
                icon: Icon(Icons.edit, color: cs.onSurfaceVariant, size: 20),
                tooltip: context.translate('edit_goal'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _stat(
                  context,
                  context.translate('start_weight_short'),
                  '${goal.start!.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  context.translate('current_weight'),
                  '${goal.current!.toStringAsFixed(1)} kg',
                  highlight: true,
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  context.translate('target_weight_short'),
                  '${goal.target!.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  height: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                FractionallySizedBox(
                  widthFactor: goal.progress == 0 ? 0.02 : goal.progress,
                  child: Container(
                    height: 16,
                    decoration: const BoxDecoration(
                      gradient: accentPulseGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.translate('percent_complete', [
                  (goal.progress * 100).toStringAsFixed(0),
                ]),
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (reached)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4ADE80),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.translate('goal_reached'),
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  context.translate('weight_remaining', [
                    goal.remaining.toStringAsFixed(1),
                    context.translate(
                      goal.isLosing ? 'lose_weight' : 'gain_weight',
                    ),
                  ]),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFF9D45) : cs.onSurface,
            fontSize: highlight ? 22 : 18,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightLog> logs;
  final double? target;
  const _WeightChart({required this.logs, this.target});

  @override
  Widget build(BuildContext context) {
    final axisColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    final spots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      spots.add(FlSpot(i.toDouble(), logs[i].weightKg));
    }

    final weights = logs.map((l) => l.weightKg).toList();
    double minY = weights.reduce((a, b) => a < b ? a : b);
    double maxY = weights.reduce((a, b) => a > b ? a : b);
    if (target != null) {
      minY = minY < target! ? minY : target!;
      maxY = maxY > target! ? maxY : target!;
    }
    final pad = ((maxY - minY) * 0.15).clamp(0.5, 5).toDouble();
    minY -= pad;
    maxY += pad;

    return glassCard(
      context: context,
      padding: const EdgeInsets.fromLTRB(8, 24, 20, 12),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: axisColor.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (logs.length / 4).ceilToDouble().clamp(1, 9999),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= logs.length) {
                      return const SizedBox.shrink();
                    }
                    final d = logs[i].loggedAt;
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        '${d.day}/${d.month}',
                        style: TextStyle(color: axisColor, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: ((maxY - minY) / 3).clamp(0.5, 9999),
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(color: axisColor, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: target == null
                ? const ExtraLinesData()
                : ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: target!,
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                        strokeWidth: 2,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          labelResolver: (_) =>
                              context.translate('weight_goal_line'),
                        ),
                      ),
                    ],
                  ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF85F2B), Color(0xFFFFC66A)],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF85F2B).withValues(alpha: 0.25),
                      const Color(0xFFF85F2B).withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF262F57),
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} kg',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final WeightLog log;
  final VoidCallback onDelete;
  const _LogTile({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = log.loggedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
        context: context,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.monitor_weight,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.weightKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                size: 20,
              ),
              tooltip: context.translate('delete_entry'),
            ),
          ],
        ),
      ),
    );
  }
}
