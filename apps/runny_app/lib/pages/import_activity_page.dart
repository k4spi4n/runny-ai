import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/activity_parser.dart';
import '../utils/manual_activity_namer.dart';
import '../services/activity_screenshot_import_service.dart';
import '../services/image_compress_service.dart';
import '../services/paywall_exception.dart';
import '../services/weather_service.dart';
import '../services/training_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/paywall.dart';
import '../widgets/screenshot_import_guidance.dart';
import '../widgets/ui_components.dart';
import '../models/shoe_models.dart';
import '../models/workout_models.dart';

enum _ImportOutcome { imported, duplicate, failed }

enum _InputMode { file, screenshot, manual }

class ImportActivityPage extends StatefulWidget {
  final String? scheduledWorkoutId;
  const ImportActivityPage({super.key, this.scheduledWorkoutId});

  @override
  State<ImportActivityPage> createState() => _ImportActivityPageState();
}

class _ImportActivityPageState extends State<ImportActivityPage> {
  bool _isLoading = false;
  String? _statusMessage;
  final WeatherService _weatherService = WeatherService();
  final TrainingService _trainingService = TrainingService();
  final ActivityScreenshotImportService _screenshotImportService =
      ActivityScreenshotImportService();
  final ImageCompressService _compressService = ImageCompressService();
  List<Shoe> _activeShoes = [];
  String? _selectedShoeId;
  ScreenshotActivityResult? _screenshotPreview;
  String? _screenshotFilename;

  _InputMode _mode = _InputMode.file;

  // Form nhập thủ công.
  final _manualFormKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _avgHrController = TextEditingController();
  final _avgCadenceController = TextEditingController();
  final _elevationController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _screenshotFormKey = GlobalKey<FormState>();
  final _screenshotNameController = TextEditingController();
  final _screenshotDistanceController = TextEditingController();
  final _screenshotDurationController = TextEditingController();
  final _screenshotAvgHrController = TextEditingController();
  final _screenshotAvgCadenceController = TextEditingController();
  final _screenshotElevationController = TextEditingController();
  final _screenshotNotesController = TextEditingController();
  DateTime _screenshotStartedAt = DateTime.now();
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchActiveShoes();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _avgHrController.dispose();
    _avgCadenceController.dispose();
    _elevationController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    _screenshotNameController.dispose();
    _screenshotDistanceController.dispose();
    _screenshotDurationController.dispose();
    _screenshotAvgHrController.dispose();
    _screenshotAvgCadenceController.dispose();
    _screenshotElevationController.dispose();
    _screenshotNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveShoes() async {
    try {
      final res = await Supabase.instance.client
          .from('shoes')
          .select()
          .eq('is_active', true)
          .order('name');
      final list = (res as List).map((json) => Shoe.fromJson(json)).toList();
      setState(() {
        _activeShoes = list;
        if (list.isNotEmpty) {
          _selectedShoeId = list.first.id;
        }
      });
    } catch (e) {
      debugPrint('Error fetching active shoes: $e');
    }
  }

