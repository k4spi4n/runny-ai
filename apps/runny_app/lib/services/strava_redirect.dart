import 'strava_redirect_stub.dart'
    if (dart.library.js_interop) 'strava_redirect_web.dart';

String? _pendingStravaCode;

/// Gọi SỚM trong main() — TRƯỚC khi Supabase khởi tạo — để lấy mã `code` của
/// Strava khỏi URL và xoá khỏi thanh địa chỉ. Việc này tránh để Supabase (luồng
/// PKCE) nhầm `?code=...` của Strava là callback đăng nhập của chính nó.
void captureStravaRedirect() {
  _pendingStravaCode = consumeStravaCodeImpl();
}

/// Lấy (và xoá) mã Strava đã bắt được. Dùng một lần.
String? takePendingStravaCode() {
  final code = _pendingStravaCode;
  _pendingStravaCode = null;
  return code;
}
