import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

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

/// Native (Android/iOS): Strava quay về app qua deep link
/// `runnyai://<callback-domain>/strava?code=...&state=...`. Web dùng
/// [captureStravaRedirect] nên luồng này rỗng.
Stream<({String code, String state})> stravaDeepLinks() {
  if (kIsWeb) return const Stream.empty();
  return AppLinks().uriLinkStream
      .map(_parseStravaDeepLink)
      .where((redirect) => redirect != null)
      .cast<({String code, String state})>();
}

({String code, String state})? _parseStravaDeepLink(Uri uri) {
  if (uri.scheme != 'runnyai' || uri.path != '/strava') return null;
  final code = uri.queryParameters['code'] ?? '';
  final state = uri.queryParameters['state'] ?? '';
  if (code.isEmpty || state.isEmpty) return null;
  return (code: code, state: state);
}
