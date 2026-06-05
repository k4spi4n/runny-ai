import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../services/integration_service.dart';
import '../services/social_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải hồ sơ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);
      final maxHr = int.tryParse(_maxHrController.text);

      double? bmi;
      if (weight != null && height != null && height > 0) {
        final heightInM = height / 100;
        bmi = double.parse((weight / (heightInM * heightInM)).toStringAsFixed(2));
      }

      await _supabase.from('profiles').update({
        'display_name': _displayNameController.text.trim(),
        'weight_kg': weight,
        'height_cm': height,
        'max_hr': maxHr,
        'bmi': bmi,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật hồ sơ thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật: $e')),
        );
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
          const SnackBar(content: Text('Đã lưu thiết lập ghép đôi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã ngắt kết nối Strava')));
      } else {
        await _integrationService.connectStrava();
      }
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _connectGarmin() async {
    try {
      if (_garminId != null) {
        await _integrationService.disconnectGarmin();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã ngắt kết nối Garmin')));
      } else {
        await _integrationService.connectGarmin();
      }
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildMetricsSection(),
          const SizedBox(height: 24),
          _buildIntegrationsSection(),
          const SizedBox(height: 24),
          _buildMatchingSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return glassCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFFA6B27),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Tên hiển thị',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _supabase.auth.currentUser?.email ?? '',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉ số Thể trạng (Requirement 1.2)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            decoration: themedInputDecoration('Cân nặng', suffixText: 'kg', icon: Icons.monitor_weight),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            decoration: themedInputDecoration('Chiều cao', suffixText: 'cm', icon: Icons.height),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxHrController,
            decoration: themedInputDecoration('Nhịp tim tối đa', suffixText: 'bpm', icon: Icons.favorite),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: primaryActionButton(),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Cập nhật chỉ số'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationsSection() {
    return glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết nối Nền tảng (Requirement 1.3)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          _buildIntegrationTile(
            name: 'Strava',
            icon: Icons.directions_run,
            isConnected: _stravaId != null,
            onConnect: _connectStrava,
            color: const Color(0xFFFC4C02),
          ),
          const SizedBox(height: 16),
          _buildIntegrationTile(
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

  Widget _buildMatchingSection() {
    return glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ghép đôi Bạn chạy (Requirement 4.3)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bật để xuất hiện trong gợi ý của người chạy khác và nhận lời mời chạy cùng.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _lookingForPartner,
            onChanged: (v) => setState(() => _lookingForPartner = v),
            title: const Text('Tìm bạn chạy', style: TextStyle(color: Colors.white)),
            activeThumbColor: const Color(0xFFFA6B27),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            decoration: themedInputDecoration('Khu vực / Thành phố', icon: Icons.place),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _preferredPaceController,
            decoration: themedInputDecoration('Pace mong muốn', suffixText: 'phút/km', icon: Icons.speed),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: themedInputDecoration('Giới thiệu ngắn', icon: Icons.notes),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingMatching ? null : _saveMatching,
              style: primaryActionButton(),
              child: _isSavingMatching
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Lưu thiết lập ghép đôi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationTile({
    required String name,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onConnect,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(
                  isConnected ? 'Đã kết nối' : 'Chưa kết nối',
                  style: TextStyle(color: isConnected ? Colors.green : Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.white12 : color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isConnected ? 'Ngắt kết nối' : 'Kết nối'),
          ),
        ],
      ),
    );
  }
}
