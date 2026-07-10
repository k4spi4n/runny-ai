import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/run_reminder_model.dart';
import '../services/run_reminder_service.dart';
import '../services/training_service.dart';
import '../services/paywall_exception.dart';
import '../widgets/ui_components.dart';
import '../widgets/paywall.dart';
import 'create_training_plan_page.dart';
import 'manual_workout_page.dart';
import 'ai_coach_page.dart';
import 'training_history_page.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import 'import_activity_page.dart';

(int, int) _parseWorkoutTime(String? raw) {
  if (raw == null || raw.isEmpty) return (6, 0);
  final parts = raw.split(':');
  if (parts.length < 2) return (6, 0);
  final hour = int.tryParse(parts[0]) ?? 6;
  final minute = int.tryParse(parts[1]) ?? 0;
  return (hour.clamp(0, 23).toInt(), minute.clamp(0, 59).toInt());
}

class TrainingPlanPage extends StatefulWidget {
  /// [embedded] = true khi hiển thị bên trong khung tab của Dashboard: bỏ nền
  /// gradient riêng (Dashboard đã vẽ gradient toàn màn) để không tạo ra "box"
  /// hình chữ nhật lệch màu, đồng bộ với các tab còn lại.
  final bool embedded;

  const TrainingPlanPage({super.key, this.embedded = false});

  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TrainingService _trainingService = TrainingService();
  final RunReminderService _reminderService = RunReminderService();
  bool _isLoading = true;
  Map<String, dynamic>? _activeSchedule;
  List<Map<String, dynamic>> _workouts = [];
  Map<String, RunReminder> _runReminders = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Lấy lịch gần nhất ở một trong các trạng thái hiển thị tại tab này:
      // active (đang chạy), completed (vừa hoàn thành — hiện banner chúc mừng),
      // generating (AI đang tạo), failed (tạo lỗi). Các trạng thái abandoned/
      // archived chỉ xuất hiện trong màn hình Lịch sử.
      final schedule = await _supabase
          .from('training_schedules')
          .select()
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'completed', 'generating', 'failed'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      List<Map<String, dynamic>> workouts = [];
      if (schedule != null &&
          (schedule['status'] == 'active' ||
              schedule['status'] == 'completed')) {
        workouts = List<Map<String, dynamic>>.from(
          await _supabase
              .from('scheduled_workouts')
              .select()
              .eq('schedule_id', schedule['id'])
              .order('date', ascending: true),
        ).map(TrainingService.normalizeScheduledWorkout).toList();

        // Tự động chuyển sang 'completed' khi mọi buổi tập đã hoàn thành — để lịch
        // được lưu vào Lịch sử. Bao phủ cả luồng liên kết lẫn tải hoạt động.
        if (schedule['status'] == 'active' &&
            workouts.isNotEmpty &&
            workouts.every((w) => w['status'] == 'completed')) {
          await _supabase
              .from('training_schedules')
              .update({'status': 'completed'})
              .eq('id', schedule['id']);
          schedule['status'] = 'completed';
        }
      }
      Map<String, RunReminder> reminders = {};
      if (workouts.isNotEmpty) {
        reminders = await _reminderService.remindersForWorkouts(
          workouts.map((w) => w['id'] as String).toList(),
        );
      }

