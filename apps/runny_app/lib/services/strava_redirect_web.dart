import 'package:web/web.dart' as web;

/// Web: nếu URL là callback của Strava (state=strava & có code) thì trả về code
/// và xoá toàn bộ query khỏi URL (giữ nguyên path) để không xử lý lại / không
/// để Supabase nhầm là callback đăng nhập.
String? consumeStravaCodeImpl() {
  final params = Uri.base.queryParameters;
  if (params['state'] == 'strava' && (params['code'] ?? '').isNotEmpty) {
    final code = params['code'];
    final cleaned = Uri(path: Uri.base.path.isEmpty ? '/' : Uri.base.path).toString();
    web.window.history.replaceState(null, '', cleaned);
    return code;
  }
  return null;
}
