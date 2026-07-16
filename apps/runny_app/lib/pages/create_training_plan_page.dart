import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gemini_service.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import '../widgets/paywall.dart';
import '../l10n/app_localizations.dart';

/// Màn hình tạo lịch tập: người dùng nhập ngày bắt đầu (mặc định hôm nay),
/// ngày kết thúc (tùy chọn — có thể để AI tự chọn) và mục tiêu. Khi gửi, AI sẽ
/// phân tích thể trạng + 5 hoạt động gần nhất để sinh lịch ở chế độ nền, người
/// dùng có thể rời màn hình ngay mà không cần chờ.
class CreateTrainingPlanPage extends StatefulWidget {
  const CreateTrainingPlanPage({super.key});

  @override
  State<CreateTrainingPlanPage> createState() => _CreateTrainingPlanPageState();
}

class _CreateTrainingPlanPageState extends State<CreateTrainingPlanPage> {
  final TrainingService _trainingService = TrainingService();
  final GeminiService _geminiService = GeminiService();
  final _supabase = Supabase.instance.client;
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _constraintsController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _letAiDecideEnd = true;
  bool _isSubmitting = false;
  bool _isSuggestingGoals = false;
  int _trainingDaysPerWeek = 4;
  String _preferredTime = 'flexible';
  List<String> _goalSuggestions = const [];

