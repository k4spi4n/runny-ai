import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class PostRunReviewCard extends StatelessWidget {
  const PostRunReviewCard({
    super.key,
    required this.workoutTitle,
    this.plannedDistanceKm,
    this.plannedDurationMin,
    required this.actualDistanceKm,
    required this.actualDurationMin,
    required this.selectedRpe,
    required this.savingRpe,
    required this.onRpeSelected,
    required this.onAnalyzeWithAi,
    required this.onOptimizePlan,
  });

  final String workoutTitle;
  final double? plannedDistanceKm;
  final double? plannedDurationMin;
  final double actualDistanceKm;
  final double actualDurationMin;
  final int? selectedRpe;
  final bool savingRpe;
  final ValueChanged<int> onRpeSelected;
  final VoidCallback onAnalyzeWithAi;
  final VoidCallback onOptimizePlan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
            const SizedBox(height: 10),
            Text(
              context.translate('post_run_completed_title'),
              key: const ValueKey('post_run_completed_title'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              workoutTitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _ComparisonRow(
              label: context.translate('distance'),
              planned: plannedDistanceKm == null
                  ? '—'
                  : '${plannedDistanceKm!.toStringAsFixed(1)} km',
              actual: '${actualDistanceKm.toStringAsFixed(2)} km',
            ),
            const SizedBox(height: 10),
            _ComparisonRow(
              label: context.translate('time'),
              planned: plannedDurationMin == null
                  ? '—'
                  : '${plannedDurationMin!.toStringAsFixed(0)} ${context.translate('min')}',
              actual:
                  '${actualDurationMin.toStringAsFixed(0)} ${context.translate('min')}',
            ),
            const SizedBox(height: 20),
            Text(
              context.translate('post_run_rpe_question'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in [2, 4, 6, 8, 10])
                  ChoiceChip(
                    key: ValueKey('post_run_rpe_$value'),
                    label: Text('$value'),
                    selected: selectedRpe == value,
                    onSelected: savingRpe ? null : (_) => onRpeSelected(value),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('post_run_analyze_ai'),
              onPressed: onAnalyzeWithAi,
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.translate('post_run_analyze_ai')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('post_run_optimize_plan'),
              onPressed: onOptimizePlan,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(context.translate('post_run_optimize_plan')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.planned,
    required this.actual,
  });

  final String label;
  final String planned;
  final String actual;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            planned,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16),
          ),
          Text(actual, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
