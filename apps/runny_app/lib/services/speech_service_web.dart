import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'speech_service.dart';

SpeechService createSpeechService() => WebSpeechService();

/// Binding tới `webkitSpeechRecognition` (Chrome/Edge) của Web Speech API.
@JS('webkitSpeechRecognition')
extension type _Recognition._(JSObject _) implements JSObject {
  external _Recognition();
  external set lang(String value);
  external set continuous(bool value);
  external set interimResults(bool value);
  external set maxAlternatives(int value);
  external set onresult(JSFunction value);
  external set onerror(JSFunction value);
  external set onend(JSFunction value);
  external void start();
  external void stop();
  external void abort();
}

extension type _SpeechResultEvent._(JSObject _) implements JSObject {
  external int get resultIndex;
  external _ResultList get results;
}

extension type _ResultList._(JSObject _) implements JSObject {
  external int get length;
  external _SpeechResult item(int index);
}

extension type _SpeechResult._(JSObject _) implements JSObject {
  external bool get isFinal;
  external _Alternative item(int index);
}

extension type _Alternative._(JSObject _) implements JSObject {
  external String get transcript;
}

extension type _SpeechErrorEvent._(JSObject _) implements JSObject {
  external String get error;
}

class WebSpeechService implements SpeechService {
  _Recognition? _recognition;

  @override
  bool get isSupported =>
      globalContext.has('webkitSpeechRecognition') ||
      globalContext.has('SpeechRecognition');

  @override
  void start({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    void Function()? onEnd,
    String localeId = 'vi-VN',
  }) {
    if (!isSupported) {
      onError('unsupported');
      return;
    }

    final rec = _Recognition();
    _recognition = rec;
    rec.lang = localeId;
    rec.continuous = false;
    rec.interimResults = true;
    rec.maxAlternatives = 1;

    rec.onresult = ((_SpeechResultEvent event) {
      final results = event.results;
      final buffer = StringBuffer();
      var isFinal = false;
      for (var i = event.resultIndex; i < results.length; i++) {
        final result = results.item(i);
        buffer.write(result.item(0).transcript);
        if (result.isFinal) isFinal = true;
      }
      onResult(buffer.toString(), isFinal);
    }).toJS;

    rec.onerror = ((_SpeechErrorEvent event) {
      onError(event.error);
    }).toJS;

    rec.onend = (() {
      _recognition = null;
      onEnd?.call();
    }).toJS;

    rec.start();
  }

  @override
  void stop() => _recognition?.stop();

  @override
  void cancel() => _recognition?.abort();
}
