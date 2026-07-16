import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../l10n/app_localizations.dart';
import '../models/workout_models.dart';
import '../utils/activity_formatters.dart';

/// Tóm tắt một hoạt động đã gắn với buổi tập, kèm lối tắt mở trang chi tiết.
class LinkedActivityDetails extends StatelessWidget {
  const LinkedActivityDetails({
    super.key,
    required this.activity,
    required this.onOpenDetails,
  });

  final Activity activity;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name =
        activity.name ??
        activity.notes ??
        context.translate('activity_details');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('open_linked_activity_details'),
              tooltip: context.translate('activity_details'),
              onPressed: onOpenDetails,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              icon: Icon(
                LucideIcons.square_arrow_out_up_right,
                color: colorScheme.primary,
                size: 16,
              ),
            ),
          ],
        ),
        Text(
          _summary(context),
          style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _summary(BuildContext context) {
    final pace = activity.distanceKm > 0 && activity.durationMin > 0
        ? '${context.translate('pace')} ${formatPace(activity.durationMin / activity.distanceKm)}'
        : null;
    final parts = <String>[
      '${activity.distanceKm.toStringAsFixed(2)} km',
      formatDurationMinutes(activity.durationMin),
    ];
    if (pace != null) parts.add(pace);
    return parts.join(' • ');
  }
}
