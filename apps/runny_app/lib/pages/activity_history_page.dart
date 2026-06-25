import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/workout_models.dart';
import '../models/shoe_models.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';
import 'activity_details_page.dart';
import 'dart:math' as math;

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Activity> _activities = [];
  List<Shoe> _shoes = [];
  int _maxHr = 190; // Default Max HR
  String _selectedRange = '30'; // '7', '30', '90', 'all'
  String _selectedTrendTab = 'pace'; // 'pace' or 'hr'
  int _touchedHrZoneIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch activities
      final response = await _supabase
          .from('activities')
          .select()
          .order('started_at', ascending: false);

      final fetchedActivities = (response as List)
          .map((json) => Activity.fromJson(json))
          .toList();

      // 2. Fetch profile for max HR
      final profileResponse = await _supabase
          .from('profiles')
          .select('max_hr')
          .eq('id', userId)
          .maybeSingle();

      int maxHr = 190;
      if (profileResponse != null && profileResponse['max_hr'] != null) {
        maxHr = profileResponse['max_hr'] as int;
      }

      // 3. Fetch shoes
      final shoesResponse = await _supabase
          .from('shoes')
          .select()
          .order('acquired_at', ascending: false);

      final fetchedShoes = (shoesResponse as List)
          .map((json) => Shoe.fromJson(json))
          .toList();

      setState(() {
        _activities = fetchedActivities;
        _shoes = fetchedShoes;
        _maxHr = maxHr;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching history data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Activity> get _filteredActivities {
    if (_selectedRange == 'all') return _activities;
    final now = DateTime.now();
    final days = int.parse(_selectedRange);
    final cutoff = now.subtract(Duration(days: days));
    return _activities
        .where((activity) => activity.startedAt.isAfter(cutoff))
        .toList();
  }

  // Calculate statistics for the filtered range
  double get _totalDistance => _filteredActivities.fold(0.0, (sum, a) => sum + a.distanceKm);
  double get _totalDuration => _filteredActivities.fold(0.0, (sum, a) => sum + a.durationMin);
  
  double get _avgPace {
    final dist = _totalDistance;
    if (dist == 0) return 0.0;
    return _totalDuration / dist;
  }

  double get _avgHr {
    final hrs = _filteredActivities.where((a) => a.avgHr != null).map((a) => a.avgHr!).toList();
    if (hrs.isEmpty) return 0.0;
    return hrs.reduce((a, b) => a + b) / hrs.length;
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal == 0 || paceDecimal.isInfinite || paceDecimal.isNaN) return "-:--";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  String _formatDuration(double minutes) {
    int m = minutes.toInt();
    int s = ((minutes - m) * 60).round();
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  // Group distance by date
  List<BarChartGroupData> _buildDistanceChartData() {
    final filtered = _filteredActivities;
    if (filtered.isEmpty) return [];

    if (_selectedRange == '7') {
      final Map<int, double> dailyData = {};
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        dailyData[date.weekday] = 0.0;
      }

      for (var a in filtered) {
        final weekday = a.startedAt.weekday;
        if (dailyData.containsKey(weekday)) {
          dailyData[weekday] = dailyData[weekday]! + a.distanceKm;
        }
      }

      final sortedWeekdays = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)).weekday);
      return List.generate(7, (index) {
        final weekday = sortedWeekdays[index];
        final val = dailyData[weekday] ?? 0.0;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: val,
              gradient: accentPulseGradient,
              width: 14,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (val > 0) ? val * 1.2 : 5,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        );
      });
    } else {
      final Map<String, double> weeklyData = {};
      final List<DateTime> weekStarts = [];
      final now = DateTime.now();

      int weeksToCalculate = _selectedRange == '30' ? 4 : (_selectedRange == '90' ? 12 : 24);
      for (int i = 0; i < weeksToCalculate; i++) {
        final date = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
        final key = DateFormat('yyyy-MM-dd').format(date);
        weeklyData[key] = 0.0;
        weekStarts.add(DateTime(date.year, date.month, date.day));
      }

      for (var a in filtered) {
        final actMonday = a.startedAt.subtract(Duration(days: a.startedAt.weekday - 1));
        final key = DateFormat('yyyy-MM-dd').format(actMonday);
        if (weeklyData.containsKey(key)) {
          weeklyData[key] = weeklyData[key]! + a.distanceKm;
        }
      }

      weekStarts.sort();
      return List.generate(weekStarts.length, (index) {
        final date = weekStarts[index];
        final key = DateFormat('yyyy-MM-dd').format(date);
        final val = weeklyData[key] ?? 0.0;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: val,
              gradient: secondaryPulseGradient,
              width: 12,
              borderRadius: BorderRadius.circular(3),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (val > 0) ? val * 1.2 : 10,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        );
      });
    }
  }

  // HR Zone Analysis: returns Map of Zone index -> Duration percentage (0.0 to 1.0)
  Map<int, double> _calculateHrZones() {
    final filtered = _filteredActivities;
    final Map<int, int> zoneSeconds = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int totalSeconds = 0;

    final z1Max = (_maxHr * 0.60).round();
    final z2Max = (_maxHr * 0.70).round();
    final z3Max = (_maxHr * 0.80).round();
    final z4Max = (_maxHr * 0.90).round();

    for (var a in filtered) {
      final List<dynamic>? hrs = a.dataPoints?['hrs'];
      final List<dynamic>? times = a.dataPoints?['times'];

      if (hrs != null && times != null && hrs.length == times.length && hrs.isNotEmpty) {
        for (int i = 0; i < hrs.length; i++) {
          final hr = (hrs[i] as num).toInt();
          final interval = (i == 0) ? 1 : ((times[i] as num) - (times[i - 1] as num)).toInt();
          
          int zone = 1;
          if (hr >= z4Max) {
            zone = 5;
          } else if (hr >= z3Max) {
            zone = 4;
          } else if (hr >= z2Max) {
            zone = 3;
          } else if (hr >= z1Max) {
            zone = 2;
          }

          zoneSeconds[zone] = zoneSeconds[zone]! + interval;
          totalSeconds += interval;
        }
      } else if (a.avgHr != null) {
        final hr = a.avgHr!;
        final seconds = (a.durationMin * 60).toInt();
        int zone = 1;
        if (hr >= z4Max) {
          zone = 5;
        } else if (hr >= z3Max) {
          zone = 4;
        } else if (hr >= z2Max) {
          zone = 3;
        } else if (hr >= z1Max) {
          zone = 2;
        }
        zoneSeconds[zone] = zoneSeconds[zone]! + seconds;
        totalSeconds += seconds;
      }
    }

    if (totalSeconds == 0) return {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0};
    return zoneSeconds.map((zone, sec) => MapEntry(zone, sec / totalSeconds));
  }

  // VO2 Max & Race Predictor Calculations
  double _estimateVo2Max() {
    final runsWithHr = _activities.where((a) => a.avgHr != null && a.avgHr! > 100 && a.distanceKm > 0 && a.durationMin > 0).toList();
    if (runsWithHr.isEmpty) return 40.0; // Standard baseline VO2 Max

    double bestVo2 = 0.0;
    for (var a in runsWithHr) {
      final speedKmh = a.distanceKm / (a.durationMin / 60);
      final avgHr = a.avgHr!;
      final hrRatio = _maxHr / avgHr;
      // Formula based on oxygen intake estimation relative to max effort
      final vo2 = speedKmh * hrRatio * 3.3;
      if (vo2 > bestVo2) {
        bestVo2 = vo2;
      }
    }
    return bestVo2.clamp(32.0, 75.0);
  }

  // Jack Daniels VDOT / VO2 Max Race Predictor estimations
  Map<String, double> _predictRaceTimes(double vo2max) {
    // Linear / power model approximation of Daniels' running tables
    // times in minutes
    final t5 = 357.66 / (_mathPow(vo2max, 0.69));
    final t10 = 779.13 / (_mathPow(vo2max, 0.70));
    final tHalf = 1880.8 / (_mathPow(vo2max, 0.72));
    final tFull = 4232.1 / (_mathPow(vo2max, 0.74));

    return {
      '5K': t5,
      '10K': t10,
      '21K': tHalf,
      '42K': tFull,
    };
  }

  // Custom power math utility
  double _mathPow(double base, double exponent) {
    // Safe power estimation
    return math.pow(base, exponent).toDouble();
  }

  String _formatPredictedTime(double minutes) {
    if (minutes.isNaN || minutes.isInfinite) return "--:--";
    final int h = (minutes / 60).floor();
    final int m = (minutes % 60).floor();
    final int s = ((minutes - (h * 60) - m) * 60).round();
    if (h > 0) {
      return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    } else {
      return "$m:${s.toString().padLeft(2, '0')}";
    }
  }

  // Build performance trend lines (Chronological order)
  List<FlSpot> _buildTrendChartData() {
    final filtered = List<Activity>.from(_filteredActivities);
    filtered.sort((a, b) => a.startedAt.compareTo(b.startedAt));

    List<FlSpot> spots = [];
    for (int i = 0; i < filtered.length; i++) {
      final a = filtered[i];
      if (_selectedTrendTab == 'pace') {
        final double pace = a.durationMin / a.distanceKm;
        if (pace > 0 && !pace.isInfinite && !pace.isNaN) {
          spots.add(FlSpot(i.toDouble(), pace));
        }
      } else {
        if (a.avgHr != null) {
          spots.add(FlSpot(i.toDouble(), a.avgHr!.toDouble()));
        }
      }
    }
    return spots;
  }

  // Shoe functions
  Future<void> _showAddShoeDialog() async {
    final nameController = TextEditingController();
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    DateTime acquiredDate = DateTime.now();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(context.translate('add_shoe'), style: TextStyle(color: colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: themedInputDecoration(context, context.translate('shoe_name')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: brandController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: themedInputDecoration(context, context.translate('brand')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: themedInputDecoration(context, context.translate('model')),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.translate('acquired_date')}: ${DateFormat('yyyy-MM-dd').format(acquiredDate)}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: acquiredDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => acquiredDate = picked);
                        }
                      },
                      child: Text(context.translate('edit_info')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.translate('cancel'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                
                final userId = _supabase.auth.currentUser?.id;
                if (userId == null) return;

                final newShoe = Shoe(
                  userId: userId,
                  name: name,
                  brand: brandController.text.trim().isEmpty ? null : brandController.text.trim(),
                  model: modelController.text.trim().isEmpty ? null : modelController.text.trim(),
                  acquiredAt: acquiredDate,
                );

                setState(() => _isLoading = true);
                try {
                  await _supabase.from('shoes').insert(newShoe.toJson());
                  await _fetchData();
                } catch (e) {
                  debugPrint('Error inserting shoe: $e');
                  setState(() => _isLoading = false);
                }
              },
              child: Text(context.translate('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleShoeActive(Shoe shoe) async {
    if (shoe.id == null) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('shoes')
          .update({'is_active': !shoe.isActive})
          .eq('id', shoe.id!);
      await _fetchData();
    } catch (e) {
      debugPrint('Error toggling shoe status: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredActivities;
    final estimatedVo2 = _estimateVo2Max();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Range Filter Chip Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('history_analytics'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              DropdownButton<String>(
                value: _selectedRange,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                icon: Icon(Icons.tune, color: colorScheme.primary, size: 20),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedRange = newValue);
                  }
                },
                items: [
                  DropdownMenuItem(value: '7', child: Text(context.translate('filter_7d'))),
                  DropdownMenuItem(value: '30', child: Text(context.translate('filter_30d'))),
                  DropdownMenuItem(value: '90', child: Text(context.translate('filter_90d'))),
                  DropdownMenuItem(value: 'all', child: Text(context.translate('filter_all'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Period Statistics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildMiniStatCard(
                title: context.translate('distance'),
                value: '${_totalDistance.toStringAsFixed(1)} km',
                icon: Icons.straighten,
                gradient: accentPulseGradient,
              ),
              _buildMiniStatCard(
                title: context.translate('sessions'),
                value: '${filtered.length} ${context.translate('run_count').toLowerCase()}',
                icon: Icons.directions_run,
                gradient: secondaryPulseGradient,
              ),
              _buildMiniStatCard(
                title: context.translate('pace'),
                value: '${_formatPace(_avgPace)} /km',
                icon: Icons.speed,
                gradient: secondaryPulseGradient,
              ),
              _buildMiniStatCard(
                title: context.translate('avg_hr'),
                value: _avgHr > 0 ? '${_avgHr.round()} bpm' : '--',
                icon: Icons.favorite,
                gradient: accentPulseGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (filtered.isEmpty) ...[
            glassCard(
              context: context,
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.query_stats_rounded, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      context.translate('no_data_range'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            // 1. Weekly/Daily Running Distance Chart
            _buildSectionTitle(context.translate('distance_chart')),
            const SizedBox(height: 12),
            _buildDistanceChartSection(),
            const SizedBox(height: 24),

            // 2. Heart Rate Zones Donut Chart
            _buildSectionTitle(context.translate('hr_zones_chart')),
            const SizedBox(height: 12),
            _buildHrZonesDonutChartSection(),
            const SizedBox(height: 24),

            // 3. Performance Trends Chart
            _buildSectionTitle(context.translate('trends_chart')),
            const SizedBox(height: 12),
            _buildTrendsChartSection(),
            const SizedBox(height: 24),

            // 4. Race Predictor Table
            _buildSectionTitle(context.translate('race_predictor')),
            const SizedBox(height: 12),
            _buildRacePredictorSection(estimatedVo2),
            const SizedBox(height: 24),
          ],

          // 5. Shoe Tracker Section
          _buildSectionTitle(context.translate('shoe_tracker')),
          const SizedBox(height: 12),
          _buildShoeTrackerSection(),
          const SizedBox(height: 24),

          // 6. Detailed Activities List
          _buildSectionTitle(context.translate('recent_activities')),
          const SizedBox(height: 12),
          _buildActivitiesList(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return glassCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Distance Bar Chart
  Widget _buildDistanceChartSection() {
    final spots = _buildDistanceChartData();
    final colorScheme = Theme.of(context).colorScheme;

    return glassCard(
      context: context,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barGroups: spots,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final int val = value.toInt();
                    String label = '';
                    if (_selectedRange == '7') {
                      final now = DateTime.now();
                      final sortedWeekdays = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
                      if (val >= 0 && val < 7) {
                        label = DateFormat('E').format(sortedWeekdays[val]);
                      }
                    } else {
                      label = 'W${val + 1}';
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        label,
                        style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        '${value.toStringAsFixed(0)}k',
                        style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => const Color(0xFF1E2640),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)} km',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Heart Rate Zones Chart (Donut Chart)
  Widget _buildHrZonesDonutChartSection() {
    final zones = _calculateHrZones();
    final colorScheme = Theme.of(context).colorScheme;

    final List<Map<String, dynamic>> zoneMeta = [
      {
        'label': context.translate('zone_recovery'),
        'color': const Color(0xFF64748B),
      },
      {
        'label': context.translate('zone_aerobic'),
        'color': const Color(0xFF10B981),
      },
      {
        'label': context.translate('zone_tempo'),
        'color': const Color(0xFFFBBF24),
      },
      {
        'label': context.translate('zone_threshold'),
        'color': const Color(0xFFF97316),
      },
      {
        'label': context.translate('zone_anaerobic'),
        'color': const Color(0xFFEF4444),
      },
    ];

    List<PieChartSectionData> pieSections = List.generate(5, (index) {
      final zoneNum = index + 1;
      final pct = zones[zoneNum] ?? 0.0;
      final meta = zoneMeta[index];
      
      final isTouched = index == _touchedHrZoneIndex;
      final radius = isTouched ? 48.0 : 40.0;
      
      return PieChartSectionData(
        color: meta['color'] as Color,
        value: pct > 0 ? pct * 100 : 0.01,
        title: pct > 0.05 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 46,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedHrZoneIndex = -1;
                              return;
                            }
                            _touchedHrZoneIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (index) {
                    final zoneNum = index + 1;
                    final pct = zones[zoneNum] ?? 0.0;
                    final meta = zoneMeta[index];
                    final Color color = meta['color'] as Color;
                    final String label = meta['label'] as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Performance Trend Line Chart
  Widget _buildTrendsChartSection() {
    final spots = _buildTrendChartData();
    final colorScheme = Theme.of(context).colorScheme;

    if (spots.isEmpty) return const SizedBox.shrink();

    return glassCard(
      context: context,
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _selectedTrendTab = 'pace'),
                style: TextButton.styleFrom(
                  backgroundColor: _selectedTrendTab == 'pace' ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                  foregroundColor: _selectedTrendTab == 'pace' ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                child: Text(context.translate('pace_trend')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _selectedTrendTab = 'hr'),
                style: TextButton.styleFrom(
                  backgroundColor: _selectedTrendTab == 'hr' ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                  foregroundColor: _selectedTrendTab == 'hr' ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                child: Text(context.translate('hr_trend')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (spots.length / 5).clamp(1.0, 9999.0),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            'Run ${value.toInt() + 1}',
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        String label = '';
                        if (_selectedTrendTab == 'pace') {
                          label = _formatPace(value);
                        } else {
                          label = '${value.toStringAsFixed(0)} bpm';
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            label,
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: _selectedTrendTab == 'pace' ? secondaryPulseGradient : accentPulseGradient,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: _selectedTrendTab == 'pace'
                            ? [
                                colorScheme.secondary.withValues(alpha: 0.25),
                                colorScheme.secondary.withValues(alpha: 0.0),
                              ]
                            : [
                                colorScheme.primary.withValues(alpha: 0.25),
                                colorScheme.primary.withValues(alpha: 0.0),
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1E2640),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final valStr = _selectedTrendTab == 'pace' ? _formatPace(spot.y) : '${spot.y.toStringAsFixed(0)} bpm';
                        return LineTooltipItem(
                          'Run ${spot.x.toInt() + 1}\n$valStr',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Race Predictor
  Widget _buildRacePredictorSection(double vo2max) {
    final predictions = _predictRaceTimes(vo2max);
    final colorScheme = Theme.of(context).colorScheme;

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('estimated_vo2max'),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: accentPulseGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${vo2max.toStringAsFixed(1)} ml/kg/min',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.translate('vo2max_progress_msg', [vo2max.toStringAsFixed(1)]),
            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Predictions Grid
          Row(
            children: predictions.entries.map((entry) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatPredictedTime(entry.value),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Shoe Tracker Panel
  Widget _buildShoeTrackerSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Title action button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.translate('active_shoes'),
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: colorScheme.primary),
              onPressed: _showAddShoeDialog,
              tooltip: context.translate('add_shoe'),
            ),
          ],
        ),
        if (_shoes.isEmpty) ...[
          glassCard(
            context: context,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                context.translate('no_shoes_yet'),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ] else ...[
          Column(
            children: _shoes.map((shoe) {
              final isOverLimit = shoe.distanceKm >= 500.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: glassCard(
                  context: context,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (shoe.isActive ? colorScheme.primary : Colors.grey).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FontAwesomeIcons.shoePrints,
                          color: shoe.isActive ? (isOverLimit ? Colors.redAccent : colorScheme.primary) : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    shoe.name,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: shoe.isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (shoe.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    shoe.isActive ? 'Active' : 'Retired',
                                    style: TextStyle(
                                      color: shoe.isActive ? Colors.green : Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${shoe.brand ?? ''} ${shoe.model ?? ''} • ${context.translate('acquired_date')}: ${DateFormat('yyyy-MM-dd').format(shoe.acquiredAt)}',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            // Mileage Progress Bar
                            Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      Container(
                                        height: 6,
                                        width: MediaQuery.of(context).size.width * 0.45 * (shoe.distanceKm / 500.0).clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: isOverLimit
                                              ? const LinearGradient(colors: [Colors.redAccent, Colors.red])
                                              : accentPulseGradient,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${shoe.distanceKm.toStringAsFixed(1)} / 500 km',
                                  style: TextStyle(
                                    color: isOverLimit ? Colors.redAccent : colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (isOverLimit && shoe.isActive) ...[
                              const SizedBox(height: 6),
                              Text(
                                context.translate('shoe_replace_warning'),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          shoe.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () => _toggleShoeActive(shoe),
                        tooltip: shoe.isActive ? 'Retire Shoe' : 'Reactivate Shoe',
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // Activities List matching date range filter
  Widget _buildActivitiesList(BuildContext context) {
    final filtered = _filteredActivities;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: filtered.map((activity) {
        final paceStr = _formatPace(activity.durationMin / activity.distanceKm);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: glassCard(
            context: context,
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityDetailsPage(activity: activity),
                  ),
                );
                if (result == true) {
                  _fetchData();
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: accentPulseGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.run_circle, color: Colors.white, size: 24),
              ),
              title: Text(
                activity.notes ?? context.translate('run_activity'),
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              subtitle: Text(
                '${activity.distanceKm.toStringAsFixed(2)} km • ${_formatDuration(activity.durationMin)} • ${context.translate('pace')} $paceStr',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }).toList(),
    );
  }
}
