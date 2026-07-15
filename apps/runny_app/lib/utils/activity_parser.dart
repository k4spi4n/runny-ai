import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:gpx/gpx.dart';
import 'package:fit_tool/fit_tool.dart';
import 'package:xml/xml.dart';

class ParsedActivity {
  final DateTime startedAt;
  final double distanceKm;
  final double durationMin;
  final int? avgHr;
  final int? avgCadence;
  final double? elevationGainM;
  final Map<String, dynamic>? dataPoints;
  final double? startLat;
  final double? startLon;

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
  });

  /// Các cột activity được dùng chung bởi luồng nhập file và ảnh chụp.
  ///
  /// Giữ ánh xạ này cạnh dữ liệu đã parse để khi schema có thêm một chỉ số,
  /// mọi luồng dùng [ParsedActivity] đều lưu cùng một payload.
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
  static Future<ParsedActivity> parse(Uint8List bytes, String extension) async {
    if (extension == 'gpx') {
      return _parseGpx(bytes);
    } else if (extension == 'fit') {
      return _parseFit(bytes);
    } else if (extension == 'tcx') {
      return _parseTcx(bytes);
    } else {
      throw Exception('Định dạng không hỗ trợ: $extension');
    }
  }

  /// Parse TCX (XML từ Garmin/COROS/Strava...). TCX thường kèm nhịp tim và quãng
  /// đường tích luỹ (DistanceMeters) -> chính xác hơn GPX cho pace/HR.
  static Future<ParsedActivity> _parseTcx(Uint8List bytes) async {
    final doc = XmlDocument.parse(utf8.decode(bytes));

    String? childText(XmlElement parent, String name) {
      for (final e in parent.findElements(name)) {
        return e.innerText.trim();
      }
      return null;
    }

    final trackpoints = doc.findAllElements('Trackpoint').toList();
    if (trackpoints.isEmpty) {
      throw Exception('Không tìm thấy Trackpoint trong file TCX.');
    }

    DateTime? startedAt;
    DateTime? endedAt;
    double? startLat;
    double? startLon;
    double minEle = double.infinity;
    double maxEle = double.negativeInfinity;

    final times = <double>[];
    final distances = <double>[]; // km tích luỹ
    final elevations = <double>[];
    final paces = <double>[];
    final hrs = <double>[];
    final cadences = <double>[];

    double cumKm = 0.0;
    double? prevLat;
    double? prevLon;
    double hrSum = 0;
    int hrCount = 0;
    double cadenceSum = 0;
    int cadenceCount = 0;

    for (final tp in trackpoints) {
      final timeStr = childText(tp, 'Time');
      final time = timeStr != null ? DateTime.tryParse(timeStr) : null;
      startedAt ??= time;
      if (time != null) endedAt = time;
      final timeOffset = (startedAt != null && time != null)
          ? time.difference(startedAt).inSeconds.toDouble()
          : (times.isNotEmpty ? times.last : 0.0);

      double? lat, lon;
      for (final pos in tp.findElements('Position')) {
        lat = double.tryParse(childText(pos, 'LatitudeDegrees') ?? '');
        lon = double.tryParse(childText(pos, 'LongitudeDegrees') ?? '');
      }
      if (lat != null && lon != null) {
        startLat ??= lat;
        startLon ??= lon;
      }

      // Quãng đường: ưu tiên DistanceMeters (tích luỹ); thiếu thì dùng haversine.
      final distM = double.tryParse(childText(tp, 'DistanceMeters') ?? '');
      if (distM != null) {
        cumKm = distM / 1000.0;
      } else if (lat != null &&
          lon != null &&
          prevLat != null &&
          prevLon != null) {
        cumKm += _haversine(prevLat, prevLon, lat, lon);
      }
      if (lat != null && lon != null) {
        prevLat = lat;
        prevLon = lon;
      }

      final ele = double.tryParse(childText(tp, 'AltitudeMeters') ?? '');
      if (ele != null) {
        if (ele < minEle) minEle = ele;
        if (ele > maxEle) maxEle = ele;
      }

      double hr = 0;
      for (final hrEl in tp.findElements('HeartRateBpm')) {
        final v = double.tryParse(childText(hrEl, 'Value') ?? '');
        if (v != null) hr = v;
      }
      if (hr > 0) {
        hrs.add(hr);
        hrSum += hr;
        hrCount++;
      }

      var cadenceStr = childText(tp, 'Cadence');
      if (cadenceStr == null) {
        for (final ext in tp.findElements('Extensions')) {
          for (final tpx in ext.findElements('TPX')) {
            final runCad = childText(tpx, 'RunCadence');
            if (runCad != null) {
              cadenceStr = runCad;
            }
          }
        }
      }
      final cadence = cadenceStr != null ? double.tryParse(cadenceStr) : null;
      if (cadence != null && cadence > 0) {
        cadences.add(cadence);
        cadenceSum += cadence;
        cadenceCount++;
      }

      if (times.isNotEmpty) {
        final dDist = cumKm - distances.last;
        final dTime = timeOffset - times.last;
        if (dTime > 0 && dDist > 0) {
          final pace = (dTime / 60.0) / dDist;
          paces.add(pace > 20 ? 20 : pace);
        } else {
          paces.add(paces.isNotEmpty ? paces.last : 0.0);
        }
      } else {
        paces.add(0.0);
      }

      times.add(timeOffset);
      distances.add(cumKm);
      elevations.add(ele ?? 0.0);
    }

    startedAt ??= DateTime.now();
    endedAt ??= startedAt;

    // Thời lượng: ưu tiên tổng Lap/TotalTimeSeconds, không thì theo mốc thời gian.
    double lapSeconds = 0;
    for (final lap in doc.findAllElements('Lap')) {
      final secs = double.tryParse(childText(lap, 'TotalTimeSeconds') ?? '');
      if (secs != null) lapSeconds += secs;
    }
    final durationMin = lapSeconds > 0
        ? lapSeconds / 60.0
        : endedAt.difference(startedAt).inSeconds / 60.0;

    final elevationGain =
        (maxEle != double.negativeInfinity && minEle != double.infinity)
        ? (maxEle - minEle)
        : 0.0;

    int? avgHr;
    if (hrCount > 0) {
      avgHr = (hrSum / hrCount).round();
    } else {
      // Dự phòng: lấy trung bình AverageHeartRateBpm của các Lap.
      double lapHrSum = 0;
      int lapHrCount = 0;
      for (final lap in doc.findAllElements('Lap')) {
        for (final avg in lap.findElements('AverageHeartRateBpm')) {
          final v = double.tryParse(childText(avg, 'Value') ?? '');
          if (v != null) {
            lapHrSum += v;
            lapHrCount++;
          }
        }
      }
      if (lapHrCount > 0) avgHr = (lapHrSum / lapHrCount).round();
    }

    int? avgCadence;
    if (cadenceCount > 0) {
      avgCadence = (cadenceSum / cadenceCount).round();
    }

    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: distances.isNotEmpty ? distances.last : 0.0,
      durationMin: durationMin,
      avgHr: avgHr,
      avgCadence: avgCadence,
      elevationGainM: elevationGain,
      startLat: startLat,
      startLon: startLon,
      dataPoints: {
        'times': times,
        'distances': distances,
        'elevations': elevations,
        'paces': paces,
        'hrs': hrs,
        'cadences': cadences,
      },
    );
  }

  static Future<ParsedActivity> _parseGpx(Uint8List bytes) async {
    final gpxString = utf8.decode(bytes);
    final gpx = GpxReader().fromString(gpxString);

    if (gpx.trks.isEmpty || gpx.trks.first.trksegs.isEmpty) {
      throw Exception('Không tìm thấy track dữ liệu trong file GPX.');
    }

    final trkpts = gpx.trks.first.trksegs.first.trkpts;
    if (trkpts.isEmpty) {
      throw Exception('Không có điểm track.');
    }

    DateTime startedAt = trkpts.first.time ?? DateTime.now();
    DateTime endedAt = trkpts.last.time ?? startedAt;
    final startLat = trkpts.first.lat;
    final startLon = trkpts.first.lon;

    double totalDistance = 0.0;
    double minEle = double.infinity;
    double maxEle = double.negativeInfinity;

    List<double> times = [];
    List<double> distances = [];
    List<double> elevations = [];
    List<double> paces = []; // min/km

    for (int i = 0; i < trkpts.length; i++) {
      final p = trkpts[i];
      final currentTime = p.time ?? startedAt;
      final timeOffset = currentTime.difference(startedAt).inSeconds.toDouble();

      if (i > 0) {
        final pPrev = trkpts[i - 1];
        if (pPrev.lat != null &&
            pPrev.lon != null &&
            p.lat != null &&
            p.lon != null) {
          final d = _haversine(pPrev.lat!, pPrev.lon!, p.lat!, p.lon!);
          totalDistance += d;

          final timeDiffSeconds = currentTime
              .difference(pPrev.time ?? currentTime)
              .inSeconds;
          if (timeDiffSeconds > 0 && d > 0) {
            final currentPace = (timeDiffSeconds / 60.0) / d;
            // Cap pace at 20 min/km to avoid spikes
            paces.add(currentPace > 20 ? 20 : currentPace);
          } else {
            paces.add(paces.isNotEmpty ? paces.last : 0.0);
          }
        } else {
          paces.add(paces.isNotEmpty ? paces.last : 0.0);
        }
      } else {
        paces.add(0.0);
      }

      times.add(timeOffset);
      distances.add(totalDistance);
      elevations.add(p.ele ?? 0.0);

      if (p.ele != null) {
        if (p.ele! < minEle) minEle = p.ele!;
        if (p.ele! > maxEle) maxEle = p.ele!;
      }
    }

    double elevationGain =
        (maxEle != double.negativeInfinity && minEle != double.infinity)
        ? (maxEle - minEle)
        : 0.0;

    double durationMin = endedAt.difference(startedAt).inSeconds / 60.0;

    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: totalDistance,
      durationMin: durationMin,
      elevationGainM: elevationGain,
      avgHr: null,
      startLat: startLat,
      startLon: startLon,
      dataPoints: {
        'times': times,
        'distances': distances,
        'elevations': elevations,
        'paces': paces,
      },
    );
  }

  static Future<ParsedActivity> _parseFit(Uint8List bytes) async {
    final file = FitFile.fromBytes(bytes);

    DateTime? startedAt;
    double totalDistanceKm = 0.0;
    double durationMin = 0.0;
    int? avgHr;
    int? avgCadence;
    double elevationGain = 0.0;
    double minEle = double.infinity;
    double maxEle = double.negativeInfinity;

    List<double> times = [];
    List<double> distances = [];
    List<double> elevations = [];
    List<double> paces = [];
    List<double> hrs = [];
    List<double> recordCadences = [];
    double? startLat;
    double? startLon;

    DateTime? firstTimestamp;

    for (final record in file.records) {
      final message = record.message;
      if (message is SessionMessage) {
        final startTimeValue = message.startTime;
        if (startTimeValue != null) {
          startedAt = DateTime.fromMillisecondsSinceEpoch(
            startTimeValue * 1000 + 631065600000,
          );
        }
        final distanceValue = message.totalDistance;
        if (distanceValue != null) {
          totalDistanceKm = distanceValue / 1000.0;
        }
        final timeValue = message.totalTimerTime;
        if (timeValue != null) {
          durationMin = timeValue / 60.0;
        }
        final hrValue = message.avgHeartRate;
        if (hrValue != null) {
          avgHr = hrValue.toInt();
        }
        final cadenceValue = message.avgRunningCadence ?? message.avgCadence;
        if (cadenceValue != null) {
          avgCadence = cadenceValue.toInt();
        }
      } else if (message is RecordMessage) {
        final timestampValue = message.timestamp;
        if (timestampValue == null) continue;

        final currentTimestamp = DateTime.fromMillisecondsSinceEpoch(
          timestampValue * 1000 + 631065600000,
        );
        firstTimestamp ??= currentTimestamp;

        final timeOffset = currentTimestamp
            .difference(firstTimestamp)
            .inSeconds
            .toDouble();
        final dist = (message.distance ?? 0.0) / 1000.0;
        final ele = message.altitude ?? 0.0;
        final hr = (message.heartRate ?? 0).toDouble();
        final cad = (message.cadence ?? 0).toDouble();
        final recordLat = message.positionLat;
        final recordLon = message.positionLong;
        if (startLat == null && recordLat != null && recordLon != null) {
          startLat = _semicirclesToDegrees(recordLat);
          startLon = _semicirclesToDegrees(recordLon);
        }

        if (times.isNotEmpty) {
          final dDist = dist - distances.last;
          final dTime = timeOffset - times.last;
          if (dTime > 0 && dDist > 0) {
            final pace = (dTime / 60.0) / dDist;
            paces.add(pace > 20 ? 20 : pace);
          } else {
            paces.add(paces.isNotEmpty ? paces.last : 0.0);
          }
        } else {
          paces.add(0.0);
        }

        times.add(timeOffset);
        distances.add(dist);
        elevations.add(ele);
        if (hr > 0) hrs.add(hr);
        if (cad > 0) recordCadences.add(cad);

        if (message.altitude != null) {
          if (message.altitude! < minEle) minEle = message.altitude!;
          if (message.altitude! > maxEle) maxEle = message.altitude!;
        }
      }
    }

    startedAt ??= firstTimestamp ?? DateTime.now();
    if (maxEle != double.negativeInfinity && minEle != double.infinity) {
      elevationGain = maxEle - minEle;
    }

    if (avgCadence == null && recordCadences.isNotEmpty) {
      avgCadence =
          (recordCadences.reduce((a, b) => a + b) / recordCadences.length)
              .round();
    }

    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: totalDistanceKm,
      durationMin: durationMin,
      avgHr: avgHr,
      avgCadence: avgCadence,
      elevationGainM: elevationGain,
      startLat: startLat,
      startLon: startLon,
      dataPoints: {
        'times': times,
        'distances': distances,
        'elevations': elevations,
        'paces': paces,
        'hrs': hrs,
        'cadences': recordCadences,
      },
    );
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);
    final c = 2 * asin(sqrt(a));
    return r * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  static double _semicirclesToDegrees(num semicircles) {
    return semicircles.toDouble() * (180 / 2147483648);
  }
}
