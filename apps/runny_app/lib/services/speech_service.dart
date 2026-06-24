import 'speech_service_stub.dart'
    if (dart.library.js_interop) 'speech_service_web.dart';

/// Issue #29: Speech-to-Text cho AI Chatbot.
///
/// Trừu tượng hoá nhận diện giọng nói. Trên web dùng Web Speech API của trình
/// duyệt; các nền tảng khác trả về bản "không hỗ trợ" để vẫn biên dịch được.
abstract class SpeechService {
  /// Trình duyệt/thiết bị có hỗ trợ nhận diện giọng nói hay không.
  bool get isSupported;

  /// Bắt đầu ghi âm & nhận diện.
  /// - [onResult]: gọi mỗi khi có kết quả; `isFinal=false` là kết quả tạm thời
  ///   (real-time), `isFinal=true` là kết quả chốt của một câu.
  /// - [onError]: mã lỗi (vd 'not-allowed', 'no-speech', 'network'...).
  /// - [onEnd]: phiên nhận diện kết thúc.
  void start({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    void Function()? onEnd,
    String localeId,
  });

  /// Dừng & chốt kết quả hiện tại (sẽ kích hoạt [onEnd]).
  void stop();

  /// Huỷ ngay lập tức, bỏ kết quả đang có.
  void cancel();

  factory SpeechService() => createSpeechService();
}
