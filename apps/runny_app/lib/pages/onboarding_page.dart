import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import 'dashboard_page.dart';
import '../l10n/app_localizations.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('app_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const LanguageSwitcher(),
          const ThemeToggle(),
          TextButton(
            onPressed: () => _skipOnboarding(context),
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: const OnboardingContent(),
    );
  }

  Future<void> _skipOnboarding(BuildContext context) async {
    final supabase = Supabase.instance.client;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('profiles').update({
        'has_completed_onboarding': true,
      }).eq('id', user.id);

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class OnboardingContent extends StatefulWidget {
  const OnboardingContent({super.key});

  @override
  State<OnboardingContent> createState() => _OnboardingContentState();
}

class _OnboardingContentState extends State<OnboardingContent> {
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
    final weightStr = _weightController.text.trim().replaceAll(',', '.');
    final heightStr = _heightController.text.trim().replaceAll(',', '.');
    final maxHrStr = _maxHrController.text.trim();
    final goal = _goalController.text.trim();

    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final maxHr = int.tryParse(maxHrStr);

    if (weight == null || height == null || goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all required information')),
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient(context)))),
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
    );
  }

  Widget _buildMetricsStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Athlete metrics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87
            )),
            const SizedBox(height: 12),
            Text('Set up your baseline metrics for personalized AI training.', 
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 28),
            TextField(
              controller: _weightController,
              decoration: themedInputDecoration(context, 'Weight', suffixText: 'kg', icon: Icons.monitor_weight),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _heightController,
              decoration: themedInputDecoration(context, 'Height', suffixText: 'cm', icon: Icons.height),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _maxHrController,
              decoration: themedInputDecoration(context, 'Max HR', hint: '220 - age', suffixText: 'bpm', icon: Icons.favorite),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(context), child: const Text('Next')),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Training goal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87
            )),
            const SizedBox(height: 12),
            Text('Tell us your primary goal so AI can build your winning roadmap.', 
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 28),
            TextField(
              controller: _goalController,
              maxLines: 5,
              decoration: themedInputDecoration(
                context,
                'Your Goal',
                hint: 'e.g., I want to run my first 5km under 25 minutes.',
                icon: Icons.flag_circle,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(context), child: const Text('Complete & Create Plan')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (_currentStep > 0) {
                  _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                  setState(() => _currentStep--);
                }
              },
              child: Text('Back', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StepDot(label: 'Metrics', active: currentStep == 0),
          Expanded(child: Container(height: 2, color: theme.dividerColor.withValues(alpha: 0.1))),
          _StepDot(label: 'Goal', active: currentStep == 1),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : (isDark ? Colors.white12 : Colors.black12),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: active ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white54 : Colors.black45))),
      ],
    );
  }
}
