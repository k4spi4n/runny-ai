import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'training_plan_page.dart';
import 'ai_coach_page.dart';
import 'import_activity_page.dart';
import 'activity_details_page.dart';
import 'profile_page.dart';
import 'community_page.dart';
import 'nutrition_page.dart';
import 'activity_history_page.dart';
import '../widgets/ui_components.dart';
import '../widgets/nutrition_components.dart';
import '../services/nutrition_service.dart';
import '../models/workout_models.dart';
import '../services/weather_service.dart';
import '../services/gemini_service.dart';
import '../services/dashboard_layout.dart';
import '../services/integration_service.dart';
import '../services/strava_redirect.dart';
import '../services/entitlement_service.dart';
import '../services/payment_redirect.dart';
import '../widgets/paywall.dart';
import '../widgets/dashboard_settings_sheet.dart';
import '../widgets/pwa_install_button.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

Widget Function(Color color, double size) _materialIcon(IconData icon) {
  return (color, size) => Icon(icon, color: color, size: size);
}

Widget _hugeChatBotIcon(Color color, double size) {
  return HugeIcon(
    icon: HugeIcons.strokeRoundedChatBot,
    color: color,
    size: size,
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isRailHovered = false;
  final GlobalKey<_OverviewContentState> _overviewKey =
      GlobalKey<_OverviewContentState>();

  late final List<Widget> _pages;
  late final List<HoverSync> _navSyncs;
  // Bố cục tùy chỉnh của trang Tổng quan (ẩn/hiện + sắp xếp các mục). Mỗi màn
  // hình tự quản cấu hình riêng; hiện chỉ dashboard có tùy chọn.
  final DashboardLayout _dashboardLayout = DashboardLayout();
  final IntegrationService _integrationService = IntegrationService();

  @override
  void initState() {
    super.initState();
    _navSyncs = List.generate(7, (_) => HoverSync());
    _dashboardLayout.load();
    _pages = [
      OverviewContent(
        key: _overviewKey,
        layout: _dashboardLayout,
        onViewAllActivities: () => setState(() => _selectedIndex = 4),
        onViewTrainingPlan: () => setState(() => _selectedIndex = 1),
      ),
      const TrainingPlanPage(embedded: true),
      const AICoachPage(embedded: true),
      const NutritionPage(embedded: true),
      const ActivityHistoryPage(),
      const CommunityPage(),
      const ProfilePage(),
    ];

    // Request location on entry to ensure weather can be fetched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationOnEntry();
      _handleStravaRedirect();
      _handlePaymentRedirectAndEntitlement();
    });
  }

  /// Làm mới entitlement khi vào Dashboard; nếu vừa quay lại từ PayOS thì hiện
  /// thông báo kết quả thanh toán (webhook đã kích hoạt subscription ở server).
  Future<void> _handlePaymentRedirectAndEntitlement() async {
    final payment = consumePaymentRedirect();
    if (!mounted) return;
    await context.read<EntitlementProvider>().refresh();
    if (!mounted) return;
    if (payment != null) {
      final msg = payment == 'success'
          ? context.translate('payment_success')
          : context.translate('payment_cancelled');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    await _maybeShowTrialReminder();
  }

  Future<void> _openImportActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportActivityPage()),
    );
    if (result == true && mounted) {
      _overviewKey.currentState?.refreshActivityData();
      await context.read<NutritionService>().refresh();
    }
  }

  /// Nhắc nâng cấp mỗi 4 ngày kể từ ngày tạo tài khoản trong lúc còn trial
  /// (mốc ngày 4/8/12). Lưu mốc đã nhắc vào shared_preferences theo user để
  /// không lặp lại mỗi lần vào Dashboard.
  Future<void> _maybeShowTrialReminder() async {
    if (!mounted) return;
    final ent = context.read<EntitlementProvider>();
    if (!ent.isTrial) return;

    final createdAt = ent.accountCreatedAt;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (createdAt == null || userId == null) return;

    // Mốc nhắc = số ngày kể từ tạo tài khoản chia 4 (ngày 0-3 chưa nhắc).
    final daysSince = DateTime.now().difference(createdAt).inDays;
    final period = daysSince ~/ 4;
    if (period < 1) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'trial_reminder_period_$userId';
    final lastShown = prefs.getInt(key) ?? 0;
    if (period <= lastShown) return;

    await prefs.setInt(key, period);
    if (!mounted) return;
    await showUpgradeSheet(
      context,
      message: context.translate('trial_reminder_message', [
        '${ent.trialDaysLeft}',
      ]),
    );
  }

  /// Sau khi người dùng cấp quyền Strava, trình duyệt quay về app kèm ?code=...
  /// -> đổi lấy token và nhập hoạt động, rồi dọn URL.
  Future<void> _handleStravaRedirect() async {
    final code = takePendingStravaCode();
    if (code == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.translate('error');
    messenger.showSnackBar(
      SnackBar(content: Text(context.translate('strava_connecting'))),
    );
    try {
      final imported = await _integrationService.exchangeStravaCode(code);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.translate('strava_connected_imported', ['$imported']),
          ),
        ),
      );
      if (imported > 0) {
        _overviewKey.currentState?.refreshActivityData();
        await context.read<NutritionService>().refresh();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  @override
  void dispose() {
    for (var sync in _navSyncs) {
      sync.dispose();
    }
    _dashboardLayout.dispose();
    super.dispose();
  }

  /// Mở tùy chọn cấu hình cho màn hình đang hiển thị. Nút này độc lập theo từng
  /// màn hình: hiện chỉ Tổng quan có tùy chọn, các màn khác báo "chưa có".
  void _openScreenSettings() {
    if (_selectedIndex == 0) {
      DashboardSettingsSheet.show(context, _dashboardLayout);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('no_screen_settings')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  NavigationRailDestination _buildRailDestination({
    required int index,
    required Widget Function(Color color, double size) iconBuilder,
    required Widget Function(Color color, double size) selectedIconBuilder,
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
          child: iconBuilder(
            isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant,
            24,
          ),
        ),
      ),
      selectedIcon: HoverSyncWidget(
        sync: sync,
        builder: (context, isHovered) => AnimatedScale(
          scale: isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: selectedIconBuilder(colorScheme.primary, 24),
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
        iconBuilder: _materialIcon(Icons.dashboard_outlined),
        selectedIconBuilder: _materialIcon(Icons.dashboard),
        label: context.translate('dashboard'),
      ),
      (
        iconBuilder: _materialIcon(Icons.calendar_month_outlined),
        selectedIconBuilder: _materialIcon(Icons.calendar_month),
        label: context.translate('training_plan'),
      ),
      (
        iconBuilder: _hugeChatBotIcon,
        selectedIconBuilder: _hugeChatBotIcon,
        label: context.translate('ai_coach'),
      ),
      (
        iconBuilder: _materialIcon(Icons.restaurant_outlined),
        selectedIconBuilder: _materialIcon(Icons.restaurant),
        label: context.translate('nutrition'),
      ),
      (
        iconBuilder: _materialIcon(Icons.history_outlined),
        selectedIconBuilder: _materialIcon(Icons.history),
        label: context.translate('history'),
      ),
      (
        iconBuilder: _materialIcon(Icons.groups_outlined),
        selectedIconBuilder: _materialIcon(Icons.groups),
        label: context.translate('community'),
      ),
      (
        iconBuilder: _materialIcon(Icons.person_outline),
        selectedIconBuilder: _materialIcon(Icons.person),
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
            icon: Icon(Icons.tune, color: colorScheme.onSurface),
            tooltip: context.translate('screen_settings'),
            onPressed: _openScreenSettings,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colorScheme.onSurface),
            tooltip: context.translate('import_activity'),
            onPressed: _openImportActivity,
          ),
          const PwaInstallButton(),
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
                          iconBuilder: item.iconBuilder,
                          selectedIconBuilder: item.selectedIconBuilder,
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
                    child: ResponsiveContent(child: _pages[_selectedIndex]),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSelected ? 12 : 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    (isSelected
                                        ? item.selectedIconBuilder
                                        : item.iconBuilder)(
                                      isSelected
                                          ? theme.primaryColor
                                          : colorScheme.onSurfaceVariant,
                                      22,
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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
}

class OverviewContent extends StatefulWidget {
  final VoidCallback? onViewAllActivities;
  final VoidCallback? onViewTrainingPlan;
  final DashboardLayout layout;

  const OverviewContent({
    super.key,
    required this.layout,
    this.onViewAllActivities,
    this.onViewTrainingPlan,
  });

  @override
  State<OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<OverviewContent> {
  late Future<WeatherSnapshot?> _weatherFuture;
  late Future<String?> _displayNameFuture;
  Future<String?>? _insightFuture;
  String? _insightLang;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchLatestWeather();
    _displayNameFuture = _fetchDisplayName();
  }

  /// Tạo (một lần cho mỗi ngôn ngữ) future lấy nhận xét AI về hiệu suất.
  Future<String?> _insightFor(String langCode) {
    if (_insightFuture == null || _insightLang != langCode) {
      _insightLang = langCode;
      _insightFuture = _fetchPerformanceInsight(langCode);
    }
    return _insightFuture!;
  }

  // Khoá lưu nhận xét AI đã cache (SharedPreferences).
  static const _insightTextKey = 'dash_insight_text';
  static const _insightSigKey = 'dash_insight_sig';
  static const _insightLangKey = 'dash_insight_lang';

  /// Chữ ký của tập buổi chạy gần đây: nhận xét chỉ đổi khi tập này đổi (có buổi
  /// chạy mới / sửa). Nhờ vậy không gọi lại AI mỗi lần mở lại tab Tổng quan.
  String _activitiesSignature(List<Activity> activities) {
    return activities
        .map((a) => a.id ?? a.startedAt.millisecondsSinceEpoch.toString())
        .join('|');
  }

  /// Gọi AI để nhận xét ngắn về xu hướng hiệu suất dựa trên các buổi chạy gần đây.
  /// Có cache bền (SharedPreferences) theo ngôn ngữ + chữ ký buổi chạy: chỉ tạo
  /// nhận xét mới khi có buổi chạy mới, tránh cập nhật (và tốn quota AI) liên tục.
  Future<String?> _fetchPerformanceInsight(String langCode) async {
    try {
      final activities = await _fetchLatestActivities();
      if (activities.isEmpty) return null;

      final signature = _activitiesSignature(activities);
      final prefs = await SharedPreferences.getInstance();

      // Dùng lại nhận xét đã cache khi cùng ngôn ngữ và tập buổi chạy không đổi.
      final cachedText = prefs.getString(_insightTextKey);
      if (cachedText != null &&
          cachedText.isNotEmpty &&
          prefs.getString(_insightLangKey) == langCode &&
          prefs.getString(_insightSigKey) == signature) {
        return cachedText;
      }

      final buffer = StringBuffer();
      for (final a in activities) {
        final dateStr = DateFormat('dd/MM').format(a.startedAt.toLocal());
        final pace = a.distanceKm > 0 ? a.durationMin / a.distanceKm : 0.0;
        String paceStr = '--';
        if (pace > 0) {
          final min = pace.floor();
          final sec = ((pace - min) * 60).round();
          paceStr = '$min:${sec.toString().padLeft(2, '0')}';
        }
        buffer.writeln(
          '- $dateStr: ${a.distanceKm.toStringAsFixed(1)} km, '
          '${a.durationMin.toStringAsFixed(0)} phút, pace $paceStr/km'
          '${a.avgHr != null ? ', HR ${a.avgHr} bpm' : ''}',
        );
      }

      final langName = langCode == 'en' ? 'English' : 'Vietnamese';
      final prompt =
          'Đây là các buổi chạy gần đây nhất của một người dùng:\n'
          '${buffer.toString()}\n'
          'Hãy đưa ra nhận xét ngắn gọn (2-3 câu), tích cực và khích lệ về xu hướng hiệu suất '
          '(quãng đường, nhịp độ, nhịp tim), kèm đúng 1 gợi ý cải thiện cụ thể. '
          'Trả lời bằng $langName, văn phong thân thiện, không dùng markdown hay tiêu đề.';

      final insight = await GeminiService().generateResponse(
        prompt,
        preferredProvider: 'groq',
        preferredModel: 'llama-3.1-8b-instant',
      );
      final trimmed = insight.trim();
      if (trimmed.isEmpty) return null;

      // Lưu cache để các lần mở sau dùng lại cho tới khi có buổi chạy mới.
      await prefs.setString(_insightTextKey, trimmed);
      await prefs.setString(_insightSigKey, signature);
      await prefs.setString(_insightLangKey, langCode);
      return trimmed;
    } catch (e) {
      debugPrint('Performance insight error: $e');
      return null;
    }
  }

  Future<String?> _fetchDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = (data?['display_name'] as String?)?.trim();
      return (name != null && name.isNotEmpty) ? name : null;
    } catch (e) {
      debugPrint('Display name fetch error: $e');
      return null;
    }
  }

  /// Lời chào theo thời điểm trong ngày, kèm tên người dùng.
  String _greeting(BuildContext context, String? name) {
    final hour = DateTime.now().hour;
    final String key;
    if (hour < 12) {
      key = 'greeting_morning';
    } else if (hour < 18) {
      key = 'greeting_afternoon';
    } else {
      key = 'greeting_evening';
    }
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : context.translate('greeting_runner');
    return context.translate(key, [displayName]);
  }

  Future<void> _retryWeather({bool forceRequest = false}) async {
    setState(() {
      _weatherFuture = _fetchLatestWeather(forceRequest: forceRequest);
    });
  }

  void refreshActivityData() {
    if (!mounted) return;
    setState(() {
      _weatherFuture = _fetchLatestWeather();
      _insightFuture = null;
      _insightLang = null;
    });
  }

  Future<void> _openImportActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportActivityPage()),
    );
    if (result == true && mounted) {
      refreshActivityData();
      await context.read<NutritionService>().refresh();
    }
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
        lastError = 'weather_location_error';
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      if (e.toString().contains('503')) {
        lastError = 'weather_server_error';
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
  }

  Future<List<Activity>> _fetchLatestActivities() async {
    final response = await Supabase.instance.client
        .from('activities')
        .select()
        .order('started_at', ascending: false)
        .limit(5);

    return (response as List).map((json) => Activity.fromJson(json)).toList();
  }

  /// Lấy các buổi tập theo lịch của hôm nay (lịch tập đang hoạt động).
  Future<List<ScheduledWorkout>> _fetchTodayWorkouts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Tìm lịch tập hiện tại (active hoặc completed gần nhất) của người dùng
    final scheduleRes = await Supabase.instance.client
        .from('training_schedules')
        .select('id')
        .eq('user_id', user.id)
        .inFilter('status', ['active', 'completed'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (scheduleRes == null) return [];
    final scheduleId = scheduleRes['id'];

    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final response = await Supabase.instance.client
        .from('scheduled_workouts')
        .select()
        .eq('schedule_id', scheduleId)
        .eq('date', today)
        .order('date', ascending: true);

    return (response as List)
        .map((json) => ScheduledWorkout.fromJson(json))
        .toList();
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

  /// Tính chuỗi ngày tập liên tiếp (streak) tính tới hôm nay (hoặc hôm qua nếu
  /// hôm nay chưa tập). Dựa trên các ngày có hoạt động thực tế.
  Future<int> _fetchStreak() async {
    final response = await Supabase.instance.client
        .from('activities')
        .select('started_at')
        .order('started_at', ascending: false)
        .limit(365);

    final days = <DateTime>{};
    for (final a in response as List) {
      final d = DateTime.parse(a['started_at'] as String).toLocal();
      days.add(DateTime(d.year, d.month, d.day));
    }
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    // Hôm nay chưa tập -> cho phép tính streak tính tới hôm qua.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }

    int streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Dựng một mục cấu hình được theo key (trả null nếu key không xác định).
  Widget? _buildSection(
    String key,
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    int crossAxisCount,
  ) {
    switch (key) {
      case DashboardLayout.nutrition:
        return _buildNutritionSection(context, theme, colorScheme);
      case DashboardLayout.performance:
        return _buildPerformanceSection(
          context,
          theme,
          colorScheme,
          crossAxisCount,
        );
      case DashboardLayout.aiInsight:
        return _buildAiInsightSection(context, theme, colorScheme);
      case DashboardLayout.todaySchedule:
        return _buildTodaySchedule(context, theme, colorScheme);
    }
    return null;
  }

  /// Mục "Lịch tập hôm nay": hiển thị các buổi tập theo lịch của ngày hôm nay.
  /// Tự ẩn khi đang tải hoặc khi người dùng chưa có lịch tập nào.
  Widget _buildTodaySchedule(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<List<ScheduledWorkout>>(
      future: _fetchTodayWorkouts(),
      builder: (context, snapshot) {
        // Chưa có dữ liệu (đang tải / lỗi) -> không chiếm chỗ trên dashboard.
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final workouts = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.translate('today_schedule'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (workouts.isEmpty)
              glassCard(
                context: context,
                child: Row(
                  children: [
                    Icon(
                      Icons.self_improvement,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.translate('today_no_workout'),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...workouts.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: glassCard(
                    context: context,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      onTap: widget.onViewTrainingPlan,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: w.status == 'completed'
                              ? secondaryPulseGradient
                              : accentPulseGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          w.status == 'completed'
                              ? Icons.check_circle
                              : Icons.directions_run,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        w.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _scheduledWorkoutSubtitle(context, w),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Tóm tắt mục tiêu của buổi tập theo lịch (quãng đường • thời gian • nhịp độ),
  /// hoặc mô tả/đã hoàn thành nếu không có chỉ số mục tiêu.
  String _scheduledWorkoutSubtitle(BuildContext context, ScheduledWorkout w) {
    final parts = <String>[];
    if (w.targetDistanceKm != null) {
      parts.add('${w.targetDistanceKm!.toStringAsFixed(1)} km');
    }
    if (w.targetDurationMin != null) {
      parts.add(_formatDuration(w.targetDurationMin!));
    }
    if (w.targetPaceMinPerKm != null) {
      parts.add(
        '${context.translate('pace')} ${_formatPace(w.targetPaceMinPerKm!)}',
      );
    }
    if (parts.isNotEmpty) {
      final base = parts.join(' • ');
      return w.status == 'completed'
          ? '$base • ${context.translate('today_workout_done')}'
          : base;
    }
    if (w.status == 'completed') return context.translate('today_workout_done');
    return w.description ?? '';
  }

  Widget _buildNutritionSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.translate('nutrition_status'),
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
      ],
    );
  }

  Widget _buildPerformanceSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    int crossAxisCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.translate('performance_overview'),
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
                  title: context.translate('sessions'),
                  value: '${stats['totalSessions']}',
                  icon: Icons.directions_run,
                  gradient: secondaryPulseGradient,
                ),
                PerformanceStatCard(
                  title: context.translate('avg_hr'),
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
      ],
    );
  }

  Widget _buildAiInsightSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<String?>(
      future: _insightFor(Localizations.localeOf(context).languageCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return glassCard(
            context: context,
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.translate('ai_insight_loading'),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        }
        final insight = snapshot.data;
        if (insight == null || insight.isEmpty) {
          return const SizedBox.shrink();
        }
        return glassCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.translate('ai_insight_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                insight,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Luôn ít nhất 2 cột để cụm chỉ số gọn lại, không phải kéo dài mới thấy hoạt động.
    final crossAxisCount = width > 800 ? 4 : 2;
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
                // Dòng chào mừng chiếm trọn 1 hàng đầy đủ chiều rộng.
                FutureBuilder<String?>(
                  future: _displayNameFuture,
                  builder: (context, snapshot) => MarqueeText(
                    _greeting(context, snapshot.data),
                    style:
                        (width < 560
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.displaySmall)
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cụm thời tiết/không khí bên trái, 2 badge ngày & chuỗi
                // được đẩy xuống ngang hàng bên phải.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FutureBuilder<WeatherSnapshot?>(
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
                                      ? '${context.translate('error')}: ${context.translate(error.toString())}'
                                      : context.translate(
                                          'weather_unavailable',
                                        ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _retryWeather(),
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: Text(context.translate('retry')),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
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

                          // Chi hien nhiet do + AQI, bo cac thong tin phu
                          // (tom tat thoi tiet, dia diem). Badge AQI xuong
                          // dong rieng de khong bi tran/cat tren mobile.
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (weather.icon != null) ...[
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
                                  ],
                                  Flexible(
                                    child: Text(
                                      tempText,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: weather.aqiColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: weather.aqiColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'AQI ${weather.aqi ?? '--'} - ${weather.aqiLabel}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: weather.aqiColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        badgeLabel(
                          context,
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<int>(
                          future: _fetchStreak(),
                          builder: (context, snapshot) {
                            final n = snapshot.data ?? 0;
                            final hasStreakMomentum = n > 2;
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final inactiveTextColor = isDark
                                ? Colors.white
                                : Colors.black87;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: hasStreakMomentum
                                    ? null
                                    : (isDark
                                          ? const Color(0xFF3A4057)
                                          : const Color(0xFFE2E8F0)),
                                gradient: hasStreakMomentum
                                    ? accentPulseGradient
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    context.translate('streak'),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: hasStreakMomentum
                                          ? Colors.white70
                                          : inactiveTextColor.withValues(
                                              alpha: 0.7,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.translate('streak_days', ['$n']),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: hasStreakMomentum
                                              ? Colors.white
                                              : inactiveTextColor,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Các mục tùy chỉnh được (ẩn/hiện + sắp xếp) theo cấu hình dashboard.
          AnimatedBuilder(
            animation: widget.layout,
            builder: (context, _) {
              final children = <Widget>[];
              for (final key in widget.layout.order) {
                if (!widget.layout.isVisible(key)) continue;
                final section = _buildSection(
                  key,
                  context,
                  theme,
                  colorScheme,
                  crossAxisCount,
                );
                if (section == null) continue;
                children.add(section);
                children.add(const SizedBox(height: 24));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            },
          ),
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
                  onPressed: widget.onViewAllActivities,
                  child: Text(context.translate('view_all')),
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
                      context.translate('no_activities_yet'),
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
                          activity.name ??
                              activity.notes ??
                              context.translate('run_activity'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${activity.distanceKm.toStringAsFixed(2)} km • ${_formatDuration(activity.durationMin)} • ${context.translate('pace')} $paceStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(activity.startedAt.toLocal()),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
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
              context.translate('quick_actions'),
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
                  text: context.translate('import_activity'),
                  icon: const Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                    size: 18,
                  ),
                  onTap: _openImportActivity,
                ),
                _ActionChip(
                  text: context.translate('training_plan'),
                  icon: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 18,
                  ),
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
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedChatBot,
                    color: Colors.white,
                    size: 18,
                  ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
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
  final Widget icon;
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
            icon,
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
