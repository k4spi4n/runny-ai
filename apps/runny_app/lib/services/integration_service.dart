import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class IntegrationService {
  final _supabase = Supabase.instance.client;

  // Cấu hình Strava đọc từ .env (xem .env.example: STRAVA_CLIENT_ID,
  // STRAVA_REDIRECT_URI). Không hardcode credentials trong mã nguồn.
  String get _stravaClientId => dotenv.env['STRAVA_CLIENT_ID'] ?? '';
  String get _stravaRedirectUri =>
      dotenv.env['STRAVA_REDIRECT_URI'] ?? 'http://localhost:3000/';

  Future<void> connectStrava() async {
    if (_stravaClientId.isEmpty) {
      throw 'Chưa cấu hình STRAVA_CLIENT_ID trong .env';
    }

    // state=strava giúp phân biệt callback của Strava với mã `code` của Supabase
    // (PKCE) khi cùng quay về URL gốc của ứng dụng.
    final authUrl = Uri.parse(
      'https://www.strava.com/oauth/authorize'
      '?client_id=$_stravaClientId'
      '&redirect_uri=$_stravaRedirectUri'
      '&response_type=code'
      '&approval_prompt=auto'
      '&state=strava'
      '&scope=activity:read_all,profile:read_all'
    );

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
  Future<int> exchangeStravaCode(String code) async {
    try {
      final res = await _supabase.functions.invoke(
        'strava_oauth',
        body: {'action': 'connect', 'code': code},
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
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'strava_id': null,
      'strava_access_token': null,
      'strava_refresh_token': null,
      'strava_expires_at': null,
    }).eq('id', user.id);
  }

  Future<void> disconnectGarmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'garmin_id': null,
    }).eq('id', user.id);
  }
}
