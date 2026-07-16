import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/activity_charts.dart';

void main() {
  test('min/max downsampling preserves a narrow peak', () {
    final points = List.generate(
      1000,
      (index) => FlSpot(index.toDouble(), index == 503 ? 220 : 100),
    );

    final sampled = ActivityChart.downsampleSpots(points, maxPoints: 200);

    expect(sampled.length, lessThanOrEqualTo(200));
    expect(sampled.first, points.first);
    expect(sampled.last, points.last);
    expect(sampled.any((spot) => spot.x == 503 && spot.y == 220), isTrue);
  });
}
