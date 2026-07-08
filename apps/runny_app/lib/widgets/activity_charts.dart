import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'ui_components.dart';
import '../l10n/app_localizations.dart';

class ActivityChart extends StatelessWidget {
  final String title;
  final List<double> xValues;
  final List<double> yValues;
  final Color color;
  final String yAxisLabel;
  final bool isPace;
  final double? activeX;
  final ValueChanged<double?>? onXSelected;

  const ActivityChart({
    super.key,
    required this.title,
    required this.xValues,
    required this.yValues,
    required this.color,
    required this.yAxisLabel,
    this.isPace = false,
    this.activeX,
    this.onXSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (xValues.isEmpty || yValues.isEmpty) {
      return const SizedBox.shrink();
    }

    // Subsample if there are too many points for performance
    const maxPoints = 200;
    List<FlSpot> spots = [];
    final pointCount = xValues.length < yValues.length
        ? xValues.length
        : yValues.length;
    int step = (pointCount / maxPoints).ceil();
    if (step < 1) step = 1;

    for (int i = 0; i < pointCount; i += step) {
      final x = xValues[i];
      final y = yValues[i];
      if (x.isFinite && y.isFinite) {
        spots.add(FlSpot(x, y));
      }
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final xBounds = _chartBounds(
      spots.map((spot) => spot.x).toList(),
      zeroBaseline: true,
    );
    final yBounds = _chartBounds(
      spots.map((spot) => spot.y).toList(),
      minPaddingRatio: 0.08,
      maxPaddingRatio: 0.18,
      zeroBaseline: !isPace,
    );
    final leftTitleWidth = _leftTitleReservedSize(yBounds.min, yBounds.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        glassCard(
          context: context,
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
          child: SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: xBounds.min,
                maxX: xBounds.max,
                minY: yBounds.min,
                maxY: yBounds.max,
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    if (activeX != null)
                      VerticalLine(
                        x: activeX!,
                        color: Colors.white.withValues(alpha: 0.35),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                      ),
                  ],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _calculateIntervalFromRange(
                        xBounds.min,
                        xBounds.max,
                        divisions: 5,
                      ),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            _formatTimeAxis(context, value, xBounds.max),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _calculateIntervalFromRange(
                        yBounds.min,
                        yBounds.max,
                        divisions: 4,
                      ),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            isPace
                                ? _formatPace(value)
                                : _formatAxisValue(value),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: leftTitleWidth,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.6)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback:
                      (FlTouchEvent event, LineTouchResponse? response) {
                        if (onXSelected == null) return;
                        if (response == null ||
                            response.lineBarSpots == null ||
                            response.lineBarSpots!.isEmpty) {
                          onXSelected!(null);
                        } else {
                          onXSelected!(response.lineBarSpots!.first.x);
                        }
                      },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF262F57),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipMargin: 10,
                    maxContentWidth: 120,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final minutes = (barSpot.x / 60).floor();
                        final seconds = (barSpot.x % 60).floor();
                        final timeStr =
                            '$minutes:${seconds.toString().padLeft(2, '0')}';
                        final valStr = isPace
                            ? _formatPace(barSpot.y)
                            : barSpot.y.toStringAsFixed(1);
                        return LineTooltipItem(
                          '$timeStr\n$valStr $yAxisLabel',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _ChartBounds _chartBounds(
    List<double> values, {
    double minPaddingRatio = 0,
    double maxPaddingRatio = 0,
    bool zeroBaseline = false,
  }) {
    double min = values.reduce((a, b) => a < b ? a : b);
    double max = values.reduce((a, b) => a > b ? a : b);
    final originalMin = min;
    double range = max - min;
    if (range == 0) {
      final fallback = max.abs() > 0 ? max.abs() * 0.1 : 1.0;
      range = fallback;
      min -= fallback;
      max += fallback;
    } else {
      min -= range * minPaddingRatio;
      max += range * maxPaddingRatio;
    }

    if (zeroBaseline && originalMin >= 0) min = 0;
    return _ChartBounds(min, max);
  }

  double _calculateIntervalFromRange(
    double min,
    double max, {
    required int divisions,
  }) {
    final range = (max - min).abs();
    if (range == 0 || !range.isFinite) return 1.0;
    return range / divisions;
  }

  double _leftTitleReservedSize(double min, double max) {
    final samples = [min, max, (min + max) / 2];
    final longest = samples
        .map((value) => isPace ? _formatPace(value) : _formatAxisValue(value))
        .fold<int>(
          0,
          (length, label) => label.length > length ? label.length : length,
        );
    return (longest * 7.0 + 14).clamp(42.0, 68.0);
  }

  String _formatAxisValue(double value) {
    final abs = value.abs();
    if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  String _formatTimeAxis(BuildContext context, double seconds, double maxX) {
    final safeSeconds = seconds < 0 ? 0 : seconds.round();
    if (maxX < 60) {
      return '$safeSeconds ${context.translate('second_short')}';
    }
    if (maxX < 600) {
      final minutes = safeSeconds ~/ 60;
      final remainingSeconds = safeSeconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${safeSeconds ~/ 60} ${context.translate('minute_short')}';
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal == 0) return "0:00";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}

class _ChartBounds {
  final double min;
  final double max;

  const _ChartBounds(this.min, this.max);
}
