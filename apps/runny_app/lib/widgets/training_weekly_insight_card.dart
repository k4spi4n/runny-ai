import 'package:flutter/material.dart';

class TrainingWeeklyInsightCard extends StatelessWidget {
  const TrainingWeeklyInsightCard({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.encouragement = false,
  });

  final String title;
  final String message;
  final bool loading;
  final bool encouragement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = encouragement ? const Color(0xFFFF8A3D) : colors.primary;
    return Container(
      key: const ValueKey('training_weekly_ai_insight'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            colors.surfaceContainerHighest.withValues(alpha: 0.48),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.48), width: 0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: loading
                ? SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : Icon(
                    encouragement
                        ? Icons.waving_hand_rounded
                        : Icons.auto_awesome_rounded,
                    color: accent,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
