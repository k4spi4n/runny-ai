class RunReminder {
  final String? id;
  final String userId;
  final String workoutId;
  final DateTime workoutAt;
  final int leadMinutes;
  final bool enabled;
  final int notificationId;
  final DateTime scheduledFor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RunReminder({
    this.id,
    required this.userId,
    required this.workoutId,
    required this.workoutAt,
    required this.leadMinutes,
    required this.enabled,
    required this.notificationId,
    required this.scheduledFor,
    this.createdAt,
    this.updatedAt,
  });

  factory RunReminder.fromJson(Map<String, dynamic> json) {
    return RunReminder(
      id: json['id'],
      userId: json['user_id'],
      workoutId: json['workout_id'],
      workoutAt: DateTime.parse(json['workout_at']).toLocal(),
      leadMinutes: (json['lead_minutes'] as num?)?.toInt() ?? 10,
      enabled: json['enabled'] as bool? ?? false,
      notificationId: (json['notification_id'] as num?)?.toInt() ??
          notificationIdForWorkout(json['workout_id'] as String),
      scheduledFor: DateTime.parse(json['scheduled_for']).toLocal(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at']).toLocal(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'user_id': userId,
      'workout_id': workoutId,
      'workout_at': workoutAt.toUtc().toIso8601String(),
      'lead_minutes': leadMinutes,
      'enabled': enabled,
      'notification_id': notificationId,
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  RunReminder copyWith({
    String? id,
    String? userId,
    String? workoutId,
    DateTime? workoutAt,
    int? leadMinutes,
    bool? enabled,
    int? notificationId,
    DateTime? scheduledFor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RunReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutId: workoutId ?? this.workoutId,
      workoutAt: workoutAt ?? this.workoutAt,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      enabled: enabled ?? this.enabled,
      notificationId: notificationId ?? this.notificationId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const reminderLeadMinuteOptions = [0, 5, 10, 30, 60];

DateTime reminderScheduledFor(DateTime workoutAt, int leadMinutes) {
  return workoutAt.subtract(Duration(minutes: leadMinutes));
}

int notificationIdForWorkout(String workoutId) {
  var hash = 0x811c9dc5;
  for (final unit in workoutId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
