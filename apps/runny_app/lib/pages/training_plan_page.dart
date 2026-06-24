import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import 'create_training_plan_page.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import 'import_activity_page.dart';

class TrainingPlanPage extends StatefulWidget {
  const TrainingPlanPage({super.key});

  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TrainingService _trainingService = TrainingService();
  bool _isLoading = true;
  Map<String, dynamic>? _activeSchedule;
  List<Map<String, dynamic>> _workouts = [];

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

      // Lấy lịch gần nhất ở một trong các trạng thái hiển thị được:
      // active (đã tạo xong), generating (AI đang tạo), failed (tạo lỗi).
      final schedule = await _supabase
          .from('training_schedules')
          .select()
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'generating', 'failed'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      List<Map<String, dynamic>> workouts = [];
      if (schedule != null && schedule['status'] == 'active') {
        workouts = List<Map<String, dynamic>>.from(await _supabase
            .from('scheduled_workouts')
            .select()
            .eq('schedule_id', schedule['id'])
            .order('date', ascending: true));
      }

      if (mounted) {
        setState(() {
          _activeSchedule = schedule;
          _workouts = workouts;
        });
      }
    } catch (e) {
      debugPrint('Error fetching training plan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adjustPlan() async {
    setState(() => _isLoading = true);
    try {
      await _trainingService.adjustPlanDynamically();
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('plan_adjusted'))),
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

    final completedWorkouts = _workouts.where((w) => w['status'] == 'completed').length;
    final completionRate = _workouts.isEmpty ? 0 : ((completedWorkouts / _workouts.length) * 100).round();
    final Map<String, dynamic> nextWorkout = _workouts.firstWhere((workout) {
      final date = DateTime.parse(workout['date'] as String);
      return !DateUtils.isSameDay(date, DateTime.now()) || workout['status'] == 'planned';
    }, orElse: () => _workouts.first);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_activeSchedule!['title'] ?? context.translate('your_training_plan'), style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.auto_fix_high, color: colorScheme.onSurface), onPressed: _adjustPlan, tooltip: context.translate('optimize_plan_tooltip')),
          IconButton(icon: Icon(Icons.refresh, color: colorScheme.onSurface), onPressed: _fetchData),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient(context)))),
          Positioned(
            top: 24,
            right: -100,
            child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [colorScheme.primary.withValues(alpha: 0.08), Colors.transparent]))),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  glassCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.translate('plan_details'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                        const SizedBox(height: 12),
                        Text(context.translate('ai_keeping_pace'), style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _PlanMetricCard(label: context.translate('workout'), value: '${_workouts.length}', icon: Icons.fitness_center),
                            _PlanMetricCard(label: context.translate('completed'), value: '$completionRate%', icon: Icons.check_circle),
                            _PlanMetricCard(label: context.translate('goal'), value: nextWorkout['target_distance_km']?.toString() ?? '---', icon: Icons.track_changes),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(context.translate('next_workout'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  glassCard(
                    context: context,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      leading: Icon(Icons.flag, color: colorScheme.primary, size: 32),
                      title: Text(nextWorkout['title'] ?? context.translate('next_workout'), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${DateFormat('EEEE, dd MMM').format(DateTime.parse(nextWorkout['date'] as String))} • ${nextWorkout['target_distance_km']} km',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: ElevatedButton(onPressed: () {}, style: primaryActionButton(context), child: Text(context.translate('warm_up'))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(context.translate('detailed_schedule'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 14),
                  Column(
                    children: List.generate(
                      _workouts.length,
                      (index) {
                        final workout = _workouts[index];
                        final date = DateTime.parse(workout['date'] as String);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: glassCard(
                            context: context,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(workout['status']),
                                child: const Icon(Icons.directions_run, color: Colors.white),
                              ),
                              title: Text(workout['title'], style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${DateFormat('EEEE, dd/MM').format(date)} • ${workout['target_distance_km']} km', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                  if (workout['description'] != null)
                                    Text(workout['description'], style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13)),
                                ],
                              ),
                              trailing: workout['status'] == 'planned'
                                  ? ElevatedButton(
                                      onPressed: () => _showAddActivityOptions(workout),
                                      style: primaryActionButton(context),
                                      child: Text(context.translate('add_activity')),
                                    )
                                  : Icon(_getStatusIcon(workout['status']), color: _getStatusColor(workout['status'])),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
            Text(context.translate('no_plan_yet'), style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(context.translate('no_plan_desc'), style: TextStyle(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openCreatePlan,
              style: primaryActionButton(context),
              child: Text(context.translate('create_plan_ai')),
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
            Text(context.translate('plan_generating_title'), style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(context.translate('plan_generating_desc'), style: TextStyle(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
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
            Text(context.translate('plan_failed_title'), style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(context.translate('plan_failed_desc'), style: TextStyle(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openCreatePlan,
              style: primaryActionButton(context),
              child: Text(context.translate('retry')),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _dismissFailedPlan,
              child: Text(context.translate('dismiss'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
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
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.cloud_upload, color: colorScheme.primary),
                ),
                title: Text(context.translate('add_activity_option_upload'), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                subtitle: Text(context.translate('supported_formats'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                title: Text(context.translate('add_activity_option_link'), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                subtitle: Text(context.translate('select_activity_to_link'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkActivityDialog(workout);
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
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
                      context.translate('select_activity_to_link'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchUnlinkedActivities(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('${context.translate('error')}: ${snapshot.error}', style: TextStyle(color: colorScheme.onSurface)));
                        }
                        final activities = snapshot.data ?? [];
                        if (activities.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                context.translate('no_activities_to_link'),
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: activities.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            final date = DateTime.parse(activity['started_at'] as String);
                            final distance = (activity['distance_km'] as num).toDouble();
                            final duration = (activity['duration_min'] as num).toDouble();
                            final notes = activity['notes'] as String?;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.directions_run, color: colorScheme.primary),
                              ),
                              title: Text(
                                '${distance.toStringAsFixed(2)} km • ${duration.toStringAsFixed(0)} mins',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, dd/MM/yyyy HH:mm').format(date),
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                  ),
                                  if (notes != null && notes.isNotEmpty)
                                    Text(
                                      notes,
                                      style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              onTap: () => _linkActivity(workout, activity['id']),
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

    final List<Map<String, dynamic>> allActivities = List<Map<String, dynamic>>.from(activitiesRes as List);
    
    return allActivities
        .where((activity) => !linkedActivityIds.contains(activity['id']))
        .toList();
  }

  Future<void> _linkActivity(Map<String, dynamic> workout, String activityId) async {
    Navigator.pop(context);

    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('scheduled_workouts')
          .update({
            'activity_id': activityId,
            'status': 'completed',
          })
          .eq('id', workout['id']);

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
}

class _PlanMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PlanMetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
