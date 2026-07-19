import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';
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

      await supabase
          .from('profiles')
          .update({'has_completed_onboarding': true})
          .eq('id', user.id);

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
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
  // Khoảng giá trị hợp lý cho thể trạng (đồng bộ với ProfilePage và cột
  // numeric(5,2) của DB) — ép người dùng nhập đúng ngay khi đăng ký.
  static const double _minWeight = 20, _maxWeight = 300; // kg
  static const double _minHeight = 90, _maxHeight = 250; // cm
  static const int _minMaxHr = 80, _maxMaxHr = 230; // bpm

  final _pageController = PageController();
  final _trainingService = TrainingService();
  final _aiService = AiService();
  final _supabase = Supabase.instance.client;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _maxHrController = TextEditingController();
  final _goalController = TextEditingController();
  final _constraintsController = TextEditingController();

  String? _gender;
  bool _isLoading = false;
  bool _isSuggestingGoals = false;
  int _currentStep = 0;
  List<String> _goalSuggestions = const [];

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _letAiDecideEnd = true;
  int _trainingDaysPerWeek = 4;
  String _preferredTime = 'flexible';

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _maxHrController.dispose();
    _goalController.dispose();
    _constraintsController.dispose();
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
      // Bắt buộc nhập đúng thể trạng (trong khoảng hợp lý) trước khi qua bước
      // mục tiêu — không cho bỏ qua bằng giá trị thiếu/vô lý.
      if (!_validateMetrics()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  /// Kiểm tra cân nặng, chiều cao, nhịp tim tối đa: bắt buộc nhập và phải nằm
  /// trong khoảng hợp lý. Hiện snackbar nếu thiếu, dialog nếu ngoài khoảng.
  bool _validateMetrics() {
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _heightController.text.trim().replaceAll(',', '.'),
    );
    // Nhịp tim tối đa KHÔNG bắt buộc; chỉ kiểm tra khoảng nếu người dùng nhập.
    final maxHrStr = _maxHrController.text.trim();
    final maxHr = maxHrStr.isEmpty ? null : int.tryParse(maxHrStr);

    if (weight == null || height == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('onboarding_info_required'))),
      );
      return false;
    }

    if (weight < _minWeight ||
        weight > _maxWeight ||
        height < _minHeight ||
        height > _maxHeight ||
        (maxHrStr.isNotEmpty &&
            (maxHr == null || maxHr < _minMaxHr || maxHr > _maxMaxHr))) {
      _showInvalidMetricsDialog();
      return false;
    }
    return true;
  }

  /// Dialog nhắc nhập thể trạng trong khoảng hợp lý (đồng bộ với ProfilePage).
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
            _metricRangeRow(
              context,
              Icons.monitor_weight,
              context.translate('weight'),
              '${_minWeight.toInt()} – ${_maxWeight.toInt()} kg',
            ),
            _metricRangeRow(
              context,
              Icons.height,
              context.translate('height'),
              '${_minHeight.toInt()} – ${_maxHeight.toInt()} cm',
            ),
            _metricRangeRow(
              context,
              Icons.favorite,
              context.translate('max_hr_label'),
              '$_minMaxHr – $_maxMaxHr bpm',
            ),
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
    BuildContext context,
    IconData icon,
    String label,
    String range,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            range,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    final weightStr = _weightController.text.trim().replaceAll(',', '.');
    final heightStr = _heightController.text.trim().replaceAll(',', '.');
    final maxHrStr = _maxHrController.text.trim();
    final goal = _goalController.text.trim();

    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final maxHr = int.tryParse(maxHrStr);

    // Thể trạng đã được kiểm tra ở bước trước (_validateMetrics); kiểm tra lại
    // để chắc chắn, đồng thời yêu cầu nhập mục tiêu.
    if (!_validateMetrics()) return;
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('onboarding_info_required'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final heightInM = height! / 100;
      final bmi = weight! / (heightInM * heightInM);

      await _supabase
          .from('profiles')
          .update({
            'weight_kg': weight,
            'height_cm': height,
            'bmi': double.parse(bmi.toStringAsFixed(2)),
            'max_hr': maxHr,
            'gender': _gender,
            'has_completed_onboarding': true,
          })
          .eq('id', user.id);
      if (!mounted) return;

      final constraints = _constraintsController.text.trim();
      final goalWithPreferences = context
          .translate('plan_goal_with_preferences', [
            goal,
            '$_trainingDaysPerWeek',
            context.translate('plan_time_$_preferredTime'),
            constraints.isEmpty
                ? context.translate('plan_constraints_none')
                : constraints,
          ]);

      // Khởi tạo lịch tập ở chế độ nền — không chặn người dùng chờ AI.
      await _trainingService.startPlanGeneration(
        goal: goalWithPreferences,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _suggestGoals() async {
    if (!_validateMetrics()) return;

    setState(() => _isSuggestingGoals = true);
    try {
      final prompt =
          '''
Tao 2 den 4 muc tieu chay bo khoi dau cho nguoi dung Runny AI.

Thong tin nguoi dung:
- Gioi tinh: ${_gender ?? 'chua ro'}
- Can nang: ${_weightController.text.trim()} kg
- Chieu cao: ${_heightController.text.trim()} cm
- Nhip tim toi da: ${_maxHrController.text.trim().isEmpty ? 'chua ro' : '${_maxHrController.text.trim()} bpm'}
- Ngay bat dau: ${DateFormat('yyyy-MM-dd').format(_startDate)}
- Ngay ket thuc: ${_letAiDecideEnd ? 'de AI tu quyet dinh' : (_endDate == null ? 'chua chon' : DateFormat('yyyy-MM-dd').format(_endDate!))}
- So buoi co the tap moi tuan: $_trainingDaysPerWeek
- Thoi gian uu tien: ${context.translate('plan_time_$_preferredTime')}
- Gioi han/luu y suc khoe: ${_constraintsController.text.trim().isEmpty ? 'khong co' : _constraintsController.text.trim()}

Yeu cau:
- Moi muc tieu la mot cau ngan, cu the, phu hop nguoi moi/nguoi quay lai tap.
- Co the gom cu ly, tan suat, thoi gian, muc do an toan.
- Khong tao lich tap chi tiet.
- Tra ve JSON dung schema: {"goals":["..."]}.
''';

      final content = await _aiService.generateResponse(
        prompt,
        feature: AiFeature.onboardingGoals,
      );
      final suggestions = _parseGoalSuggestions(content);

      if (!mounted) return;
      if (suggestions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('goal_suggestions_empty'))),
        );
        return;
      }

      setState(() {
        _goalSuggestions = suggestions;
        _goalController.text = suggestions.first;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.translate('error')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSuggestingGoals = false);
    }
  }

  List<String> _parseGoalSuggestions(String content) {
    final trimmed = content.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return const [];
    final jsonText = trimmed.substring(start, end + 1);
    final decoded = jsonDecode(jsonText);
    final rawGoals = decoded is Map ? decoded['goals'] : null;
    if (rawGoals is! List) return const [];
    return rawGoals
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
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
    );
  }

  Widget _buildMetricsStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ResponsiveContent(
      maxWidth: 560,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 900 ? 20.0 : 16.0,
          vertical: 16.0,
        ),
        child: glassCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.translate('athlete_metrics'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.translate('onboarding_metrics_desc'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _weightController,
                decoration: themedInputDecoration(
                  context,
                  context.translate('weight'),
                  suffixText: 'kg',
                  icon: Icons.monitor_weight,
                  isRequired: true,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _heightController,
                decoration: themedInputDecoration(
                  context,
                  context.translate('height'),
                  suffixText: 'cm',
                  icon: Icons.height,
                  isRequired: true,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _maxHrController,
                decoration:
                    themedInputDecoration(
                      context,
                      context.translate('max_hr_label'),
                      hint: context.translate('max_hr_hint'),
                      suffixText: 'bpm',
                      icon: Icons.favorite,
                    ).copyWith(
                      suffixIcon: Tooltip(
                        message: context.translate('max_hr_tooltip'),
                        triggerMode: TooltipTriggerMode.tap,
                        child: const Icon(Icons.info_outline),
                      ),
                    ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 20),
              GenderSelector(
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _nextPage,
                style: primaryActionButton(context),
                child: Text(context.translate('next')),
              ),
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
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 900 ? 20.0 : 16.0,
          vertical: 16.0,
        ),
        child: glassCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.translate('training_goal'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.translate('training_goal_desc'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              _OnboardingDateTile(
                icon: Icons.play_circle_outline,
                label: context.translate('plan_start_date'),
                value: DateFormat('dd/MM/yyyy').format(_startDate),
                onTap: _isSuggestingGoals ? null : _pickStartDate,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _letAiDecideEnd,
                onChanged: _isSuggestingGoals
                    ? null
                    : (v) => setState(() => _letAiDecideEnd = v),
                title: Text(
                  context.translate('let_ai_decide_end'),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  context.translate('let_ai_decide_end_desc'),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!_letAiDecideEnd) ...[
                const SizedBox(height: 8),
                _OnboardingDateTile(
                  icon: Icons.flag_outlined,
                  label: context.translate('plan_end_date'),
                  value: _endDate != null
                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                      : context.translate('plan_end_date_hint'),
                  onTap: _isSuggestingGoals ? null : _pickEndDate,
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _goalController,
                maxLines: 5,
                enabled: !_isSuggestingGoals,
                decoration: themedInputDecoration(
                  context,
                  context.translate('your_goal'),
                  hint: context.translate('goal_hint'),
                  icon: Icons.flag_circle,
                  isRequired: true,
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              GradientButton.icon(
                width: double.infinity,
                onPressed: _isSuggestingGoals || _goalSuggestions.isNotEmpty
                    ? null
                    : _suggestGoals,
                icon: _isSuggestingGoals
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(context.translate('ai_suggest_goals')),
              ),
              if (_goalSuggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  children: _goalSuggestions.map((goal) {
                    final selected = _goalController.text.trim() == goal;
                    return _GoalSuggestionTile(
                      goal: goal,
                      selected: selected,
                      onTap: () => setState(() {
                        _goalController.text = goal;
                      }),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                context.translate('plan_days_per_week', [
                  '$_trainingDaysPerWeek',
                ]),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _trainingDaysPerWeek.toDouble(),
                min: 2,
                max: 6,
                divisions: 4,
                label: '$_trainingDaysPerWeek',
                onChanged: _isSuggestingGoals
                    ? null
                    : (value) =>
                          setState(() => _trainingDaysPerWeek = value.round()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _preferredTime,
                decoration: themedInputDecoration(
                  context,
                  context.translate('plan_preferred_time'),
                  icon: Icons.schedule,
                ),
                items: ['flexible', 'morning', 'evening']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(context.translate('plan_time_$value')),
                      ),
                    )
                    .toList(),
                onChanged: _isSuggestingGoals
                    ? null
                    : (value) =>
                          setState(() => _preferredTime = value ?? 'flexible'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _constraintsController,
                maxLines: 3,
                enabled: !_isSuggestingGoals,
                decoration: themedInputDecoration(
                  context,
                  context.translate('plan_constraints_label'),
                  hint: context.translate('plan_constraints_hint'),
                  icon: Icons.health_and_safety_outlined,
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.translate('plan_ai_context_note'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              GradientButton.icon(
                width: double.infinity,
                onPressed: _isSuggestingGoals ? null : _nextPage,
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                label: Text(context.translate('complete_create_plan')),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (_currentStep > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentStep--);
                  }
                },
                child: Text(
                  context.translate('back'),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSuggestionTile extends StatelessWidget {
  final String goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalSuggestionTile({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.24 : 0.12)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.035)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.72)
                  : theme.dividerColor.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.25,
                  ),
                ),
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
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 900 ? 20.0 : 16.0,
      ),
      child: Row(
        children: [
          _StepDot(
            label: context.translate('metrics_tab'),
            active: currentStep == 0,
          ),
          Expanded(
            child: Container(
              height: 2,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          _StepDot(
            label: context.translate('goal_tab'),
            active: currentStep == 1,
          ),
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
            color: active
                ? theme.primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ],
    );
  }
}

class _OnboardingDateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _OnboardingDateTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

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
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.calendar_month,
              color: isDark ? Colors.white54 : Colors.black45,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
