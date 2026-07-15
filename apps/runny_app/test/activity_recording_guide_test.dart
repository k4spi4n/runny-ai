import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/activity_recording_guide.dart';

void main() {
  Widget buildSubject({
    required VoidCallback onFindActivity,
    required VoidCallback onImport,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ActivityRecordingGuide(
          onFindActivity: onFindActivity,
          onImportActivity: onImport,
        ),
      ),
    );
  }

  testWidgets('offers finding an existing activity or importing a new one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var findTapped = false;
    var importTapped = false;
    await tester.pumpWidget(
      buildSubject(
        onFindActivity: () => findTapped = true,
        onImport: () => importTapped = true,
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
    expect(findButton, findsOneWidget);
    await tester.ensureVisible(findButton);
    await tester.tap(findButton);
    await tester.pump();
    expect(findTapped, isTrue);
    expect(importTapped, isFalse);

    final importButton = find.byKey(
      const ValueKey('recording_guide_import_activity'),
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();
    expect(importTapped, isTrue);
  });
}
