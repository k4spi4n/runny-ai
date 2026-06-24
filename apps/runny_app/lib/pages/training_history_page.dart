import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';

/// Màn hình Lịch sử lịch tập: hiển thị các lịch đã hoàn thành, đã bỏ, hoặc đã
/// bị thay thế bởi lịch mới. Bấm vào một lịch để xem chi tiết các buổi tập.
class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({super.key});

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await _supabase
        .from('training_schedules')
        .select()
        .eq('user_id', user.id)
        .inFilter('status', ['completed', 'abandoned', 'archived'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final f = _fetchHistory();
    setState(() => _future = f);
    await f;
  }

  ({String label, Color color}) _statusBadge(BuildContext context, String? status) {
    switch (status) {
      case 'completed':
        return (label: context.translate('plan_status_completed'), color: Colors.greenAccent);
      case 'abandoned':
        return (label: context.translate('plan_status_abandoned'), color: Colors.redAccent);
      default: // archived
        return (label: context.translate('plan_status_archived'), color: Colors.orangeAccent);
    }
  }

  String _dateRange(Map<String, dynamic> s) {
    final fmt = DateFormat('dd/MM/yyyy');
    final start = s['start_date'] != null ? fmt.format(DateTime.parse(s['start_date'] as String)) : '—';
    final end = s['end_date'] != null ? fmt.format(DateTime.parse(s['end_date'] as String)) : '—';
    return '$start → $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('training_history'), style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Stack(
        children: [
          SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient(context)))),
          SafeArea(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 56, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(context.translate('no_history'), style: TextStyle(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildCard(context, items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> s) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badge = _statusBadge(context, s['status'] as String?);
    final goal = (s['goal_description'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showScheduleDetail(s),
        borderRadius: BorderRadius.circular(24),
        child: glassCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (s['title'] ?? context.translate('your_training_plan')).toString(),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badge.color.withValues(alpha: 0.4)),
                    ),
                    child: Text(badge.label, style: TextStyle(color: badge.color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(_dateRange(s), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  goal,
                  style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showScheduleDetail(Map<String, dynamic> schedule) {
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
                color: colorScheme.surface,
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      (schedule['title'] ?? context.translate('detailed_schedule')).toString(),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchWorkouts(schedule['id'] as String),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final workouts = snapshot.data ?? [];
                        if (workouts.isEmpty) {
                          return Center(
                            child: Text(context.translate('no_history'), style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: workouts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final w = workouts[index];
                            final date = DateTime.parse(w['date'] as String);
                            final done = w['status'] == 'completed';
                            return ListTile(
                              leading: Icon(
                                done ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: done ? Colors.greenAccent : colorScheme.onSurfaceVariant,
                              ),
                              title: Text(w['title']?.toString() ?? '', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${DateFormat('EEEE, dd/MM').format(date)} • ${w['target_distance_km']} km',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
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

  Future<List<Map<String, dynamic>>> _fetchWorkouts(String scheduleId) async {
    final rows = await _supabase
        .from('scheduled_workouts')
        .select()
        .eq('schedule_id', scheduleId)
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }
}
