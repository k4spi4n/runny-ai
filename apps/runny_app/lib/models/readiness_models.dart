class RecoveryFeedback {
  final String? id;
  final String activityId;
  final int rpe;
  final String? notes;
  final DateTime? recordedAt;
  const RecoveryFeedback({
    this.id,
    required this.activityId,
    required this.rpe,
    this.notes,
    this.recordedAt,
  });
  factory RecoveryFeedback.fromJson(Map<String, dynamic> json) =>
      RecoveryFeedback(
        id: json['id'] as String?,
        activityId: json['activity_id'] as String,
        rpe: (json['rpe'] as num).toInt(),
        notes: json['notes'] as String?,
        recordedAt: json['recorded_at'] == null
            ? null
            : DateTime.parse(json['recorded_at'] as String),
      );
}

class RecoveryCheckin {
  final DateTime date;
  final int sleepQuality;
  final double? sleepHours;
  final int soreness;
  final bool painFlag;
  final String? notes;
  const RecoveryCheckin({
    required this.date,
    required this.sleepQuality,
    this.sleepHours,
    required this.soreness,
    required this.painFlag,
    this.notes,
  });
  factory RecoveryCheckin.fromJson(Map<String, dynamic> json) =>
      RecoveryCheckin(
        date: DateTime.parse(json['checkin_date'] as String),
        sleepQuality: (json['sleep_quality'] as num).toInt(),
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        soreness: (json['soreness'] as num).toInt(),
        painFlag: json['pain_flag'] == true,
        notes: json['notes'] as String?,
      );
}

class ReadinessSnapshot {
  final int score;
  final String status;
  final double acuteLoad;
  final double chronicLoad;
  final double? acwr;
  final bool hasSufficientLoadData;
  final bool painFlag;
  final DateTime? checkinDate;
  final Map<String, dynamic> factors;
  const ReadinessSnapshot({
    required this.score,
    required this.status,
    required this.acuteLoad,
    required this.chronicLoad,
    this.acwr,
    required this.hasSufficientLoadData,
    required this.painFlag,
    this.checkinDate,
    required this.factors,
  });
  factory ReadinessSnapshot.fromJson(Map<String, dynamic> json) =>
      ReadinessSnapshot(
        score: (json['readiness_score'] as num? ?? 0).toInt(),
        status: json['readiness_status'] as String? ?? 'ready',
        acuteLoad: (json['acute_load'] as num? ?? 0).toDouble(),
        chronicLoad: (json['chronic_load'] as num? ?? 0).toDouble(),
        acwr: (json['acwr'] as num?)?.toDouble(),
        hasSufficientLoadData: json['has_sufficient_load_data'] == true,
        painFlag: json['pain_flag'] == true,
        checkinDate: json['checkin_date'] == null
            ? null
            : DateTime.parse(json['checkin_date'] as String),
        factors: Map<String, dynamic>.from(json['factors'] as Map? ?? const {}),
      );
  bool get needsCheckin => factors['needs_checkin'] == true;
}
