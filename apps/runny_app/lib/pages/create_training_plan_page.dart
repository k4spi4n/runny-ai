import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final TextEditingController _goalController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _letAiDecideEnd = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
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
    try {
      await _trainingService.startPlanGeneration(
        goal: goal,
        startDate: _startDate,
        endDate: _letAiDecideEnd ? null : _endDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(startedMsg)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.translate('error')}: $e')),
      );
    }
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
        title: Text(context.translate('create_plan_title'), style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Stack(
        children: [
          SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient(context)))),
          SafeArea(
            child: ResponsiveContent(
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
                      context.translate('create_plan_subtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    // Ngày bắt đầu
                    _DateTile(
                      icon: Icons.play_circle_outline,
                      label: context.translate('plan_start_date'),
                      value: dateFmt.format(_startDate),
                      onTap: _isSubmitting ? null : _pickStartDate,
                    ),
                    const SizedBox(height: 16),
                    // Ngày kết thúc (tùy chọn)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _letAiDecideEnd,
                      onChanged: _isSubmitting ? null : (v) => setState(() => _letAiDecideEnd = v),
                      title: Text(
                        context.translate('let_ai_decide_end'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        context.translate('let_ai_decide_end_desc'),
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    if (!_letAiDecideEnd) ...[
                      const SizedBox(height: 8),
                      _DateTile(
                        icon: Icons.flag_outlined,
                        label: context.translate('plan_end_date'),
                        value: _endDate != null ? dateFmt.format(_endDate!) : context.translate('plan_end_date_hint'),
                        onTap: _isSubmitting ? null : _pickEndDate,
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Mục tiêu
                    TextField(
                      controller: _goalController,
                      maxLines: 4,
                      enabled: !_isSubmitting,
                      decoration: themedInputDecoration(
                        context,
                        context.translate('plan_goal_label'),
                        hint: context.translate('goal_hint'),
                        icon: Icons.flag_circle,
                        isRequired: true,
                      ),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.translate('plan_ai_context_note'),
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: primaryActionButton(context),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.translate('generate_plan_btn')),
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

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DateTile({required this.icon, required this.label, required this.value, this.onTap});

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
                Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Icon(Icons.calendar_month, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
