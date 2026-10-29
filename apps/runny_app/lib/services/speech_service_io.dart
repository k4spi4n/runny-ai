import 'dart:io';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_service.dart';

/// Native (Android/iOS): dùng bộ nhận diện giọng nói của hệ điều hành qua
/// `speech_to_text`. Desktop chưa hỗ trợ.
SpeechService createSpeechService() => NativeSpeechService();

class NativeSpeechService implements SpeechService {
  final SpeechToText _stt = SpeechToText();

  // `initialize` chỉ đăng ký listener ở lần đầu, nên các callback của phiên
  // hiện tại được giữ ở đây và listener chung chuyển tiếp tới chúng.
  void Function(String code)? _onError;
  void Function()? _onEnd;
  bool _active = false;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void start({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    void Function()? onEnd,
    String localeId = 'vi-VN',
  }) {
    _start(onResult: onResult, onError: onError, onEnd: onEnd, localeId: localeId);
  }

  Future<void> _start({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    void Function()? onEnd,
    required String localeId,
  }) async {
    if (!isSupported) {
      onError('unsupported');
      return;
    }
    _onError = onError;
    _onEnd = onEnd;
    _active = true;

    try {
      final ready = await _stt.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      if (!ready) {
        // Không khởi tạo được: hoặc người dùng từ chối quyền micro, hoặc máy
        // không có dịch vụ nhận diện giọng nói.
        _fail(await _stt.hasPermission ? 'unsupported' : 'not-allowed');
        return;
      }
      await _stt.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: localeId.replaceAll('-', '_'),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      _fail('audio-capture');
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _fail(_mapError(error.errorMsg));
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.doneStatus) _finish();
  }

  void _fail(String code) {
    if (!_active) return;
    _onError?.call(code);
    _finish();
  }

  void _finish() {
    if (!_active) return;
    _active = false;
    _onEnd?.call();
  }

  /// Quy đổi mã lỗi Android về mã của Web Speech API mà giao diện đang dùng.
  static String _mapError(String errorMsg) => switch (errorMsg) {
    'error_permission' => 'not-allowed',
    'error_no_match' || 'error_speech_timeout' => 'no-speech',
    'error_network' ||
    'error_network_timeout' ||
    'error_server' ||
    'error_server_disconnected' => 'network',
    'error_audio_error' => 'audio-capture',
    'error_language_not_supported' ||
    'error_language_unavailable' => 'unsupported',
    _ => errorMsg,
  };

  @override
  void stop() => _stt.stop();

  @override
  void cancel() {
    _stt.cancel();
    _finish();
  }
}
