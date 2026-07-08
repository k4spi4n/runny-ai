import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/training_service.dart';
import '../widgets/manual_workout_form.dart';
import '../widgets/ui_components.dart';

class ManualWorkoutPage extends StatefulWidget {
  final Map<String, dynamic>? workout;

  const ManualWorkoutPage({super.key, this.workout});

  @override
  State<ManualWorkoutPage> createState() => _ManualWorkoutPageState();
}

class _ManualWorkoutPageState extends State<ManualWorkoutPage> {
  final TrainingService _trainingService = TrainingService();

  bool get _isEditing => widget.workout != null;

  Future<void> _submit(ManualWorkoutFormValue value) async {
    try {
      if (_isEditing) {
        await _trainingService.updateManualWorkout(
          workoutId: widget.workout!['id'] as String,
          input: value.toInput(),
        );
      } else {
        await _trainingService.createManualWorkout(value.toInput());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.translate(
              _isEditing
                  ? 'manual_workout_updated'
                  : 'manual_workout_created',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException &&
        error.code == 'PGRST204' &&
        _isManualWorkoutSchemaColumn(error.message)) {
      return context.translate('manual_workout_schema_missing');
    }
    return '${context.translate('error')}: $error';
  }

  bool _isManualWorkoutSchemaColumn(String message) {
    return message.contains("'source'") ||
        message.contains("'start_time'") ||
        message.contains("'workout_type'");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleKey = _isEditing
        ? 'manual_workout_edit_title'
        : 'manual_workout_create_title';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.translate(titleKey),
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
            ),
          ),
          SafeArea(
            child: ResponsiveContent(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 900 ? 20.0 : 16.0,
                  vertical: 16.0,
                ),
                child: glassCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.translate('manual_workout_subtitle'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ManualWorkoutForm(
                        initialValue: widget.workout == null
                            ? null
                            : ManualWorkoutFormValue.fromWorkout(
                                widget.workout!,
                              ),
                        submitLabel: context.translate(
                          _isEditing
                              ? 'manual_workout_update_btn'
                              : 'manual_workout_save_btn',
                        ),
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
