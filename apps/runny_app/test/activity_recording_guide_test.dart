import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/activity_recording_guide.dart';

void main() {
  Widget buildSubject({required VoidCallback onImport}) {
    return MaterialApp(
      home: Scaffold(body: ActivityRecordingGuide(onImportActivity: onImport)),
    );
  }

  testWidgets('explains the manual import workflow and opens activity import', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var importTapped = false;
    await tester.pumpWidget(buildSubject(onImport: () => importTapped = true));
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
    expect(
      find.byKey(const ValueKey('recording_guide_find_activity')),
      findsNothing,
    );

    final importButton = find.byKey(
      const ValueKey('recording_guide_import_activity'),
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();
    expect(importTapped, isTrue);
  });
}
