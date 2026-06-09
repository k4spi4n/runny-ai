import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import '../widgets/ui_components.dart';
import '../widgets/activity_charts.dart';
import '../services/weather_service.dart';
import 'ai_coach_page.dart';

class ActivityDetailsPage extends StatefulWidget {
  final Activity activity;

  const ActivityDetailsPage({super.key, required this.activity});

  @override
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  late Activity _activity;
  bool _isSaving = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  Future<void> _updateActivityNotes(String notes) async {
    if (_activity.id == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('activities')
          .update({'notes': notes.isEmpty ? null : notes})
          .eq('id', _activity.id!);

      setState(() {
        _activity = Activity(
          id: _activity.id,
          userId: _activity.userId,
          startedAt: _activity.startedAt,
          distanceKm: _activity.distanceKm,
          durationMin: _activity.durationMin,
          avgHr: _activity.avgHr,
          elevationGainM: _activity.elevationGainM,
          notes: notes.isEmpty ? null : notes,
          dataPoints: _activity.dataPoints,
          startLat: _activity.startLat,
          startLon: _activity.startLon,
          weatherSummary: _activity.weatherSummary,
          temperatureC: _activity.temperatureC,
          aqi: _activity.aqi,
          weatherFetchedAt: _activity.weatherFetchedAt,
          weatherJson: _activity.weatherJson,
        );
        _hasChanged = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin hoạt động thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity() async {
    if (_activity.id == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('activities')
          .delete()
          .eq('id', _activity.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa hoạt động thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Pop page indicating deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi xóa: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditNotesDialog() {
    final controller = TextEditingController(text: _activity.notes ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Chỉnh sửa thông tin', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú hoặc tên hoạt động...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A82FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final newNotes = controller.text.trim();
              Navigator.pop(context);
              await _updateActivityNotes(newNotes);
            },
            child: const Text('Lưu', style: TextStyle(color: Color(0xFF4A82FF))),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActivity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xóa hoạt động?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa hoạt động này? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteActivity();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataPoints = _activity.dataPoints;
    final List<double> times = _convertToList(dataPoints?['times']);
    final List<double> paces = _convertToList(dataPoints?['paces']);
    final List<double> elevations = _convertToList(dataPoints?['elevations']);
    final List<double> hrs = _convertToList(dataPoints?['hrs']);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          title: Text(_activity.notes ?? 'Chi tiết hoạt động'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditNotesDialog();
                } else if (value == 'delete') {
                  _confirmDeleteActivity();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Sửa thông tin', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Xóa hoạt động', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
              color: const Color(0xFF1E293B),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AICoachPage(initialActivity: _activity),
              ),
            );
          },
          backgroundColor: const Color(0xFF4A82FF),
          child: const Icon(Icons.tips_and_updates_outlined, color: Colors.white),
        ),
        body: Stack(
          children: [
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSaving) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 24),
                    ],
                    _buildSummaryHeader(context),
                    const SizedBox(height: 24),
                    if (_activity.weatherSummary != null ||
                        _activity.temperatureC != null ||
                        _activity.aqi != null) ...[
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
                    if (_activity.notes != null && _activity.notes!.isNotEmpty) ...[
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
                        context: context,
                        child: Text(
                          _activity.notes!,
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
      ),
    );
  }

  Widget _buildWeatherCard(BuildContext context) {
    WeatherSnapshot? snapshot;
    if (_activity.weatherJson != null) {
      snapshot = WeatherSnapshot.fromJson(_activity.weatherJson!);
    } else if (_activity.temperatureC != null ||
        _activity.aqi != null ||
        _activity.weatherSummary != null) {
      snapshot = WeatherSnapshot(
        fetchedAt: _activity.weatherFetchedAt ?? DateTime.now(),
        temperatureC: _activity.temperatureC,
        aqi: _activity.aqi,
        description: _activity.weatherSummary,
      );
    }

    if (snapshot == null) return const SizedBox.shrink();

    return glassCard(
      context: context,
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
                        const Icon(Icons.air, color: Colors.white54, size: 14),
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
                            color: snapshot.aqiColor.withValues(alpha: 0.2),
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
                    const Icon(
                      Icons.wind_power,
                      color: Colors.white54,
                      size: 20,
                    ),
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
      context: context,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Quãng đường',
                  '${_activity.distanceKm.toStringAsFixed(2)} km',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Thời gian',
                  _formatDuration(_activity.durationMin),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                context,
                'Pace TB',
                _formatPace(_activity.durationMin / _activity.distanceKm),
              ),
              _buildStatItem(
                context,
                'Độ cao (+)',
                '${_activity.elevationGainM?.toStringAsFixed(0) ?? 0} m',
              ),
            ],
          ),
          if (_activity.avgHr != null) ...[
            const Divider(color: Colors.white10, height: 32),
            _buildStatItem(context, 'Nhịp tim TB', '${_activity.avgHr} bpm'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    int h = minutes ~/ 60;
    int m = minutes.toInt() % 60;
    int s = ((minutes - minutes.toInt()) * 60).round();
    if (h > 0) {
      return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
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
