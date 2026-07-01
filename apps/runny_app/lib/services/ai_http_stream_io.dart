import 'dart:async';

import 'package:http/http.dart' as http;

import 'ai_http_stream_types.dart';

export 'ai_http_stream_types.dart';

/// Bản hiện thực cho VM/mobile/desktop: `http.Client.send` trả về
/// [http.StreamedResponse] phát body theo từng chunk (streaming thật). Đóng
/// client khi luồng kết thúc/huỷ để không rò kết nối.
Future<HttpStreamResult> postStreaming(
  Uri url,
  Map<String, String> headers,
  String body,
) async {
  final client = http.Client();
  final request = http.Request('POST', url)
    ..headers.addAll(headers)
    ..body = body;

  final response = await client.send(request);

  final controller = StreamController<List<int>>();
  late final StreamSubscription<List<int>> sub;
  sub = response.stream.listen(
    controller.add,
    onError: controller.addError,
    onDone: () {
      controller.close();
      client.close();
    },
    cancelOnError: true,
  );
  controller.onCancel = () async {
    await sub.cancel();
    client.close();
  };

  return HttpStreamResult(response.statusCode, controller.stream);
}
