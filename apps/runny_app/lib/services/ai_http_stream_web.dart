import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ai_http_stream_types.dart';

export 'ai_http_stream_types.dart';

/// Bản hiện thực cho Flutter Web: dùng Fetch API + ReadableStream reader để đọc
/// body tăng dần (streaming thật trên trình duyệt — `package:http` mặc định chỉ
/// trả body một lần khi hoàn tất nên không dùng được cho SSE).
Future<HttpStreamResult> postStreaming(
  Uri url,
  Map<String, String> headers,
  String body,
) async {
  final jsHeaders = web.Headers();
  headers.forEach((k, v) => jsHeaders.append(k, v));

  final response = await web.window
      .fetch(
        url.toString().toJS,
        web.RequestInit(
          method: 'POST',
          headers: jsHeaders,
          body: body.toJS,
        ),
      )
      .toDart;

  final controller = StreamController<List<int>>();
  final bodyStream = response.body;

  if (bodyStream == null) {
    // Không có luồng (hiếm): đọc trọn text rồi phát một lần.
    final text = (await response.text().toDart).toDart;
    controller.add(Uint8List.fromList(text.codeUnits));
    unawaited(controller.close());
    return HttpStreamResult(response.status, controller.stream);
  }

  final reader =
      bodyStream.getReader() as web.ReadableStreamDefaultReader;

  Future<void> pump() async {
    try {
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final value = chunk.value;
        if (value != null && value.isDefinedAndNotNull) {
          controller.add((value as JSUint8Array).toDart);
        }
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      await controller.close();
    }
  }

  unawaited(pump());
  return HttpStreamResult(response.status, controller.stream);
}
