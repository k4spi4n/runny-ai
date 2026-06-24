import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_recognition_models.dart';
import '../models/nutrition_models.dart';
import '../services/food_recognition_service.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

class FoodRecognitionPanel extends StatefulWidget {
  final MealType mealType;
  final DateTime consumedAt;
  final Future<void> Function(MealLog log) onSave;

  const FoodRecognitionPanel({
    super.key,
    required this.mealType,
    required this.consumedAt,
    required this.onSave,
  });

  @override
  State<FoodRecognitionPanel> createState() => _FoodRecognitionPanelState();
}

class _FoodRecognitionPanelState extends State<FoodRecognitionPanel> {
  final _service = FoodRecognitionService();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'phần');

  Uint8List? _imageBytes;
  String? _filename;
  FoodRecognitionResult? _result;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _filename = file.name;
        _result = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể tải ảnh. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _captureImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _filename = image.name;
        _result = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể mở camera. Vui lòng thử tải ảnh từ thư viện.';
      });
    }
  }

  Future<void> _analyzeImage() async {
    final bytes = _imageBytes;
    final filename = _filename;
    if (bytes == null || filename == null) {
      setState(() {
        _errorMessage = 'Vui lòng chọn hoặc chụp ảnh món ăn.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.analyzeImage(bytes: bytes, filename: filename);
      if (!mounted) return;
      setState(() {
        _result = result;
        _foodNameController.text = result.foodName;
        _caloriesController.text = result.nutrition.calories.toStringAsFixed(0);
        _proteinController.text = result.nutrition.protein.toStringAsFixed(0);
        _carbsController.text = result.nutrition.carbs.toStringAsFixed(0);
        _fatController.text = result.nutrition.fat.toStringAsFixed(0);
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final log = MealLog(
        userId: Supabase.instance.client.auth.currentUser?.id ?? '',
        foodName: _foodNameController.text.trim(),
        calories: double.parse(_caloriesController.text),
        protein: double.parse(_proteinController.text),
        carbs: double.parse(_carbsController.text),
        fat: double.parse(_fatController.text),
        amount: double.parse(_amountController.text),
        unit: _unitController.text.trim().isEmpty ? 'phần' : _unitController.text.trim(),
        mealType: widget.mealType,
        consumedAt: widget.consumedAt,
      );

      await widget.onSave(log);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể lưu món ăn: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _pickImageFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Tải ảnh'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing || kIsWeb ? null : _captureImage,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Chụp ảnh'),
              ),
            ),
          ],
        ),
        if (_imageBytes != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: _isAnalyzing ? null : _analyzeImage,
            child: _isAnalyzing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Đang phân tích bằng AI...'),
                    ],
                  )
                : const Text('Phân tích bằng AI'),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kết quả nhận dạng',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${(_result!.confidence * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _foodNameController,
                    decoration: const InputDecoration(labelText: 'Tên món ăn dự đoán'),
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(_caloriesController, 'Calories', suffix: 'kcal'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(_proteinController, 'Protein', suffix: 'g'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(_carbsController, 'Carbs', suffix: 'g'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(_fatController, 'Fat', suffix: 'g'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(_amountController, 'Khẩu phần'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(labelText: 'Đơn vị'),
                          validator: _requiredText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveMeal,
                      style: primaryActionButton(context),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Đang lưu...' : 'Xác nhận và lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  TextFormField _numberField(
    TextEditingController controller,
    String label, {
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final parsed = double.tryParse(value ?? '');
        if (parsed == null || parsed < 0) {
          return 'Không hợp lệ';
        }
        return null;
      },
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bắt buộc';
    }
    return null;
  }
}
