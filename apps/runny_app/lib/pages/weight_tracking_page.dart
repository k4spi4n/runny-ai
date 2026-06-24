import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/weight_models.dart';
import '../services/weight_service.dart';
import '../widgets/ui_components.dart';

/// Issue #30: Quản lý và theo dõi cân nặng.
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
    final results = await Future.wait([_service.fetchGoal(), _service.fetchLogs()]);
    return _WeightData(goal: results[0] as WeightGoal, logs: results[1] as List<WeightLog>);
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Theo dõi cân nặng')),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
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
                      child: Text('Lỗi: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  );
                }
                final data = snapshot.data!;
                final onSurface = Theme.of(context).colorScheme.onSurface;
                return ResponsiveContent(
                  child: SingleChildScrollView(
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
                          label: const Text('Ghi nhận cân nặng hôm nay'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (data.logs.length >= 2) ...[
                        Text('Diễn biến cân nặng',
                            style: TextStyle(
                                color: onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _WeightChart(logs: data.logs, target: data.goal.target),
                        const SizedBox(height: 24),
                      ],
                      Text('Lịch sử',
                          style: TextStyle(
                              color: onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (data.logs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('Chưa có dữ liệu. Hãy ghi nhận cân nặng đầu tiên!',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                        )
                      else
                        ...data.logs.reversed
                            .map((log) => _LogTile(log: log, onDelete: () => _deleteLog(log))),
                      const SizedBox(height: 24),
                    ],
                  ),
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
    final result = await _showWeightDialog(title: 'Ghi nhận cân nặng', label: 'Cân nặng');
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.logWeight(result);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu cân nặng!')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _editGoal(WeightGoal goal) async {
    final result = await _showGoalDialog(goal);
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.setGoal(targetWeight: result.$1, startWeight: result.$2);
      messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật mục tiêu!')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteLog(WeightLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteLog(log.id);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá bản ghi')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<double?> _showWeightDialog({required String title, required String label}) {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              themedInputDecoration(context, label, suffixText: 'kg', icon: Icons.monitor_weight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            style: primaryActionButton(context),
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Trả về (target, start?) — start có thể null nếu giữ nguyên.
  Future<(double, double?)?> _showGoalDialog(WeightGoal goal) {
    final targetController = TextEditingController(text: goal.target?.toStringAsFixed(1) ?? '');
    final startController =
        TextEditingController(text: (goal.start ?? goal.current)?.toStringAsFixed(1) ?? '');
    return showDialog<(double, double?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mục tiêu cân nặng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: themedInputDecoration(context, 'Cân nặng bắt đầu',
                  suffixText: 'kg', icon: Icons.flag),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: themedInputDecoration(context, 'Cân nặng mục tiêu',
                  suffixText: 'kg', icon: Icons.emoji_events),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            style: primaryActionButton(context),
            onPressed: () {
              final target = double.tryParse(targetController.text);
              final start = double.tryParse(startController.text);
              if (target == null) return;
              Navigator.pop(context, (target, start));
            },
            child: const Text('Lưu mục tiêu'),
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

// ---------------------------------------------------------------------
// Thẻ mục tiêu + thanh tiến trình
// ---------------------------------------------------------------------

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
            Text('Chưa có mục tiêu cân nặng',
                style: TextStyle(
                    color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Đặt mục tiêu để theo dõi tiến trình của bạn.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onEditGoal(goal),
                style: primaryActionButton(context),
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('Tạo mục tiêu'),
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
                child: Text('Tiến trình mục tiêu',
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => onEditGoal(goal),
                icon: Icon(Icons.edit, color: cs.onSurfaceVariant, size: 20),
                tooltip: 'Sửa mục tiêu',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(context, 'Bắt đầu', '${goal.start!.toStringAsFixed(1)} kg'),
              _stat(context, 'Hiện tại', '${goal.current!.toStringAsFixed(1)} kg', highlight: true),
              _stat(context, 'Mục tiêu', '${goal.target!.toStringAsFixed(1)} kg'),
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
                        : Colors.black.withValues(alpha: 0.06)),
                FractionallySizedBox(
                  widthFactor: goal.progress == 0 ? 0.02 : goal.progress,
                  child: Container(
                    height: 16,
                    decoration: const BoxDecoration(gradient: accentPulseGradient),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('${(goal.progress * 100).toStringAsFixed(0)}% hoàn thành',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              if (reached)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 18),
                    SizedBox(width: 6),
                    Text('Đã đạt mục tiêu!',
                        style: TextStyle(
                            color: Color(0xFF4ADE80), fontWeight: FontWeight.w700)),
                  ],
                )
              else
                Flexible(
                  child: Text(
                    'Còn ${goal.remaining.toStringAsFixed(1)} kg ${goal.isLosing ? "cần giảm" : "cần tăng"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: highlight ? const Color(0xFFFF9D45) : cs.onSurface,
                fontSize: highlight ? 22 : 18,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Biểu đồ diễn biến cân nặng
// ---------------------------------------------------------------------

class _WeightChart extends StatelessWidget {
  final List<WeightLog> logs;
  final double? target;
  const _WeightChart({required this.logs, this.target});

  @override
  Widget build(BuildContext context) {
    final axisColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: axisColor.withValues(alpha: 0.2), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (logs.length / 4).ceilToDouble().clamp(1, 9999),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= logs.length) return const SizedBox.shrink();
                    final d = logs[i].loggedAt;
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text('${d.day}/${d.month}',
                          style: TextStyle(color: axisColor, fontSize: 10)),
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
                    child: Text(value.toStringAsFixed(0),
                        style: TextStyle(color: axisColor, fontSize: 10)),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: target == null
                ? const ExtraLinesData()
                : ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: target!,
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                            color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w700),
                        labelResolver: (_) => 'Mục tiêu',
                      ),
                    ),
                  ]),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: const LinearGradient(colors: [Color(0xFFF85F2B), Color(0xFFFFC66A)]),
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
                    .map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} kg',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Dòng lịch sử
// ---------------------------------------------------------------------

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
              child: Icon(Icons.monitor_weight, color: cs.onSurfaceVariant, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${log.weightKg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7), size: 20),
              tooltip: 'Xoá',
            ),
          ],
        ),
      ),
    );
  }
}
