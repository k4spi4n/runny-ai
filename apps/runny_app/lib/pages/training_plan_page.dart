import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
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
  List<dynamic> _workouts = [];

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
        
        setState(() {
          _activeSchedule = schedule;
          _workouts = workouts;
        });
      }
    } catch (e) {
      debugPrint('Error fetching training plan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _adjustPlan() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi điều chỉnh: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_activeSchedule == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bạn chưa có lịch tập nào.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to AI Coach to create one
              },
              child: const Text('Tạo lịch tập với AI Coach'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_activeSchedule!['title']),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _adjustPlan,
            tooltip: 'Tối ưu lịch tập với AI',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          final workout = _workouts[index];
          final date = DateTime.parse(workout['date']);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return Card(
            elevation: isToday ? 4 : 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: isToday 
                ? RoundedRectangleBorder(side: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(12))
                : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(workout['status']),
                child: Icon(_getStatusIcon(workout['status']), color: Colors.white),
              ),
              title: Text(workout['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${DateFormat('EEEE, dd/MM').format(date)} • ${workout['target_distance_km']} km'),
                  if (workout['description'] != null)
                    Text(workout['description'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
              trailing: workout['status'] == 'planned' 
                  ? ElevatedButton(onPressed: () {}, child: const Text('Bắt đầu'))
                  : const Icon(Icons.check_circle, color: Colors.green),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'skipped': return Colors.grey;
      case 'rescheduled': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed': return Icons.check;
      case 'skipped': return Icons.close;
      case 'rescheduled': return Icons.update;
      default: return Icons.directions_run;
    }
  }
}
