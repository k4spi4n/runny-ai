import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'training_plan_page.dart';
import 'ai_coach_page.dart';
import 'import_activity_page.dart';
import 'activity_details_page.dart';
import 'profile_page.dart';
import 'community_page.dart';
import '../widgets/ui_components.dart';
import '../models/workout_models.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OverviewContent(),
      Center(
        child: Builder(
          builder: (context) => Text(
            'Activity History', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
          ),
        ),
      ),
      const TrainingPlanPage(),
      const AICoachPage(),
      const CommunityPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const RunnyLogo(fontSize: 20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const LanguageSwitcher(),
          const ThemeToggle(),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colorScheme.onSurface),
            tooltip: 'Import Activity',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportActivityPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.onSurface),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  NavigationRail(
                    extended: width > 1100,
                    backgroundColor: theme.brightness == Brightness.dark 
                        ? Colors.white.withValues(alpha: 0.05) 
                        : Colors.black.withValues(alpha: 0.03),
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _selectedIndex = index),
                    labelType: width > 1100
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.dashboard_outlined),
                        selectedIcon: const Icon(Icons.dashboard),
                        label: Text(context.translate('dashboard')),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('History'),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.calendar_month_outlined),
                        selectedIcon: const Icon(Icons.calendar_month),
                        label: Text(context.translate('training_plan')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.psychology_outlined),
                        selectedIcon: const Icon(Icons.psychology),
                        label: Text(context.translate('ai_coach')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.groups_outlined),
                        selectedIcon: const Icon(Icons.groups),
                        label: Text(context.translate('community')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person_outline),
                        selectedIcon: const Icon(Icons.person),
                        label: Text(context.translate('profile')),
                      ),
                    ],
                  ),
                if (isDesktop)
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard),
                  label: context.translate('dashboard'),
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month),
                  label: context.translate('training_plan'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.psychology),
                  label: context.translate('ai_coach'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups),
                  label: context.translate('community'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: context.translate('profile'),
                ),
              ],
            )
          : null,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('Logout', style: TextStyle(color: colorScheme.onSurface)),
        content: Text('Are you sure you want to logout from Runny AI?', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Logging out...'),
                  duration: Duration(seconds: 1),
                ),
              );
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error logging out: $e')),
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewContent extends StatefulWidget {
  const OverviewContent({super.key});

  @override
  State<OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<OverviewContent> {
  late final Future<WeatherSnapshot?> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchLatestWeather();
  }

  Future<Position?> _getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<WeatherSnapshot?> _fetchLatestWeather() async {
    try {
      final position = await _getCurrentPosition();
      if (position != null) {
        final weatherService = WeatherService();
        return weatherService.fetchWeatherSnapshot(
          lat: position.latitude,
          lon: position.longitude,
        );
      }
    } catch (_) {
      // Fallback to latest activity weather.
    }

    try {
      final response = await Supabase.instance.client
          .from('activities')
          .select('start_lat, start_lon, weather_json')
          .order('started_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      final activity = response.first;
      final weatherJson = activity['weather_json'];
      if (weatherJson is Map<String, dynamic>) {
        return WeatherSnapshot.fromJson(weatherJson);
      }

      final lat = (activity['start_lat'] as num?)?.toDouble();
      final lon = (activity['start_lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final weatherService = WeatherService();
      return weatherService.fetchWeatherSnapshot(lat: lat, lon: lon);
    } catch (_) {
      return null;
    }
  }

  Future<List<Activity>> _fetchLatestActivities() async {
    final response = await Supabase.instance.client
        .from('activities')
        .select()
        .order('started_at', ascending: false)
        .limit(5);

    return (response as List).map((json) => Activity.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final response = await Supabase.instance.client
        .from('activities')
        .select('distance_km, duration_min, avg_hr');

    final activities = response as List;
    double totalDistance = 0;
    int totalSessions = activities.length;
    double totalDuration = 0;
    int hrSum = 0;
    int hrCount = 0;

    for (var a in activities) {
      totalDistance += (a['distance_km'] as num).toDouble();
      totalDuration += (a['duration_min'] as num).toDouble();
      if (a['avg_hr'] != null) {
        hrSum += (a['avg_hr'] as int);
        hrCount++;
      }
    }

    double avgPace = totalDistance > 0 ? totalDuration / totalDistance : 0;
    int avgHr = hrCount > 0 ? hrSum ~/ hrCount : 0;

    return {
      'totalDistance': totalDistance,
      'totalSessions': totalSessions,
      'avgPace': avgPace,
      'avgHr': avgHr,
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 4 : (width > 800 ? 2 : 1);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          glassCard(
            context: context,
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Overview',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<WeatherSnapshot?>(
                            future: _weatherFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 32,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final weather = snapshot.data;
                              if (weather == null) {
                                return Text(
                                  'Weather data unavailable.',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                                );
                              }

                              final tempText = weather.temperatureC != null
                                  ? '${weather.temperatureC!.toStringAsFixed(1)}°C'
                                  : '--';
                              final location =
                                  weather.locationName ?? 'Unknown Location';

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (weather.icon != null)
                                    Image.network(
                                      'https://openweathermap.org/img/wn/${weather.icon}@2x.png',
                                      width: 56,
                                      height: 56,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$tempText • ${weather.summary ?? 'Clear'}',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(color: colorScheme.onSurface),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              '$location • ',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: weather.aqiColor
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: weather.aqiColor
                                                      .withValues(alpha: 0.5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'AQI ${weather.aqi ?? '--'} - ${weather.aqiLabel}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: weather.aqiColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        badgeLabel(context, 'PRO HUD'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: accentPulseGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Streak',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '7 Days',
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Performance Stats',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final stats =
                  snapshot.data ??
                  {
                    'totalDistance': 0.0,
                    'totalSessions': 0,
                    'avgPace': 0.0,
                    'avgHr': 0,
                  };

              String formattedPace = "-:--";
              if (stats['avgPace'] > 0) {
                int min = stats['avgPace'].floor();
                int sec = ((stats['avgPace'] - min) * 60).round();
                formattedPace = "$min:${sec.toString().padLeft(2, '0')}";
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.6,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  PerformanceStatCard(
                    title: context.translate('distance'),
                    value:
                        '${(stats['totalDistance'] as double).toStringAsFixed(1)} km',
                    icon: Icons.straighten,
                    gradient: accentPulseGradient,
                  ),
                  PerformanceStatCard(
                    title: 'Sessions',
                    value: '${stats['totalSessions']}',
                    icon: Icons.directions_run,
                    gradient: secondaryPulseGradient,
                  ),
                  PerformanceStatCard(
                    title: 'Avg HR',
                    value: stats['avgHr'] > 0 ? '${stats['avgHr']} bpm' : '--',
                    icon: Icons.favorite,
                    gradient: accentPulseGradient,
                  ),
                  PerformanceStatCard(
                    title: context.translate('pace'),
                    value: '$formattedPace /km',
                    icon: Icons.speed,
                    gradient: secondaryPulseGradient,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.translate('recent_activities'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {}, 
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Activity>>(
            future: _fetchLatestActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No activities yet.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              }

              final activities = snapshot.data!;
              return Column(
                children: activities.map((activity) {
                  final paceStr = _formatPace(
                    activity.durationMin / activity.distanceKm,
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: glassCard(
                      context: context,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ActivityDetailsPage(activity: activity),
                            ),
                          );
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: accentPulseGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.run_circle,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          activity.notes ?? 'Run Activity',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${activity.distanceKm.toStringAsFixed(2)} km • ${_formatDuration(activity.durationMin)} • Pace $paceStr',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Quick Actions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionChip(
                  text: 'Import Activity',
                  icon: Icons.cloud_upload,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImportActivityPage(),
                      ),
                    );
                  },
                ),
                _ActionChip(
                  text: context.translate('training_plan'),
                  icon: Icons.calendar_month,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainingPlanPage(),
                      ),
                    );
                  },
                ),
                _ActionChip(
                  text: context.translate('ai_coach'),
                  icon: Icons.psychology,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AICoachPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDuration(double minutes) {
    int m = minutes.toInt();
    int s = ((minutes - m) * 60).round();
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal.isInfinite || paceDecimal.isNaN) return "-:--";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}

class PerformanceStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const PerformanceStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return glassCard(
      context: context,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A82FF), Color(0xFF3AB8FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
