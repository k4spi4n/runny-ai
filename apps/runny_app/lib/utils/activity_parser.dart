import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:gpx/gpx.dart';
import 'package:fit_tool/fit_tool.dart';

class ParsedActivity {
  final DateTime startedAt;
  final double distanceKm;
  final double durationMin;
  final int? avgHr;
  final double? elevationGainM;
  final Map<String, dynamic>? dataPoints;
  final double? startLat;
  final double? startLon;

  ParsedActivity({
    required this.startedAt,
    required this.distanceKm,
    required this.durationMin,
    this.avgHr,
    this.elevationGainM,
    this.dataPoints,
    this.startLat,
    this.startLon,
  });
}

class ActivityParser {
  static Future<ParsedActivity> parse(Uint8List bytes, String extension) async {
    if (extension == 'gpx') {
      return _parseGpx(bytes);
    } else if (extension == 'fit') {
      return _parseFit(bytes);
    } else {
      throw Exception('Định dạng không hỗ trợ: $extension');
    }
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
    double elevationGain = 0.0;
    double minEle = double.infinity;
    double maxEle = double.negativeInfinity;

    List<double> times = [];
    List<double> distances = [];
    List<double> elevations = [];
    List<double> paces = [];
    List<double> hrs = [];
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

    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: totalDistanceKm,
      durationMin: durationMin,
      avgHr: avgHr,
      elevationGainM: elevationGain,
      startLat: startLat,
      startLon: startLon,
      dataPoints: {
        'times': times,
        'distances': distances,
        'elevations': elevations,
        'paces': paces,
        'hrs': hrs,
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
