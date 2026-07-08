import 'dart:async';

import 'package:flutter/foundation.dart';

enum RunTimerStatus { notStarted, running, paused, finished }

class RunTimerController extends ChangeNotifier {
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _lastResumedAt;
  Duration _elapsedBeforeResume = Duration.zero;
  Duration _elapsedAtFinish = Duration.zero;
  RunTimerStatus _status = RunTimerStatus.notStarted;

  RunTimerStatus get status => _status;

  Duration get elapsed {
    if (_status == RunTimerStatus.finished) return _elapsedAtFinish;
    final resumedAt = _lastResumedAt;
    if (_status == RunTimerStatus.running && resumedAt != null) {
      return _elapsedBeforeResume + DateTime.now().difference(resumedAt);
    }
    return _elapsedBeforeResume;
  }

  DateTime? get startedAt => _startedAt;

  void start() {
    _startedAt = DateTime.now();
    _lastResumedAt = _startedAt;
    _elapsedBeforeResume = Duration.zero;
    _elapsedAtFinish = Duration.zero;
    _status = RunTimerStatus.running;
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (_status != RunTimerStatus.running || _lastResumedAt == null) return;
    _elapsedBeforeResume = elapsed;
    _lastResumedAt = null;
    _status = RunTimerStatus.paused;
    _stopTicker();
    notifyListeners();
  }

  void resume() {
    if (_status != RunTimerStatus.paused) return;
    _lastResumedAt = DateTime.now();
    _status = RunTimerStatus.running;
    _startTicker();
    notifyListeners();
  }

  void finish() {
    if (_status == RunTimerStatus.notStarted ||
        _status == RunTimerStatus.finished) {
      return;
    }
    _elapsedAtFinish = elapsed;
    _elapsedBeforeResume = _elapsedAtFinish;
    _lastResumedAt = null;
    _status = RunTimerStatus.finished;
    _stopTicker();
    notifyListeners();
  }

  void reset() {
    _startedAt = null;
    _lastResumedAt = null;
    _elapsedBeforeResume = Duration.zero;
    _elapsedAtFinish = Duration.zero;
    _status = RunTimerStatus.notStarted;
    _stopTicker();
    notifyListeners();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
