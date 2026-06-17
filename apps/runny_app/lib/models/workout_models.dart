class Activity {
  final String? id;
  final String userId;
  final DateTime startedAt;
  final double distanceKm;
  final double durationMin;
  final int? avgHr;
  final double? elevationGainM;
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
    required this.distanceKm,
    required this.durationMin,
    this.avgHr,
    this.elevationGainM,
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
      startedAt: DateTime.parse(json['started_at']),
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMin: (json['duration_min'] as num).toDouble(),
      avgHr: json['avg_hr'],
      elevationGainM: json['elevation_gain_m'] != null
          ? (json['elevation_gain_m'] as num).toDouble()
          : null,
      notes: json['notes'],
      dataPoints: json['data_points'],
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLon: (json['start_lon'] as num?)?.toDouble(),
      weatherSummary: json['weather_summary'],
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      aqi: json['aqi'],
      weatherFetchedAt: json['weather_fetched_at'] != null
          ? DateTime.parse(json['weather_fetched_at'])
          : null,
      weatherJson: json['weather_json'],
      shoeId: json['shoe_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'avg_hr': avgHr,
      'elevation_gain_m': elevationGainM,
      'notes': notes,
      'data_points': dataPoints,
      'start_lat': startLat,
      'start_lon': startLon,
      'weather_summary': weatherSummary,
      'temperature_c': temperatureC,
      'aqi': aqi,
      'weather_fetched_at': weatherFetchedAt?.toIso8601String(),
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
    };
  }
}

class ScheduledWorkout {
  final String? id;
  final String scheduleId;
  final String userId;
  final DateTime date;
  final String title;
  final String? description;
  final double? targetDistanceKm;
  final double? targetDurationMin;
  final double? targetPaceMinPerKm;
  final String status;
  final String? activityId;

  ScheduledWorkout({
    this.id,
    required this.scheduleId,
    required this.userId,
    required this.date,
    required this.title,
    this.description,
    this.targetDistanceKm,
    this.targetDurationMin,
    this.targetPaceMinPerKm,
    required this.status,
    this.activityId,
  });

  factory ScheduledWorkout.fromJson(Map<String, dynamic> json) {
    return ScheduledWorkout(
      id: json['id'],
      scheduleId: json['schedule_id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
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
      'title': title,
      'description': description,
      'target_distance_km': targetDistanceKm,
      'target_duration_min': targetDurationMin,
      'target_pace_min_per_km': targetPaceMinPerKm,
      'status': status,
      'activity_id': activityId,
    };
  }
}
