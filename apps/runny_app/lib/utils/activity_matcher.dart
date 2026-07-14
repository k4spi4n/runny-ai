class ActivityMatchCandidate {
  const ActivityMatchCandidate({
    required this.activity,
    required this.score,
    required this.timeDifferenceHours,
    required this.distanceDifferenceKm,
  });

  final Map<String, dynamic> activity;
  final double score;
  final double timeDifferenceHours;
  final double? distanceDifferenceKm;

  bool get isStrongMatch => score >= 70;
}

/// Xếp hạng hoạt động có khả năng thuộc về một buổi tập đã lên lịch.
///
/// Ngày/giờ chiếm trọng số lớn nhất, sau đó tới cự ly và thời lượng. Hàm thuần
/// để có thể kiểm thử mà không phụ thuộc Supabase hay widget tree.
class ActivityMatcher {
  const ActivityMatcher._();

  static List<ActivityMatchCandidate> rank({
    required Map<String, dynamic> workout,
    required List<Map<String, dynamic>> activities,
  }) {
    final workoutAt = _workoutAt(workout);
    final plannedDistance = _asDouble(workout['target_distance_km']);
    final plannedDuration = _asDouble(workout['target_duration_min']);

    final candidates = activities.map((activity) {
      final startedAt = DateTime.tryParse(
        activity['started_at']?.toString() ?? '',
      )?.toLocal();
      final actualDistance = _asDouble(activity['distance_km']);
      final actualDuration = _asDouble(activity['duration_min']);
      final hours = startedAt == null
          ? 9999.0
          : startedAt.difference(workoutAt).inMinutes.abs() / 60.0;

      final timeScore = (50.0 - hours * 2.0).clamp(0.0, 50.0);
      final distanceScore = _similarityScore(
        plannedDistance,
        actualDistance,
        35.0,
      );
      final durationScore = _similarityScore(
        plannedDuration,
        actualDuration,
        15.0,
      );

      return ActivityMatchCandidate(
        activity: activity,
        score: timeScore + distanceScore + durationScore,
        timeDifferenceHours: hours,
        distanceDifferenceKm: plannedDistance == null || actualDistance == null
            ? null
            : (plannedDistance - actualDistance).abs(),
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    return candidates;
  }

  static DateTime _workoutAt(Map<String, dynamic> workout) {
    final date =
        DateTime.tryParse(workout['date']?.toString() ?? '') ?? DateTime.now();
    final parts = workout['start_time']?.toString().split(':') ?? const [];
    final hour = parts.isEmpty ? 6 : int.tryParse(parts[0]) ?? 6;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static double _similarityScore(
    double? planned,
    double? actual,
    double maxScore,
  ) {
    if (planned == null || actual == null || planned <= 0) return 0;
    final ratio = ((planned - actual).abs() / planned).clamp(0.0, 1.0);
    return maxScore * (1 - ratio);
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
