import 'package:intl/intl.dart';

import '../models/workout_models.dart';
import '../utils/activity_formatters.dart';
import 'ai_service.dart';

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
  AiInsightService({AiService? ai}) : _ai = ai ?? AiService();

  final AiService _ai;

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
      feature: AiFeature.activityInsight,
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
      feature: AiFeature.activityInsight,
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
          return '${DateFormat('yyyy-MM-dd').format(activity.startedAt.toLocal())},'
              '${activity.distanceKm.toStringAsFixed(1)},'
              '${activity.durationMin.toStringAsFixed(0)},'
              '${formatPace(pace, invalid: '')},'
              '${activity.avgHr ?? ''}';
        })
        .join('\n');
    final language = languageCode == 'en' ? 'en' : 'vi';

    return '''
${_todayContext(today)}
OUTPUT_LANGUAGE:$language
ACTIVITIES_CSV_NEWEST_FIRST:
date,distance_km,duration_min,pace_min_per_km,avg_hr
$activityLines
TASK: Write exactly 2 concise sentences: (1) one trend supported by the CSV; (2) one concrete, low-risk action.
CONSTRAINTS: Listed metrics only; no training-plan discussion, unsupported comparison, markdown, or heading.
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
    final language = languageCode == 'en' ? 'en' : 'vi';
    return '''
${_todayContext(today)}
OUTPUT_LANGUAGE:$language
CURRENT_WEEK:${_metricsLine(currentWeek)}
PREVIOUS_WEEK:${_metricsLine(previousWeek)}
ADHERENCE:completed=$completedWorkouts,scheduled=$plannedWorkouts,skipped=$skippedWorkouts
TASK: Return exactly one sentence (maximum 24 words) about weekly momentum or adherence.
CONSTRAINTS: If comparison is insufficient, only say momentum has started; no activity detail, advice, list, markdown, emoji, or medical claim.
''';
  }

  static String _metricsLine(WeeklyTrainingMetrics metrics) {
    return 'activities=${metrics.activityCount},'
        'distance_km=${metrics.distanceKm.toStringAsFixed(1)},'
        'duration_min=${metrics.durationMin.toStringAsFixed(0)},'
        'avg_pace=${formatPace(metrics.averagePaceMinPerKm, invalid: 'unknown')}';
  }

  static String _todayContext(DateTime today) {
    final local = today.toLocal();
    return 'REFERENCE_DATE:${DateFormat('yyyy-MM-dd').format(local)}';
  }
}
