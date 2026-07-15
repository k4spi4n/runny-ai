import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

class ActivityRecordingGuide extends StatelessWidget {
  const ActivityRecordingGuide({
    super.key,
    required this.onFindActivity,
    required this.onImportActivity,
  });

  final VoidCallback onFindActivity;
  final VoidCallback onImportActivity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = [
      (
        Icons.watch_outlined,
        context.translate('recording_guide_step_record_title'),
        context.translate('recording_guide_step_record_desc'),
      ),
      (
        Icons.save_alt_outlined,
        context.translate('recording_guide_step_sync_title'),
        context.translate('recording_guide_step_sync_desc'),
      ),
      (
        Icons.upload_file_outlined,
        context.translate('recording_guide_step_link_title'),
        context.translate('recording_guide_step_link_desc'),
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.translate('recording_guide_title'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.translate('recording_guide_intro'),
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < steps.length; index++) ...[
              _GuideStep(
                number: index + 1,
                icon: steps[index].$1,
                title: steps[index].$2,
                description: steps[index].$3,
              ),
              if (index != steps.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('recording_guide_find_activity'),
              onPressed: onFindActivity,
              icon: const Icon(Icons.manage_search_outlined),
              label: Text(context.translate('recording_guide_find_activity')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('recording_guide_import_activity'),
              onPressed: onImportActivity,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(context.translate('recording_guide_import_activity')),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(
  name: 'Activity recording guide',
  group: 'Training',
  size: Size(420, 760),
)
Widget activityRecordingGuidePreview() {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: Scaffold(
      body: ActivityRecordingGuide(
        onFindActivity: () {},
        onImportActivity: () {},
      ),
    ),
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final int number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('recording_guide_step_$number'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
