import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../widgets/ui_components.dart';
import 'ai_coach_page.dart';
import 'package:intl/intl.dart';

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
          const SnackBar(content: Text('Lịch tập đã được AI điều chỉnh tối ưu!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi điều chỉnh: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('Bạn chưa có lịch tập nào.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Bắt đầu với AI Coach để nhận ngay lịch tập cá nhân hoá, phù hợp với mục tiêu của bạn.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AICoachPage()));
              }, style: primaryActionButton(context), child: const Text('Tạo lịch tập với AI Coach')),
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
        title: Text(_activeSchedule!['title'] ?? 'Lịch tập của bạn'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.auto_fix_high), onPressed: _adjustPlan, tooltip: 'Tối ưu lịch tập với AI'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient(context)))),
          Positioned(
            top: 24,
            right: -100,
            child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent]))),
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
                        Text('Chi tiết lịch tập', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        Text('Hệ thống AI đang giữ nhịp cho tiến độ của bạn với chuyên môn thể thao cao cấp.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _PlanMetricCard(label: 'Bài tập', value: '${_workouts.length}', icon: Icons.fitness_center),
                            _PlanMetricCard(label: 'Hoàn thành', value: '$completionRate%', icon: Icons.check_circle),
                            _PlanMetricCard(label: 'Mục tiêu', value: nextWorkout['target_distance_km']?.toString() ?? '---', icon: Icons.track_changes),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Buổi tập tiếp theo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  glassCard(
                    context: context,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      leading: Icon(Icons.flag, color: Colors.white, size: 32),
                      title: Text(nextWorkout['title'] ?? 'Bài tập tiếp theo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${DateFormat('EEEE, dd MMM').format(DateTime.parse(nextWorkout['date'] as String))} • ${nextWorkout['target_distance_km']} km',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: ElevatedButton(onPressed: () {}, style: primaryActionButton(context, backgroundColor: const Color(0xFF4A82FF)), child: const Text('Khởi động')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Lịch trình chi tiết', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                                child: Icon(_getStatusIcon(workout['status']), color: Colors.white),
                              ),
                              title: Text(workout['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${DateFormat('EEEE, dd/MM').format(date)} • ${workout['target_distance_km']} km', style: const TextStyle(color: Colors.white70)),
                                  if (workout['description'] != null)
                                    Text(workout['description'], style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                ],
                              ),
                              trailing: workout['status'] == 'planned'
                                  ? ElevatedButton(onPressed: () {}, style: primaryActionButton(context, backgroundColor: const Color(0xFF4A82FF)), child: const Text('Bắt đầu'))
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
        return Colors.white54;
      case 'rescheduled':
        return Colors.orangeAccent;
      default:
        return const Color(0xFF4A82FF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check;
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
    return Container(
      width: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
