import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/workout_models.dart';
import '../services/workout_input_preference.dart';
import '../utils/pace_calculator.dart';
import 'ui_components.dart';

const List<String> workoutTypeOptions = [
  'easy_run',
  'long_run',
  'interval',
  'tempo',
  'recovery',
];

class ManualWorkoutFormValue {
  final String title;
  final DateTime date;
  final TimeOfDay startTime;
  final double targetDurationMin;
  final double targetDistanceKm;
  final double? targetPaceMinPerKm;
  final String workoutType;
  final String? notes;

  const ManualWorkoutFormValue({
    required this.title,
    required this.date,
    required this.startTime,
    required this.targetDurationMin,
    required this.targetDistanceKm,
    this.targetPaceMinPerKm,
    required this.workoutType,
    this.notes,
  });

  factory ManualWorkoutFormValue.fromWorkout(Map<String, dynamic> workout) {
    final date =
        DateTime.tryParse(workout['date']?.toString() ?? '') ?? DateTime.now();
    final time = _parseDbTime(workout['start_time']?.toString());
    final distance = (workout['target_distance_km'] as num?)?.toDouble() ?? 0;
    final duration = (workout['target_duration_min'] as num?)?.toDouble() ?? 0;
    final pace = (workout['target_pace_min_per_km'] as num?)?.toDouble();
    final type = workout['workout_type']?.toString();

    return ManualWorkoutFormValue(
      title: workout['title']?.toString() ?? '',
      date: date,
      startTime: time,
      targetDurationMin: duration,
      targetDistanceKm: distance,
      targetPaceMinPerKm: pace,
      workoutType: workoutTypeOptions.contains(type) ? type! : 'easy_run',
      notes: workout['description']?.toString(),
    );
  }

  ManualWorkoutInput toInput() {
    return ManualWorkoutInput(
      title: title,
      date: date,
      startTime:
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
      targetDurationMin: targetDurationMin,
      targetDistanceKm: targetDistanceKm,
      targetPaceMinPerKm: targetPaceMinPerKm,
      workoutType: workoutType,
      notes: notes,
    );
  }

  static TimeOfDay _parseDbTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const TimeOfDay(hour: 6, minute: 0);
    }
    final parts = value.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 6, minute: 0);
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 6, minute: 0);
    }
    return TimeOfDay(
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
    );
  }
}

class ManualWorkoutForm extends StatefulWidget {
  final ManualWorkoutFormValue? initialValue;
  final String submitLabel;
  final Future<void> Function(ManualWorkoutFormValue value) onSubmit;

  const ManualWorkoutForm({
    super.key,
    this.initialValue,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<ManualWorkoutForm> createState() => _ManualWorkoutFormState();
}

class _ManualWorkoutFormState extends State<ManualWorkoutForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _paceController;
  late final TextEditingController _notesController;

  late DateTime _date;
  late TimeOfDay _startTime;
  late String _workoutType;
  bool _isSubmitting = false;
  bool _usesPace = true;
  bool _hasChangedInputMode = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _durationController = TextEditingController(
      text: _formatInitialNumber(initial?.targetDurationMin),
    );
    _distanceController = TextEditingController(
      text: _formatInitialNumber(initial?.targetDistanceKm),
    );
    _paceController = TextEditingController(
      text: _formatInitialNumber(initial?.targetPaceMinPerKm),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _date = initial?.date ?? DateTime.now();
    _startTime = initial?.startTime ?? const TimeOfDay(hour: 6, minute: 0);
    _workoutType = initial?.workoutType ?? 'easy_run';
    final hasInitialPace = (initial?.targetPaceMinPerKm ?? 0) > 0;
    _usesPace = hasInitialPace || initial == null;
    if (!hasInitialPace) _loadInputModePreference();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _paceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatInitialNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  Future<void> _loadInputModePreference() async {
    final usesPace = await WorkoutInputPreference.loadUsesPace();
    if (mounted && !_hasChangedInputMode) {
      setState(() => _usesPace = usesPace);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.translate('manual_workout_title_required');
    }
    return null;
  }

  String? _requiredNonNegativeNumber(String? value) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';
    final parsed = double.tryParse(normalized);
    if (normalized.isEmpty || parsed == null || parsed.isNaN || parsed < 0) {
      return context.translate('manual_workout_number_invalid');
    }
    return null;
  }

  String? _requiredPositiveNumber(String? value) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';
    final parsed = double.tryParse(normalized);
    if (normalized.isEmpty || parsed == null || parsed.isNaN || parsed <= 0) {
      return context.translate('manual_workout_number_invalid');
    }
    return null;
  }

  double _numberFrom(TextEditingController controller) {
    return double.parse(controller.text.trim().replaceAll(',', '.'));
  }

