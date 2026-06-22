import 'dart:convert';
import 'dart:typed_data';

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

    test('elevation gain = max - min', () async {
      final activity = await ActivityParser.parse(_bytes(_validGpx), 'gpx');
      expect(activity.elevationGainM, closeTo(7.0, 1e-6)); // 12 - 5
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

  group('ActivityParser - xử lý lỗi', () {
    test('định dạng không hỗ trợ ném exception', () {
      expect(
        () => ActivityParser.parse(_bytes('x'), 'tcx'),
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
