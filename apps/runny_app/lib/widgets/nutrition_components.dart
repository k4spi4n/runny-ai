import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/nutrition_models.dart';
import '../models/weight_models.dart';
import '../services/weight_service.dart';
import '../pages/weight_tracking_page.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

class NutritionOverviewCard extends StatelessWidget {
  final DailyNutritionSummary summary;
  final VoidCallback? onEditGoal;

  const NutritionOverviewCard({
    super.key,
    required this.summary,
    this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;

    return glassCard(
      context: context,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('daily_goal'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${summary.caloriesIn.toInt()} / ${summary.goal.dailyCalories.toInt()} kcal',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (onEditGoal != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(LucideIcons.pen_line, size: 19),
                            tooltip: l10n.translate('edit_nutrition_goal'),
                            onPressed: onEditGoal,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildCircularProgress(context),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                l10n.translate('calories_in'),
                summary.caloriesIn.toInt().toString(),
                AppTheme.primary,
              ),
              _buildStatItem(
                context,
                l10n.translate('calories_burned_running'),
                summary.caloriesOut.toInt().toString(),
                AppTheme.secondary,
              ),
              _buildStatItem(
                context,
                summary.isOverCalories
                    ? l10n.translate('calories_over')
                    : l10n.translate('calories_left'),
                (summary.isOverCalories
                        ? summary.caloriesOver
                        : summary.caloriesRemaining)
                    .toInt()
                    .toString(),
                summary.isOverCalories ? AppTheme.error : AppTheme.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(BuildContext context) {
    return SizedBox(
      height: 80,
      width: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: summary.calorieCompletion,
            strokeWidth: 10,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              summary.isOverCalories ? AppTheme.error : AppTheme.primary,
            ),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              summary.isOverCalories
                  ? '${(summary.caloriesOver).toInt()}+'
                  : '${(summary.calorieCompletion * 100).toInt()}%',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class MacroTrackingCard extends StatelessWidget {
  final DailyNutritionSummary summary;

  const MacroTrackingCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context;

    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('macros'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          _buildMacroBar(
            context,
            l10n.translate('protein'),
            summary.protein,
            summary.goal.targetProteinGrams,
            AppTheme.primary,
          ),
          const SizedBox(height: 16),
          _buildMacroBar(
            context,
            l10n.translate('carbs'),
            summary.carbs,
            summary.goal.targetCarbsGrams,
            AppTheme.secondary,
          ),
          const SizedBox(height: 16),
          _buildMacroBar(
            context,
            l10n.translate('fat'),
            summary.fat,
            summary.goal.targetFatGrams,
            AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(
    BuildContext context,
    String label,
    double current,
    double target,
    Color color,
  ) {
    final isOver = current > target;
    final progress = (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${current.toInt()}g / ${target.toInt()}g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? AppTheme.error : color,
            ),
          ),
        ),
      ],
    );
  }
}

class MealSection extends StatelessWidget {
  final String title;
  final List<MealLog> logs;
  final VoidCallback onAdd;
  final VoidCallback onAISuggest;
  final ValueChanged<MealLog> onEdit;
  final ValueChanged<MealLog> onDelete;

  const MealSection({
    super.key,
    required this.title,
    required this.logs,
    required this.onAdd,
    required this.onAISuggest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final statusColor = isDark
        ? AppTheme.darkTextSecondary.withValues(alpha: 0.62)
        : AppTheme.lightTextSecondary.withValues(alpha: 0.82);
    final aiButtonColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFFFF3D7);
    final addButtonColor = isDark
        ? AppTheme.primary.withValues(alpha: 0.14)
        : const Color(0xFFFFE7D8);
    final aiIconColor = isDark ? AppTheme.warning : const Color(0xFFE89A00);
    final sectionFill = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.white.withValues(alpha: 0.82);
    final sectionBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.lightBorder.withValues(alpha: 0.95);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: sectionFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sectionBorder, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    if (logs.isEmpty) ...[
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          context.translate('no_items_logged'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onAISuggest,
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: aiButtonColor,
                      foregroundColor: aiIconColor,
                      fixedSize: const Size(40, 40),
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.translate('ai_meal_suggestions'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: addButtonColor,
                      foregroundColor: AppTheme.primary,
                      fixedSize: const Size(40, 40),
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.translate('add_food'),
                  ),
                ],
              ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...logs.map(
              (log) => _buildMealTile(
                context,
                log,
                onEdit: () => onEdit(log),
                onDelete: () => onDelete(log),
              ),
            ),
          ] else
            const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildMealTile(
    BuildContext context,
    MealLog log, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.foodName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.amount} ${log.unit} - ${log.protein.toInt()}g P - ${log.carbs.toInt()}g C - ${log.fat.toInt()}g F',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${log.calories.toInt()} kcal',
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_MealLogAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: context.translate('meal_actions'),
            onSelected: (action) {
              switch (action) {
                case _MealLogAction.edit:
                  onEdit();
                  break;
                case _MealLogAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MealLogAction.edit,
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(context.translate('edit')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MealLogAction.delete,
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.translate('delete'),
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MealLogAction { edit, delete }

/// Thẻ tóm tắt "Quản lý cân nặng" nhúng trong trang Dinh dưỡng: hiển thị cân
/// nặng hiện tại + tiến trình mục tiêu ở dạng gọn, kèm nút mở màn hình
/// [WeightTrackingPage] đầy đủ. Tự tải lại dữ liệu khi quay về từ màn hình đó.
class WeightSummaryCard extends StatefulWidget {
  const WeightSummaryCard({super.key});

  @override
  State<WeightSummaryCard> createState() => _WeightSummaryCardState();
}

class _WeightSummaryCardState extends State<WeightSummaryCard> {
  final WeightService _service = WeightService();
  WeightGoal? _goal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final goal = await _service.fetchGoal();
      if (mounted) {
        setState(() {
          _goal = goal;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFull() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeightTrackingPage()),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = _goal;

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monitor_weight,
                  color: AppTheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.translate('weight_management'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openFull,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.translate('view_full')),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (goal == null || goal.current == null)
            _buildNoData(context)
          else
            _buildSummary(context, goal),
        ],
      ),
    );
  }

  Widget _buildNoData(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.translate('weight_no_data'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WeightGoal goal) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${goal.current!.toStringAsFixed(1)} kg',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.translate('current_weight'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (goal.hasGoal)
              Text(
                '${context.translate('target_weight_short')}: ${goal.target!.toStringAsFixed(1)} kg',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (goal.hasGoal) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress == 0 ? 0.02 : goal.progress,
              minHeight: 8,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.secondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal.reached
                ? context.translate('goal_reached')
                : context.translate('weight_remaining', [
                    goal.remaining.toStringAsFixed(1),
                    goal.isLosing
                        ? context.translate('lose_weight')
                        : context.translate('gain_weight'),
                  ]),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            context.translate('weight_goal_empty_desc'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
