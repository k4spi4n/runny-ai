import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nutrition_service.dart';
import '../widgets/nutrition_components.dart';
import '../models/nutrition_models.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final nutritionService = context.watch<NutritionService>();
    final summary = nutritionService.getDailySummary(_selectedDate);
    final l10n = context;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('nutrition')),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            NutritionOverviewCard(summary: summary),
            const SizedBox(height: 16),
            MacroTrackingCard(summary: summary),
            const SizedBox(height: 24),
            MealSection(
              title: l10n.translate('breakfast'),
              logs: nutritionService.getLogsForMealType(MealType.breakfast, _selectedDate),
              onAdd: () => _showAddFoodModal(context, MealType.breakfast),
            ),
            MealSection(
              title: l10n.translate('lunch'),
              logs: nutritionService.getLogsForMealType(MealType.lunch, _selectedDate),
              onAdd: () => _showAddFoodModal(context, MealType.lunch),
            ),
            MealSection(
              title: l10n.translate('dinner'),
              logs: nutritionService.getLogsForMealType(MealType.dinner, _selectedDate),
              onAdd: () => _showAddFoodModal(context, MealType.dinner),
            ),
            MealSection(
              title: l10n.translate('snack'),
              logs: nutritionService.getLogsForMealType(MealType.snack, _selectedDate),
              onAdd: () => _showAddFoodModal(context, MealType.snack),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddFoodModal(BuildContext context, MealType mealType) {
    // For now, just a quick add mock
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddFoodQuickView(mealType: mealType),
    );
  }
}

class _AddFoodQuickView extends StatelessWidget {
  final MealType mealType;

  const _AddFoodQuickView({required this.mealType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;

    return Container(
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
            '${l10n.translate('add_food')} - ${l10n.translate(mealType.name)}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: l10n.translate('search_food'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('recent_foods'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildQuickItem(context, 'Banana', '105 kcal'),
          _buildQuickItem(context, 'Chicken Breast (100g)', '165 kcal'),
          _buildQuickItem(context, 'Brown Rice (1 cup)', '216 kcal'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l10n.translate('quick_add')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickItem(BuildContext context, String name, String cal) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name),
      subtitle: Text(cal),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () {
        // Logic to add item
        final nutritionService = context.read<NutritionService>();
        nutritionService.addMealLog(MealLog(
          userId: 'user-123',
          foodName: name,
          calories: double.parse(cal.split(' ')[0]),
          protein: 10, // Mocked
          carbs: 20,   // Mocked
          fat: 5,      // Mocked
          amount: 1,
          unit: 'serving',
          mealType: mealType,
          consumedAt: DateTime.now(),
        ));
        Navigator.pop(context);
      },
    );
  }
}
