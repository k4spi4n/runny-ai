import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../services/integration_service.dart';
import '../services/social_service.dart';
import '../l10n/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _integrationService = IntegrationService();
  final _socialService = SocialService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _preferredPaceController = TextEditingController();

  String? _stravaId;
  String? _garminId;
  bool _lookingForPartner = false;
  bool _isSavingMatching = false;

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

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _displayNameController.text = data['display_name'] ?? '';
        _weightController.text = (data['weight_kg'] ?? '').toString();
        _heightController.text = (data['height_cm'] ?? '').toString();
        _maxHrController.text = (data['max_hr'] ?? '').toString();
        _stravaId = data['strava_id'];
        _garminId = data['garmin_id'];
        _cityController.text = data['city'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _preferredPaceController.text = (data['preferred_pace_min_per_km'] ?? '').toString();
        _lookingForPartner = data['looking_for_partner'] == true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
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
        const SnackBar(content: Text('Please enter weight and height')),
      );
      return;
    }

    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final maxHr = int.tryParse(maxHrStr);

    if (weight == null || height == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid weight or height')),
      );
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
            'bmi': bmi,
            'has_completed_onboarding': true,
          })
          .eq('id', user.id);

      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveMatching() async {
    setState(() => _isSavingMatching = true);
    try {
      await _socialService.updateMatchingPreferences(
        lookingForPartner: _lookingForPartner,
        preferredPace: double.tryParse(_preferredPaceController.text),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matching settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingMatching = false);
    }
  }

  Future<void> _connectStrava() async {
    try {
      if (_stravaId != null) {
        await _integrationService.disconnectStrava();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Disconnected from Strava')));
      } else {
        await _integrationService.connectStrava();
      }
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _connectGarmin() async {
    try {
      if (_garminId != null) {
        await _integrationService.disconnectGarmin();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Disconnected from Garmin')));
      } else {
        await _integrationService.connectGarmin();
      }
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                context.translate('Logout'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _supabase.auth.signOut();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Logout error: $e')),
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
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
              hintText: 'Display Name',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
            'Body Metrics',
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
              'Weight',
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
              'Height',
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
              'Max HR',
              suffixText: 'bpm',
              icon: Icons.favorite,
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: primaryActionButton(context),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Update Metrics'),
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
            'Integrations',
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
            'Partner Matching',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: colorScheme.onSurface
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _lookingForPartner,
            onChanged: (v) => setState(() => _lookingForPartner = v),
            title: Text('Find Running Partner', style: TextStyle(color: colorScheme.onSurface)),
            activeThumbColor: theme.primaryColor,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            decoration: themedInputDecoration(context, 'City / Region', icon: Icons.place),
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _preferredPaceController,
            decoration: themedInputDecoration(context, 'Preferred Pace', suffixText: 'min/km', icon: Icons.speed),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: themedInputDecoration(context, 'Short Bio', icon: Icons.notes),
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
                  : const Text('Save Settings'),
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
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
                  isConnected ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    color: isConnected ? Colors.green : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? (isDark ? Colors.white12 : Colors.black12) : color,
              foregroundColor: isConnected ? colorScheme.onSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}
