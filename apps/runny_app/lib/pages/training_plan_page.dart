import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import 'ai_coach_page.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

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

      final schedule = await _supabase
          .from('training_schedules')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (schedule != null) {
        final workouts = await _supabase
            .from('scheduled_workouts')
            .select()
            .eq('schedule_id', schedule['id'])
            .order('date', ascending: true);

        if (mounted) {
          setState(() {
            _activeSchedule = schedule;
            _workouts = workouts;
          });
        }
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

    if (_activeSchedule == null || _workouts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.translate('no_plan_yet'), style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(context.translate('no_plan_desc'), style: TextStyle(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AICoachPage()));
              }, style: primaryActionButton(context), child: Text(context.translate('create_plan_ai'))),
            ],
          ),
        ),
      );
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
                                  ? ElevatedButton(onPressed: () {}, style: primaryActionButton(context), child: Text(context.translate('start')))
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
