import 'package:flutter/material.dart';

import '../pages/training_plan_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String? _pendingWorkoutPayload;

void handleRunReminderPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    _pendingWorkoutPayload = payload;
    return;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (_) => const TrainingPlanPage(),
      settings: RouteSettings(name: 'run-reminder:$payload'),
    ),
  );
}

void flushPendingRunReminderNavigation() {
  final payload = _pendingWorkoutPayload;
  if (payload == null) return;
  _pendingWorkoutPayload = null;
  handleRunReminderPayload(payload);
}