  Future<void> _togglePaceMode() async {
    final distance = double.tryParse(
      _distanceController.text.trim().replaceAll(',', '.'),
    );
    if (_usesPace) {
      final pace = parsePaceMinutesPerKm(_paceController.text);
      final duration = distance != null && pace != null
          ? durationFromPace(distanceKm: distance, paceMinutesPerKm: pace)
          : null;
      if (duration != null) {
        _durationController.text = duration.toStringAsFixed(2);
      }
    } else {
      final duration = double.tryParse(
        _durationController.text.trim().replaceAll(',', '.'),
      );
      if (distance != null &&
          distance > 0 &&
          duration != null &&
          duration > 0) {
        _paceController.text = (duration / distance).toStringAsFixed(2);
      }
    }
    final usesPace = !_usesPace;
    _hasChangedInputMode = true;
    setState(() => _usesPace = usesPace);
    await WorkoutInputPreference.saveUsesPace(usesPace);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final distance = _numberFrom(_distanceController);
    final pace = parsePaceMinutesPerKm(_paceController.text);
    final duration = _usesPace
        ? durationFromPace(distanceKm: distance, paceMinutesPerKm: pace!)!
        : _numberFrom(_durationController);
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        ManualWorkoutFormValue(
          title: _titleController.text.trim(),
          date: _date,
          startTime: _startTime,
          targetDurationMin: duration,
          targetDistanceKm: distance,
          targetPaceMinPerKm: _usesPace ? pace : null,
          workoutType: _workoutType,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dateText = DateFormat('EEEE, dd/MM/yyyy').format(_date);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('manual_workout_title_field'),
            controller: _titleController,
            enabled: !_isSubmitting,
            decoration: themedInputDecoration(
              context,
              context.translate('manual_workout_title_label'),
              hint: context.translate('manual_workout_title_hint'),
              icon: Icons.edit_note,
              isRequired: true,
            ),
            validator: _requiredText,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 680
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PickerTile(
                    width: tileWidth,
                    icon: Icons.calendar_month,
                    label: context.translate('manual_workout_date_label'),
                    value: dateText,
                    onTap: _isSubmitting ? null : _pickDate,
                  ),
                  _PickerTile(
                    width: tileWidth,
                    icon: Icons.schedule,
                    label: context.translate('manual_workout_start_time_label'),
                    value: _startTime.format(context),
                    onTap: _isSubmitting ? null : _pickTime,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final durationField = _NumberField(
                fieldKey: ValueKey(
                  _usesPace
                      ? 'manual_workout_pace_field'
                      : 'manual_workout_duration_field',
                ),
                controller: _usesPace ? _paceController : _durationController,
                enabled: !_isSubmitting,
                label: _usesPace
                    ? context.translate('pace')
                    : context.translate('manual_workout_duration_label'),
                suffixText: _usesPace
                    ? context.translate('pace_unit')
                    : context.translate('minutes_short'),
                icon: _usesPace ? Icons.speed_outlined : Icons.timer_outlined,
                validator: _usesPace
                    ? (value) => parsePaceMinutesPerKm(value ?? '') == null
                          ? context.translate('manual_workout_pace_invalid')
                          : null
                    : _requiredNonNegativeNumber,
                isDark: isDark,
                keyboardType: _usesPace
                    ? TextInputType.text
                    : const TextInputType.numberWithOptions(decimal: true),
              );
              final durationControl = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: durationField),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('manual_workout_pace_toggle'),
                    onPressed: _isSubmitting ? null : _togglePaceMode,
                    color: colorScheme.primary,
                    tooltip: context.translate(
                      _usesPace
                          ? 'pace_calculation_duration'
                          : 'pace_calculation_pace',
                    ),
                    icon: Icon(
                      _usesPace ? Icons.timer_outlined : Icons.speed_outlined,
                    ),
                  ),
                ],
              );
              final distanceField = _NumberField(
                fieldKey: const ValueKey('manual_workout_distance_field'),
                controller: _distanceController,
                enabled: !_isSubmitting,
                label: context.translate('manual_workout_distance_label'),
                suffixText: 'km',
                icon: Icons.route_outlined,
                validator: _usesPace
                    ? _requiredPositiveNumber
                    : _requiredNonNegativeNumber,
                isDark: isDark,
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    durationControl,
                    const SizedBox(height: 16),
                    distanceField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: durationControl),
                  const SizedBox(width: 12),
                  Expanded(child: distanceField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workoutType,
            decoration: themedInputDecoration(
              context,
              context.translate('manual_workout_type_label'),
              icon: LucideIcons.sport_shoe,
            ),
            dropdownColor: colorScheme.surface,
            items: workoutTypeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(context.translate('workout_type_$type')),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value != null) setState(() => _workoutType = value);
                  },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('manual_workout_notes_field'),
            controller: _notesController,
            enabled: !_isSubmitting,
            maxLines: 4,
            decoration: themedInputDecoration(
              context,
              context.translate('manual_workout_notes_label'),
              hint: context.translate('manual_workout_notes_hint'),
              icon: Icons.notes,
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            style: primaryActionButton(context),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _PickerTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_calendar, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String suffixText;
  final IconData icon;
  final String? Function(String?) validator;
  final bool isDark;
  final TextInputType keyboardType;

  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.label,
    required this.suffixText,
    required this.icon,
    required this.validator,
    required this.isDark,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          RegExp(keyboardType == TextInputType.text ? r'[0-9:.,]' : r'[0-9.,]'),
        ),
      ],
      decoration: themedInputDecoration(
        context,
        label,
        suffixText: suffixText,
        icon: icon,
        isRequired: true,
      ),
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
    );
  }
}
