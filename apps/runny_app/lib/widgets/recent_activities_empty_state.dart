import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

/// Hướng dẫn hiển thị khi người dùng chưa có hoạt động chạy bộ nào.
class RecentActivitiesEmptyState extends StatelessWidget {
  const RecentActivitiesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Semantics(
      container: true,
      label: context.translate('recent_activities_empty_semantics'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
          child: RichText(
            key: const Key('recent-activities-empty-state'),
            textAlign: TextAlign.center,
            text: TextSpan(
              style: hintStyle,
              children: [
                TextSpan(
                  text: context.translate('recent_activities_empty_before_icon'),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: colorScheme.primary,
                      semanticLabel: context.translate('import_activity'),
                    ),
                  ),
                ),
                TextSpan(
                  text: context.translate('recent_activities_empty_after_icon'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'No activities yet',
  group: 'Dashboard',
  size: Size(420, 240),
)
Widget recentActivitiesEmptyStatePreview() {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: const Scaffold(body: RecentActivitiesEmptyState()),
  );
}
