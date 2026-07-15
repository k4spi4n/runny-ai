import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/theme/app_background.dart';
import 'package:runny_app/theme/theme_provider.dart';
import 'package:runny_app/widgets/dashboard_background_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _labels = {
  AppBackground.none: 'No background',
  AppBackground.goldenStart: 'Golden start',
  AppBackground.flowingMiles: 'Flowing miles',
  AppBackground.electricPace: 'Electric pace',
  AppBackground.forestCalm: 'Forest calm',
  AppBackground.cityPulse: 'City pulse',
};

void main() {
  testWidgets('shows the default choice and reports a tapped background', (
    tester,
  ) async {
    AppBackground? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardBackgroundPicker(
            selected: AppBackground.none,
            labels: _labels,
            onSelected: (background) => tapped = background,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('background-selected-none')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('background-option-electricPace')),
    );
    await tester.pump();

    expect(tapped, AppBackground.electricPace);
  });

  test('ThemeProvider restores and persists the background choice', () async {
    SharedPreferences.setMockInitialValues({
      'app_background': AppBackground.forestCalm.name,
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = ThemeProvider(prefs);

    expect(provider.background, AppBackground.forestCalm);

    await provider.setBackground(AppBackground.cityPulse);

    expect(provider.background, AppBackground.cityPulse);
    expect(prefs.getString('app_background'), AppBackground.cityPulse.name);
  });

  test(
    'ThemeProvider falls back to no background for an unknown value',
    () async {
      SharedPreferences.setMockInitialValues({
        'app_background': 'removed_background',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(ThemeProvider(prefs).background, AppBackground.none);
    },
  );
}
