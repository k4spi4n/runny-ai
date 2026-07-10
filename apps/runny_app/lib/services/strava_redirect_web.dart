import 'package:web/web.dart' as web;

/// Web: nếu URL là callback của Strava (state một-lần & có code) thì trả về callback
/// và xoá toàn bộ query khỏi URL (giữ nguyên path) để không xử lý lại / không
/// để Supabase nhầm là callback đăng nhập.
({String code, String state})? consumeStravaCodeImpl() {
  final params = Uri.base.queryParameters;
  final state = params['state'];
  if (state != null && state.isNotEmpty && (params['code'] ?? '').isNotEmpty) {
    final code = params['code'];
    final cleaned = Uri(path: Uri.base.path.isEmpty ? '/' : Uri.base.path).toString();
    web.window.history.replaceState(null, '', cleaned);
    return (code: code!, state: state);
  }
  return null;
}
