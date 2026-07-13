import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

/// Trạng thái chờ cho cụm thời tiết/AQI trước khi người dùng cấp quyền vị trí.
class WeatherLocationPlaceholder extends StatelessWidget {
  const WeatherLocationPlaceholder({super.key, this.onRequestLocation});

  final VoidCallback? onRequestLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: context.translate('weather_location_placeholder'),
      child: Column(
        key: const Key('weather-location-placeholder'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.translate('weather_location_placeholder'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.translate('weather_location_permission_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('request-weather-location-button'),
            onPressed: onRequestLocation,
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: Text(context.translate('request_weather_location')),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Weather location permission',
  group: 'Dashboard',
  size: Size(420, 260),
)
Widget weatherLocationPlaceholderPreview() {
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: WeatherLocationPlaceholder(onRequestLocation: () {}),
      ),
    ),
  );
}
