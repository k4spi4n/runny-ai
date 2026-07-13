import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/weather_location_placeholder.dart';

void main() {
  testWidgets('hiển thị lời mời cấp quyền và gọi callback khi bấm', (
    tester,
  ) async {
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('vi')],
        home: Scaffold(
          body: WeatherLocationPlaceholder(
            onRequestLocation: () => requested = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Thời tiết và chất lượng không khí sẽ hiển thị ở đây.'),
      findsOneWidget,
    );
    expect(find.text('Nhấn để cho phép truy cập vị trí'), findsOneWidget);

    await tester.tap(find.byKey(const Key('request-weather-location-button')));

    expect(requested, isTrue);
  });
}
