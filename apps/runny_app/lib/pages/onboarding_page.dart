import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
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

  // Step 1: Metrics
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHrController = TextEditingController();

  // Step 2: Goal
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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text); // in cm
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

      // Calculate BMI
      final heightInM = height / 100;
      final bmi = weight / (heightInM * heightInM);

      // 1. Update Profile
      await _supabase.from('profiles').update({
        'weight_kg': weight,
        'bmi': double.parse(bmi.toStringAsFixed(2)),
        'max_hr': maxHr,
      }).eq('id', user.id);

      // 2. Generate Initial Plan via AI
      await _trainingService.createGoalBasedPlan(goal);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi khởi tạo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập tài khoản'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text('AI đang thiết kế lịch tập riêng cho bạn...'),
                  const SizedBox(height: 8),
                  const Text('Vui lòng đợi trong giây lát', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricsStep(),
                _buildGoalStep(),
              ],
            ),
    );
  }

  Widget _buildMetricsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chỉ số cơ thể',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Thông tin này giúp AI tính toán cường độ tập luyện phù hợp.'),
          const SizedBox(height: 32),
          TextField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Cân nặng (kg)',
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Chiều cao (cm)',
              border: OutlineInputBorder(),
              suffixText: 'cm',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxHrController,
            decoration: const InputDecoration(
              labelText: 'Nhịp tim tối đa (tùy chọn)',
              hintText: 'Mặc định: 220 - tuổi',
              border: OutlineInputBorder(),
              suffixText: 'bpm',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tiếp theo'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mục tiêu của bạn',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Bạn muốn đạt được điều gì trong thời gian tới?'),
          const SizedBox(height: 32),
          TextField(
            controller: _goalController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Tôi muốn chạy được 5km liên tục sau 1 tháng, hiện tại tôi có thể chạy 2km.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            color: Colors.blueGrey,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.psychology, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI sẽ dựa vào mục tiêu này để cá nhân hóa lịch tập cho bạn.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hoàn tất & Tạo lịch tập'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              _currentStep--;
            }),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }
}
