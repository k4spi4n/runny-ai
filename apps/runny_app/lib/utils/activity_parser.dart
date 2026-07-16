import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:gpx/gpx.dart';
import 'package:xml/xml.dart';

class ActivitySample {
  const ActivitySample({
    required this.timestamp,
    required this.distanceKm,
    this.latitude,
    this.longitude,
    this.elevationM,
    this.heartRate,
    this.cadence,
    this.speedMps,
    this.paceMinPerKm,
  });

  final DateTime timestamp;
  final double distanceKm;
  final double? latitude;
  final double? longitude;
  final double? elevationM;
  final double? heartRate;
  final double? cadence;
  final double? speedMps;
  final double? paceMinPerKm;
}

class ParsedActivity {
  ParsedActivity({
    required this.startedAt,
    required this.distanceKm,
    required this.durationMin,
    this.avgHr,
    this.avgCadence,
    this.elevationGainM,
    this.dataPoints,
    this.startLat,
    this.startLon,
    this.samples = const [],
  });

  final DateTime startedAt;
  final double distanceKm;
  final double durationMin;
  final int? avgHr;
  final int? avgCadence;
  final double? elevationGainM;
  final Map<String, dynamic>? dataPoints;
  final double? startLat;
  final double? startLon;
  final List<ActivitySample> samples;

  Map<String, dynamic> toDatabaseFields() {
    return {
      'started_at': startedAt.toUtc().toIso8601String(),
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'avg_hr': avgHr,
      'avg_cadence': avgCadence,
      'elevation_gain_m': elevationGainM,
      'data_points': dataPoints,
      'start_lat': startLat,
      'start_lon': startLon,
    };
  }
}

class ActivityParser {
  static const maxFileBytes = 25 * 1024 * 1024;
  static const maxRawSamples = 200000;
  static const maxStoredSamples = 5000;
  static const maxXmlDepth = 128;

  static Future<ParsedActivity> parse(Uint8List bytes, String extension) async {
    if (bytes.isEmpty) throw Exception('Tệp hoạt động rỗng.');
    if (bytes.length > maxFileBytes) {
      throw Exception('Tệp hoạt động vượt quá giới hạn 25MB.');
    }
    return switch (extension.toLowerCase()) {
      'gpx' => _parseGpx(bytes),
      'fit' => _parseFit(bytes),
      'tcx' => _parseTcx(bytes),
      _ => throw Exception('Định dạng không hỗ trợ: $extension'),
    };
  }

