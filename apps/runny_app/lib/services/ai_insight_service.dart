import 'package:intl/intl.dart';

import '../models/workout_models.dart';
import 'gemini_service.dart';

class WeeklyTrainingMetrics {
  const WeeklyTrainingMetrics({
    required this.activityCount,
    required this.distanceKm,
    required this.durationMin,
  });

  final int activityCount;
  final double distanceKm;
  final double durationMin;

  double? get averagePaceMinPerKm =>
      distanceKm > 0 ? durationMin / distanceKm : null;
}

class AiInsightService {
  AiInsightService({GeminiService? ai}) : _ai = ai ?? GeminiService();

  final GeminiService _ai;

  /// Khoá cache theo tuần Thứ Hai–Chủ Nhật. Ngày trong cùng một tuần luôn trả
  /// về cùng khoá; sang Thứ Hai kế tiếp mới cho phép tạo kết luận mới.
  static String weeklyCachePeriod(DateTime date) {
    final local = date.toLocal();
    final localDay = DateTime(local.year, local.month, local.day);
    final monday = localDay.subtract(
      Duration(days: localDay.weekday - DateTime.monday),
    );
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  Future<String> generateActivityTrendInsight({
    required List<Activity> activities,
    required String languageCode,
    required DateTime today,
  }) {
    return _ai.generateResponse(
      buildActivityTrendPrompt(
        activities: activities,
        languageCode: languageCode,
        today: today,
      ),
      preferredProvider: 'groq',
      preferredModel: 'llama-3.1-8b-instant',
    );
  }

  Future<String> generateWeeklyTrainingConclusion({
    required WeeklyTrainingMetrics currentWeek,
    required WeeklyTrainingMetrics previousWeek,
    required int plannedWorkouts,
    required int completedWorkouts,
    required int skippedWorkouts,
    required String languageCode,
    required DateTime today,
  }) {
    return _ai.generateResponse(
      buildWeeklyTrainingPrompt(
        currentWeek: currentWeek,
        previousWeek: previousWeek,
        plannedWorkouts: plannedWorkouts,
        completedWorkouts: completedWorkouts,
        skippedWorkouts: skippedWorkouts,
        languageCode: languageCode,
        today: today,
      ),
      preferredProvider: 'groq',
      preferredModel: 'llama-3.1-8b-instant',
    );
  }

  static String buildActivityTrendPrompt({
    required List<Activity> activities,
    required String languageCode,
    required DateTime today,
  }) {
    final activityLines = activities
        .map((activity) {
          final pace = activity.distanceKm > 0
              ? activity.durationMin / activity.distanceKm
              : null;
          return '- ${DateFormat('yyyy-MM-dd').format(activity.startedAt.toLocal())}: '
              '${activity.distanceKm.toStringAsFixed(1)} km, '
              '${activity.durationMin.toStringAsFixed(0)} min, '
              'pace ${_formatPace(pace)}/km'
              '${activity.avgHr == null ? '' : ', HR ${activity.avgHr} bpm'}';
        })
        .join('\n');
    final language = languageCode == 'en' ? 'English' : 'Vietnamese';

    return '''
You are reviewing only the runner's recent recorded activities.
${_todayContext(today)}

Recorded activities, newest first:
$activityLines

Write 2 concise sentences in $language:
1) State one evidence-based activity trend using only the listed dates and metrics.
2) Give exactly one concrete, low-risk improvement suggestion.
Do not discuss the training plan. Do not claim improvement or decline unless the data supports a comparison. Do not invent missing workouts, goals, feelings, injuries, dates, or metrics. No markdown and no heading.
''';
  }

  static String buildWeeklyTrainingPrompt({
    required WeeklyTrainingMetrics currentWeek,
    required WeeklyTrainingMetrics previousWeek,
    required int plannedWorkouts,
    required int completedWorkouts,
    required int skippedWorkouts,
    required String languageCode,
    required DateTime today,
  }) {
    final language = languageCode == 'en' ? 'English' : 'Vietnamese';
    return '''
You are writing the final weekly training conclusion shown inside a training plan.
${_todayContext(today)}
Current week so far: ${_metricsLine(currentWeek)}.
Previous calendar week: ${_metricsLine(previousWeek)}.
Current-week plan adherence: $completedWorkouts completed / $plannedWorkouts scheduled, $skippedWorkouts skipped.

Return exactly one short conclusion sentence in $language, at most 24 words. Focus on weekly momentum or plan adherence, not individual activity details. If comparison is insufficient, say only that momentum has started; never fabricate progress. Do not give a list, detailed advice, markdown, heading, emoji, or medical claim.
''';
  }

  static String _metricsLine(WeeklyTrainingMetrics metrics) {
    return '${metrics.activityCount} activities, '
        '${metrics.distanceKm.toStringAsFixed(1)} km, '
        '${metrics.durationMin.toStringAsFixed(0)} min, '
        'average pace ${_formatPace(metrics.averagePaceMinPerKm)}/km';
  }

  static String _formatPace(double? pace) {
    if (pace == null || !pace.isFinite || pace <= 0) return '--';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _todayContext(DateTime today) {
    final local = today.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'Local current date: ${DateFormat('yyyy-MM-dd').format(local)} '
        '(UTC$sign$hours:$minutes). Treat this as the only definition of today.';
  }
}
