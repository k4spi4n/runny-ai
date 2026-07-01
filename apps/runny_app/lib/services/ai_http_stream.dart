// Điểm nhập chung cho POST dạng streaming. Conditional import chọn bản hiện
// thực phù hợp: Fetch API trên web, `package:http` streamed trên native.
export 'ai_http_stream_io.dart'
    if (dart.library.js_interop) 'ai_http_stream_web.dart';
