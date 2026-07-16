class Activity {
  final String? id;
  final String userId;
  final DateTime startedAt;
  final DateTime? createdAt;
  final double distanceKm;
  final double durationMin;
  final int? avgHr;
  final int? avgCadence;
  final double? elevationGainM;
  final String? name;
  final String? notes;
  final Map<String, dynamic>? dataPoints;
  final double? startLat;
  final double? startLon;
  final String? weatherSummary;
  final double? temperatureC;
  final int? aqi;
  final DateTime? weatherFetchedAt;
  final Map<String, dynamic>? weatherJson;
  final String? shoeId;

  Activity({
    this.id,
    required this.userId,
    required this.startedAt,
    this.createdAt,
    required this.distanceKm,
    required this.durationMin,
    this.avgHr,
    this.avgCadence,
    this.elevationGainM,
    this.name,
    this.notes,
    this.dataPoints,
    this.startLat,
    this.startLon,
    this.weatherSummary,
    this.temperatureC,
    this.aqi,
    this.weatherFetchedAt,
    this.weatherJson,
    this.shoeId,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      userId: json['user_id'],
      startedAt: DateTime.parse(json['started_at']).toLocal(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMin: (json['duration_min'] as num).toDouble(),
      avgHr: json['avg_hr'],
      avgCadence: json['avg_cadence'],
      elevationGainM: json['elevation_gain_m'] != null
          ? (json['elevation_gain_m'] as num).toDouble()
          : null,
      name: json['name'] ?? json['notes'],
      notes: json['notes'],
      dataPoints: json['data_points'],
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLon: (json['start_lon'] as num?)?.toDouble(),
      weatherSummary: json['weather_summary'],
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      aqi: json['aqi'],
      weatherFetchedAt: json['weather_fetched_at'] != null
          ? DateTime.parse(json['weather_fetched_at']).toLocal()
          : null,
      weatherJson: json['weather_json'],
      shoeId: json['shoe_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'started_at': startedAt.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'avg_hr': avgHr,
      'avg_cadence': avgCadence,
      'elevation_gain_m': elevationGainM,
      'name': name,
      'notes': notes,
      'data_points': dataPoints,
      'start_lat': startLat,
      'start_lon': startLon,
      'weather_summary': weatherSummary,
      'temperature_c': temperatureC,
      'aqi': aqi,
      'weather_fetched_at': weatherFetchedAt?.toUtc().toIso8601String(),
      'weather_json': weatherJson,
      if (shoeId != null) 'shoe_id': shoeId,
    };
  }
}

class TrainingSchedule {
  final String? id;
  final String userId;
  final String title;
  final double? targetPaceMinPerKm;
  final double? targetDistanceKm;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? goalDescription;
  final String status;
  final String source;

  TrainingSchedule({
    this.id,
    required this.userId,
    required this.title,
    this.targetPaceMinPerKm,
    this.targetDistanceKm,
    this.startDate,
    this.endDate,
    this.goalDescription,
    required this.status,
    this.source = 'ai',
  });

  factory TrainingSchedule.fromJson(Map<String, dynamic> json) {
    return TrainingSchedule(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      targetPaceMinPerKm: json['target_pace_min_per_km'] != null
          ? (json['target_pace_min_per_km'] as num).toDouble()
          : null,
      targetDistanceKm: json['target_distance_km'] != null
          ? (json['target_distance_km'] as num).toDouble()
          : null,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      goalDescription: json['goal_description'],
      status: json['status'] ?? 'active',
      source: json['source'] ?? 'ai',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'target_pace_min_per_km': targetPaceMinPerKm,
      'target_distance_km': targetDistanceKm,
      'start_date': startDate?.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'goal_description': goalDescription,
      'status': status,
      'source': source,
    };
  }
}

class ScheduledWorkout {
  final String? id;
  final String scheduleId;
  final String userId;
  final DateTime date;
  final String? startTime;
  final String title;
  final String? description;
  final double? targetDistanceKm;
  final double? targetDurationMin;
  final double? targetPaceMinPerKm;
  final String? workoutType;
  final String source;
  final String status;
  final String? activityId;

  ScheduledWorkout({
    this.id,
    required this.scheduleId,
    required this.userId,
    required this.date,
    this.startTime,
    required this.title,
    this.description,
    this.targetDistanceKm,
    this.targetDurationMin,
    this.targetPaceMinPerKm,
    this.workoutType,
    this.source = 'ai',
    required this.status,
    this.activityId,
  });

  factory ScheduledWorkout.fromJson(Map<String, dynamic> json) {
    return ScheduledWorkout(
      id: json['id'],
      scheduleId: json['schedule_id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      startTime: json['start_time'],
      title: json['title'],
      description: json['description'],
      targetDistanceKm: json['target_distance_km'] != null
          ? (json['target_distance_km'] as num).toDouble()
          : null,
      targetDurationMin: json['target_duration_min'] != null
          ? (json['target_duration_min'] as num).toDouble()
          : null,
      targetPaceMinPerKm: json['target_pace_min_per_km'] != null
          ? (json['target_pace_min_per_km'] as num).toDouble()
          : null,
      workoutType: json['workout_type'],
      source: json['source'] ?? 'ai',
      status: json['status'],
      activityId: json['activity_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'schedule_id': scheduleId,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0],
      'start_time': startTime,
      'title': title,
      'description': description,
      'target_distance_km': targetDistanceKm,
      'target_duration_min': targetDurationMin,
      'target_pace_min_per_km': targetPaceMinPerKm,
      'workout_type': workoutType,
      'source': source,
      'status': status,
      'activity_id': activityId,
    };
  }
}

class ManualWorkoutInput {
  final String title;
  final DateTime date;
  final String startTime;
  final double targetDurationMin;
  final double targetDistanceKm;
  final double? targetPaceMinPerKm;
  final String workoutType;
  final String? notes;

  const ManualWorkoutInput({
    required this.title,
    required this.date,
    required this.startTime,
    required this.targetDurationMin,
    required this.targetDistanceKm,
    this.targetPaceMinPerKm,
    required this.workoutType,
    this.notes,
  });
}
