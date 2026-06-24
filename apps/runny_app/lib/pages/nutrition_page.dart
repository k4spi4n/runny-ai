import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import '../widgets/food_recognition_panel.dart';
import '../widgets/nutrition_components.dart';
import '../models/nutrition_models.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import '../services/gemini_service.dart';
import '../widgets/ui_components.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

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
      appBar: AppBar(
        title: Text(l10n.translate('nutrition'), style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: colorScheme.onSurface),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
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
                    onAISuggest: () => _showAISuggestionsModal(context, MealType.breakfast, summary),
                  ),
                  MealSection(
                    title: l10n.translate('lunch'),
                    logs: nutritionService.getLogsForMealType(MealType.lunch, _selectedDate),
                    onAdd: () => _showAddFoodModal(context, MealType.lunch),
                    onAISuggest: () => _showAISuggestionsModal(context, MealType.lunch, summary),
                  ),
                  MealSection(
                    title: l10n.translate('dinner'),
                    logs: nutritionService.getLogsForMealType(MealType.dinner, _selectedDate),
                    onAdd: () => _showAddFoodModal(context, MealType.dinner),
                    onAISuggest: () => _showAISuggestionsModal(context, MealType.dinner, summary),
                  ),
                  MealSection(
                    title: l10n.translate('snack'),
                    logs: nutritionService.getLogsForMealType(MealType.snack, _selectedDate),
                    onAdd: () => _showAddFoodModal(context, MealType.snack),
                    onAISuggest: () => _showAISuggestionsModal(context, MealType.snack, summary),
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
      builder: (context) => _AddFoodQuickView(
        mealType: mealType,
        selectedDate: _selectedDate,
      ),
    );
  }

  void _showAISuggestionsModal(BuildContext context, MealType mealType, DailyNutritionSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AISuggestionsView(
        mealType: mealType,
        summary: summary,
      ),
    );
  }
}

enum _AddFoodMode { manual, image }

class _AddFoodQuickView extends StatefulWidget {
  final MealType mealType;
  final DateTime selectedDate;

  const _AddFoodQuickView({
    required this.mealType,
    required this.selectedDate,
  });

  @override
  State<_AddFoodQuickView> createState() => _AddFoodQuickViewState();
}

class _AddFoodQuickViewState extends State<_AddFoodQuickView> {
  _AddFoodMode _mode = _AddFoodMode.manual;

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
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_AddFoodMode>(
              segments: const [
                ButtonSegment(
                  value: _AddFoodMode.manual,
                  icon: Icon(Icons.edit_note),
                  label: Text('Thủ công'),
                ),
                ButtonSegment(
                  value: _AddFoodMode.image,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Ảnh AI'),
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
            else
              FoodRecognitionPanel(
                mealType: widget.mealType,
                consumedAt: _consumedAtForSelectedDate(),
                onSave: _saveRecognizedMeal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: GradientButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('quick_add')),
          ),
        ),
      ],
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
          userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          foodName: name,
          calories: double.parse(cal.split(' ')[0]),
          protein: 10, // Mocked
          carbs: 20,   // Mocked
          fat: 5,      // Mocked
          amount: 1,
          unit: 'serving',
          mealType: widget.mealType,
          consumedAt: _consumedAtForSelectedDate(),
        ));
        Navigator.pop(context);
      },
    );
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

    await nutritionService.addMealLog(log);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${log.foodName}" vào nhật ký ăn uống.'),
        backgroundColor: Colors.green,
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _AISuggestionsView extends StatefulWidget {
  final MealType mealType;
  final DailyNutritionSummary summary;

  const _AISuggestionsView({
    required this.mealType,
    required this.summary,
  });

  @override
  State<_AISuggestionsView> createState() => _AISuggestionsViewState();
}

class _AISuggestionsViewState extends State<_AISuggestionsView> {
  final GeminiService _geminiService = GeminiService();
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
      final mealNameVi = widget.mealType == MealType.breakfast
          ? 'Bữa sáng'
          : widget.mealType == MealType.lunch
              ? 'Bữa trưa'
              : widget.mealType == MealType.dinner
                  ? 'Bữa tối'
                  : 'Bữa phụ';

