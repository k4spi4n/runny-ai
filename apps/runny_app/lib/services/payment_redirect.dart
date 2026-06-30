import 'payment_redirect_stub.dart'
    if (dart.library.js_interop) 'payment_redirect_web.dart';

/// Lấy (và xoá khỏi URL) trạng thái trả về từ cổng thanh toán PayOS.
/// Trả về 'success' | 'cancel' | null. Trên nền tảng không phải web -> null.
String? consumePaymentRedirect() => consumePaymentRedirectImpl();