  static Future<ParsedActivity> _parseTcx(Uint8List bytes) async {
    final xml = utf8.decode(bytes);
    _validateXmlDepth(xml);
    final doc = XmlDocument.parse(xml);
    final tracks = doc
        .findAllElements('Track')
        .map((track) => track.findAllElements('Trackpoint').toList())
        .where((points) => points.isNotEmpty)
        .toList();
    if (tracks.isEmpty) {
      final points = doc.findAllElements('Trackpoint').toList();
      if (points.isNotEmpty) tracks.add(points);
    }
    final pointCount = tracks.fold<int>(
      0,
      (sum, points) => sum + points.length,
    );
    _validatePointCount(pointCount, 'TCX');

    final allTimes = tracks
        .expand((track) => track)
        .map((point) => _parseDate(_childText(point, 'Time')))
        .whereType<DateTime>()
        .toList();
    final startedAt = allTimes.isNotEmpty ? allTimes.first : DateTime.now();
    final endedAt = allTimes.isNotEmpty ? allTimes.last : startedAt;

    final samples = <ActivitySample>[];
    var cumulativeKm = 0.0;
    var elevationGain = 0.0;
    double? startLat;
    double? startLon;
    var hrSum = 0.0;
    var hrCount = 0;
    var cadenceSum = 0.0;
    var cadenceCount = 0;
    DateTime? lastTime;

    for (final track in tracks) {
      double? previousLat;
      double? previousLon;
      double? previousElevation;
      ActivitySample? previousSample;
      double? rawDistanceOffsetKm;
      double? previousRawDistanceKm;

      for (final point in track) {
        final timestamp =
            _parseDate(_childText(point, 'Time')) ?? lastTime ?? startedAt;
        lastTime = timestamp;
        final position = _firstElement(point, 'Position');
        final latitude = position == null
            ? null
            : double.tryParse(_childText(position, 'LatitudeDegrees') ?? '');
        final longitude = position == null
            ? null
            : double.tryParse(_childText(position, 'LongitudeDegrees') ?? '');
        if (_validCoordinate(latitude, longitude)) {
          startLat ??= latitude;
          startLon ??= longitude;
        }

        final rawDistanceM = double.tryParse(
          _childText(point, 'DistanceMeters') ?? '',
        );
        if (rawDistanceM != null && rawDistanceM >= 0) {
          final rawKm = rawDistanceM / 1000;
          rawDistanceOffsetKm ??= rawKm + 0.01 >= cumulativeKm
              ? 0
              : cumulativeKm;
          if (previousRawDistanceKm != null &&
              rawKm + 0.01 < previousRawDistanceKm) {
            rawDistanceOffsetKm = cumulativeKm;
          }
          cumulativeKm = max(cumulativeKm, rawDistanceOffsetKm + rawKm);
          previousRawDistanceKm = rawKm;
        } else if (_validCoordinate(latitude, longitude) &&
            previousLat != null &&
            previousLon != null) {
          cumulativeKm += _haversine(
            previousLat,
            previousLon,
            latitude!,
            longitude!,
          );
        }

        final elevation = double.tryParse(
          _childText(point, 'AltitudeMeters') ?? '',
        );
        if (elevation != null && previousElevation != null) {
          elevationGain += max(0, elevation - previousElevation);
        }

        final heartRateElement = _firstElement(point, 'HeartRateBpm');
        final heartRate = heartRateElement == null
            ? null
            : double.tryParse(_childText(heartRateElement, 'Value') ?? '');
        final cadence = double.tryParse(
          _childText(point, 'Cadence') ?? _childText(point, 'RunCadence') ?? '',
        );
        if (heartRate != null && heartRate > 0) {
          hrSum += heartRate;
          hrCount++;
        }
        if (cadence != null && cadence > 0) {
          cadenceSum += cadence;
          cadenceCount++;
        }

        final motion = _motionBetween(previousSample, timestamp, cumulativeKm);
        final sample = ActivitySample(
          timestamp: timestamp,
          distanceKm: cumulativeKm,
          latitude: latitude,
          longitude: longitude,
          elevationM: elevation,
          heartRate: heartRate != null && heartRate > 0 ? heartRate : null,
          cadence: cadence != null && cadence > 0 ? cadence : null,
          speedMps: motion.speedMps,
          paceMinPerKm: motion.paceMinPerKm,
        );
        samples.add(sample);
        previousSample = sample;
        if (_validCoordinate(latitude, longitude)) {
          previousLat = latitude;
          previousLon = longitude;
        }
        if (elevation != null) previousElevation = elevation;
      }
    }

    var lapSeconds = 0.0;
    var lapDistanceKm = 0.0;
    var lapHeartRateSum = 0.0;
    var lapHeartRateCount = 0;
    for (final lap in doc.findAllElements('Lap')) {
      final seconds = double.tryParse(
        _childText(lap, 'TotalTimeSeconds') ?? '',
      );
      if (seconds != null && seconds > 0) lapSeconds += seconds;
      final distance = double.tryParse(_childText(lap, 'DistanceMeters') ?? '');
      if (distance != null && distance > 0) lapDistanceKm += distance / 1000;
      final averageHeartRate = _firstElement(lap, 'AverageHeartRateBpm');
      final value = averageHeartRate == null
          ? null
          : double.tryParse(_childText(averageHeartRate, 'Value') ?? '');
      if (value != null && value > 0) {
        lapHeartRateSum += value;
        lapHeartRateCount++;
      }
    }

    return _parsedFromSamples(
      samples: samples,
      startedAt: startedAt,
      distanceKm: cumulativeKm > 0 ? cumulativeKm : lapDistanceKm,
      durationMin: lapSeconds > 0
          ? lapSeconds / 60
          : endedAt.difference(startedAt).inMilliseconds / 60000,
      avgHr: hrCount > 0
          ? (hrSum / hrCount).round()
          : lapHeartRateCount > 0
          ? (lapHeartRateSum / lapHeartRateCount).round()
          : null,
      avgCadence: cadenceCount > 0 ? (cadenceSum / cadenceCount).round() : null,
      elevationGainM: elevationGain,
      startLat: startLat,
      startLon: startLon,
    );
  }

