import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../services/integration_service.dart';
import '../services/social_service.dart';
import '../services/subscription_service.dart';
import '../models/subscription_models.dart';
import '../l10n/app_localizations.dart';
import 'weight_tracking_page.dart';
import 'subscription_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Khoảng giá trị hợp lý cho thể trạng (đồng bộ với cột numeric(5,2) của DB,
  // tối đa 999.99) — chặn tràn số 22003 và dữ liệu vô lý ngay từ client.
  static const double _minWeight = 20, _maxWeight = 300; // kg
  static const double _minHeight = 90, _maxHeight = 250; // cm
  static const int _minMaxHr = 80, _maxMaxHr = 230; // bpm

  final _supabase = Supabase.instance.client;
  final _integrationService = IntegrationService();
  final _socialService = SocialService();
  final _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _preferredPaceController = TextEditingController();

  String? _gender;
  String? _stravaId;
  String? _garminId;
  bool _lookingForPartner = false;
  bool _isSavingMatching = false;
  UserSubscription? _activeSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _maxHrController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _preferredPaceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final results = await Future.wait<dynamic>([
        _supabase.from('profiles').select().eq('id', user.id).single(),
        _subscriptionService.getActiveSubscription(),
      ]);

      final data = results[0] as Map<String, dynamic>;

      setState(() {
        _displayNameController.text = data['display_name'] ?? '';
        _weightController.text = (data['weight_kg'] ?? '').toString();
        _heightController.text = (data['height_cm'] ?? '').toString();
        _maxHrController.text = (data['max_hr'] ?? '').toString();
        _gender = data['gender'];
        _stravaId = data['strava_id'];
        _garminId = data['garmin_id'];
        _cityController.text = data['city'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _preferredPaceController.text =
            (data['preferred_pace_min_per_km'] ?? '').toString();
        _lookingForPartner = data['looking_for_partner'] == true;
        _activeSubscription = results[1] as UserSubscription?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final weightStr = _weightController.text.trim().replaceAll(',', '.');
    final heightStr = _heightController.text.trim().replaceAll(',', '.');
    final maxHrStr = _maxHrController.text.trim();

    if (weightStr.isEmpty || heightStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('enter_weight_height'))),
      );
      return;
    }

    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final maxHr = maxHrStr.isEmpty ? null : int.tryParse(maxHrStr);

    if (weight == null || height == null || (maxHrStr.isNotEmpty && maxHr == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('invalid_weight_height'))),
      );
      return;
    }

    // Kiểm tra khoảng hợp lý -> hiện dialog hướng dẫn thay vì để DB ném lỗi tràn số.
    if (weight < _minWeight ||
        weight > _maxWeight ||
        height < _minHeight ||
        height > _maxHeight ||
        (maxHr != null && (maxHr < _minMaxHr || maxHr > _maxMaxHr))) {
      _showInvalidMetricsDialog();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      double? bmi;
      if (height > 0) {
        final heightInM = height / 100;
        bmi = double.parse(
          (weight / (heightInM * heightInM)).toStringAsFixed(2),
        );
      }

      await _supabase
          .from('profiles')
          .update({
            'display_name': _displayNameController.text.trim(),
            'weight_kg': weight,
            'height_cm': height,
            'max_hr': maxHr,
            'gender': _gender,
            'bmi': bmi,
            'has_completed_onboarding': true,
          })
          .eq('id', user.id);

      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('profile_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Dialog nhắc người dùng nhập thể trạng trong khoảng hợp lý (thay vì để lộ
  /// lỗi tràn số thô của PostgreSQL lên giao diện).
  void _showInvalidMetricsDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('invalid_metrics_title'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate('invalid_metrics_desc'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _metricRangeRow(context, Icons.monitor_weight,
                context.translate('weight'),
                '${_minWeight.toInt()} – ${_maxWeight.toInt()} kg'),
            _metricRangeRow(context, Icons.height,
                context.translate('height'),
                '${_minHeight.toInt()} – ${_maxHeight.toInt()} cm'),
            _metricRangeRow(context, Icons.favorite,
                context.translate('max_hr_label'), '$_minMaxHr – $_maxMaxHr bpm'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('ok')),
          ),
        ],
      ),
    );
  }

  Widget _metricRangeRow(
      BuildContext context, IconData icon, String label, String range) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          Text(range,
              style: TextStyle(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _saveMatching() async {
    setState(() => _isSavingMatching = true);
    try {
      await _socialService.updateMatchingPreferences(
        lookingForPartner: _lookingForPartner,
        preferredPace: double.tryParse(_preferredPaceController.text),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('matching_settings_saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingMatching = false);
    }
  }

  Future<void> _connectStrava() async {
    final messenger = ScaffoldMessenger.of(context);
    final disconnectedStravaText = context.translate('disconnected_strava');
    final errorText = context.translate('error');

    // Tạm thời: tính năng kết nối Strava đang phát triển -> chỉ hiện thông báo.
    // (Đường nhập liệu chính hiện tại là import file GPX/FIT/TCX.)
    if (_stravaId == null) {
      _showComingSoonDialog();
      return;
    }

    try {
      await _integrationService.disconnectStrava();
      messenger.showSnackBar(SnackBar(content: Text(disconnectedStravaText)));
      _loadProfile();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  void _showComingSoonDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('feature_in_development'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          context.translate('feature_in_development_desc'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _syncStrava() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.translate('error');
    messenger.showSnackBar(
      SnackBar(content: Text(context.translate('strava_syncing'))),
    );
    try {
      final imported = await _integrationService.syncStrava();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.translate('strava_synced', ['$imported']))),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  Future<void> _connectGarmin() async {
    final messenger = ScaffoldMessenger.of(context);
    final disconnectedGarminText = context.translate('disconnected_garmin');
    final errorText = context.translate('error');
    try {
      if (_garminId != null) {
        await _integrationService.disconnectGarmin();
        messenger.showSnackBar(SnackBar(content: Text(disconnectedGarminText)));
      } else {
        await _integrationService.connectGarmin();
      }
      _loadProfile();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 24),
          _buildSubscriptionSection(context),
          const SizedBox(height: 24),
          _buildMetricsSection(context),
          const SizedBox(height: 24),
          _buildIntegrationsSection(context),
          const SizedBox(height: 24),
          _buildMatchingSection(context),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: Text(
                context.translate('logout'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPremium = _activeSubscription != null;

    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('subscription'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPremium ? theme.primaryColor : Colors.grey)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPremium ? Icons.star : Icons.star_outline,
                  color: isPremium ? theme.primaryColor : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium
                          ? _activeSubscription!.plan!.name
                          : context.translate('subscription_free'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isPremium
                          ? context.translate('subscription_expires', [
                              '${_activeSubscription!.endDate.day}/${_activeSubscription!.endDate.month}/${_activeSubscription!.endDate.year}',
                            ])
                          : context.translate('subscription_upgrade_hint'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  ).then((_) => _loadProfile());
                },
                child: Text(
                  isPremium
                      ? context.translate('manage')
                      : context.translate('upgrade'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('logout')),
        content: Text(context.translate('logout_confirm_short')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final errorText = context.translate('error');
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await _supabase.auth.signOut();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$errorText: $e')),
                );
              }
            },
            child: Text(
              context.translate('logout'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return glassCard(
      context: context,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.primaryColor,
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: context.translate('display_name'),
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _supabase.auth.currentUser?.email ?? '',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('body_metrics'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            decoration: themedInputDecoration(
              context,
              context.translate('weight'),
              suffixText: 'kg',
              icon: Icons.monitor_weight,
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            decoration: themedInputDecoration(
              context,
              context.translate('height'),
              suffixText: 'cm',
              icon: Icons.height,
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxHrController,
            decoration: themedInputDecoration(
              context,
              context.translate('max_hr_label'),
              suffixText: 'bpm',
              icon: Icons.favorite,
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 20),
          GenderSelector(
            value: _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: primaryActionButton(context),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(context.translate('update_metrics')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: secondaryActionButton(context),
              icon: const Icon(Icons.timeline, size: 18),
              label: Text(context.translate('weight_tracking_cta')),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeightTrackingPage()),
                ).then((_) => _loadProfile());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('integrations'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          _buildIntegrationTile(
            context: context,
            name: 'Strava',
            icon: Icons.directions_run,
            isConnected: _stravaId != null,
            onConnect: _connectStrava,
            onSync: _syncStrava,
            color: const Color(0xFFFC4C02),
          ),
          const SizedBox(height: 16),
          _buildIntegrationTile(
            context: context,
            name: 'Garmin',
            icon: Icons.watch,
            isConnected: _garminId != null,
            onConnect: _connectGarmin,
            color: const Color(0xFF007CC3),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('partner_matching'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _lookingForPartner,
            onChanged: (v) => setState(() => _lookingForPartner = v),
            title: Text(
              context.translate('find_partner'),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            activeThumbColor: theme.primaryColor,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            decoration: themedInputDecoration(
              context,
              context.translate('city_region'),
              icon: Icons.place,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _preferredPaceController,
            decoration: themedInputDecoration(
              context,
              context.translate('preferred_pace'),
              suffixText: 'min/km',
              icon: Icons.speed,
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: themedInputDecoration(
              context,
              context.translate('short_bio'),
              icon: Icons.notes,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingMatching ? null : _saveMatching,
              style: primaryActionButton(context),
              child: _isSavingMatching
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(context.translate('save_settings')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationTile({
    required BuildContext context,
    required String name,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onConnect,
    required Color color,
    VoidCallback? onSync,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  isConnected
                      ? context.translate('connected')
                      : context.translate('not_connected'),
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected && onSync != null) ...[
            IconButton(
              onPressed: onSync,
              icon: Icon(Icons.sync, color: color),
              tooltip: context.translate('strava_sync'),
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected
                  ? (isDark ? Colors.white12 : Colors.black12)
                  : color,
              foregroundColor: isConnected
                  ? colorScheme.onSurface
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isConnected
                  ? context.translate('disconnect')
                  : context.translate('connect'),
            ),
          ),
        ],
      ),
    );
  }
}
