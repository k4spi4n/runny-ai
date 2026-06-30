import 'dart:convert';

/// Ném khi server trả 402 / `code: 'upgrade_required'`: tính năng AI cao cấp bị
/// khóa với tier `free`. UI bắt ngoại lệ này để mở luồng nâng cấp (paywall) thay
/// vì chỉ hiển thị thông báo lỗi thường.
class PaywallException implements Exception {
  final String message;
  const PaywallException([
    this.message = 'Tính năng này dành cho gói trả phí. Vui lòng nâng cấp để tiếp tục.',
  ]);

  @override
  String toString() => message;

  /// Phát hiện tín hiệu nâng cấp từ phản hồi server (status 402 hoặc body có
  /// `code == 'upgrade_required'`). Dùng chung cho cả AI proxy và food-recognition.
  static bool isUpgradeSignal(int? status, dynamic data) {
    if (status == 402) return true;
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map && decoded['code'] == 'upgrade_required') return true;
    } catch (_) {
      // bỏ qua: không decode được thì coi như không phải tín hiệu nâng cấp
    }
    return false;
  }
}
