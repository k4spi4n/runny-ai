import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/nutrition_models.dart';

/// Chỉnh mục tiêu nạp năng lượng và macro ở cùng một chỗ. Runner có thể lấy
/// đề xuất theo cân nặng rồi tinh chỉnh từng giá trị trước khi lưu.
class NutritionGoalSheet extends StatefulWidget {
  final NutritionGoal goal;
  final double? weightKg;
  final double? targetWeightKg;
  final Future<void> Function(NutritionGoal goal) onSave;

  const NutritionGoalSheet({
    super.key,
    required this.goal,
    required this.weightKg,
    required this.targetWeightKg,
    required this.onSave,
  });

  @override
  State<NutritionGoalSheet> createState() => _NutritionGoalSheetState();
}

class _NutritionGoalSheetState extends State<NutritionGoalSheet> {
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late NutritionGoalSource _source;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _calories = TextEditingController(
      text: widget.goal.dailyCalories.round().toString(),
    );
    _protein = TextEditingController(
      text: widget.goal.proteinGrams.round().toString(),
    );
    _carbs = TextEditingController(
      text: widget.goal.carbsGrams.round().toString(),
    );
    _fat = TextEditingController(text: widget.goal.fatGrams.round().toString());
    _source = widget.goal.source;
  }

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _applyWeightRecommendation() {
    final weight = widget.weightKg;
    if (weight == null) return;
    final recommendation = NutritionGoalRecommendation.forRunner(
      weightKg: weight,
      targetWeightKg: widget.targetWeightKg,
    );
    setState(() {
      _calories.text = recommendation.dailyCalories.round().toString();
      _protein.text = recommendation.proteinGrams.round().toString();
      _carbs.text = recommendation.carbsGrams.round().toString();
      _fat.text = recommendation.fatGrams.round().toString();
      _source = NutritionGoalSource.weightBased;
    });
  }

  void _markManual() {
    setState(() => _source = NutritionGoalSource.manual);
  }

  Future<void> _save() async {
    final calories = _number(_calories);
    final protein = _number(_protein);
    final carbs = _number(_carbs);
    final fat = _number(_fat);
    if (calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        calories <= 0 ||
        protein <= 0 ||
        carbs <= 0 ||
        fat <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('nutrition_goal_invalid'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        NutritionGoal(
          userId: widget.goal.userId,
          dailyCalories: calories,
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fat,
          source: _source,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('nutrition_goal_save_failed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;
    final macroCalories =
        (_number(_protein) ?? 0) * 4 +
        (_number(_carbs) ?? 0) * 4 +
        (_number(_fat) ?? 0) * 9;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.translate('nutrition_goal_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('nutrition_goal_description'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.weightKg != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_run,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.translate('nutrition_weight_suggestion', [
                              widget.weightKg!.toStringAsFixed(1),
                            ]),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _applyWeightRecommendation,
                          child: Text(l10n.translate('apply_suggestion')),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  l10n.translate('nutrition_weight_missing'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _numberField(
                controller: _calories,
                label: l10n.translate('daily_calorie_target'),
                suffix: 'kcal',
                onChanged: (_) => _markManual(),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.translate('macro_targets'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.translate('macro_target_helper'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _protein,
                      label: l10n.translate('protein'),
                      suffix: 'g',
                      onChanged: (_) => _markManual(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      controller: _carbs,
                      label: l10n.translate('carbs'),
                      suffix: 'g',
                      onChanged: (_) => _markManual(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      controller: _fat,
                      label: l10n.translate('fat'),
                      suffix: 'g',
                      onChanged: (_) => _markManual(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.translate('macro_energy_summary', [
                  macroCalories.round().toString(),
                  (_number(_calories) ?? 0).round().toString(),
                ]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.translate('save_nutrition_goal')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
