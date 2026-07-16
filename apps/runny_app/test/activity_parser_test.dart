import 'dart:convert';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/utils/activity_parser.dart';

/// GPX hợp lệ với 3 điểm dọc kinh tuyến để khoảng cách dễ kiểm chứng.
/// 0.01 độ vĩ độ ~ 1.1119 km (theo công thức haversine, R = 6371 km).
const _validGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <trkseg>
      <trkpt lat="10.0000" lon="106.0000">
        <ele>5.0</ele>
        <time>2026-06-19T00:00:00Z</time>
      </trkpt>
      <trkpt lat="10.0100" lon="106.0000">
        <ele>12.0</ele>
        <time>2026-06-19T00:05:00Z</time>
      </trkpt>
      <trkpt lat="10.0200" lon="106.0000">
        <ele>8.0</ele>
        <time>2026-06-19T00:10:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

/// TCX hợp lệ: 3 trackpoint, có DistanceMeters tích luỹ, nhịp tim, độ cao, cadence.
const _validTcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase>
  <Activities>
    <Activity Sport="Running">
      <Id>2026-06-19T00:00:00Z</Id>
      <Lap StartTime="2026-06-19T00:00:00Z">
        <TotalTimeSeconds>600</TotalTimeSeconds>
        <DistanceMeters>2000</DistanceMeters>
        <Track>
          <Trackpoint>
            <Time>2026-06-19T00:00:00Z</Time>
            <Position><LatitudeDegrees>10.0</LatitudeDegrees><LongitudeDegrees>106.0</LongitudeDegrees></Position>
            <AltitudeMeters>5</AltitudeMeters>
            <DistanceMeters>0</DistanceMeters>
            <HeartRateBpm><Value>140</Value></HeartRateBpm>
            <Cadence>80</Cadence>
          </Trackpoint>
          <Trackpoint>
            <Time>2026-06-19T00:05:00Z</Time>
            <Position><LatitudeDegrees>10.01</LatitudeDegrees><LongitudeDegrees>106.0</LongitudeDegrees></Position>
            <AltitudeMeters>12</AltitudeMeters>
            <DistanceMeters>1000</DistanceMeters>
            <HeartRateBpm><Value>150</Value></HeartRateBpm>
            <Cadence>90</Cadence>
          </Trackpoint>
          <Trackpoint>
            <Time>2026-06-19T00:10:00Z</Time>
            <Position><LatitudeDegrees>10.02</LatitudeDegrees><LongitudeDegrees>106.0</LongitudeDegrees></Position>
            <AltitudeMeters>8</AltitudeMeters>
            <DistanceMeters>2000</DistanceMeters>
            <HeartRateBpm><Value>160</Value></HeartRateBpm>
            <Cadence>100</Cadence>
          </Trackpoint>
        </Track>
      </Lap>
    </Activity>
  </Activities>
