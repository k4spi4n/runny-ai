import 'package:flutter/material.dart';

enum MissedWorkoutRescheduleChoice { today, tomorrow }

class MissedWorkoutRescheduleDialog extends StatelessWidget {
  const MissedWorkoutRescheduleDialog({
    super.key,
    required this.title,
    required this.message,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.dismissLabel,
  });

  final String title;
  final String message;
  final String todayLabel;
  final String tomorrowLabel;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const ValueKey('missed_workout_reschedule_dialog'),
      icon: Icon(Icons.event_repeat_rounded, color: colors.primary, size: 34),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const ValueKey('missed_workout_dismiss'),
          onPressed: () => Navigator.pop(context),
          child: Text(dismissLabel),
        ),
        OutlinedButton(
          key: const ValueKey('missed_workout_tomorrow'),
          onPressed: () =>
              Navigator.pop(context, MissedWorkoutRescheduleChoice.tomorrow),
          child: Text(tomorrowLabel),
        ),
        FilledButton(
          key: const ValueKey('missed_workout_today'),
          onPressed: () =>
              Navigator.pop(context, MissedWorkoutRescheduleChoice.today),
          child: Text(todayLabel),
        ),
      ],
    );
  }
}
