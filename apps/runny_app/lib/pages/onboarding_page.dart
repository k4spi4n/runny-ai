import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            child: Text(
              context.translate('skip'),
              style: const TextStyle(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.translate('error')}: $e')));
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

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _letAiDecideEnd = true;

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _maxHrController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && !_endDate!.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initial = _endDate ?? _startDate.add(const Duration(days: 28));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: _startDate.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
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
        SnackBar(content: Text(context.translate('onboarding_info_required'))),
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

      // Khởi tạo lịch tập ở chế độ nền — không chặn người dùng chờ AI.
      await _trainingService.startPlanGeneration(
        goal: goal,
        startDate: _startDate,
        endDate: _letAiDecideEnd ? null : _endDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('plan_generation_started'))),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.translate('error')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    return ResponsiveContent(
      maxWidth: 560,
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('athlete_metrics'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87
            )),
            const SizedBox(height: 12),
            Text(context.translate('onboarding_metrics_desc'), 
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 28),
            TextField(
              controller: _weightController,
              decoration: themedInputDecoration(context, context.translate('weight'), suffixText: 'kg', icon: Icons.monitor_weight),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _heightController,
              decoration: themedInputDecoration(context, context.translate('height'), suffixText: 'cm', icon: Icons.height),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _maxHrController,
              decoration: themedInputDecoration(context, context.translate('max_hr_label'), hint: context.translate('max_hr_hint'), suffixText: 'bpm', icon: Icons.favorite),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(context), child: Text(context.translate('next'))),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildGoalStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ResponsiveContent(
      maxWidth: 560,
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: glassCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('training_goal'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87
            )),
            const SizedBox(height: 12),
            Text(context.translate('training_goal_desc'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 24),
            _OnboardingDateTile(
              icon: Icons.play_circle_outline,
              label: context.translate('plan_start_date'),
              value: DateFormat('dd/MM/yyyy').format(_startDate),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _letAiDecideEnd,
              onChanged: (v) => setState(() => _letAiDecideEnd = v),
              title: Text(
                context.translate('let_ai_decide_end'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                context.translate('let_ai_decide_end_desc'),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
              ),
            ),
            if (!_letAiDecideEnd) ...[
              const SizedBox(height: 8),
              _OnboardingDateTile(
                icon: Icons.flag_outlined,
                label: context.translate('plan_end_date'),
                value: _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : context.translate('plan_end_date_hint'),
                onTap: _pickEndDate,
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _goalController,
              maxLines: 5,
              decoration: themedInputDecoration(
                context,
                context.translate('your_goal'),
                hint: context.translate('goal_hint'),
                icon: Icons.flag_circle,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _nextPage, style: primaryActionButton(context), child: Text(context.translate('complete_create_plan'))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (_currentStep > 0) {
                  _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                  setState(() => _currentStep--);
                }
              },
              child: Text(context.translate('back'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ),
          ],
        ),
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
          _StepDot(label: context.translate('metrics_tab'), active: currentStep == 0),
          Expanded(child: Container(height: 2, color: theme.dividerColor.withValues(alpha: 0.1))),
          _StepDot(label: context.translate('goal_tab'), active: currentStep == 1),
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

class _OnboardingDateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _OnboardingDateTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Icon(Icons.calendar_month, color: isDark ? Colors.white54 : Colors.black45, size: 20),
          ],
        ),
      ),
    );
  }
}
