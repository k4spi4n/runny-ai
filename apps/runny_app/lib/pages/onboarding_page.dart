import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import 'dashboard_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _trainingService = TrainingService();
  final _supabase = Supabase.instance.client;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _goalController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _maxHrController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final maxHr = int.tryParse(_maxHrController.text);
    final goal = _goalController.text.trim();

    if (weight == null || height == null || goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')), 
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final heightInM = height / 100;
      final bmi = weight / (heightInM * heightInM);

      await _supabase.from('profiles').update({
        'weight_kg': weight,
        'height_cm': height,
        'bmi': double.parse(bmi.toStringAsFixed(2)),
        'max_hr': maxHr,
        'has_completed_onboarding': true,
      }).eq('id', user.id);

      await _trainingService.createGoalBasedPlan(goal);

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi khởi tạo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Thiết lập tài khoản'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            },
            child: const Text(
              'Bỏ qua',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient))),
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.orange.withValues(alpha: 0.16), Colors.transparent]),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  _OnboardingStepper(currentStep: _currentStep),
                  const SizedBox(height: 18),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricsStep(context),
                        _buildGoalStep(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Athlete metrics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Thiết lập chỉ số nền tảng để AI đưa ra lịch tập tối ưu cho bạn.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 28),
            TextField(
              controller: _weightController,
              decoration: themedInputDecoration('Cân nặng', suffixText: 'kg', icon: Icons.monitor_weight),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _heightController,
              decoration: themedInputDecoration('Chiều cao', suffixText: 'cm', icon: Icons.height),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _maxHrController,
              decoration: themedInputDecoration('Nhịp tim tối đa', hint: '220 - tuổi', suffixText: 'bpm', icon: Icons.favorite),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(), child: const Text('Tiếp theo')),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Training goal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Cho chúng tôi biết mục tiêu hàng đầu của bạn để AI đưa ra lộ trình chiến thắng.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 28),
            TextField(
              controller: _goalController,
              maxLines: 5,
              decoration: themedInputDecoration(
                'Mục tiêu của bạn',
                hint: 'Ví dụ: Tôi muốn hoàn thành 5km với pace dưới 5:30 trong 6 tuần.',
                icon: Icons.flag_circle,
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.psychology, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI sẽ dùng mục tiêu này để cá nhân hóa cường độ, phục hồi và khối lượng tập.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(), child: const Text('Hoàn tất & Tạo lịch tập')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (_currentStep > 0) {
                  _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                  setState(() => _currentStep--);
                }
              },
              child: const Text('Quay lại', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStepper extends StatelessWidget {
  final int currentStep;

  const _OnboardingStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StepDot(label: 'Chỉ số', active: currentStep == 0),
          Expanded(child: Container(height: 2, color: Colors.white12)),
          _StepDot(label: 'Mục tiêu', active: currentStep == 1),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;

  const _StepDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFA6B27) : Colors.white12,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54)),
      ],
    );
  }
}
