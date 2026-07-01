// Điểm nhập chung cho tính năng "Cài đặt PWA". Conditional import chọn bản hiện
// thực: no-op trên native (không có khái niệm cài PWA), JS interop trên web.
export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
