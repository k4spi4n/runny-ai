import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/activity_parser.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_components.dart';

class ImportActivityPage extends StatefulWidget {
  const ImportActivityPage({super.key});

  @override
  State<ImportActivityPage> createState() => _ImportActivityPageState();
}

class _ImportActivityPageState extends State<ImportActivityPage> {
  bool _isLoading = false;
  String? _statusMessage;
  final WeatherService _weatherService = WeatherService();

  Future<void> _pickAndImportFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = context.translate('selecting_file');
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
          _statusMessage = context.translate('analyzing_file', [file.name]);
        });

        // Parse file
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception(context.translate('read_file_error'));
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
              _statusMessage = context.translate('fetching_weather');
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
          _statusMessage = context.translate('saving_to_db');
        });

        // Save to Supabase
        await Supabase.instance.client.from('activities').insert({
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
          'notes': context.translate('imported_from', [file.name]),
        });

        setState(() {
          _statusMessage = context.translate('import_success');
        });
      } else {
        setState(() {
          _statusMessage = context.translate('import_cancelled');
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '${context.translate('import_error')}: $e';
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
              const SizedBox(height: 32),
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
    );
  }
}
