import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../widgets/ui_components.dart';
import '../widgets/activity_charts.dart';
import '../services/weather_service.dart';

class ActivityDetailsPage extends StatelessWidget {
  final Activity activity;

  const ActivityDetailsPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final dataPoints = activity.dataPoints;
    final List<double> times = _convertToList(dataPoints?['times']);
    final List<double> paces = _convertToList(dataPoints?['paces']);
    final List<double> elevations = _convertToList(dataPoints?['elevations']);
    final List<double> hrs = _convertToList(dataPoints?['hrs']);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(activity.notes ?? 'Chi tiết hoạt động'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryHeader(context),
                  const SizedBox(height: 24),
                  if (activity.weatherSummary != null ||
                      activity.temperatureC != null ||
                      activity.aqi != null) ...[
                    _buildWeatherCard(context),
                    const SizedBox(height: 24),
                  ],
                  if (paces.isNotEmpty) ...[
                    ActivityChart(
                      title: 'Pace (Tốc độ)',
                      xValues: times,
                      yValues: paces,
                      color: const Color(0xFFFA6B27),
                      yAxisLabel: 'min/km',
                      isPace: true,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (hrs.isNotEmpty) ...[
                    ActivityChart(
                      title: 'Nhịp tim',
                      xValues: times,
                      yValues: hrs,
                      color: Colors.redAccent,
                      yAxisLabel: 'bpm',
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (elevations.isNotEmpty) ...[
                    ActivityChart(
                      title: 'Độ cao',
                      xValues: times,
                      yValues: elevations,
                      color: const Color(0xFF3CABFF),
                      yAxisLabel: 'm',
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                    const Text(
                      'Ghi chú',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    glassCard(
                      child: Text(
                        activity.notes!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(BuildContext context) {
    WeatherSnapshot? snapshot;
    if (activity.weatherJson != null) {
      snapshot = WeatherSnapshot.fromJson(activity.weatherJson!);
    } else if (activity.temperatureC != null ||
        activity.aqi != null ||
        activity.weatherSummary != null) {
      snapshot = WeatherSnapshot(
        fetchedAt: activity.weatherFetchedAt ?? DateTime.now(),
        temperatureC: activity.temperatureC,
        aqi: activity.aqi,
        description: activity.weatherSummary,
      );
    }

    if (snapshot == null) return const SizedBox.shrink();

    return glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điều kiện môi trường',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (snapshot.icon != null) ...[
                Image.network(
                  'https://openweathermap.org/img/wn/${snapshot.icon}@2x.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.temperatureC?.toStringAsFixed(1) ?? '--'}°C • ${snapshot.summary ?? snapshot.description ?? 'Thời tiết'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.air,
                          color: Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AQI ${snapshot.aqi ?? '--'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: snapshot.aqiColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            snapshot.aqiLabel,
                            style: TextStyle(
                              color: snapshot.aqiColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (snapshot.windKph != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.wind_power, color: Colors.white54, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.windKph!.toStringAsFixed(1)} km/h',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    return glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(context, 'Quãng đường', '${activity.distanceKm.toStringAsFixed(2)} km'),
              _buildStatItem(context, 'Thời gian', _formatDuration(activity.durationMin)),
            ],
          ),
          const Divider(color: Colors.white10, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(context, 'Pace TB', _formatPace(activity.durationMin / activity.distanceKm)),
              _buildStatItem(context, 'Độ cao (+)', '${activity.elevationGainM?.toStringAsFixed(0) ?? 0} m'),
            ],
          ),
          if (activity.avgHr != null) ...[
            const Divider(color: Colors.white10, height: 32),
            _buildStatItem(context, 'Nhịp tim TB', '${activity.avgHr} bpm'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(double minutes) {
    int h = minutes ~/ 60;
    int m = minutes.toInt() % 60;
    int s = ((minutes - minutes.toInt()) * 60).round();
    if (h > 0) return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal.isInfinite || paceDecimal.isNaN) return "-:--";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  List<double> _convertToList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => (e as num).toDouble()).toList();
    }
    return [];
  }
}