  @override
  void dispose() {
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
        // Đảm bảo ngày kết thúc luôn sau ngày bắt đầu.
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

  Future<void> _submit() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('plan_goal_required'))),
      );
      return;
    }

    // Tạo kế hoạch là tính năng cao cấp: chặn tier free trước khi chạy nền.
    if (!await ensurePaywall(context, 'plan')) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final startedMsg = context.translate('plan_generation_started');
    final preferredTimeLabel = context.translate('plan_time_$_preferredTime');
    final constraints = _constraintsController.text.trim();
    final goalWithPreferences = context
        .translate('plan_goal_with_preferences', [
          goal,
          '$_trainingDaysPerWeek',
          preferredTimeLabel,
          constraints.isEmpty
              ? context.translate('plan_constraints_none')
              : constraints,
        ]);
    try {
      await _trainingService.startPlanGeneration(
        goal: goalWithPreferences,
        startDate: _startDate,
        endDate: _letAiDecideEnd ? null : _endDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(startedMsg)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.translate('error')}: $e')),
      );
    }
  }

  Future<void> _suggestGoals() async {
    setState(() => _isSuggestingGoals = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase
          .from('profiles')
          .select('gender, weight_kg, height_cm, max_hr')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final constraints = _constraintsController.text.trim();
      final prompt =
          '''
Tao 2 den 4 muc tieu chay bo an toan, cu the va phu hop nguoi dung Runny AI.

Thong tin nguoi dung:
- Gioi tinh: ${profile?['gender'] ?? 'chua ro'}
- Can nang: ${profile?['weight_kg'] ?? 'chua ro'} kg
- Chieu cao: ${profile?['height_cm'] ?? 'chua ro'} cm
- Nhip tim toi da: ${profile?['max_hr'] ?? 'chua ro'} bpm
- Muc tieu dang nhap: ${_goalController.text.trim().isEmpty ? 'chua co' : _goalController.text.trim()}
- Ngay bat dau: ${DateFormat('yyyy-MM-dd').format(_startDate)}
- Ngay ket thuc: ${_letAiDecideEnd ? 'de AI tu quyet dinh' : (_endDate == null ? 'chua chon' : DateFormat('yyyy-MM-dd').format(_endDate!))}
- So buoi co the tap moi tuan: $_trainingDaysPerWeek
- Thoi gian uu tien: ${context.translate('plan_time_$_preferredTime')}
- Gioi han/luu y suc khoe: ${constraints.isEmpty ? 'khong co' : constraints}

Yeu cau:
- Moi muc tieu la mot cau ngan, cu the va phu hop the trang hien tai.
- Co the gom cu ly, tan suat, thoi gian, muc do an toan.
- Khong tao lich tap chi tiet.
- Tra ve JSON dung schema: {"goals":["..."]}.
''';
      final content = await _geminiService.generateResponse(
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
    final decoded = jsonDecode(trimmed.substring(start, end + 1));
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('EEEE, dd/MM/yyyy');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.translate('create_plan_title'),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
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
            child: ResponsiveContent(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 900
                      ? 20.0
                      : 16.0,
                  vertical: 16.0,
                ),
                child: glassCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.translate('create_plan_subtitle'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Ngày bắt đầu
                      _DateTile(
                        icon: Icons.play_circle_outline,
                        label: context.translate('plan_start_date'),
                        value: dateFmt.format(_startDate),
                        onTap: _isSubmitting || _isSuggestingGoals
                            ? null
                            : _pickStartDate,
                      ),
                      const SizedBox(height: 16),
                      // Ngày kết thúc (tùy chọn)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _letAiDecideEnd,
                        onChanged: _isSubmitting || _isSuggestingGoals
                            ? null
                            : (v) => setState(() => _letAiDecideEnd = v),
                        title: Text(
                          context.translate('let_ai_decide_end'),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          context.translate('let_ai_decide_end_desc'),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (!_letAiDecideEnd) ...[
                        const SizedBox(height: 8),
                        _DateTile(
                          icon: Icons.flag_outlined,
                          label: context.translate('plan_end_date'),
                          value: _endDate != null
                              ? dateFmt.format(_endDate!)
                              : context.translate('plan_end_date_hint'),
                          onTap: _isSubmitting || _isSuggestingGoals
                              ? null
                              : _pickEndDate,
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Mục tiêu
                      TextField(
                        controller: _goalController,
                        maxLines: 4,
                        enabled: !_isSubmitting && !_isSuggestingGoals,
                        decoration: themedInputDecoration(
                          context,
                          context.translate('plan_goal_label'),
                          hint: context.translate('goal_hint'),
                          icon: Icons.flag_circle,
                          isRequired: true,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GradientButton.icon(
                        width: double.infinity,
                        onPressed:
                            _isSubmitting ||
                                _isSuggestingGoals ||
                                _goalSuggestions.isNotEmpty
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
                            : const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                              ),
                        label: Text(context.translate('ai_suggest_goals')),
                      ),
                      if (_goalSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Column(
                          children: _goalSuggestions.map((goal) {
                            final selected =
                                _goalController.text.trim() == goal;
                            return _GoalSuggestionTile(
                              goal: goal,
                              selected: selected,
                              onTap: () =>
                                  setState(() => _goalController.text = goal),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        context.translate('plan_days_per_week', [
                          '$_trainingDaysPerWeek',
                        ]),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: _trainingDaysPerWeek.toDouble(),
                        min: 2,
                        max: 6,
                        divisions: 4,
                        label: '$_trainingDaysPerWeek',
                        onChanged: _isSubmitting || _isSuggestingGoals
                            ? null
                            : (value) => setState(
                                () => _trainingDaysPerWeek = value.round(),
                              ),
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
                                child: Text(
                                  context.translate('plan_time_$value'),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting || _isSuggestingGoals
                            ? null
                            : (value) => setState(
                                () => _preferredTime = value ?? 'flexible',
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _constraintsController,
                        maxLines: 3,
                        enabled: !_isSubmitting && !_isSuggestingGoals,
                        decoration: themedInputDecoration(
                          context,
                          context.translate('plan_constraints_label'),
                          hint: context.translate('plan_constraints_hint'),
                          icon: Icons.health_and_safety_outlined,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.translate('plan_ai_context_note'),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      GradientButton.icon(
                        width: double.infinity,
                        onPressed: _isSubmitting || _isSuggestingGoals
                            ? null
                            : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.calendar_month,
                                color: Colors.white,
                              ),
                        label: Text(context.translate('generate_plan_btn')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSuggestionTile extends StatelessWidget {
  const _GoalSuggestionTile({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final String goal;
  final bool selected;
  final VoidCallback onTap;

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

@Preview(
  name: 'Goal suggestions - Light',
  group: 'Training plan',
  size: Size(420, 360),
  brightness: Brightness.light,
)
@Preview(
  name: 'Goal suggestions - Dark',
  group: 'Training plan',
  size: Size(420, 360),
  brightness: Brightness.dark,
)
Widget createPlanGoalSuggestionsPreview() {
  return MaterialApp(
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GradientButton.icon(
              width: double.infinity,
              onPressed: () {},
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('AI gợi ý mục tiêu'),
            ),
            const SizedBox(height: 12),
            GradientButton.icon(
              width: double.infinity,
              onPressed: () {},
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              label: const Text('Tạo lịch tập'),
            ),
            const SizedBox(height: 12),
            _GoalSuggestionTile(
              goal: 'Chạy liên tục 5 km trong 8 tuần, 3 buổi mỗi tuần.',
              selected: true,
              onTap: () {},
            ),
            _GoalSuggestionTile(
              goal: 'Duy trì 4 buổi chạy nhẹ mỗi tuần trong 1 tháng.',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DateTile({
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
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.calendar_month,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
