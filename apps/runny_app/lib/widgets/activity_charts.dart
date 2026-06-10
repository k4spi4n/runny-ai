import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'ui_components.dart';

class ActivityChart extends StatelessWidget {
  final String title;
  final List<double> xValues;
  final List<double> yValues;
  final Color color;
  final String yAxisLabel;
  final bool isPace;

  const ActivityChart({
    super.key,
    required this.title,
    required this.xValues,
    required this.yValues,
    required this.color,
    required this.yAxisLabel,
    this.isPace = false,
  });

  @override
  Widget build(BuildContext context) {
    if (xValues.isEmpty || yValues.isEmpty) {
      return const SizedBox.shrink();
    }

    // Subsample if there are too many points for performance
    const maxPoints = 200;
    List<FlSpot> spots = [];
    int step = (xValues.length / maxPoints).ceil();
    if (step < 1) step = 1;

    for (int i = 0; i < xValues.length; i += step) {
      spots.add(FlSpot(xValues[i], yValues[i]));
    }

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
                      interval: xValues.last / 5,
                      getTitlesWidget: (value, meta) {
                        final minutes = (value / 60).floor();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '$minutes m',
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
                      interval: _calculateInterval(yValues),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            isPace ? _formatPace(value) : value.toStringAsFixed(0),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 42,
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
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF262F57),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final minutes = (barSpot.x / 60).floor();
                        final seconds = (barSpot.x % 60).floor();
                        final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
                        final valStr = isPace ? _formatPace(barSpot.y) : barSpot.y.toStringAsFixed(1);
                        return LineTooltipItem(
                          '$timeStr\n$valStr $yAxisLabel',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  double _calculateInterval(List<double> values) {
    if (values.isEmpty) return 1.0;
    double min = values.reduce((a, b) => a < b ? a : b);
    double max = values.reduce((a, b) => a > b ? a : b);
    double range = max - min;
    if (range == 0) return 1.0;
    return range / 3;
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal == 0) return "0:00";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
