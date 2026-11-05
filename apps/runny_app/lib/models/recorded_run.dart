import 'package:geolocator/geolocator.dart';

enum RunPhase { recording, paused, finished }

class RunFix {
  const RunFix(this.latitude, this.longitude, this.time, this.accuracy);

  final double latitude;
  final double longitude;
  final DateTime time;
  final double accuracy;

  bool usableAt(DateTime now) =>
      latitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.isFinite &&
      longitude.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0 &&
      accuracy <= 25 &&
      now.difference(time).inMilliseconds >= -2000 &&
      now.difference(time).inMilliseconds <= 10000;

  List<num> toJson() => [latitude, longitude, time.millisecondsSinceEpoch];

  factory RunFix.fromJson(List<dynamic> point) {
    if (point.length != 3 ||
        point.any((v) => v is! num || !v.isFinite) ||
        (point[0] as num).abs() > 90 ||
        (point[1] as num).abs() > 180) {
      throw const FormatException('Invalid GPS point');
    }
    return RunFix(
      (point[0] as num).toDouble(),
      (point[1] as num).toDouble(),
      DateTime.fromMillisecondsSinceEpoch(
        (point[2] as num).toInt(),
        isUtc: true,
      ),
      0,
    );
  }
}

List<List<RunFix>> parseRunSegments(List<dynamic> value) => value
    .map(
      (segment) =>
          (segment as List).map((p) => RunFix.fromJson(p as List)).toList(),
    )
    .toList();

class RecordedRun {
  RecordedRun({
    required this.id,
    required this.userId,
    required this.startedAt,
    required RunFix firstFix,
  }) : activeSince = startedAt,
       segments = [] {
    segments.add([firstFix]);
  }

  RecordedRun._({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.distanceM,
    required this.activeMs,
    required this.segments,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final List<List<RunFix>> segments;
  double distanceM = 0;
  int activeMs = 0;
  DateTime? activeSince;
  RunPhase phase = RunPhase.recording;
  bool _newSegment = false;
  DateTime? _lastObservedAt;

  int elapsedMs(DateTime now) =>
      activeMs +
      (activeSince == null
          ? 0
          : now.difference(activeSince!).inMilliseconds.clamp(0, 1 << 53));

  double? pace(DateTime now) =>
      distanceM < 100 ? null : elapsedMs(now) / 60000 / (distanceM / 1000);

  void gap() => _newSegment = true;

  bool addFix(RunFix fix, DateTime now) {
    if (phase != RunPhase.recording) return false;
    if (fix.time.isBefore(activeSince!) ||
        (_lastObservedAt != null && !fix.time.isAfter(_lastObservedAt!))) {
      return false;
    }
    if (!fix.usableAt(now)) {
      gap();
      return false;
    }
    final previous = segments.last.last;
    if (fix.time.difference(_lastObservedAt ?? previous.time).inMilliseconds >
        15000) {
      gap();
    }
    _lastObservedAt = fix.time;
    final seconds = fix.time.difference(previous.time).inMilliseconds / 1000;
    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      fix.latitude,
      fix.longitude,
    );
    if (!_newSegment && (seconds <= 0 || meters / seconds > 12)) {
      gap();
      return false;
    }
    if (_newSegment) {
      segments.add([fix]);
      _newSegment = false;
    } else {
      // Ignore small jitter; accumulate movement from the last retained point.
      if (meters < 3) return false;
      distanceM += meters;
      segments.last.add(fix);
    }
    return true;
  }

  void pause(DateTime now) {
    if (phase != RunPhase.recording) return;
    activeMs = elapsedMs(now);
    activeSince = null;
    phase = RunPhase.paused;
    gap();
  }

  void resume(DateTime now) {
    if (phase != RunPhase.paused) return;
    activeSince = now;
    phase = RunPhase.recording;
    gap();
  }

  void finish(DateTime now) {
    pause(now);
    phase = RunPhase.finished;
  }

  List<List<List<num>>> get routeJson =>
      segments.map((s) => s.map((p) => p.toJson()).toList()).toList();

  Map<String, dynamic> toJson(DateTime now) => {
    'id': id,
    'user_id': userId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'distance_m': distanceM,
    'active_ms': elapsedMs(now),
    'segments': routeJson,
  };

  factory RecordedRun.restore(Map<String, dynamic> json) => RecordedRun._(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String),
    distanceM: (json['distance_m'] as num).toDouble(),
    activeMs: (json['active_ms'] as num).toInt(),
    segments: parseRunSegments(json['segments'] as List),
  )..phase = RunPhase.finished;
}