      if (mounted) {
        setState(() {
          _activeSchedule = schedule;
          _workouts = workouts;
          _runReminders = reminders;
        });
      }
    } catch (e) {
      debugPrint('Error fetching training plan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adjustPlan() async {
    // Điều chỉnh kế hoạch bằng AI là tính năng cao cấp: chặn tier free trước.
    if (!await ensurePaywall(context, 'plan')) return;
    if (!mounted) return;

    // Bước 1: HLV AI phân tích và ĐỀ XUẤT (chưa lưu).
    setState(() => _isLoading = true);
    PlanAdjustmentProposal proposal;
    try {
      proposal = await _trainingService.proposePlanAdjustments();
    } on NoCompletedWorkoutException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('adjust_need_workout'))),
      );
      return;
    } on PaywallException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await showUpgradeSheet(context, message: e.message);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.translate('error')}: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (proposal.isEmpty) {
      // AI thấy lịch đã hợp lý — không có gì để đổi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('adjust_no_change'))),
      );
      return;
    }

    // Bước 2: người dùng xem trước thay đổi + giải thích, xác nhận mới lưu.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AdjustmentPreviewDialog(proposal: proposal),
    );
    if (confirmed != true || !mounted) return;

    // Bước 3: đã xác nhận -> ghi vào DB.
    setState(() => _isLoading = true);
    try {
      await _trainingService.applyPlanAdjustments(proposal.adjustments);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('plan_adjusted'))),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _activeSchedule?['status'] as String?;

    if (status == 'generating') {
      return _buildGeneratingState(context);
    }

    if (status == 'failed') {
      return _buildFailedState(context);
    }

    if (_activeSchedule == null || _workouts.isEmpty) {
      return _buildEmptyState(context);
    }

    final completedWorkouts = _workouts
        .where((w) => w['status'] == 'completed')
        .length;
    final completionRate = _workouts.isEmpty
        ? 0
        : ((completedWorkouts / _workouts.length) * 100).round();
    final allCompleted = _workouts.every((w) => w['status'] == 'completed');
    // Buổi tập tiếp theo = buổi 'planned' gần nhất; nếu đã hoàn thành hết thì không dùng tới.
    final Map<String, dynamic> nextWorkout = _workouts.firstWhere(
      (workout) => workout['status'] == 'planned',
      orElse: () => _workouts.first,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: AppBar(
        title: MarqueeText(
          _activeSchedule!['title'] ?? context.translate('your_training_plan'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_task, color: colorScheme.onSurface),
            onPressed: () => _openManualWorkout(),
            tooltip: context.translate('manual_workout_add_tooltip'),
          ),
          if (!allCompleted)
            IconButton(
              icon: Icon(Icons.auto_fix_high, color: colorScheme.onSurface),
              onPressed: _adjustPlan,
              tooltip: context.translate('optimize_plan_tooltip'),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            onSelected: (v) {
              switch (v) {
                case 'history':
                  _openHistory();
                case 'refresh':
                  _fetchData();
                case 'abandon':
                  _abandonPlan();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: colorScheme.onSurface, size: 20),
                    const SizedBox(width: 10),
                    Text(context.translate('training_history')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: colorScheme.onSurface, size: 20),
                    const SizedBox(width: 10),
                    Text(context.translate('refresh')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'abandon',
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(context.translate('abandon_plan')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!widget.embedded)
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: sportPlatformGradient(context),
                ),
              ),
            ),
          Positioned(
            top: 24,
            right: -100,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.embedded
                    ? 0.0
                    : (MediaQuery.of(context).size.width > 900 ? 20.0 : 16.0),
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  glassCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.translate('plan_details'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fitness_center_rounded,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.translate('workout'),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  context.translate('workout_progress', [
                                    completedWorkouts.toString(),
                                    _workouts.length.toString(),
                                  ]),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _GradientProgressBar(
                              progress: _workouts.isEmpty
                                  ? 0.0
                                  : completedWorkouts / _workouts.length,
                              gradient: secondaryPulseGradient,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.translate('completed'),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$completionRate%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _GradientProgressBar(
                              progress: completionRate / 100.0,
                              gradient: accentPulseGradient,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (allCompleted)
                    _buildCompletionBanner(context)
                  else ...[
                    Text(
                      context.translate('next_workout'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dùng cùng thẻ gập (mũi tên) như lịch chi tiết, mở sẵn và có
                    // thêm nút "Khởi động" cho buổi tập sắp tới.
                    _WorkoutScheduleCard(
                      workout: nextWorkout,
                      statusColor: _statusColorFor(
                        nextWorkout,
                        isNext: true,
                        isLast:
                            _workouts.isNotEmpty &&
                            nextWorkout['id'] == _workouts.last['id'],
                      ),
                      statusIcon: _statusIconFor(
                        nextWorkout,
                        isNext: true,
                        isLast:
                            _workouts.isNotEmpty &&
                            nextWorkout['id'] == _workouts.last['id'],
                      ),
                      onAddActivity: () => _showAddActivityOptions(nextWorkout),
                      onReschedule: () => _rescheduleWorkout(nextWorkout),
                      onScheduleChanged: (workoutAt, leadMinutes, enabled) =>
                          _rescheduleWorkoutAt(
                            workout: nextWorkout,
                            workoutAt: workoutAt,
                            leadMinutes: leadMinutes,
                            enabled: enabled,
                          ),
                      onEditManual: nextWorkout['source'] == 'manual'
                          ? () => _openManualWorkout(workout: nextWorkout)
                          : null,
                      onDeleteManual: nextWorkout['source'] == 'manual'
                          ? () => _deleteManualWorkout(nextWorkout)
                          : null,
                      onWarmUp: () => _askWarmUp(nextWorkout),
                      reminder: _runReminders[nextWorkout['id']],
                      onReminderChanged: (workoutAt, leadMinutes, enabled) =>
                          _saveReminder(
                            workout: nextWorkout,
                            workoutAt: workoutAt,
                            leadMinutes: leadMinutes,
                            enabled: enabled,
                          ),
                      initiallyExpanded: true,
                      isLast: _workouts.isNotEmpty &&
                          nextWorkout['id'] == _workouts.last['id'],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    context.translate('detailed_schedule'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Column(
                    children: List.generate(_workouts.length, (index) {
                      final workout = _workouts[index];
                      final isLast = index == _workouts.length - 1;
                      final isNext =
                          !allCompleted && workout['id'] == nextWorkout['id'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _WorkoutScheduleCard(
                          workout: workout,
                          statusColor: _statusColorFor(
                            workout,
                            isNext: isNext,
                            isLast: isLast,
                          ),
                          statusIcon: _statusIconFor(
                            workout,
                            isNext: isNext,
                            isLast: isLast,
                          ),
                          onAddActivity: () => _showAddActivityOptions(workout),
                          onReschedule: () => _rescheduleWorkout(workout),
                          onScheduleChanged:
                              (workoutAt, leadMinutes, enabled) =>
                                  _rescheduleWorkoutAt(
                                    workout: workout,
                                    workoutAt: workoutAt,
                                    leadMinutes: leadMinutes,
                                    enabled: enabled,
                                  ),
                          onEditManual: workout['source'] == 'manual'
                              ? () => _openManualWorkout(workout: workout)
                              : null,
                          onDeleteManual: workout['source'] == 'manual'
                              ? () => _deleteManualWorkout(workout)
                              : null,
                          reminder: _runReminders[workout['id']],
                          onReminderChanged:
                              (workoutAt, leadMinutes, enabled) =>
                                  _saveReminder(
                                    workout: workout,
                                    workoutAt: workoutAt,
                                    leadMinutes: leadMinutes,
                                    enabled: enabled,
                                  ),
                          isLast: isLast,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _askWarmUp(Map<String, dynamic> workout) {
    final title = (workout['title'] ?? '').toString();
    final distance = workout['target_distance_km']?.toString() ?? '';
    final prompt = context.translate('warm_up_prompt', [title, distance]);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AICoachPage(initialPrompt: prompt)),
    );
  }

  Future<void> _saveReminder({
    required Map<String, dynamic> workout,
    required DateTime workoutAt,
    required int leadMinutes,
    required bool enabled,
  }) async {
    try {
      final reminder = await _reminderService.saveReminder(
        workoutId: workout['id'] as String,
        workoutTitle: workout['title']?.toString() ?? '',
        workoutAt: workoutAt,
        leadMinutes: leadMinutes,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _runReminders = {..._runReminders, reminder.workoutId: reminder};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('reminder_saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.translate('reminder_error')}: $e')),
      );
    }
  }

  Widget _buildCompletionBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text(
            context.translate('plan_completed_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.translate('plan_completed_desc'),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _openCreatePlan,
            style: primaryActionButton(context),
            child: Text(context.translate('create_new_plan')),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePlan() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTrainingPlanPage()),
    );
    if (created == true) {
      _fetchData();
    }
  }

  Future<void> _openManualWorkout({Map<String, dynamic>? workout}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ManualWorkoutPage(workout: workout)),
    );
    if (saved == true) {
      _fetchData();
    }
  }

  Future<void> _deleteManualWorkout(Map<String, dynamic> workout) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('manual_workout_delete_title'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          context.translate('manual_workout_delete_confirm'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _trainingService.deleteManualWorkout(workout['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('manual_workout_deleted'))),
        );
      }
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainingHistoryPage()),
    );
    // Quay lại có thể đã đổi dữ liệu (vd tạo lịch mới từ lịch sử) -> làm mới.
    if (mounted) _fetchData();
  }

  Future<void> _abandonPlan() async {
    final id = _activeSchedule?['id'];
    if (id == null) return;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('abandon_plan'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          context.translate('abandon_plan_confirm'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.translate('cancel'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('abandon_plan'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase
          .from('training_schedules')
          .update({'status': 'abandoned'})
          .eq('id', id);
    } catch (e) {
      debugPrint('Error abandoning plan: $e');
    }
    await _fetchData();
  }

  Future<void> _dismissFailedPlan() async {
    final id = _activeSchedule?['id'];
    if (id == null) return;
    try {
      await _supabase.from('training_schedules').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error dismissing failed plan: $e');
    }
    if (mounted) {
      setState(() => _activeSchedule = null);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              context.translate('no_plan_yet'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.translate('no_plan_desc'),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openCreatePlan,
              style: primaryActionButton(context),
              child: Text(context.translate('create_plan_ai')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openManualWorkout(),
              icon: const Icon(Icons.add_task),
              label: Text(context.translate('manual_workout_create_title')),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              label: Text(context.translate('training_history')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              context.translate('plan_generating_title'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.translate('plan_generating_desc'),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: Text(context.translate('refresh')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              context.translate('plan_failed_title'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.translate('plan_failed_desc'),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openCreatePlan,
              style: primaryActionButton(context),
              child: Text(context.translate('retry')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openManualWorkout(),
              icon: const Icon(Icons.add_task),
              label: Text(context.translate('manual_workout_create_title')),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _dismissFailedPlan,
              child: Text(
                context.translate('dismiss'),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Màu vàng "tự hào" cho buổi tập cuối cùng (vạch đích của cả lịch tập).
  static const Color _finishLineColor = Color(0xFFFFC107);

  /// Màu điểm nhấn của một buổi tập, theo thứ tự ưu tiên:
  /// buổi cuối cùng (vàng tự hào) > đã hoàn thành (xanh lá) > buổi kế tiếp
  /// (cam nổi bật) > mặc định theo trạng thái.
  Color _statusColorFor(
    Map<String, dynamic> w, {
    required bool isNext,
    required bool isLast,
  }) {
    final status = w['status'] as String? ?? 'planned';
    if (isLast) return _finishLineColor;
    if (status == 'completed') return Colors.greenAccent;
    if (isNext && status == 'planned') return Colors.orangeAccent;
    return _getStatusColor(status);
  }

  /// Icon của một buổi tập theo cùng thứ tự ưu tiên như [_statusColorFor];
  /// buổi cuối cùng dùng icon huy chương.
  IconData _statusIconFor(
    Map<String, dynamic> w, {
    required bool isNext,
    required bool isLast,
  }) {
    final status = w['status'] as String? ?? 'planned';
    if (isLast) return Icons.military_tech;
    if (status == 'completed') return Icons.check_circle;
    if (isNext && status == 'planned') return Icons.directions_run;
    return _getStatusIcon(status);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'skipped':
        return Colors.grey;
      case 'rescheduled':
        return Colors.orangeAccent;
      default:
        return const Color(0xFF4A82FF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'skipped':
        return Icons.pause_circle;
      case 'rescheduled':
        return Icons.update;
      default:
        return Icons.directions_run;
    }
  }

  Future<void> _rescheduleWorkout(Map<String, dynamic> workout) async {
    final currentDate = DateTime.parse(workout['date'] as String);
    final firstDate = DateTime.now().subtract(const Duration(days: 365));
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final initialDate = currentDate.isBefore(firstDate)
        ? firstDate
        : currentDate.isAfter(lastDate)
        ? lastDate
        : currentDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate == null || !mounted) return;

    final reminder = _runReminders[workout['id']];
    final startTime = _parseWorkoutTime(workout['start_time']?.toString());
    final workoutAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime.$1,
      startTime.$2,
    );

    await _rescheduleWorkoutAt(
      workout: workout,
      workoutAt: workoutAt,
      leadMinutes: reminder?.leadMinutes ?? 10,
      enabled: reminder?.enabled ?? false,
    );
  }

  /// Đổi ngày buổi tập và giờ nhắc trong cùng một thao tác.
  Future<void> _rescheduleWorkoutAt({
    required Map<String, dynamic> workout,
    required DateTime workoutAt,
    required int leadMinutes,
    required bool enabled,
  }) async {
    final newDate = DateFormat('yyyy-MM-dd').format(workoutAt);
    final newStartTime = DateFormat('HH:mm:ss').format(workoutAt);
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('scheduled_workouts')
          .update({
            'date': newDate,
            'start_time': newStartTime,
          })
          .eq('id', workout['id']);
      await _reminderService.saveReminder(
        workoutId: workout['id'] as String,
        workoutTitle: workout['title']?.toString() ?? '',
        workoutAt: workoutAt,
        leadMinutes: leadMinutes,
        enabled: enabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('reschedule_success'))),
        );
      }
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddActivityOptions(Map<String, dynamic> workout) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  context.translate('add_activity'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.cloud_upload, color: colorScheme.primary),
                ),
                title: Text(
                  context.translate('add_activity_option_upload'),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.translate('supported_formats'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadNewActivity(workout);
                },
              ),
              const Divider(indent: 72, endIndent: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.link, color: colorScheme.primary),
                ),
                title: Text(
                  context.translate('add_activity_option_link'),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.translate('select_activity_to_link'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkActivityDialog(workout);
                },
              ),
              const Divider(indent: 72, endIndent: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.hotel, color: colorScheme.primary),
                ),
                title: Text(
                  context.translate('add_activity_option_skip_rest'),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.translate('add_activity_option_skip_rest_desc'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _skipWorkoutAsRest(workout);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadNewActivity(Map<String, dynamic> workout) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportActivityPage(scheduledWorkoutId: workout['id']),
      ),
    );
    if (result == true) {
      _fetchData();
    }
  }

  void _showLinkActivityDialog(Map<String, dynamic> workout) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      context.translate('select_activity_to_link'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchUnlinkedActivities(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              '${context.translate('error')}: ${snapshot.error}',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          );
                        }
                        final activities = snapshot.data ?? [];
                        if (activities.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                context.translate('no_activities_to_link'),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: activities.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            final date = DateTime.parse(
                              activity['started_at'] as String,
                            );
                            final distance = (activity['distance_km'] as num)
                                .toDouble();
                            final duration = (activity['duration_min'] as num)
                                .toDouble();
                            final name =
                                (activity['name'] ?? activity['notes'])
                                    as String?;
                            final notes = activity['notes'] as String?;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(
                                  Icons.directions_run,
                                  color: colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                name?.isNotEmpty == true
                                    ? name!
                                    : '${distance.toStringAsFixed(2)} km • ${duration.toStringAsFixed(0)} mins',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'EEEE, dd/MM/yyyy HH:mm',
                                    ).format(date.toLocal()),
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (notes != null &&
                                      notes.isNotEmpty &&
                                      notes != name)
                                    Text(
                                      notes,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              onTap: () =>
                                  _linkActivity(workout, activity['id']),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUnlinkedActivities() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final workoutsRes = await _supabase
        .from('scheduled_workouts')
        .select('activity_id')
        .eq('user_id', user.id);

    final List<String> linkedActivityIds = (workoutsRes as List)
        .map((w) => w['activity_id'] as String?)
        .whereType<String>()
        .toList();

    final activitiesRes = await _supabase
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .order('started_at', ascending: false);

    final List<Map<String, dynamic>> allActivities =
        List<Map<String, dynamic>>.from(activitiesRes as List);

    return allActivities
        .where((activity) => !linkedActivityIds.contains(activity['id']))
        .toList();
  }

  Future<void> _linkActivity(
    Map<String, dynamic> workout,
    String activityId,
  ) async {
    Navigator.pop(context);

    setState(() => _isLoading = true);
    try {
      await _trainingService.completeScheduledWorkout(
        workoutId: workout['id'] as String,
        activityId: activityId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('link_success'))),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('link_error')}: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _skipWorkoutAsRest(Map<String, dynamic> workout) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final dateStr = workout['date'] as String;
      final now = DateTime.now();
      final startedAt = DateTime.parse(dateStr).add(Duration(
        hours: now.hour,
        minutes: now.minute,
        seconds: now.second,
      ));
      final startedIso = startedAt.toUtc().toIso8601String();

      // Create Rest activity (0 km, 0 min)
      final activityRes = await _supabase
          .from('activities')
          .insert({
            'user_id': user.id,
            'started_at': startedIso,
            'distance_km': 0.0,
            'duration_min': 0.0,
            'name': context.translate('rest_activity_name'),
            'notes': context.translate('add_activity_option_skip_rest_desc'),
          })
          .select('id')
          .single();

      final activityId = activityRes['id'] as String;

      // Link the activity to the scheduled workout and complete it
      await _trainingService.completeScheduledWorkout(
        workoutId: workout['id'] as String,
        activityId: activityId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('link_success'))),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }
}

/// Thẻ buổi tập trong "Lịch chi tiết". Mặc định chỉ hiện tiêu đề; nhấn mũi tên
/// để mở chi tiết (ngày, quãng đường, mô tả) và nút thao tác — tránh tràn chữ
/// trên màn hình hẹp (mobile).
class _WorkoutScheduleCard extends StatefulWidget {
  final Map<String, dynamic> workout;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback onAddActivity;
  final VoidCallback onReschedule;
  final VoidCallback? onEditManual;
  final VoidCallback? onDeleteManual;
  final RunReminder? reminder;
  final Future<void> Function(DateTime workoutAt, int leadMinutes, bool enabled)
  onReminderChanged;
  final Future<void> Function(DateTime workoutAt, int leadMinutes, bool enabled)
  onScheduleChanged;
  // Chỉ buổi tập sắp tới mới có nút "Khởi động" (null -> ẩn).
  final VoidCallback? onWarmUp;
  final bool initiallyExpanded;
  final bool isLast;

  const _WorkoutScheduleCard({
    required this.workout,
    required this.statusColor,
    required this.statusIcon,
    required this.onAddActivity,
    required this.onReschedule,
    this.onEditManual,
    this.onDeleteManual,
    required this.onReminderChanged,
    required this.onScheduleChanged,
    this.reminder,
    this.onWarmUp,
    this.initiallyExpanded = false,
    this.isLast = false,
  });

  @override
  State<_WorkoutScheduleCard> createState() => _WorkoutScheduleCardState();
}

class _WorkoutScheduleCardState extends State<_WorkoutScheduleCard> {
  late bool _expanded = widget.initiallyExpanded;
  bool _savingReminder = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workout = widget.workout;
    final date = DateTime.parse(workout['date'] as String);
    final description = workout['description'] as String?;

    return glassCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_expanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.statusColor,
                    child: Icon(
                      widget.isLast ? LucideIcons.medal : Icons.directions_run,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      workout['title'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (workout['source'] == 'manual') ...[
                    _buildSourceChip(context, compact: true),
                    const SizedBox(width: 8),
                  ],
                  if (!_expanded) ...[
                    Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _workoutMeta(context, date, workout),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSourceChip(context),
                      if (workout['workout_type'] != null)
                        _buildInfoChip(
                          context,
                          Icons.category_outlined,
                          context.translate(
                            'workout_type_${workout['workout_type']}',
                          ),
                        ),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  // Ẩn tạm thời tính năng nhắc lịch chạy trên Web/PWA
                  // if (workout['status'] == 'planned') ...[
                  //   const SizedBox(height: 14),
                  //   _buildReminderSettings(context, date),
                  // ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (workout['status'] == 'planned') ...[
                        if (widget.onWarmUp != null)
                          ElevatedButton.icon(
                            onPressed: widget.onWarmUp,
                            style: primaryActionButton(context),
                            icon: const Icon(
                              Icons.local_fire_department,
                              size: 18,
                            ),
                            label: Text(context.translate('warm_up')),
                          ),
                        OutlinedButton.icon(
                          onPressed: widget.onAddActivity,
                          icon: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 18,
                          ),
                          label: Text(context.translate('attach_activity')),
                        ),
                      ] else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.statusIcon, color: widget.statusColor),
                            const SizedBox(width: 8),
                            Text(
                              context.translate('status_${workout['status']}'),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      // Nút "Đặt lịch" cho các buổi tập chưa hoàn thành để đổi ngày theo ý muốn.
                      if (workout['status'] != 'completed')
                        OutlinedButton.icon(
                          onPressed: widget.onReschedule,
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: Text(context.translate('reschedule')),
                        ),
                      if (widget.onEditManual != null)
                        OutlinedButton.icon(
                          onPressed: widget.onEditManual,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(context.translate('edit')),
                        ),
                      if (widget.onDeleteManual != null)
                        OutlinedButton.icon(
                          onPressed: widget.onDeleteManual,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: Text(context.translate('delete')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _workoutMeta(
    BuildContext context,
    DateTime date,
    Map<String, dynamic> workout,
  ) {
    final parts = <String>[DateFormat('EEEE, dd/MM').format(date)];
    final startTime = _formatStartTime(workout['start_time']?.toString());
    if (startTime != null) parts.add(startTime);
    final distance = (workout['target_distance_km'] as num?)?.toDouble();
    if (distance != null) parts.add('${_formatNumber(distance)} km');

    double? pace = (workout['target_pace_min_per_km'] as num?)?.toDouble();
    if (pace == null || pace == 0) {
      final dist = distance ?? 0.0;
      final dur = (workout['target_duration_min'] as num?)?.toDouble() ?? 0.0;
      if (dist > 0 && dur > 0) {
        pace = dur / dist;
      }
    }
    if (pace != null && pace > 0) {
      parts.add('${context.translate('pace')} ${_formatPace(pace)}');
    }
    return parts.join(' • ');
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal == 0 || paceDecimal.isInfinite || paceDecimal.isNaN) {
      return "-:--";
    }
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  String? _formatStartTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  Widget _buildSourceChip(BuildContext context, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isManual = widget.workout['source'] == 'manual';
    final color = isManual ? colorScheme.secondary : colorScheme.primary;
    return _buildInfoChip(
      context,
      isManual ? Icons.edit_calendar_outlined : Icons.auto_awesome,
      context.translate(isManual ? 'source_manual' : 'source_ai'),
      compact: compact,
      color: color,
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label, {
    bool compact = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: effectiveColor),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReminderSettings(BuildContext context, DateTime workoutDate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminder = widget.reminder;
    final enabled = reminder?.enabled ?? false;
    final leadMinutes = reminder?.leadMinutes ?? 10;
    final workoutAt = _workoutAt(workoutDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.translate('run_reminder'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_savingReminder)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: enabled,
                  onChanged: (value) => _changeReminder(
                    workoutAt: workoutAt,
                    leadMinutes: leadMinutes,
                    enabled: value,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _savingReminder
                    ? null
                    : () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _datePickerInitial(workoutAt),
                          firstDate: _datePickerFirstDate,
                          lastDate: _datePickerLastDate,
                        );
                        if (pickedDate == null || !context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(workoutAt),
                        );
                        if (pickedTime == null) return;
                        final updated = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        await _changeSchedule(
                          workoutAt: updated,
                          leadMinutes: leadMinutes,
                          enabled: true,
                        );
                      },
                icon: const Icon(Icons.event_repeat, size: 18),
                label: Text(DateFormat('dd/MM HH:mm').format(workoutAt)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: leadMinutes,
                    onChanged: _savingReminder
                        ? null
                        : (value) {
                            if (value == null) return;
                            _changeReminder(
                              workoutAt: workoutAt,
                              leadMinutes: value,
                              enabled: true,
                            );
                          },
                    items: reminderLeadMinuteOptions
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text(_leadLabel(context, minutes)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Text(
                enabled
                    ? context.translate('reminder_on')
                    : context.translate('reminder_off'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _workoutAt(DateTime workoutDate) {
    final startTime = _parseWorkoutTime(widget.workout['start_time']?.toString());
    return DateTime(
      workoutDate.year,
      workoutDate.month,
      workoutDate.day,
      startTime.$1,
      startTime.$2,
    );
  }

  Future<void> _changeReminder({
    required DateTime workoutAt,
    required int leadMinutes,
    required bool enabled,
  }) async {
    setState(() => _savingReminder = true);
    try {
      await widget.onReminderChanged(workoutAt, leadMinutes, enabled);
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _changeSchedule({
    required DateTime workoutAt,
    required int leadMinutes,
    required bool enabled,
  }) async {
    setState(() => _savingReminder = true);
    try {
      await widget.onScheduleChanged(workoutAt, leadMinutes, enabled);
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  DateTime get _datePickerFirstDate =>
      DateTime.now().subtract(const Duration(days: 365));

  DateTime get _datePickerLastDate =>
      DateTime.now().add(const Duration(days: 365));

  DateTime _datePickerInitial(DateTime current) {
    final firstDate = _datePickerFirstDate;
    final lastDate = _datePickerLastDate;
    if (current.isBefore(firstDate)) return firstDate;
    if (current.isAfter(lastDate)) return lastDate;
    return current;
  }

  String _leadLabel(BuildContext context, int minutes) {
    switch (minutes) {
      case 0:
        return context.translate('reminder_at_time');
      case 60:
        return context.translate('reminder_before_1h');
      default:
        return context.translate('reminder_before_minutes', ['$minutes']);
    }
  }
}

class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final Gradient gradient;

  const _GradientProgressBar({
    required this.progress,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 10,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final progressWidth = maxWidth * progress.clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              width: progressWidth,
              height: 10,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hộp thoại xem trước các điều chỉnh do HLV AI đề xuất: hiển thị nhận xét tổng
/// quan + từng thay đổi "cũ → mới" kèm lý do; người dùng xác nhận mới lưu.
class _AdjustmentPreviewDialog extends StatelessWidget {
  final PlanAdjustmentProposal proposal;
  const _AdjustmentPreviewDialog({required this.proposal});

  /// Đổi 'YYYY-MM-DD' sang 'dd/MM' cho gọn; giữ nguyên nếu không phân tích được.
  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : DateFormat('dd/MM').format(d);
  }

  String _fmtDist(num? km) => km == null ? '—' : '$km km';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_fix_high, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(context.translate('adjust_preview_title'))),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proposal.summary != null &&
                  proposal.summary!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    proposal.summary!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                context.translate('adjust_preview_changes'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...proposal.adjustments.map(
                (adj) => _buildChangeTile(context, adj),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.translate('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.translate('adjust_preview_confirm')),
        ),
      ],
    );
  }

  Widget _buildChangeTile(BuildContext context, WorkoutAdjustment adj) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final rows = <Widget>[];
    // Chỉ hiện dòng nào thực sự thay đổi.
    if (adj.newDate != null && adj.newDate != adj.currentDate) {
      rows.add(
        _changeRow(
          context,
          Icons.event,
          '${_fmtDate(adj.currentDate)}  →  ${_fmtDate(adj.newDate)}',
        ),
      );
    }
    if (adj.newDistanceKm != null &&
        adj.newDistanceKm != adj.currentDistanceKm) {
      rows.add(
        _changeRow(
          context,
          Icons.straighten,
          '${_fmtDist(adj.currentDistanceKm)}  →  ${_fmtDist(adj.newDistanceKm)}',
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adj.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
          if (adj.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              adj.reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _changeRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
