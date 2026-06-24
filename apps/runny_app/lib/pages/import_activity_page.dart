import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/activity_parser.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_components.dart';
import '../models/shoe_models.dart';

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

  Future<void> _pickAndImportFile() async {
    final localizations = AppLocalizations.of(context);
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = localizations?.translate('selecting_file') ?? 'selecting_file';
      });

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'fit'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.extension?.toLowerCase();

        setState(() {
          _statusMessage = localizations?.translate('analyzing_file', [file.name]) ?? 'analyzing_file';
        });

        // Parse file
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception(localizations?.translate('read_file_error') ?? 'read_file_error');
        }

        final parsedActivity = await ActivityParser.parse(
          bytes,
          extension ?? '',
        );

        WeatherSnapshot? weatherSnapshot;
        if (parsedActivity.startLat != null &&
            parsedActivity.startLon != null) {
          try {
            setState(() {
              _statusMessage = localizations?.translate('fetching_weather') ?? 'fetching_weather';
            });
            weatherSnapshot = await _weatherService.fetchWeatherSnapshot(
              lat: parsedActivity.startLat!,
              lon: parsedActivity.startLon!,
            );
          } catch (e) {
            weatherSnapshot = null;
          }
        }

        setState(() {
          _statusMessage = localizations?.translate('saving_to_db') ?? 'saving_to_db';
        });

        // Save to Supabase
        final activityRes = await Supabase.instance.client.from('activities').insert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'started_at': parsedActivity.startedAt.toIso8601String(),
          'distance_km': parsedActivity.distanceKm,
          'duration_min': parsedActivity.durationMin,
          'avg_hr': parsedActivity.avgHr,
          'elevation_gain_m': parsedActivity.elevationGainM,
          'data_points': parsedActivity.dataPoints,
          'start_lat': parsedActivity.startLat,
          'start_lon': parsedActivity.startLon,
          'weather_summary': weatherSnapshot?.summary,
          'temperature_c': weatherSnapshot?.temperatureC,
          'aqi': weatherSnapshot?.aqi,
          'weather_json': weatherSnapshot?.toJson(),
          'weather_fetched_at': weatherSnapshot?.fetchedAt.toIso8601String(),
          'notes': localizations?.translate('imported_from', [file.name]) ?? 'imported_from',
          if (_selectedShoeId != null) 'shoe_id': _selectedShoeId,
        }).select('id').single();

        final activityId = activityRes['id'] as String;

        if (widget.scheduledWorkoutId != null) {
          await Supabase.instance.client
              .from('scheduled_workouts')
              .update({
                'activity_id': activityId,
                'status': 'completed',
              })
              .eq('id', widget.scheduledWorkoutId!);
        }

        setState(() {
          _statusMessage = localizations?.translate('import_success') ?? 'import_success';
        });

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      } else {
        setState(() {
          _statusMessage = localizations?.translate('import_cancelled') ?? 'import_cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '${localizations?.translate('import_error') ?? 'import_error'}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.translate('import_activity'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ResponsiveContent(
            maxWidth: 480,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                context.translate('upload_raw_activity'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                context.translate('supported_formats'),
                style: const TextStyle(color: Colors.grey),
              ),
              if (_activeShoes.isNotEmpty) ...[
                Text(
                  context.translate('select_shoe'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectedShoeId,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedShoeId = newValue;
                    });
                  },
                  items: _activeShoes.map<DropdownMenuItem<String>>((Shoe shoe) {
                    return DropdownMenuItem<String>(
                      value: shoe.id,
                      child: Text('${shoe.name} (${shoe.brand ?? ''})'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (_isLoading)
                const CircularProgressIndicator()
              else
                GradientButton.icon(
                  onPressed: _pickAndImportFile,
                  icon: const Icon(Icons.file_upload, color: Colors.white),
                  label: Text(context.translate('select_file')),
                ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}
