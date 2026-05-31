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

  ParsedActivity({
    required this.startedAt,
    required this.distanceKm,
    required this.durationMin,
    this.avgHr,
    this.elevationGainM,
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

    double totalDistance = 0.0;
    double minEle = double.infinity;
    double maxEle = double.negativeInfinity;

    for (int i = 1; i < trkpts.length; i++) {
      final p1 = trkpts[i - 1];
      final p2 = trkpts[i];

      if (p1.lat != null &&
          p1.lon != null &&
          p2.lat != null &&
          p2.lon != null) {
        totalDistance += _haversine(p1.lat!, p1.lon!, p2.lat!, p2.lon!);
      }

      if (p1.ele != null) {
        if (p1.ele! < minEle) minEle = p1.ele!;
        if (p1.ele! > maxEle) maxEle = p1.ele!;
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
      avgHr: null, // GPX normally doesn't have HR unless extended
    );
  }

  static Future<ParsedActivity> _parseFit(Uint8List bytes) async {
    final file = FitFile.fromBytes(bytes);

    DateTime? startedAt;
    double totalDistanceKm = 0.0;
    double durationMin = 0.0;
    int? avgHr;

    // A very basic extraction for FIT files
    for (final record in file.records) {
      if (record.message is SessionMessage) {
        final session = record.message as SessionMessage;

        final startTimeValue = session.startTime;
        if (startTimeValue != null) {
          startedAt = DateTime.fromMillisecondsSinceEpoch(
            startTimeValue * 1000 + 631065600000,
          ); // FIT epoch offset
        }

        final distanceValue = session.totalDistance;
        if (distanceValue != null) {
          totalDistanceKm = distanceValue / 1000.0;
        }

        final timeValue = session.totalTimerTime;
        if (timeValue != null) {
          durationMin = timeValue / 60.0;
        }

        final hrValue = session.avgHeartRate;
        if (hrValue != null) {
          avgHr = hrValue.toInt();
        }
      }
    }

    startedAt ??= DateTime.now();

    return ParsedActivity(
      startedAt: startedAt,
      distanceKm: totalDistanceKm,
      durationMin: durationMin,
      avgHr: avgHr,
      elevationGainM: 0.0,
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
}
