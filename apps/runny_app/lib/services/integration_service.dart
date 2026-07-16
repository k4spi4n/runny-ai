import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class IntegrationService {
  final _supabase = Supabase.instance.client;

  Future<void> connectStrava() async {
    final res = await _supabase.functions.invoke(
      'strava_oauth',
      body: {'action': 'start'},
    );
    final data = res.data;
    final rawUrl = data is Map ? data['authorizationUrl'] : null;
    if (res.status != 200 || rawUrl is! String || rawUrl.isEmpty) {
      throw Exception('Không thể bắt đầu kết nối Strava.');
    }
    final authUrl = Uri.parse(rawUrl);

    // Trên web mở cùng tab ('_self') để sau khi cấp quyền, Strava redirect quay
    // lại đúng URL ứng dụng và mã `code` được xử lý. Tham số này bị bỏ qua ngoài web.
    await launchUrl(
      authUrl,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
  }

  /// Đổi authorization code lấy token (qua Edge Function, secret ở server) và
  /// nhập ngay hoạt động gần đây. Trả về số hoạt động đã nhập.
  Future<int> exchangeStravaCode(String code, String state) async {
    try {
      final res = await _supabase.functions.invoke(
        'strava_oauth',
        body: {'action': 'connect', 'code': code, 'state': state},
      );
      return _importedFrom(res.data);
    } on FunctionException catch (e) {
      throw _functionError(e);
    }
  }

  /// Đồng bộ thủ công: nhập các hoạt động chạy gần đây từ Strava.
  Future<int> syncStrava() async {
    try {
      final res = await _supabase.functions.invoke(
        'strava_oauth',
        body: {'action': 'sync'},
      );
      return _importedFrom(res.data);
    } on FunctionException catch (e) {
      throw _functionError(e);
    }
  }

  int _importedFrom(dynamic data) {
    if (data is Map && data['imported'] is num) {
      return (data['imported'] as num).toInt();
    }
    return 0;
  }

  String _functionError(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Strava: ${e.reasonPhrase ?? e.details ?? e.status}';
  }

  Future<void> connectGarmin() async {
    // Garmin OAuth is more complex (OAuth 1.0a or 2.0 depending on API)
    // For now, we'll just show a placeholder URL or message
    final authUrl = Uri.parse('https://connect.garmin.com/oauth/authorize');

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Garmin auth URL';
    }
  }

  Future<void> disconnectStrava() async {
    await _supabase.functions.invoke(
      'strava_oauth',
      body: {'action': 'disconnect'},
    );
  }

  Future<void> disconnectGarmin() async {
    // Garmin OAuth is not implemented yet, so there is no trusted server-side
    // connection to revoke. Provider-owned profile identifiers are never
    // writable by the client.
  }
}
