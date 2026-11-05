import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/dashboard_bottom_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.preload(const Locale('en'));
    await AppLocalizations.preload(const Locale('vi'));
  });

  Widget subject({
    required ValueChanged<int> onSelected,
    VoidCallback? onRecord,
    int selectedIndex = 0,
    bool hasRunDraft = false,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('vi')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: DashboardBottomBar(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        onRecord: onRecord,
        hasRunDraft: hasRunDraft,
      ),
    ),
  );

  testWidgets(
    'fixed destinations and center record action work without sliding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selections = <int>[];
      var recordings = 0;
      await tester.pumpWidget(
        subject(onSelected: selections.add, onRecord: () => recordings++),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollable), findsNothing);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .items,
        hasLength(5),
      );
      final record = find.byKey(const ValueKey('nav-record-run'));
      expect(tester.getCenter(record).dx, closeTo(160, 0.1));
      expect(tester.getSize(record).width, greaterThanOrEqualTo(48));
      for (final label in ['Home', 'History', 'Community']) {
        await tester.tap(find.text(label));
      }
      await tester.tap(record);
      expect(selections, [0, 4, 5]);
      expect(recordings, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('More keeps every secondary screen reachable', (tester) async {
    final selections = <int>[];
    await tester.pumpWidget(
      subject(onSelected: selections.add, onRecord: () {}, selectedIndex: 3),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      4,
    );
    for (final item in [
      ('Training Plan', 1),
      ('AI Coach', 2),
      ('Nutrition', 3),
      ('Profile', 6),
    ]) {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.$1));
      await tester.pumpAndSettle();
      expect(selections.last, item.$2);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vietnamese draft action fits with enlarged text and safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    var returned = false;
    await tester.pumpWidget(
      subject(
        onSelected: (_) {},
        onRecord: () => returned = true,
        hasRunDraft: true,
        locale: const Locale('vi'),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trở lại'), findsOneWidget);
    expect(find.byTooltip('Trở lại buổi chạy / bản nháp'), findsOneWidget);
    final record = find.byKey(const ValueKey('nav-record-run'));
    expect(tester.getBottomRight(record).dy, lessThan(666));
    await tester.tap(record);
    expect(returned, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'web keeps coach and history navigation without mobile recording',
    (tester) async {
      final selections = <int>[];
      await tester.pumpWidget(subject(onSelected: selections.add));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-record-run')), findsNothing);
      await tester.tap(find.text('AI Coach'));
      await tester.tap(find.text('History'));
      expect(selections, [2, 4]);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Training Plan'), findsOneWidget);
      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    },
  );
}
