import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/activity_recording_guide.dart';

void main() {
  Widget buildSubject({
    required bool connected,
    required VoidCallback onFind,
    required VoidCallback onImport,
    VoidCallback? onSync,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ActivityRecordingGuide(
          stravaConnected: connected,
          syncing: false,
          onFindActivity: onFind,
          onImportActivity: onImport,
          onSyncStrava: onSync,
        ),
      ),
    );
  }

  testWidgets('explains the device workflow and finds a recorded activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var findTapped = false;
    await tester.pumpWidget(
      buildSubject(
        connected: false,
        onFind: () => findTapped = true,
        onImport: () {},
      ),
    );
    await tester.pump();

    expect(find.byType(ActivityRecordingGuide), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recording_guide_step_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recording_guide_step_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recording_guide_step_3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recording_guide_sync_strava')),
      findsNothing,
    );

    final findButton = find.byKey(
      const ValueKey('recording_guide_find_activity'),
    );
    await tester.ensureVisible(findButton);
    await tester.tap(findButton);
    await tester.pump();
    expect(findTapped, isTrue);
  });

  testWidgets('shows Strava sync only for a connected account', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var syncTapped = false;
    await tester.pumpWidget(
      buildSubject(
        connected: true,
        onFind: () {},
        onImport: () {},
        onSync: () => syncTapped = true,
      ),
    );
    await tester.pump();

    final syncButton = find.byKey(
      const ValueKey('recording_guide_sync_strava'),
    );
    await tester.ensureVisible(syncButton);
    await tester.tap(syncButton);
    await tester.pump();
    expect(syncTapped, isTrue);
  });
}
