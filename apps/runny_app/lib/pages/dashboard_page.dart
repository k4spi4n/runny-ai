import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'training_plan_page.dart';
import 'ai_coach_page.dart';
import 'import_activity_page.dart';
import 'activity_details_page.dart';
import 'profile_page.dart';
import 'community_page.dart';
import 'nutrition_page.dart';
import '../widgets/ui_components.dart';
import '../widgets/nutrition_components.dart';
import '../services/nutrition_service.dart';
import '../models/workout_models.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isRailHovered = false;

  late final List<Widget> _pages;
  late final List<HoverSync> _navSyncs;

  @override
  void initState() {
    super.initState();
    _navSyncs = List.generate(7, (_) => HoverSync());
    _pages = [
      const OverviewContent(),
      const NutritionPage(),
      Center(
        child: Builder(
          builder: (context) => Text(
            'Activity History',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
      const TrainingPlanPage(),
      const AICoachPage(),
      const CommunityPage(),
      const ProfilePage(),
    ];

    // Request location on entry to ensure weather can be fetched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationOnEntry();
    });
  }

  @override
  void dispose() {
    for (var sync in _navSyncs) {
      sync.dispose();
    }
    super.dispose();
  }

  NavigationRailDestination _buildRailDestination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = _navSyncs[index];

    return NavigationRailDestination(
      icon: HoverSyncWidget(
        sync: sync,
        builder: (context, isHovered) => AnimatedScale(
          scale: isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Icon(
            icon,
            color: isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      selectedIcon: HoverSyncWidget(
        sync: sync,
        builder: (context, isHovered) => AnimatedScale(
          scale: isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Icon(
            selectedIcon,
            color: colorScheme.primary,
          ),
        ),
      ),
      label: HoverSyncWidget(
        sync: sync,
        builder: (context, isHovered) => AnimatedScale(
          scale: isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Text(
            label,
            style: TextStyle(
              color: isHovered ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestLocationOnEntry() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
      // If permission is granted, OverviewContent will fetch weather on its own
      // or the user can manually trigger it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final navItems = [
      (
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: context.translate('dashboard'),
      ),
      (
        icon: Icons.restaurant_outlined,
        selectedIcon: Icons.restaurant,
        label: context.translate('nutrition'),
      ),
      (
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        label: context.translate('history'),
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: context.translate('training_plan'),
      ),
      (
        icon: Icons.psychology_outlined,
        selectedIcon: Icons.psychology,
        label: context.translate('ai_coach'),
      ),
      (
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: context.translate('community'),
      ),
      (
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: context.translate('profile'),
      ),
    ];

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
              decoration: BoxDecoration(
                gradient: sportPlatformGradient(context),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  MouseRegion(
                    onEnter: (_) => setState(() => _isRailHovered = true),
                    onExit: (_) => setState(() => _isRailHovered = false),
                    child: NavigationRail(
                      extended: _isRailHovered,
                      minWidth: 72,
                      minExtendedWidth: 240,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      labelType: NavigationRailLabelType.none,
                      destinations: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        return _buildRailDestination(
                          index: index,
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: item.label,
                        );
                      }),
                    ),
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
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                height: 64,
                child: glassCard(
                  context: context,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(navItems.length, (index) {
                          final isSelected = _selectedIndex == index;
                          final item = navItems[index];

                          return GestureDetector(
                            onTap: () => setState(() => _selectedIndex = index),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSelected ? 12 : 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected ? item.selectedIcon : item.icon,
                                      size: 22,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutCubic,
                                      child: isSelected
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 6),
                                                Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: theme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
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
        content: Text(
          'Are you sure you want to logout from Runny AI?',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
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
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
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
  late Future<WeatherSnapshot?> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchLatestWeather();
  }

  Future<void> _retryWeather({bool forceRequest = false}) async {
    setState(() {
      _weatherFuture = _fetchLatestWeather(forceRequest: forceRequest);
    });
  }

  Future<Position?> _getCurrentPosition({bool forceRequest = false}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      debugPrint('Location services are disabled.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || forceRequest) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are denied: $permission');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      if (kIsWeb || kDebugMode) {
        // Fallback to a default location (Hanoi) if geolocation fails on Web/Debug
        debugPrint('Using fallback location (Hanoi)');
        return Position(
          latitude: 21.0285,
          longitude: 105.8342,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<WeatherSnapshot?> _fetchLatestWeather({
    bool forceRequest = false,
  }) async {
    Object? lastError;
    try {
      final position = await _getCurrentPosition(forceRequest: forceRequest);
      if (position != null) {
        final weatherService = WeatherService();
        return await weatherService.fetchWeatherSnapshot(
          lat: position.latitude,
          lon: position.longitude,
        );
      } else {
        lastError =
            'Không thể lấy vị trí hiện tại. Vui lòng bật định vị hoặc kiểm tra quyền truy cập browser.';
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      if (e.toString().contains('503')) {
        lastError =
            'Lỗi kết nối Server (503). Vui lòng kiểm tra "supabase status" và đảm bảo Function "weather" đã được serve.';
      } else {
        lastError = e;
      }
    }

    try {
      final response = await Supabase.instance.client
          .from('activities')
          .select('start_lat, start_lon, weather_json')
          .order('started_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final activity = response.first;
        final weatherJson = activity['weather_json'];
        if (weatherJson is Map<String, dynamic>) {
          return WeatherSnapshot.fromJson(weatherJson);
        }

        final lat = (activity['start_lat'] as num?)?.toDouble();
        final lon = (activity['start_lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          final weatherService = WeatherService();
          return await weatherService.fetchWeatherSnapshot(lat: lat, lon: lon);
        }
      }
    } catch (e) {
      debugPrint('Weather fallback error: $e');
    }

    throw lastError;
    return null;
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final weather = snapshot.data;
                              final error = snapshot.error;

                              if (weather == null) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      error != null
                                          ? 'Lỗi: $error'
                                          : context.translate(
                                              'weather_unavailable',
                                            ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _retryWeather(forceRequest: true),
                                          icon: const Icon(
                                            Icons.location_on,
                                            size: 16,
                                          ),
                                          label: Text(
                                            context.translate('allow_location'),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => _retryWeather(),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 16,
                                          ),
                                          label: Text(
                                            context.translate('retry'),
                                          ),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.cloud_queue,
                                                size: 32,
                                              ),
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
                                              ?.copyWith(
                                                color: colorScheme.onSurface,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '$location • ',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '7 Days',
                                style: theme.textTheme.headlineSmall?.copyWith(
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
              'Nutrition Status',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Consumer<NutritionService>(
            builder: (context, nutrition, _) {
              final summary = nutrition.getDailySummary(DateTime.now());
              return NutritionOverviewCard(summary: summary);
            },
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
                TextButton(onPressed: () {}, child: const Text('View All')),
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