</TrainingCenterDatabase>
''';

const _multiSegmentGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <trkseg>
      <trkpt lat="10.0000" lon="106.0000"><ele>5</ele><time>2026-06-19T00:00:00Z</time></trkpt>
      <trkpt lat="10.0100" lon="106.0000"><ele>12</ele><time>2026-06-19T00:05:00Z</time></trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="20.0000" lon="106.0000"><ele>8</ele><time>2026-06-19T00:10:00Z</time></trkpt>
      <trkpt lat="20.0100" lon="106.0000"><ele>15</ele><time>2026-06-19T00:15:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

const _missingMetricsTcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase>
  <Activities><Activity Sport="Running">
    <Lap StartTime="2026-06-19T00:00:00Z">
      <TotalTimeSeconds>600</TotalTimeSeconds>
      <Track>
        <Trackpoint>
          <Time>2026-06-19T00:00:00Z</Time>
          <DistanceMeters>0</DistanceMeters>
          <HeartRateBpm><Value>140</Value></HeartRateBpm>
          <Cadence>80</Cadence>
        </Trackpoint>
        <Trackpoint>
          <Time>2026-06-19T00:05:00Z</Time>
          <DistanceMeters>1000</DistanceMeters>
        </Trackpoint>
        <Trackpoint>
          <Time>2026-06-19T00:10:00Z</Time>
          <DistanceMeters>2000</DistanceMeters>
          <HeartRateBpm><Value>160</Value></HeartRateBpm>
          <Cadence>100</Cadence>
        </Trackpoint>
      </Track>
    </Lap>
  </Activity></Activities>
</TrainingCenterDatabase>
''';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('ActivityParser - GPX', () {
    test('tính quãng đường bằng haversine sát giá trị lý thuyết', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      // 2 đoạn x ~1.1119 km = ~2.224 km
      expect(activity.distanceKm, closeTo(2.224, 0.02));
    });

    test('tính đúng thời lượng từ mốc thời gian đầu/cuối', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      expect(activity.durationMin, closeTo(10.0, 1e-6));
    });

    test('elevation gain là tổng các đoạn đi lên', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      expect(activity.elevationGainM, closeTo(7.0, 1e-6));
    });

    test('đọc mọi segment và không nối khoảng cách giữa các segment', () async {
      final activity = await ActivityParser.parse(
        _bytes(_multiSegmentGpx),
        'gpx',
      );

      expect(activity.distanceKm, closeTo(2.224, 0.03));
      // 5 -> 12 và 8 -> 15; bước nhảy giữa segment không được tính.
      expect(activity.elevationGainM, closeTo(14, 1e-6));
      expect((activity.dataPoints!['times'] as List), hasLength(4));
    });

    test('ghi nhận toạ độ điểm xuất phát', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      expect(activity.startLat, closeTo(10.0, 1e-6));
      expect(activity.startLon, closeTo(106.0, 1e-6));
    });

    test('dataPoints có đủ chuỗi times/distances/elevations/paces', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      final dp = activity.dataPoints!;
      expect((dp['times'] as List).length, 3);
      expect((dp['distances'] as List).length, 3);
      expect((dp['elevations'] as List).length, 3);
      expect((dp['paces'] as List).length, 3);
      // distance cộng dồn tăng dần
      final dist = (dp['distances'] as List).cast<double>();
      expect(dist.first, 0.0);
      expect(dist.last, greaterThan(dist.first));
    });
  });

  group('ActivityParser - TCX', () {
    test('quãng đường lấy từ DistanceMeters tích luỹ', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.distanceKm, closeTo(2.0, 1e-6));
    });

    test('thời lượng ưu tiên tổng Lap/TotalTimeSeconds', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.durationMin, closeTo(10.0, 1e-6));
    });

    test('avg HR là trung bình các trackpoint', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.avgHr, 150); // (140 + 150 + 160) / 3
    });

    test('avg cadence là trung bình các trackpoint', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.avgCadence, 90); // (80 + 90 + 100) / 3
    });

    test('payload lưu database giữ lại avg cadence', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');

      final fields = activity.toDatabaseFields();

      expect(fields['avg_cadence'], 90);
      expect(fields['avg_hr'], 150);
      expect(fields['started_at'], '2026-06-19T00:00:00.000Z');
    });

    test('elevation gain là tổng các đoạn đi lên', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.elevationGainM, closeTo(7.0, 1e-6));
    });

    test('ghi nhận toạ độ xuất phát và đủ chuỗi dataPoints', () async {
      final activity = await ActivityParser.parse(_bytes(_validTcx), 'tcx');
      expect(activity.startLat, closeTo(10.0, 1e-6));
      expect(activity.startLon, closeTo(106.0, 1e-6));
      final dp = activity.dataPoints!;
      expect((dp['times'] as List).length, 3);
      expect((dp['hrs'] as List).length, 3);
      expect((dp['cadences'] as List).length, 3);
    });

    test(
      'các chuỗi metric giữ đúng index khi trackpoint thiếu dữ liệu',
      () async {
        final activity = await ActivityParser.parse(
          _bytes(_missingMetricsTcx),
          'tcx',
        );
        final data = activity.dataPoints!;
        final times = data['times'] as List;
        final heartRates = data['hrs'] as List;
        final cadences = data['cadences'] as List;

        expect(heartRates, hasLength(times.length));
        expect(cadences, hasLength(times.length));
        expect(heartRates, [140.0, null, 160.0]);
        expect(cadences, [80.0, null, 100.0]);
        expect(activity.avgHr, 150);
        expect(activity.avgCadence, 90);
      },
    );
  });

  group('ActivityParser - FIT', () {
    test('suy ra tổng từ Record khi không có Session usable', () async {
      final start = DateTime.utc(2026, 6, 19);
      final builder = FitFileBuilder(autoDefine: true)
        ..add(
          RecordMessage()
            ..timestamp = start.millisecondsSinceEpoch
            ..distance = 0
            ..altitude = 10
            ..heartRate = 140
            ..cadence = 80
            ..positionLat = 10
            ..positionLong = 106,
        )
        ..add(
          RecordMessage()
            ..timestamp = start
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch
            ..distance = 1000
            ..altitude = 20
            ..heartRate = 150
            ..cadence = 90
            ..positionLat = 10.01
            ..positionLong = 106,
        )
        ..add(
          RecordMessage()
            ..timestamp = start
                .add(const Duration(minutes: 10))
                .millisecondsSinceEpoch
            ..distance = 2000
            ..altitude = 15
            ..heartRate = 160
            ..cadence = 100
            ..positionLat = 10.02
            ..positionLong = 106,
        );

      final activity = await ActivityParser.parse(
        builder.build().toBytes(),
        'fit',
      );

      expect(activity.startedAt, start);
      expect(activity.distanceKm, closeTo(2, 1e-6));
      expect(activity.durationMin, closeTo(10, 1e-6));
      expect(activity.avgHr, 150);
      expect(activity.avgCadence, 90);
      expect(activity.elevationGainM, closeTo(10, 1e-6));
      expect(activity.startLat, closeTo(10, 1e-6));
      expect(activity.startLon, closeTo(106, 1e-6));
      expect((activity.dataPoints!['hrs'] as List), hasLength(3));
    });
  });

  group('ActivityParser - xử lý lỗi', () {
    test('định dạng không hỗ trợ ném exception', () {
      expect(
        () => ActivityParser.parse(_bytes('x'), 'csv'),
        throwsA(isA<Exception>()),
      );
    });

    test('GPX không có track ném exception', () {
      const empty = '<?xml version="1.0"?><gpx version="1.1"></gpx>';
      expect(
        () => ActivityParser.parse(_bytes(empty), 'gpx'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
