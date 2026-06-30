import 'package:web/web.dart' as web;

/// Web: đọc tham số `?payment=success|cancel` mà PayOS gắn vào returnUrl/cancelUrl,
/// rồi xoá query khỏi URL để không xử lý lại khi reload.
String? consumePaymentRedirectImpl() {
  final payment = Uri.base.queryParameters['payment'];
  if (payment == 'success' || payment == 'cancel') {
    final cleaned = Uri(path: Uri.base.path.isEmpty ? '/' : Uri.base.path).toString();
    web.window.history.replaceState(null, '', cleaned);
    return payment;
  }
  return null;
}
