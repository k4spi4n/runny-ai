import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/activity_parser.dart';

class ImportActivityPage extends StatefulWidget {
  const ImportActivityPage({super.key});

  @override
  State<ImportActivityPage> createState() => _ImportActivityPageState();
}

class _ImportActivityPageState extends State<ImportActivityPage> {
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _pickAndImportFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Đang chọn file...';
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
          _statusMessage = 'Đang phân tích tệp ${file.name}...';
        });

        // Parse file
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Không thể đọc dữ liệu file');
        }

        final parsedActivity = await ActivityParser.parse(
          bytes,
          extension ?? '',
        );

        setState(() {
          _statusMessage = 'Đang lưu vào cơ sở dữ liệu...';
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
          'notes': 'Imported from ${file.name}',
        });

        setState(() {
          _statusMessage = 'Import thành công!';
        });
      } else {
        setState(() {
          _statusMessage = 'Đã hủy import.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi import: $e';
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
      appBar: AppBar(title: const Text('Nhập Hoạt Động')),
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
              const Text(
                'Tải lên hoạt động từ file thô',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hỗ trợ định dạng: .GPX, .FIT',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickAndImportFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Chọn File (.gpx, .fit)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
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
