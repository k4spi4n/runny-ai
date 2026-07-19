import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import '../widgets/food_recognition_panel.dart';
import '../widgets/nutrition_components.dart';
import '../widgets/nutrition_goal_sheet.dart';
import '../models/nutrition_models.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/ai_request_builder.dart';
import '../services/ai_service.dart';
import '../widgets/ui_components.dart';
import '../utils/date_time_utils.dart';

class NutritionPage extends StatefulWidget {
  /// [embedded] = true khi hiển thị bên trong khung tab của Dashboard: bỏ nền
  /// gradient riêng (Dashboard đã vẽ gradient toàn màn) để không tạo ra "box"
  /// hình chữ nhật lệch màu, đồng bộ với các tab còn lại.
  final bool embedded;

  const NutritionPage({super.key, this.embedded = false});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NutritionService>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nutritionService = context.watch<NutritionService>();
    final summary = nutritionService.getDailySummary(_selectedDate);
    final l10n = context;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: AppBar(
        title: Text(
          l10n.translate('nutrition'),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.calendar_today, color: colorScheme.onSurface),
            label: Text(
              _formatSelectedDate(),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onPressed: () => _selectDate(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!widget.embedded)
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: sportPlatformGradient(context),
                ),
              ),
            ),
          if (nutritionService.isLoading && nutritionService.logs.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            SafeArea(
              child: RefreshIndicator(
                onRefresh: () => nutritionService.refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.embedded
                        ? 0.0
                        : (MediaQuery.of(context).size.width > 900
                              ? 20.0
                              : 16.0),
                    vertical: 16.0,
                  ),
                  child: Column(
                    children: [
                      NutritionOverviewCard(
                        summary: summary,
                        selectedDate: _selectedDate,
                        onEditGoal: () => _showNutritionGoalSheet(
                          context,
                          nutritionService,
                          summary.goal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MacroTrackingCard(summary: summary),
                      const SizedBox(height: 16),
                      const WeightSummaryCard(),
                      const SizedBox(height: 24),
                      MealSection(
                        title: l10n.translate('breakfast'),
                        logs: nutritionService.getLogsForMealType(
                          MealType.breakfast,
                          _selectedDate,
                        ),
                        onAdd: () =>
                            _showAddFoodModal(context, MealType.breakfast),
                        onAISuggest: () => _showAISuggestionsModal(
                          context,
                          MealType.breakfast,
                          summary,
                          _selectedDate,
                        ),
                        onEdit: (log) => _showEditMealLogModal(context, log),
                        onDelete: (log) => _confirmDeleteMealLog(context, log),
                      ),
                      MealSection(
                        title: l10n.translate('lunch'),
                        logs: nutritionService.getLogsForMealType(
                          MealType.lunch,
                          _selectedDate,
                        ),
                        onAdd: () => _showAddFoodModal(context, MealType.lunch),
                        onAISuggest: () => _showAISuggestionsModal(
                          context,
                          MealType.lunch,
                          summary,
                          _selectedDate,
                        ),
                        onEdit: (log) => _showEditMealLogModal(context, log),
                        onDelete: (log) => _confirmDeleteMealLog(context, log),
                      ),
                      MealSection(
                        title: l10n.translate('dinner'),
                        logs: nutritionService.getLogsForMealType(
                          MealType.dinner,
                          _selectedDate,
                        ),
                        onAdd: () =>
                            _showAddFoodModal(context, MealType.dinner),
                        onAISuggest: () => _showAISuggestionsModal(
                          context,
                          MealType.dinner,
                          summary,
                          _selectedDate,
                        ),
                        onEdit: (log) => _showEditMealLogModal(context, log),
                        onDelete: (log) => _confirmDeleteMealLog(context, log),
                      ),
                      MealSection(
                        title: l10n.translate('snack'),
                        logs: nutritionService.getLogsForMealType(
                          MealType.snack,
                          _selectedDate,
                        ),
                        onAdd: () => _showAddFoodModal(context, MealType.snack),
                        onAISuggest: () => _showAISuggestionsModal(
                          context,
                          MealType.snack,
                          summary,
                          _selectedDate,
                        ),
                        onEdit: (log) => _showEditMealLogModal(context, log),
                        onDelete: (log) => _confirmDeleteMealLog(context, log),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatSelectedDate() {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    return '$day/$month/${_selectedDate.year}';
  }

  void _showAddFoodModal(BuildContext context, MealType mealType) {
    // For now, just a quick add mock
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _AddFoodQuickView(mealType: mealType, selectedDate: _selectedDate),
    );
  }

  void _showEditMealLogModal(BuildContext context, MealLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditMealLogView(log: log),
    );
  }

  Future<void> _confirmDeleteMealLog(BuildContext context, MealLog log) async {
    if (log.id == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.translate('delete_food_title')),
        content: Text(
          context.translate('delete_food_confirmation', [log.foodName]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.translate('delete')),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<NutritionService>().deleteMealLog(log.id!);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.translate('meal_deleted'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $error')),
        );
      }
    }
  }

  void _showAISuggestionsModal(
    BuildContext context,
    MealType mealType,
    DailyNutritionSummary summary,
    DateTime selectedDate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AISuggestionsView(
        mealType: mealType,
        summary: summary,
        selectedDate: selectedDate,
      ),
    );
  }

  void _showNutritionGoalSheet(
    BuildContext context,
    NutritionService nutritionService,
    NutritionGoal goal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => NutritionGoalSheet(
        goal: goal,
        weightKg: nutritionService.currentWeightKg,
        targetWeightKg: nutritionService.targetWeightKg,
        onSave: nutritionService.setGoal,
      ),
    );
  }
}

enum _AddFoodMode { manual, image }

class _AddFoodQuickView extends StatefulWidget {
  final MealType mealType;
  final DateTime selectedDate;

  const _AddFoodQuickView({required this.mealType, required this.selectedDate});

  @override
  State<_AddFoodQuickView> createState() => _AddFoodQuickViewState();
}

class _AddFoodQuickViewState extends State<_AddFoodQuickView> {
  _AddFoodMode _mode = _AddFoodMode.manual;

  final _nameCtrl = TextEditingController();
  final _customNameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customNameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.translate('add_food')} - ${l10n.translate(widget.mealType.name)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_AddFoodMode>(
              segments: [
                ButtonSegment(
                  value: _AddFoodMode.manual,
                  icon: const Icon(Icons.edit_note),
                  label: Text(l10n.translate('manual_entry')),
                ),
                ButtonSegment(
                  value: _AddFoodMode.image,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(l10n.translate('ai_photo')),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            if (_mode == _AddFoodMode.manual)
              _buildManualEntry(context)
            else ...[
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('ai_photo_hint'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FoodRecognitionPanel(
                mealType: widget.mealType,
                consumedAt: _consumedAtForSelectedDate(),
                onSave: _saveRecognizedMeal,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;
    final nutritionService = context.watch<NutritionService>();

    final query = _nameCtrl.text.trim().toLowerCase();
    final recent = nutritionService.recentDistinctFoods
        .where((f) => query.isEmpty || f.foodName.toLowerCase().contains(query))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.translate('search_food'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (recent.isNotEmpty) ...[
          Text(
            l10n.translate('recent_foods'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...recent.map((f) => _buildRecentItem(context, f)),
          const SizedBox(height: 20),
        ],
        Text(
          l10n.translate('custom_food'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customNameCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            label: Text.rich(
              TextSpan(
                text: l10n.translate('food_name'),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            prefixIcon: const Icon(Icons.restaurant_menu),
          ),
        ),
        const SizedBox(height: 12),
        _numberField(
          _caloriesCtrl,
          '${l10n.translate('calories')} (kcal)',
          isRequired: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _numberField(
                _proteinCtrl,
                '${l10n.translate('protein')} (g)',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberField(_carbsCtrl, '${l10n.translate('carbs')} (g)'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberField(_fatCtrl, '${l10n.translate('fat')} (g)'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            onPressed: _addCustomFood,
            child: Text(l10n.translate('add_food')),
          ),
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        label: isRequired
            ? Text.rich(
                TextSpan(
                  text: label,
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        labelText: isRequired ? null : label,
      ),
    );
  }

  /// Một món đã từng ăn — nhấn để thêm nhanh với đúng thông số dinh dưỡng cũ.
  Widget _buildRecentItem(BuildContext context, MealLog food) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(Icons.restaurant, color: colorScheme.primary, size: 20),
      ),
      title: Text(food.foodName),
      subtitle: Text(
        '${food.calories.toStringAsFixed(0)} kcal • '
        'P ${food.protein.toStringAsFixed(0)} · '
        'C ${food.carbs.toStringAsFixed(0)} · '
        'F ${food.fat.toStringAsFixed(0)}',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Icon(Icons.add_circle, color: colorScheme.primary),
      onTap: () => _addExistingFood(food),
    );
  }

  Future<void> _addExistingFood(MealLog source) async {
    final nutritionService = context.read<NutritionService>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.translate('meal_added_log', [
      source.foodName,
    ]);
    final errorPrefix = context.translate('error');
    try {
      await nutritionService.addMealLog(
        MealLog(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          foodName: source.foodName,
          calories: source.calories,
          protein: source.protein,
          carbs: source.carbs,
          fat: source.fat,
          amount: source.amount,
          unit: source.unit,
          mealType: widget.mealType,
          consumedAt: _consumedAtForSelectedDate(),
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _addCustomFood() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _customNameCtrl.text.trim();
    final calories = double.tryParse(
      _caloriesCtrl.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || calories == null || calories <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.translate('food_entry_required')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    double parse(TextEditingController c, [double fallback = 0]) =>
        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

    // Bỏ trường số lượng/đơn vị ở form tự chọn -> dùng mặc định 1 phần.
    final unit = context.translate('portion').toLowerCase();

    final nutritionService = context.read<NutritionService>();
    final successMessage = context.translate('meal_added_log', [name]);
    final errorPrefix = context.translate('error');
    try {
      await nutritionService.addMealLog(
        MealLog(
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          foodName: name,
          calories: calories,
          protein: parse(_proteinCtrl),
          carbs: parse(_carbsCtrl),
          fat: parse(_fatCtrl),
          amount: 1,
          unit: unit,
          mealType: widget.mealType,
          consumedAt: _consumedAtForSelectedDate(),
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  DateTime _consumedAtForSelectedDate() {
    final now = DateTime.now();
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  Future<void> _saveRecognizedMeal(MealLog log) async {
    final nutritionService = context.read<NutritionService>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.translate('meal_added_log', [log.foodName]);

    await nutritionService.addMealLog(log);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _EditMealLogView extends StatefulWidget {
  final MealLog log;

  const _EditMealLogView({required this.log});

  @override
  State<_EditMealLogView> createState() => _EditMealLogViewState();
}

class _EditMealLogViewState extends State<_EditMealLogView> {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late MealType _mealType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _name = TextEditingController(text: log.foodName);
    _calories = TextEditingController(text: _format(log.calories));
    _protein = TextEditingController(text: _format(log.protein));
    _carbs = TextEditingController(text: _format(log.carbs));
    _fat = TextEditingController(text: _format(log.fat));
    _amount = TextEditingController(text: _format(log.amount));
    _unit = TextEditingController(text: log.unit);
    _mealType = log.mealType;
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _amount.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = _number(_calories);
    final protein = _number(_protein);
    final carbs = _number(_carbs);
    final fat = _number(_fat);
    final amount = _number(_amount);
    final name = _name.text.trim();
    final unit = _unit.text.trim();
    if (name.isEmpty ||
        unit.isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        amount == null ||
        calories <= 0 ||
        protein < 0 ||
        carbs < 0 ||
        fat < 0 ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('food_edit_invalid'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<NutritionService>().updateMealLog(
        MealLog(
          id: widget.log.id,
          userId: widget.log.userId,
          foodName: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          amount: amount,
          unit: unit,
          mealType: _mealType,
          consumedAt: widget.log.consumedAt,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('meal_updated'))),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('edit_food'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            _field(_name, l10n.translate('food_name'), text: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<MealType>(
              initialValue: _mealType,
              decoration: InputDecoration(
                labelText: l10n.translate('meal_type'),
                border: const OutlineInputBorder(),
              ),
              items: MealType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(l10n.translate(type.name)),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (type) {
                      if (type != null) setState(() => _mealType = type);
                    },
            ),
            const SizedBox(height: 12),
            _field(_calories, '${l10n.translate('calories')} (kcal)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(_protein, '${l10n.translate('protein')} (g)'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(_carbs, '${l10n.translate('carbs')} (g)'),
                ),
                const SizedBox(width: 8),
                Expanded(child: _field(_fat, '${l10n.translate('fat')} (g)')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_amount, l10n.translate('amount'))),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(_unit, l10n.translate('unit'), text: true),
                ),
              ],
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
                    : Text(l10n.translate('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool text = false,
  }) => TextField(
    controller: controller,
    keyboardType: text
        ? TextInputType.text
        : const TextInputType.numberWithOptions(decimal: true),
    textCapitalization: text
        ? TextCapitalization.sentences
        : TextCapitalization.none,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _AISuggestionsView extends StatefulWidget {
  final MealType mealType;
  final DailyNutritionSummary summary;
  final DateTime selectedDate;

  const _AISuggestionsView({
    required this.mealType,
    required this.summary,
    required this.selectedDate,
  });

  @override
  State<_AISuggestionsView> createState() => _AISuggestionsViewState();
}

class _AISuggestionsViewState extends State<_AISuggestionsView> {
  final AiService _aiService = AiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final goal = widget.summary.goal;
      final inputJson = AiRequestBuilder.nutritionSuggestions(
        locale: Localizations.localeOf(context).languageCode,
        date: widget.selectedDate,
        mealType: widget.mealType.name,
        remainingCalories: widget.summary.caloriesRemaining,
        remainingProtein: goal.targetProteinGrams - widget.summary.protein,
        remainingCarbs: goal.targetCarbsGrams - widget.summary.carbs,
        remainingFat: goal.targetFatGrams - widget.summary.fat,
      );
      final response = await _aiService.generateStructuredResponse(
        inputJson,
        feature: AiFeature.nutritionSuggestions,
      );
      final suggestions = AiStructuredResponseParser.nutritionSuggestions(
        response,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addSuggestedMeal(Map<String, dynamic> suggestion) async {
    final nutritionService = context.read<NutritionService>();
    final messenger = ScaffoldMessenger.of(context);
    final fallbackFoodName = context.translate('ai_suggestion_fallback');
    final defaultUnit = context.translate('portion').toLowerCase();
    final errorPrefix = context.translate('error');
    try {
      final log = MealLog(
        userId: Supabase.instance.client.auth.currentUser?.id ?? '',
        foodName: suggestion['foodName'] ?? fallbackFoodName,
        calories: (suggestion['calories'] as num).toDouble(),
        protein: (suggestion['protein'] as num).toDouble(),
        carbs: (suggestion['carbs'] as num).toDouble(),
        fat: (suggestion['fat'] as num).toDouble(),
        amount: (suggestion['amount'] as num).toDouble(),
        unit: suggestion['unit'] ?? defaultUnit,
        mealType: widget.mealType,
        consumedAt: dateWithTime(widget.selectedDate, DateTime.now()),
      );
      final successMessage = context.translate('meal_added_menu', [
        log.foodName,
      ]);

      await nutritionService.addMealLog(log);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final mealName = context.translate(widget.mealType.name);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1230) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Gợi ý $mealName',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    context.translate('ai_suggestions_loading'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.translate('ai_suggestions_error'),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchSuggestions,
                    style: primaryActionButton(context),
                    child: Text(context.translate('retry')),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ..._suggestions.map((suggestion) {
                  final calories = (suggestion['calories'] as num)
                      .toStringAsFixed(0);
                  final protein = (suggestion['protein'] as num)
                      .toStringAsFixed(0);
                  final carbs = (suggestion['carbs'] as num).toStringAsFixed(0);
                  final fat = (suggestion['fat'] as num).toStringAsFixed(0);
                  final foodName =
                      suggestion['foodName'] ??
                      context.translate('unknown_food');
                  final amount = (suggestion['amount'] as num).toStringAsFixed(
                    0,
                  );
                  final unit =
                      suggestion['unit'] ??
                      context.translate('portion').toLowerCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
                                      foodName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.translate('portion')}: $amount $unit',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$calories kcal',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildMacroMiniBadge(
                                context.translate('protein'),
                                '${protein}g',
                                Colors.redAccent,
                              ),
                              _buildMacroMiniBadge(
                                context.translate('carbs'),
                                '${carbs}g',
                                Colors.blueAccent,
                              ),
                              _buildMacroMiniBadge(
                                context.translate('fat'),
                                '${fat}g',
                                Colors.orangeAccent,
                              ),
                              IconButton(
                                onPressed: () => _addSuggestedMeal(suggestion),
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: AppTheme.primary,
                                  size: 28,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: context.translate('add_to_log'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMacroMiniBadge(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
