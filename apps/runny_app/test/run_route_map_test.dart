import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/recorded_run.dart';
import 'package:runny_app/widgets/run_route_map.dart';

void main() {
  testWidgets(
    'live map follows supplied GPS coordinates and shows uncertainty',
    (tester) async {
      final now = DateTime.utc(2026, 11, 5);
      Widget subject(
        RunFix? position, {
        List<List<RunFix>> segments = const [],
      }) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: RunRouteMap(
              position: position,
              segments: segments,
              live: true,
              showTiles: false,
            ),
          ),
        ),
      );

      await tester.pumpWidget(subject(null));
      await tester.pumpAndSettle();
      expect(find.text('run_map_waiting_location'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );

      const latitude = 21.0278;
      const longitude = 105.8342;
      final first = RunFix(latitude, longitude, now, 7);
      await tester.pumpWidget(subject(first));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(controller.camera.center.latitude, closeTo(latitude, 0.000001));
      expect(controller.camera.center.longitude, closeTo(longitude, 0.000001));
      expect(controller.camera.zoom, 16);
      expect(find.text('run_map_waiting_location'), findsNothing);
      final accuracy = tester
          .widget<CircleLayer>(find.byType(CircleLayer))
          .circles
          .single;
      expect(accuracy.radius, 7);
      expect(accuracy.useRadiusInMeter, isTrue);

      await tester.drag(find.byType(FlutterMap), const Offset(80, 30));
      await tester.pumpAndSettle();
      final panned = controller.camera.center;
      final next = RunFix(
        latitude + 0.0001,
        longitude,
        now.add(const Duration(seconds: 5)),
        5,
      );
      await tester.pumpWidget(subject(next));
      await tester.pumpAndSettle();
      expect(controller.camera.center, panned);
      final marker = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .single;
      expect(marker.point.latitude, next.latitude);
      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.latitude,
        closeTo(next.latitude, 0.000001),
      );

      final latest = RunFix(
        latitude + 0.0002,
        longitude,
        now.add(const Duration(seconds: 10)),
        6,
      );
      await tester.pumpWidget(subject(latest));
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.latitude,
        closeTo(latest.latitude, 0.000001),
      );

      await tester.pumpWidget(
        subject(
          null,
          segments: [
            [first, latest],
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircleLayer), findsNothing);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'offline route retains separate polylines and allows pan/recenter',
    (tester) async {
      final start = DateTime.utc(2026, 11, 3);
      final segments = [
        [RunFix(10, 106, start, 5), RunFix(10.001, 106, start, 5)],
        [RunFix(10.002, 106, start, 5), RunFix(10.003, 106, start, 5)],
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 320,
              child: RunRouteMap(segments: segments, showTiles: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines.length, 2);
      expect(layer.polylines.every((p) => p.points.length == 2), isTrue);
      expect(find.byType(TileLayer), findsNothing);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final beforePan = map.mapController!.camera.center;
      await tester.drag(find.byType(FlutterMap), const Offset(80, 30));
      await tester.pumpAndSettle();
      expect(map.mapController!.camera.center, isNot(beforePan));
      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pumpAndSettle();
      expect(
        map.mapController!.camera.center.latitude,
        closeTo(beforePan.latitude, 0.00001),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
