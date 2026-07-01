import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Bản hiện thực cho Flutter Web. Sử dụng event `beforeinstallprompt` đã được
/// `web/index.html` bắt và lưu vào `window.deferredPwaPrompt`.

/// Có sẵn lời mời cài PWA hay không (event đã được lưu và app chưa được cài).
bool pwaInstallAvailable() {
  final prompt = globalContext['deferredPwaPrompt'];
  return prompt.isDefinedAndNotNull;
}

/// Hiển thị hộp thoại cài PWA của trình duyệt. Event chỉ dùng được một lần nên
/// xoá đi sau khi gọi để nút tự ẩn.
Future<void> promptPwaInstall() async {
  final prompt = globalContext['deferredPwaPrompt'];
  if (prompt.isUndefinedOrNull) return;
  final result = (prompt as JSObject).callMethod<JSAny?>('prompt'.toJS);
  if (result.isDefinedAndNotNull) {
    try {
      await (result as JSPromise).toDart;
    } catch (_) {
      // Người dùng đóng hộp thoại — bỏ qua.
    }
  }
  globalContext['deferredPwaPrompt'] = null;
}

/// Đăng ký callback để cập nhật hiển thị nút khi trạng thái cài đặt thay đổi
/// (đủ điều kiện cài, hoặc vừa cài xong).
void setPwaInstallabilityListener(void Function() onChange) {
  final cb = onChange.toJS;
  globalContext['onPwaInstallable'] = cb;
  globalContext['onPwaInstalled'] = cb;
}