  static Future<ParsedActivity> _parseGpx(Uint8List bytes) async {
    final xml = utf8.decode(bytes);
    _validateXmlDepth(xml);
    final gpx = GpxReader().fromString(xml);
    final segments = gpx.trks
        .expand((track) => track.trksegs)
        .map((segment) => segment.trkpts)
        .where((points) => points.isNotEmpty)
        .toList();
    final pointCount = segments.fold<int>(
      0,
      (sum, points) => sum + points.length,
    );
    _validatePointCount(pointCount, 'GPX');

    final allPoints = segments.expand((segment) => segment).toList();
    final timedPoints = allPoints.where((point) => point.time != null).toList();
    final startedAt = timedPoints.isNotEmpty
        ? timedPoints.first.time!
        : DateTime.now();
    final endedAt = timedPoints.isNotEmpty ? timedPoints.last.time! : startedAt;
    final samples = <ActivitySample>[];
    var cumulativeKm = 0.0;
    var elevationGain = 0.0;
    double? startLat;
    double? startLon;
    DateTime? lastTime;

    for (final segment in segments) {
      Wpt? previousPoint;
      double? previousElevation;
      ActivitySample? previousSample;
      for (final point in segment) {
        final timestamp = point.time ?? lastTime ?? startedAt;
        lastTime = timestamp;
        if (_validCoordinate(point.lat, point.lon)) {
          startLat ??= point.lat;
          startLon ??= point.lon;
        }
        if (previousPoint != null &&
            _validCoordinate(previousPoint.lat, previousPoint.lon) &&
            _validCoordinate(point.lat, point.lon)) {
          cumulativeKm += _haversine(
            previousPoint.lat!,
            previousPoint.lon!,
            point.lat!,
            point.lon!,
          );
        }
        if (point.ele != null && previousElevation != null) {
          elevationGain += max(0, point.ele! - previousElevation);
        }
        final motion = _motionBetween(previousSample, timestamp, cumulativeKm);
        final sample = ActivitySample(
          timestamp: timestamp,
          distanceKm: cumulativeKm,
          latitude: point.lat,
          longitude: point.lon,
          elevationM: point.ele,
          speedMps: motion.speedMps,
          paceMinPerKm: motion.paceMinPerKm,
        );
        samples.add(sample);
        previousSample = sample;
        previousPoint = point;
        if (point.ele != null) previousElevation = point.ele;
      }
    }

    return _parsedFromSamples(
      samples: samples,
      startedAt: startedAt,
      distanceKm: cumulativeKm,
      durationMin: endedAt.difference(startedAt).inMilliseconds / 60000,
      elevationGainM: elevationGain,
      startLat: startLat,
      startLon: startLon,
    );
  }