      final prompt = """
      Act as a professional sports nutritionist and AI diet coach. 
      Suggest exactly 3 healthy, clean food options for a runner's $mealNameVi meal.
      The user's daily goals and current progress:
      - Daily target calories: ${widget.summary.goal.dailyCalories} kcal
      - Calories consumed so far: ${widget.summary.caloriesIn} kcal
      - Calories burned through exercise: ${widget.summary.caloriesOut} kcal
      - Current protein: ${widget.summary.protein.toStringAsFixed(1)}g (target: ${widget.summary.goal.targetProteinGrams.toStringAsFixed(1)}g)
      - Current carbs: ${widget.summary.carbs.toStringAsFixed(1)}g (target: ${widget.summary.goal.targetCarbsGrams.toStringAsFixed(1)}g)
      - Current fat: ${widget.summary.fat.toStringAsFixed(1)}g (target: ${widget.summary.goal.targetFatGrams.toStringAsFixed(1)}g)

      Suggest foods that balance the remaining macros. 
      Return the response in a raw JSON array format (do not include any markdown styling like ```json or other conversational text). Each item in the array MUST contain:
      "foodName": String (in Vietnamese, user-friendly, e.g. "Cháo yến mạch và ức gà")
      "calories": double/int (kcal)
      "protein": double/int (g)
      "carbs": double/int (g)
      "fat": double/int (g)
      "amount": double/int (amount size)
      "unit": String (e.g. "bát", "đĩa", "ly", "quả")

      Format:
      [
        {
          "foodName": "...",
          "calories": 350,
          "protein": 15,
          "carbs": 45,
          "fat": 8,
          "amount": 1,
          "unit": "bát"
        }
      ]
      """;

      final response = await _geminiService.generateResponse(prompt);
      
      // Clean up markdown markers if any
      var cleanResponse = response.trim();
      if (cleanResponse.startsWith('```')) {
        final lines = cleanResponse.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleanResponse = lines.join('\n').trim();
      }

      final decoded = json.decode(cleanResponse);
      if (decoded is List) {
        if (mounted) {
          setState(() {
            _suggestions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        throw const FormatException('Response is not a JSON list');
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
    try {
      final log = MealLog(
        userId: Supabase.instance.client.auth.currentUser?.id ?? '',
        foodName: suggestion['foodName'] ?? 'Gợi ý AI',
        calories: (suggestion['calories'] as num).toDouble(),
        protein: (suggestion['protein'] as num).toDouble(),
        carbs: (suggestion['carbs'] as num).toDouble(),
        fat: (suggestion['fat'] as num).toDouble(),
        amount: (suggestion['amount'] as num).toDouble(),
        unit: suggestion['unit'] ?? 'phần',
        mealType: widget.mealType,
        consumedAt: DateTime.now(),
      );

      await nutritionService.addMealLog(log);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã thêm "${log.foodName}" vào thực đơn!'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
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

    final mealNameVi = widget.mealType == MealType.breakfast
        ? 'Bữa sáng'
        : widget.mealType == MealType.lunch
            ? 'Bữa trưa'
            : widget.mealType == MealType.dinner
                ? 'Bữa tối'
                : 'Bữa phụ';

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
                        'AI Gợi ý $mealNameVi',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                    'AI đang tính toán lượng calories và dinh dưỡng tối ưu...',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Không thể tải gợi ý. Vui lòng kiểm tra lại kết nối hoặc API Key.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchSuggestions,
                    style: primaryActionButton(context),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ..._suggestions.map((suggestion) {
                  final calories = (suggestion['calories'] as num).toStringAsFixed(0);
                  final protein = (suggestion['protein'] as num).toStringAsFixed(0);
                  final carbs = (suggestion['carbs'] as num).toStringAsFixed(0);
                  final fat = (suggestion['fat'] as num).toStringAsFixed(0);
                  final foodName = suggestion['foodName'] ?? 'Không rõ';
                  final amount = (suggestion['amount'] as num).toStringAsFixed(0);
                  final unit = suggestion['unit'] ?? 'phần';

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
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Khẩu phần: $amount $unit',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMacroMiniBadge('Đạm', '${protein}g', Colors.redAccent),
                              _buildMacroMiniBadge('Carbs', '${carbs}g', Colors.blueAccent),
                              _buildMacroMiniBadge('Chất béo', '${fat}g', Colors.orangeAccent),
                              IconButton(
                                onPressed: () => _addSuggestedMeal(suggestion),
                                icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 28),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Thêm vào nhật ký',
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
