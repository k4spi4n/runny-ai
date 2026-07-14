import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/weather_location_placeholder.dart';

void main() {
  testWidgets('hiển thị lời mời cấp quyền và gọi callback khi bấm', (
    tester,
  ) async {
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherLocationPlaceholder(
            onRequestLocation: () => requested = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(WeatherLocationPlaceholder), findsOneWidget);
    expect(
      find.byKey(const Key('weather-location-placeholder')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('request-weather-location-button')));

    expect(requested, isTrue);
  });
}
