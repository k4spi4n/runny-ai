import 'speech_service.dart';

/// Bản dự phòng cho các nền tảng không có Web Speech API.
SpeechService createSpeechService() => _UnsupportedSpeechService();

class _UnsupportedSpeechService implements SpeechService {
  @override
  bool get isSupported => false;

  @override
  void start({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    void Function()? onEnd,
    String localeId = 'vi-VN',
  }) {
    onError('unsupported');
  }

  @override
  void stop() {}

  @override
  void cancel() {}
}