  static Future<ParsedActivity> _parseFit(Uint8List bytes) async {
    final file = FitFile.fromBytes(bytes);
    DateTime? sessionStart;
    double? sessionDistanceKm;
    double? sessionDurationMin;
    int? sessionAvgHr;
    int? sessionAvgCadence;
    double? sessionAscentM;
    final recordMessages = <RecordMessage>[];

    for (final record in file.records) {
      final message = record.message;
      if (message is SessionMessage) {
        if (message.startTime != null) {
          sessionStart = DateTime.fromMillisecondsSinceEpoch(
            message.startTime!,
            isUtc: true,
          );
        }
        if (message.totalDistance != null && message.totalDistance! > 0) {
          sessionDistanceKm = message.totalDistance! / 1000;
        }
        if (message.totalTimerTime != null && message.totalTimerTime! > 0) {
          sessionDurationMin = message.totalTimerTime! / 60;
        }
        if (message.avgHeartRate != null && message.avgHeartRate! > 0) {
          sessionAvgHr = message.avgHeartRate!.toInt();
        }
        final cadence = message.avgRunningCadence ?? message.avgCadence;
        if (cadence != null && cadence > 0) sessionAvgCadence = cadence.toInt();
        if (message.totalAscent != null && message.totalAscent! > 0) {
          sessionAscentM = message.totalAscent!.toDouble();
        }
      } else if (message is RecordMessage && message.timestamp != null) {
        recordMessages.add(message);
      }
    }
    _validatePointCount(recordMessages.length, 'FIT');
    recordMessages.sort(
      (left, right) => left.timestamp!.compareTo(right.timestamp!),
    );

    final samples = <ActivitySample>[];
    var cumulativeKm = 0.0;
    var elevationGain = 0.0;
    var hrSum = 0.0;
    var hrCount = 0;
    var cadenceSum = 0.0;
    var cadenceCount = 0;
    double? previousLat;
    double? previousLon;
    double? previousElevation;
    ActivitySample? previousSample;
    double? startLat;
    double? startLon;

    for (final message in recordMessages) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        message.timestamp!,
        isUtc: true,
      );
      final latitude = _fitCoordinate(message.positionLat);
      final longitude = _fitCoordinate(message.positionLong);
      final recordDistanceKm = message.distance == null
          ? null
          : message.distance! / 1000;
      if (recordDistanceKm != null && recordDistanceKm >= 0) {
        cumulativeKm = max(cumulativeKm, recordDistanceKm);
      } else if (latitude != null &&
          longitude != null &&
          previousLat != null &&
          previousLon != null) {
        cumulativeKm += _haversine(
          previousLat,
          previousLon,
          latitude,
          longitude,
        );
      }

      final elevation = message.altitude;
      if (elevation != null && previousElevation != null) {
        elevationGain += max(0, elevation - previousElevation);
      }
      final heartRate = message.heartRate?.toDouble();
      final cadence = message.cadence?.toDouble();
      if (heartRate != null && heartRate > 0) {
        hrSum += heartRate;
        hrCount++;
      }
      if (cadence != null && cadence > 0) {
        cadenceSum += cadence;
        cadenceCount++;
      }

