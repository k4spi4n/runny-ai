import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/activity_parser.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_components.dart';
import '../models/shoe_models.dart';

enum _ImportOutcome { imported, duplicate, failed }

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
  List<Shoe> _activeShoes = [];
  String? _selectedShoeId;

  @override
  void initState() {
    super.initState();
    _fetchActiveShoes();
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
      String? firstImportedId;

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        setState(() {
          _statusMessage = l?.translate('importing_progress', [
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
              firstImportedId ??= outcome.$2;
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
      if (widget.scheduledWorkoutId != null && firstImportedId != null) {
        await Supabase.instance.client
            .from('scheduled_workouts')
            .update({'activity_id': firstImportedId, 'status': 'completed'})
            .eq('id', widget.scheduledWorkoutId!);
      }

      setState(() {
        _statusMessage = l?.translate('imported_summary', [
              '$imported',
              '$duplicate',
              '$failed',
            ]) ??
            'imported_summary';
      });

      // Chỉ tự đóng khi có ít nhất 1 hoạt động được nhập.
      if (mounted && imported > 0) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted) Navigator.pop(context, true);
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

  /// Nhập một file. Trả về (kết quả, id hoạt động nếu có).
  Future<(_ImportOutcome, String?)> _importOne(
    PlatformFile file,
    AppLocalizations? l,
  ) async {
    final bytes = file.bytes;
    if (bytes == null) return (_ImportOutcome.failed, null);

    final parsed = await ActivityParser.parse(
      bytes,
      file.extension?.toLowerCase() ?? '',
    );

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final startedIso = parsed.startedAt.toIso8601String();

    // Chống trùng: đã có hoạt động cùng thời điểm bắt đầu cho user này.
    final existing = await Supabase.instance.client
        .from('activities')
        .select('id')
        .eq('user_id', uid)
        .eq('started_at', startedIso)
        .maybeSingle();
    if (existing != null) {
      return (_ImportOutcome.duplicate, existing['id'] as String);
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
          'notes':
              l?.translate('imported_from', [file.name]) ?? 'imported_from',
          if (_selectedShoeId != null) 'shoe_id': _selectedShoeId,
        })
        .select('id')
        .single();

    return (_ImportOutcome.imported, res['id'] as String);
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
                padding: const EdgeInsets.all(24),
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
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                        if (_activeShoes.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedShoeId,
                            decoration: themedInputDecoration(
                              context,
                              context.translate('select_shoe'),
                              prefixIcon: FaIcon(
                                FontAwesomeIcons.shoePrints,
                                size: 18,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            dropdownColor: colorScheme.surface,
                            isExpanded: true,
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedShoeId = newValue;
                              });
                            },
                            items: _activeShoes.map<DropdownMenuItem<String>>((
                              Shoe shoe,
                            ) {
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
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          GradientButton.icon(
                            onPressed: _pickAndImportFiles,
                            icon: const Icon(
                              Icons.file_upload,
                              color: Colors.white,
                            ),
                            label: Text(context.translate('select_file')),
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
                        const SizedBox(height: 16),
                        _buildExportHelp(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