  Future<void> _pickAndImportFiles() async {
    final l = AppLocalizations.of(context);
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = l?.translate('selecting_file') ?? 'selecting_file';
      });

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'fit', 'tcx'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _statusMessage =
              l?.translate('import_cancelled') ?? 'import_cancelled';
        });
        return;
      }

      int imported = 0;
      int duplicate = 0;
      int failed = 0;
      Activity? firstImportedActivity;
      Activity? mostRecentImportedActivity;

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        setState(() {
          _statusMessage =
              l?.translate('importing_progress', [
                '${i + 1}',
                '${result.files.length}',
              ]) ??
              'importing_progress';
        });

        try {
          final outcome = await _importOne(file, l);
          switch (outcome.$1) {
            case _ImportOutcome.imported:
              imported++;
              final importedActivity = outcome.$2!;
              firstImportedActivity ??= importedActivity;
              // Khi nhập nhiều file, mở buổi có thời điểm chạy mới nhất. Nếu
              // trùng thời điểm, ưu tiên file được nhập sau cùng.
              if (mostRecentImportedActivity == null ||
                  !importedActivity.startedAt.isBefore(
                    mostRecentImportedActivity.startedAt,
                  )) {
                mostRecentImportedActivity = importedActivity;
              }
              break;
            case _ImportOutcome.duplicate:
              duplicate++;
              break;
            case _ImportOutcome.failed:
              failed++;
              break;
          }
        } catch (e) {
          failed++;
          debugPrint('Import file ${file.name} error: $e');
        }
      }

      // Mở từ một buổi tập -> gắn hoạt động đầu tiên nhập được vào buổi tập đó.
      if (widget.scheduledWorkoutId != null && firstImportedActivity != null) {
        await _trainingService.completeScheduledWorkout(
          workoutId: widget.scheduledWorkoutId!,
          activityId: firstImportedActivity.id!,
        );
      }

      setState(() {
        _statusMessage =
            l?.translate('imported_summary', [
              '$imported',
              '$duplicate',
              '$failed',
            ]) ??
            'imported_summary';
      });

      // Chỉ tự đóng khi có ít nhất 1 hoạt động được nhập.
      if (mounted && imported > 0) {
        final activityToOpen = widget.scheduledWorkoutId == null
            ? mostRecentImportedActivity
            : firstImportedActivity;
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted) Navigator.pop(context, activityToOpen);
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            '${l?.translate('import_error') ?? 'import_error'}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAnalyzeScreenshot() async {
    final l = AppLocalizations.of(context);
    try {
      setState(() {
        _isLoading = true;
        _statusMessage =
            l?.translate('selecting_screenshot') ?? 'selecting_screenshot';
      });

      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        setState(() {
          _statusMessage =
              l?.translate('import_cancelled') ?? 'import_cancelled';
        });
        return;
      }

      setState(() {
        _statusMessage = l?.translate('optimizing_image') ?? 'optimizing_image';
      });

      final compressedBytes = await _compressService.compress(
        bytes: bytes,
        filename: file.name,
        maxWidth: 1800,
        quality: 85,
      );

      setState(() {
        _statusMessage =
            l?.translate('analyzing_screenshot') ?? 'analyzing_screenshot';
      });

      final resultFromAi = await _screenshotImportService.analyzeImage(
        bytes: compressedBytes,
        filename: file.name,
      );

      setState(() {
        _screenshotPreview = resultFromAi;
        _screenshotFilename = file.name;
        _screenshotStartedAt = resultFromAi.activity.startedAt;
        _screenshotDistanceController.text = _formatNumber(
          resultFromAi.activity.distanceKm,
        );
        _screenshotDurationController.text = _formatNumber(
          resultFromAi.activity.durationMin,
        );
        _screenshotAvgHrController.text =
            resultFromAi.activity.avgHr?.toString() ?? '';
        _screenshotAvgCadenceController.text =
            resultFromAi.activity.avgCadence?.toString() ?? '';
        _screenshotElevationController.text =
            resultFromAi.activity.elevationGainM != null
            ? _formatNumber(resultFromAi.activity.elevationGainM!)
            : '';
        _screenshotNameController.text = _defaultScreenshotName(file.name, l);
        _screenshotNotesController.text = resultFromAi.notes ?? '';
        _statusMessage =
            l?.translate('screenshot_preview_ready') ??
            'screenshot_preview_ready';
      });
    } on PaywallException catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = null);
      await showUpgradeSheet(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            '${l?.translate('import_error') ?? 'import_error'}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmScreenshotImport() async {
    final l = AppLocalizations.of(context);
    if (!(_screenshotFormKey.currentState?.validate() ?? false)) return;

    final distance = double.tryParse(
      _screenshotDistanceController.text.replaceAll(',', '.'),
    );
    final duration = double.tryParse(
      _screenshotDurationController.text.replaceAll(',', '.'),
    );
    if (distance == null ||
        distance <= 0 ||
        duration == null ||
        duration <= 0) {
      setState(() {
        _statusMessage =
            l?.translate('manual_validation_error') ??
            'manual_validation_error';
      });
      return;
    }

    final avgHr = int.tryParse(_screenshotAvgHrController.text.trim());
    final avgCadence = int.tryParse(
      _screenshotAvgCadenceController.text.trim(),
    );
    final elevation = double.tryParse(
      _screenshotElevationController.text.trim().replaceAll(',', '.'),
    );
    final name = _screenshotNameController.text.trim().isNotEmpty
        ? _screenshotNameController.text.trim()
        : _defaultScreenshotName(_screenshotFilename ?? '', l);
    final notes = _screenshotNotesController.text.trim();

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = l?.translate('saving_to_db') ?? 'saving_to_db';
      });

      final parsed = ParsedActivity(
        startedAt: _screenshotStartedAt,
        distanceKm: distance,
        durationMin: duration,
        avgHr: avgHr != null && avgHr > 0 ? avgHr : null,
        avgCadence: avgCadence != null && avgCadence > 0 ? avgCadence : null,
        elevationGainM: elevation,
      );
      final outcome = await _saveParsedActivity(
        parsed: parsed,
        name: name,
        notes: notes.isEmpty ? null : notes,
      );

      if (outcome.$1 == _ImportOutcome.duplicate) {
        setState(() {
          _statusMessage =
              l?.translate('duplicate_activity_error') ??
              'duplicate_activity_error';
        });
        return;
      }

      if (outcome.$1 != _ImportOutcome.imported || outcome.$2 == null) {
        setState(() {
          _statusMessage =
              l?.translate('screenshot_import_failed') ??
              'screenshot_import_failed';
        });
        return;
      }

      if (widget.scheduledWorkoutId != null) {
        await _trainingService.completeScheduledWorkout(
          workoutId: widget.scheduledWorkoutId!,
          activityId: outcome.$2!.id!,
        );
      }

      setState(() {
        _statusMessage =
            l?.translate('screenshot_import_success') ??
            'screenshot_import_success';
      });

      if (mounted) {
        final importedActivity = outcome.$2!;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pop(context, importedActivity);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            '${l?.translate('import_error') ?? 'import_error'}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Nhập một file. Trả về (kết quả, hoạt động mới nếu có).
  Future<(_ImportOutcome, Activity?)> _importOne(
    PlatformFile file,
    AppLocalizations? l,
  ) async {
    final bytes = file.bytes;
    if (bytes == null) return (_ImportOutcome.failed, null);

    final parsed = await ActivityParser.parse(
      bytes,
      file.extension?.toLowerCase() ?? '',
    );

    return _saveParsedActivity(
      parsed: parsed,
      name: l?.translate('imported_from', [file.name]) ?? 'imported_from',
    );
  }

  Future<(_ImportOutcome, Activity?)> _saveParsedActivity({
    required ParsedActivity parsed,
    required String name,
    String? notes,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final startedIso = parsed.startedAt.toUtc().toIso8601String();

    // Chống trùng: đã có hoạt động cùng thời điểm bắt đầu cho user này.
    final existing = await Supabase.instance.client
        .from('activities')
        .select('id')
        .eq('user_id', uid)
        .eq('started_at', startedIso)
        .maybeSingle();
    if (existing != null) {
      return (_ImportOutcome.duplicate, null);
    }

    WeatherSnapshot? weather;
    if (parsed.startLat != null && parsed.startLon != null) {
      try {
        weather = await _weatherService.fetchWeatherSnapshot(
          lat: parsed.startLat!,
          lon: parsed.startLon!,
        );
      } catch (_) {
        weather = null;
      }
    }

    final res = await Supabase.instance.client
        .from('activities')
        .insert({
          'user_id': uid,
          'started_at': startedIso,
          'distance_km': parsed.distanceKm,
          'duration_min': parsed.durationMin,
          'avg_hr': parsed.avgHr,
          'elevation_gain_m': parsed.elevationGainM,
          'data_points': parsed.dataPoints,
          'start_lat': parsed.startLat,
          'start_lon': parsed.startLon,
          'weather_summary': weather?.summary,
          'temperature_c': weather?.temperatureC,
          'aqi': weather?.aqi,
          'weather_json': weather?.toJson(),
          'weather_fetched_at': weather?.fetchedAt.toIso8601String(),
          'name': name,
          'notes': notes,
          if (_selectedShoeId != null) 'shoe_id': _selectedShoeId,
        })
        .select()
        .single();

    return (
      _ImportOutcome.imported,
      Activity.fromJson(Map<String, dynamic>.from(res)),
    );
  }

  /// Lưu một hoạt động nhập thủ công (không có file/GPS, nên bỏ qua thời tiết).
  Future<void> _saveManual() async {
    final l = AppLocalizations.of(context);
    if (!(_manualFormKey.currentState?.validate() ?? false)) return;

    final distance = double.tryParse(
      _distanceController.text.replaceAll(',', '.'),
    );
    final duration = double.tryParse(
      _durationController.text.replaceAll(',', '.'),
    );
    if (distance == null ||
        distance <= 0 ||
        duration == null ||
        duration <= 0) {
      setState(() {
        _statusMessage =
            l?.translate('manual_validation_error') ??
            'manual_validation_error';
      });
      return;
    }

    final avgHr = int.tryParse(_avgHrController.text.trim());
    final avgCadence = int.tryParse(_avgCadenceController.text.trim());
    final elevation = double.tryParse(
      _elevationController.text.trim().replaceAll(',', '.'),
    );
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();

    try {
      setState(() => _isLoading = true);

      final uid = Supabase.instance.client.auth.currentUser!.id;
      final startedIso = _startedAt.toUtc().toIso8601String();

      // Chống trùng: đã có hoạt động cùng thời điểm bắt đầu cho user này.
      final existing = await Supabase.instance.client
          .from('activities')
          .select('id')
          .eq('user_id', uid)
          .eq('started_at', startedIso)
          .maybeSingle();
      if (existing != null) {
        setState(() {
          _statusMessage =
              l?.translate('duplicate_activity_error') ??
              'duplicate_activity_error';
        });
        return;
      }

      final res = await Supabase.instance.client
          .from('activities')
          .insert({
            'user_id': uid,
            'started_at': startedIso,
            'distance_km': distance,
            'duration_min': duration,
            if (avgHr != null && avgHr > 0) 'avg_hr': avgHr,
            if (avgCadence != null && avgCadence > 0) 'avg_cadence': avgCadence,
            'elevation_gain_m': elevation,
            'name': name.isNotEmpty
                ? name
                : ManualActivityNamer.create(
                    distanceKm: distance,
                    startedAt: _startedAt,
                    titleTemplate:
                        l?.translate('manual_activity_default_name') ??
                        '%s km %s run',
                    morningLabel:
                        l?.translate('manual_activity_time_morning') ??
                        'morning',
                    afternoonLabel:
                        l?.translate('manual_activity_time_afternoon') ??
                        'afternoon',
                    eveningLabel:
                        l?.translate('manual_activity_time_evening') ??
                        'evening',
                  ),
            'notes': notes.isEmpty ? null : notes,
            if (_selectedShoeId != null) 'shoe_id': _selectedShoeId,
          })
          .select()
          .single();

      // Mở từ một buổi tập -> gắn hoạt động vừa lưu vào buổi tập đó.
      if (widget.scheduledWorkoutId != null) {
        await _trainingService.completeScheduledWorkout(
          workoutId: widget.scheduledWorkoutId!,
          activityId: res['id'] as String,
        );
      }

      setState(() {
        _statusMessage = l?.translate('activity_saved') ?? 'activity_saved';
      });

      if (mounted) {
        final importedActivity = Activity.fromJson(
          Map<String, dynamic>.from(res),
        );
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pop(context, importedActivity);
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            '${l?.translate('import_error') ?? 'import_error'}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickStartedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (!mounted) return;
    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _startedAt.hour,
        time?.minute ?? _startedAt.minute,
      );
    });
  }

  Future<void> _pickScreenshotStartedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _screenshotStartedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_screenshotStartedAt),
    );
    if (!mounted) return;
    setState(() {
      _screenshotStartedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _screenshotStartedAt.hour,
        time?.minute ?? _screenshotStartedAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.translate('import_activity'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.of(context).size.width > 900 ? 24.0 : 16.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: glassCard(
                context: context,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: secondaryPulseGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        _mode == _InputMode.file
                            ? Icons.cloud_upload_outlined
                            : _mode == _InputMode.screenshot
                            ? Icons.add_photo_alternate_outlined
                            : Icons.edit_outlined,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<_InputMode>(
                      segments: [
                        ButtonSegment(
                          value: _InputMode.file,
                          icon: const Icon(Icons.file_upload, size: 18),
                          label: Text(context.translate('upload_file_tab')),
                        ),
                        ButtonSegment(
                          value: _InputMode.screenshot,
                          icon: const Icon(Icons.image_search, size: 18),
                          label: Text(
                            context.translate('screenshot_entry_tab'),
                          ),
                        ),
                        ButtonSegment(
                          value: _InputMode.manual,
                          icon: const Icon(Icons.edit, size: 18),
                          label: Text(context.translate('manual_entry_tab')),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _isLoading
                          ? null
                          : (selected) {
                              setState(() {
                                _mode = selected.first;
                                _statusMessage = null;
                                if (_mode != _InputMode.screenshot) {
                                  _clearScreenshotPreview();
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 24),
                    if (_mode == _InputMode.file)
                      _buildFileBody(context)
                    else if (_mode == _InputMode.screenshot)
                      _buildScreenshotBody(context)
                    else
                      _buildManualBody(context),
                    if (_activeShoes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildShoeDropdown(context),
                    ],
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_mode == _InputMode.file)
                      GradientButton.icon(
                        onPressed: _pickAndImportFiles,
                        icon: const Icon(
                          Icons.file_upload,
                          color: Colors.white,
                        ),
                        label: Text(context.translate('select_file')),
                      )
                    else if (_mode == _InputMode.screenshot)
                      _screenshotPreview == null
                          ? GradientButton.icon(
                              onPressed: _pickAndAnalyzeScreenshot,
                              icon: const Icon(
                                Icons.image_search,
                                color: Colors.white,
                              ),
                              label: Text(
                                context.translate('select_screenshot'),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickAndAnalyzeScreenshot,
                                    icon: const Icon(Icons.image_search),
                                    label: Text(
                                      context.translate('choose_another_image'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GradientButton.icon(
                                    onPressed: _confirmScreenshotImport,
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      context.translate('confirm_import'),
                                    ),
                                  ),
                                ),
                              ],
                            )
                    else
                      GradientButton.icon(
                        onPressed: _saveManual,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: Text(context.translate('save_activity')),
                      ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_mode == _InputMode.file) ...[
                      const SizedBox(height: 16),
                      _buildExportHelp(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearScreenshotPreview() {
    _screenshotPreview = null;
    _screenshotFilename = null;
    _screenshotDistanceController.clear();
    _screenshotDurationController.clear();
    _screenshotAvgHrController.clear();
    _screenshotAvgCadenceController.clear();
    _screenshotElevationController.clear();
    _screenshotNameController.clear();
    _screenshotNotesController.clear();
    _screenshotStartedAt = DateTime.now();
  }

  String _defaultScreenshotName(String filename, AppLocalizations? l) {
    return l?.translate('default_screenshot_activity_name', [filename]) ??
        'Buổi tập nhập từ ảnh $filename';
  }

  String _formatNumber(double value) {
    final rounded = value.toStringAsFixed(2);
    return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(localDt.day)}/${two(localDt.month)}/${localDt.year} ${two(localDt.hour)}:${two(localDt.minute)}';
  }

  /// Phần mô tả cho chế độ tải file.
  Widget _buildFileBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.translate('upload_raw_activity'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.translate('supported_formats'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          context.translate('multi_file_hint'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScreenshotBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.translate('import_from_screenshot'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ScreenshotImportGuidance(
          intro: context.translate('screenshot_import_hint'),
          examplesLabel: context.translate('view_screenshot_examples'),
          onShowExamples: () => _showScreenshotExamples(context),
        ),
        if (_screenshotPreview != null) ...[
          const SizedBox(height: 24),
          _buildScreenshotPreviewForm(context),
        ],
      ],
    );
  }

  void _showScreenshotExamples(BuildContext context) {
    const examples = [
      (
        'assets/images/screenshot-example/strava.jpg',
        'screenshot_example_strava',
      ),
      (
        'assets/images/screenshot-example/google-fit.jpg',
        'screenshot_example_google_fit',
      ),
      (
        'assets/images/screenshot-example/watch-app.jpg',
        'screenshot_example_watch',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScreenshotExamplesSheet(examples: examples),
    );
  }

  Widget _buildScreenshotPreviewForm(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _screenshotPreview;
    final confidence = preview == null ? 0 : (preview.confidence * 100).round();
    final source = preview?.sourceApp;

    return Form(
      key: _screenshotFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.translate('screenshot_preview_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (source != null || confidence > 0) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (source != null && source.isNotEmpty) source,
                if (confidence > 0)
                  context.translate('ai_confidence_note', ['$confidence']),
              ].join(' • '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: _isLoading ? null : _pickScreenshotStartedAt,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: themedInputDecoration(
                context,
                context.translate('activity_date_time'),
                icon: Icons.calendar_today,
                isRequired: true,
              ),
              child: Text(
                _formatDateTime(_screenshotStartedAt),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotNameController,
            decoration: themedInputDecoration(
              context,
              context.translate('activity_name'),
              icon: Icons.title,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotDistanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('distance_label'),
              icon: Icons.straighten,
              suffixText: context.translate('km'),
              isRequired: true,
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) {
                return context.translate('manual_validation_error');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotDurationController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('duration_label'),
              icon: Icons.timer_outlined,
              suffixText: context.translate('min'),
              isRequired: true,
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) {
                return context.translate('manual_validation_error');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotAvgHrController,
            keyboardType: TextInputType.number,
            decoration: themedInputDecoration(
              context,
              context.translate('avg_hr_optional'),
              icon: Icons.favorite_outline,
              suffixText: context.translate('bpm'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotAvgCadenceController,
            keyboardType: TextInputType.number,
            decoration: themedInputDecoration(
              context,
              context.translate('avg_cadence_optional'),
              icon: Icons.directions_run_outlined,
              suffixText: context.translate('spm'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotElevationController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('elevation_gain_optional'),
              icon: Icons.terrain_outlined,
              suffixText: context.translate('m'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _screenshotNotesController,
            maxLines: 2,
            decoration: themedInputDecoration(
              context,
              context.translate('notes_optional'),
              icon: Icons.notes,
            ),
          ),
        ],
      ),
    );
  }

  /// Form nhập thủ công: ngày giờ, quãng đường, thời lượng + tùy chọn.
  Widget _buildManualBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String two(int n) => n.toString().padLeft(2, '0');
    final dt = _startedAt;
    final dateLabel =
        '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';

    return Form(
      key: _manualFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.translate('log_run_manually'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.translate('manual_entry_hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _isLoading ? null : _pickStartedAt,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: themedInputDecoration(
                context,
                context.translate('activity_date_time'),
                icon: Icons.calendar_today,
                isRequired: true,
              ),
              child: Text(dateLabel, style: theme.textTheme.bodyLarge),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: themedInputDecoration(
              context,
              context.translate('activity_name'),
              icon: Icons.title,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('distance_label'),
              icon: Icons.straighten,
              suffixText: context.translate('km'),
              isRequired: true,
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) {
                return context.translate('manual_validation_error');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _durationController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('duration_label'),
              icon: Icons.timer_outlined,
              suffixText: context.translate('min'),
              isRequired: true,
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) {
                return context.translate('manual_validation_error');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _avgHrController,
            keyboardType: TextInputType.number,
            decoration: themedInputDecoration(
              context,
              context.translate('avg_hr_optional'),
              icon: Icons.favorite_outline,
              suffixText: context.translate('bpm'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _avgCadenceController,
            keyboardType: TextInputType.number,
            decoration: themedInputDecoration(
              context,
              context.translate('avg_cadence_optional'),
              icon: Icons.directions_run_outlined,
              suffixText: context.translate('spm'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _elevationController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: themedInputDecoration(
              context,
              context.translate('elevation_gain_optional'),
              icon: Icons.terrain_outlined,
              suffixText: context.translate('m'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: themedInputDecoration(
              context,
              context.translate('notes_optional'),
              icon: Icons.notes,
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown chọn giày, dùng chung cho cả hai chế độ.
  Widget _buildShoeDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: _selectedShoeId,
      decoration: themedInputDecoration(
        context,
        context.translate('select_shoe'),
        prefixIcon: FaIcon(
          FontAwesomeIcons.shoePrints,
          size: 18,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      dropdownColor: colorScheme.surface,
      isExpanded: true,
      onChanged: (String? newValue) {
        setState(() {
          _selectedShoeId = newValue;
        });
      },
      items: _activeShoes.map<DropdownMenuItem<String>>((Shoe shoe) {
        final brand = shoe.brand?.trim();
        return DropdownMenuItem<String>(
          value: shoe.id,
          child: Text(
            brand == null || brand.isEmpty
                ? shoe.name
                : '${shoe.name} ($brand)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  /// Hướng dẫn ngắn gọn cách export file từ các nền tảng phổ biến.
  Widget _buildExportHelp(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Widget row(String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chevron_right, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.translate(key),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.help_outline, color: colorScheme.primary),
        title: Text(
          context.translate('import_help_title'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        children: [
          row('import_help_strava'),
          row('import_help_garmin'),
          row('import_help_generic'),
        ],
      ),
    );
  }
}

class _ScreenshotExamplesSheet extends StatefulWidget {
  const _ScreenshotExamplesSheet({required this.examples});

  final List<(String, String)> examples;

  @override
  State<_ScreenshotExamplesSheet> createState() =>
      _ScreenshotExamplesSheetState();
}

class _ScreenshotExamplesSheetState extends State<_ScreenshotExamplesSheet> {
  final PageController _pageController = PageController();
  var _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page.clamp(0, widget.examples.length - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('screenshot_examples_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.translate('screenshot_examples_hint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.translate('screenshot_import_guide_title'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GuideStep(
                      text: context.translate('screenshot_import_step_summary'),
                    ),
                    const SizedBox(height: 6),
                    _GuideStep(
                      text: context.translate('screenshot_import_step_details'),
                    ),
                    const SizedBox(height: 6),
                    _GuideStep(
                      text: context.translate('screenshot_import_step_clarity'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.examples.length,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemBuilder: (context, index) {
                    final example = widget.examples[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.asset(
                              example.$1,
                              fit: BoxFit.contain,
                              semanticLabel: context.translate(example.$2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              context.translate(example.$2),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _currentPage == 0
                        ? null
                        : () => _goToPage(_currentPage - 1),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    tooltip: 'Previous example',
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.examples.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentPage ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _currentPage == widget.examples.length - 1
                        ? null
                        : () => _goToPage(_currentPage + 1),
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Next example',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