      final providerSpeed = message.enhancedSpeed ?? message.speed;
      final motion = _motionBetween(previousSample, timestamp, cumulativeKm);
      final speedMps = providerSpeed != null && providerSpeed > 0
          ? providerSpeed
          : motion.speedMps;
      final sample = ActivitySample(
        timestamp: timestamp,
        distanceKm: cumulativeKm,
        latitude: latitude,
        longitude: longitude,
        elevationM: elevation,
        heartRate: heartRate != null && heartRate > 0 ? heartRate : null,
        cadence: cadence != null && cadence > 0 ? cadence : null,
        speedMps: speedMps,
        paceMinPerKm: speedMps != null && speedMps > 0
            ? (1000 / speedMps) / 60
            : motion.paceMinPerKm,
      );
      samples.add(sample);
      previousSample = sample;
      if (latitude != null && longitude != null) {
        startLat ??= latitude;
        startLon ??= longitude;
        previousLat = latitude;
        previousLon = longitude;
      }
      if (elevation != null) previousElevation = elevation;
    }

    final recordStart = samples.isNotEmpty ? samples.first.timestamp : null;
    final recordDurationMin = samples.length > 1
        ? samples.last.timestamp
                  .difference(samples.first.timestamp)
                  .inMilliseconds /
              60000
        : 0.0;
    return _parsedFromSamples(
      samples: samples,
      startedAt: sessionStart ?? recordStart ?? DateTime.now(),
      distanceKm: sessionDistanceKm ?? cumulativeKm,
      durationMin: sessionDurationMin ?? recordDurationMin,
      avgHr: sessionAvgHr ?? (hrCount > 0 ? (hrSum / hrCount).round() : null),
      avgCadence:
          sessionAvgCadence ??
          (cadenceCount > 0 ? (cadenceSum / cadenceCount).round() : null),
      elevationGainM: sessionAscentM ?? elevationGain,
      startLat: startLat,
      startLon: startLon,
    );
  }

  static ParsedActivity _parsedFromSamples({
    required List<ActivitySample> samples,
    required DateTime startedAt,
    required double distanceKm,
    required double durationMin,
    int? avgHr,
    int? avgCadence,
    double? elevationGainM,
    double? startLat,
    double? startLon,
  }) {
    final storedSamples = _downsampleSamples(samples, maxStoredSamples);
    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: distanceKm.isFinite ? max(0, distanceKm) : 0,
      durationMin: durationMin.isFinite ? max(0, durationMin) : 0,
      avgHr: avgHr,
      avgCadence: avgCadence,
      elevationGainM: elevationGainM == null || !elevationGainM.isFinite
          ? null
          : max(0, elevationGainM),
      startLat: startLat,
      startLon: startLon,
      samples: List.unmodifiable(storedSamples),
      dataPoints: storedSamples.isEmpty
          ? null
          : {
              'times': storedSamples
                  .map(
                    (sample) =>
                        sample.timestamp.difference(startedAt).inMilliseconds /
                        1000,
                  )
                  .toList(),
              'distances': storedSamples
                  .map((sample) => sample.distanceKm)
                  .toList(),
              'latitudes': storedSamples
                  .map((sample) => sample.latitude)
                  .toList(),
              'longitudes': storedSamples
                  .map((sample) => sample.longitude)
                  .toList(),
              'elevations': storedSamples
                  .map((sample) => sample.elevationM)
                  .toList(),
              'paces': storedSamples
                  .map((sample) => sample.paceMinPerKm)
                  .toList(),
              'speeds': storedSamples.map((sample) => sample.speedMps).toList(),
              'hrs': storedSamples.map((sample) => sample.heartRate).toList(),
              'cadences': storedSamples
                  .map((sample) => sample.cadence)
                  .toList(),
            },
    );
  }

  static List<ActivitySample> _downsampleSamples(
    List<ActivitySample> samples,
    int maxSamples,
  ) {
    if (samples.length <= maxSamples) return List.of(samples);
    final selected = <ActivitySample>[samples.first];
    final interiorTarget = maxSamples - 2;
    final interiorCount = samples.length - 2;
    for (var i = 0; i < interiorTarget; i++) {
      final index = 1 + ((i + 0.5) * interiorCount / interiorTarget).floor();
      selected.add(samples[index.clamp(1, samples.length - 2)]);
    }
    selected.add(samples.last);
    return selected;
  }

  static ({double? speedMps, double? paceMinPerKm}) _motionBetween(
    ActivitySample? previous,
    DateTime timestamp,
    double distanceKm,
  ) {
    if (previous == null) {
      return (speedMps: null, paceMinPerKm: null);
    }
    final seconds =
        timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    final distanceDeltaKm = distanceKm - previous.distanceKm;
    if (seconds <= 0 || distanceDeltaKm <= 0) {
      return (speedMps: null, paceMinPerKm: null);
    }
    final speedMps = distanceDeltaKm * 1000 / seconds;
    final pace = (seconds / 60) / distanceDeltaKm;
    return (speedMps: speedMps, paceMinPerKm: min(20, pace));
  }

  static String? _childText(XmlElement parent, String localName) {
    for (final node in parent.descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) return node.innerText.trim();
    }
    return null;
  }

  static XmlElement? _firstElement(XmlElement parent, String localName) {
    for (final node in parent.descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) return node;
    }
    return null;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static bool _validCoordinate(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double? _fitCoordinate(double? value) {
    if (value == null || !value.isFinite) return null;
    return value;
  }

  static void _validatePointCount(int count, String format) {
    if (count == 0) throw Exception('Không có điểm track trong file $format.');
    if (count > maxRawSamples) {
      throw Exception('File $format có quá nhiều điểm track.');
    }
  }

  static void _validateXmlDepth(String xml) {
    var depth = 0;
    final tags = RegExp(r'<\s*(/?)\s*([A-Za-z_][^>\s/]*)[^>]*>');
    for (final match in tags.allMatches(xml)) {
      final raw = match.group(0)!;
      if (raw.startsWith('<?') || raw.startsWith('<!')) continue;
      if (match.group(1) == '/') {
        depth = max(0, depth - 1);
      } else if (!raw.endsWith('/>')) {
        depth++;
        if (depth > maxXmlDepth) {
          throw Exception('Cấu trúc XML lồng quá sâu.');
        }
      }
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);
    return earthRadiusKm * 2 * asin(sqrt(a));
  }

  static double _toRadians(double degree) => degree * pi / 180;
}
