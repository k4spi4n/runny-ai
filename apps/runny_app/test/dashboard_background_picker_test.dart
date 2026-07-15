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
  test('background pages span the image from left to right', () {
    expect(DashboardBackgroundLayer.alignmentXForPage(0, 7), -1);
    expect(DashboardBackgroundLayer.alignmentXForPage(3, 7), 0);
    expect(DashboardBackgroundLayer.alignmentXForPage(6, 7), 1);
    expect(DashboardBackgroundLayer.alignmentXForPage(99, 7), 1);
  });

  testWidgets('background crop pans smoothly when the selected page changes', (
    tester,
  ) async {
    Widget buildLayer(int pageIndex) {
      return MaterialApp(
        home: SizedBox(
          width: 390,
          height: 844,
          child: DashboardBackgroundLayer(
            background: AppBackground.flowingMiles,
            pageIndex: pageIndex,
            pageCount: 7,
          ),
        ),
      );
    }

    Alignment imageAlignment() {
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('dashboard-background-image')),
      );
      return image.alignment as Alignment;
    }

    await tester.pumpWidget(buildLayer(0));
    expect(imageAlignment().x, -1);

    await tester.pumpWidget(buildLayer(6));
    await tester.pump(const Duration(milliseconds: 325));
    expect(imageAlignment().x, greaterThan(-1));
    expect(imageAlignment().x, lessThan(1));

    await tester.pump(const Duration(milliseconds: 325));
    expect(imageAlignment().x, closeTo(1, 0.001));
  });

  testWidgets('loops through background choices with slider navigation', (
    tester,
  ) async {
    final selectedBackgrounds = <AppBackground>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardBackgroundPicker(
            selected: AppBackground.none,
            labels: _labels,
            onSelected: selectedBackgrounds.add,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('background-selected-none')),
      findsOneWidget,
    );

    for (var index = 0; index < AppBackground.values.length; index++) {
      await tester.tap(find.byKey(const ValueKey('background-next')));
      await tester.pumpAndSettle();
    }

    expect(selectedBackgrounds, [
      AppBackground.goldenStart,
      AppBackground.flowingMiles,
      AppBackground.electricPace,
      AppBackground.forestCalm,
      AppBackground.cityPulse,
      AppBackground.none,
    ]);
  });

  testWidgets('swiping the layered carousel selects the next background', (
    tester,
  ) async {
    AppBackground? selectedBackground;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardBackgroundPicker(
            selected: AppBackground.goldenStart,
            labels: _labels,
            onSelected: (background) => selectedBackground = background,
          ),
        ),
      ),
    );

    await tester.fling(
      find.byType(DashboardBackgroundPicker),
      const Offset(-220, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(selectedBackground, AppBackground.flowingMiles);
    expect(
      find.byKey(const ValueKey('background-selected-flowingMiles')),
      findsOneWidget,
    );
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
