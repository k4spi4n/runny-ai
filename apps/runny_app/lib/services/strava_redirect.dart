import 'strava_redirect_stub.dart'
    if (dart.library.js_interop) 'strava_redirect_web.dart';

({String code, String state})? _pendingStravaRedirect;

/// Gọi SỚM trong main() — TRƯỚC khi Supabase khởi tạo — để lấy mã `code` của
/// Strava khỏi URL và xoá khỏi thanh địa chỉ. Việc này tránh để Supabase (luồng
/// PKCE) nhầm `?code=...` của Strava là callback đăng nhập của chính nó.
void captureStravaRedirect() {
  _pendingStravaRedirect = consumeStravaCodeImpl();
}

/// Lấy (và xoá) mã Strava đã bắt được. Dùng một lần.
({String code, String state})? takePendingStravaRedirect() {
  final redirect = _pendingStravaRedirect;
  _pendingStravaRedirect = null;
  return redirect;
}
