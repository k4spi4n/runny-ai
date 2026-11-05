import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recorded_run.dart';
import '../models/workout_models.dart';
import 'run_draft_store.dart';
import 'run_location_source.dart';

class RunRecordingService extends ChangeNotifier {
  RunRecordingService(
    this._client, {
    RunDraftStore? store,
    RunLocationSource? location,
    DateTime Function()? now,
    String? Function()? currentUserId,
    bool watchAuth = true,
  }) : _store = store ?? (supported ? RunDraftStore() : null),
       location = location ?? RunLocationSource(),
       _now = now ?? DateTime.now,
       _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id) {
    ready = _switchUser();
    if (watchAuth) {
      _auth = _client.auth.onAuthStateChange.listen((_) {
        if (_owner != _currentUserId()) ready = _switchUser();
      });
    }
  }

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final SupabaseClient _client;
  RunDraftStore? _store;
  final RunLocationSource location;
  final DateTime Function() _now;
  final String? Function() _currentUserId;
  late Future<void> ready;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<RunFix>? _positions;
  StreamSubscription<ServiceStatus>? _services;
  Timer? _timer;
  Future<void> _writes = Future.value();
  String? _owner;
  String? _deletingId;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  bool saving = false;
  bool loading = true;
  bool recoveryFailed = false;
  String locationMessage = 'run_gps_acquiring';
  String? error;
  RecordedRun? draft;
  RunFix? position;

  RunDraftStore get _draftStore => _store ??= RunDraftStore();
  DateTime get now => _now();
  String? get currentUserId => _currentUserId();
  bool get hasFix => position?.usableAt(now) ?? false;
  RunFix? get livePosition => hasFix ? position : null;
  bool get canStart =>
      hasFix &&
      !busy &&
      !loading &&
      !recoveryFailed &&
      draft == null &&
      _owner != null &&
      _owner == _currentUserId();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _stopLocation() async {
    final positions = _positions;
    final services = _services;
    _positions = null;
    _services = null;
    await positions?.cancel();
    await services?.cancel();
  }

  Future<void> _switchUser() async {
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;
    // Checkpoint only time already observed; never infer recording after a restart.
    if (draft != null && draft!.phase != RunPhase.finished) {
      draft!.finish(now);
      unawaited(checkpoint());
    }
    final stopped = _stopLocation();
    _owner = _currentUserId();
    draft = null;
    position = null;
    error = null;
    recoveryFailed = false;
    busy = false;
    saving = false;
    loading = true;
    _notify();
    await stopped;
    await _writes;
    try {
      if (_owner != null && (supported || _store != null)) {
        final value = await _draftStore.read(_owner!);
        if (generation != _generation) return;
        if (value != null) {
          final restored = RecordedRun.restore(
            jsonDecode(value) as Map<String, dynamic>,
          );
          if (restored.userId != _owner) {
            throw const FormatException('Draft owner');
          }
          draft = restored;
        }
      }
    } catch (_) {
      if (generation == _generation) {
        recoveryFailed = true;
        error = 'run_storage_error';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> retryRecovery() => ready = _switchUser();

  Future<bool> checkpoint() async {
    final run = draft;
    if (run == null || run.id == _deletingId) return true;
    final value = jsonEncode(run.toJson(now));
    final operation = _writes.then((_) => _draftStore.write(run.userId, value));
    _writes = operation.catchError((Object _) {});
    try {
      await operation;
      if (identical(run, draft) && error == 'run_storage_error') error = null;
      return true;
    } catch (_) {
      if (identical(run, draft)) {
        error = 'run_storage_error';
        _notify();
      }
      return false;
    }
  }

  Future<void> prepare({required String title, required String text}) async {
    await ready;
    if (busy ||
        loading ||
        draft?.phase == RunPhase.finished ||
        _owner == null) {
      return;
    }
    final generation = _generation;
    busy = true;
    _notify();
    try {
      final enabled = await location.enabled();
      if (generation != _generation) return;
      if (!enabled) {
        await _stopLocation();
        position = null;
        draft?.gap();
        locationMessage = 'run_location_disabled';
        return;
      }
      var permission = await location.permission();
      if (generation != _generation) return;
      if (permission == LocationPermission.denied) {
        permission = await location.requestPermission();
      }
      if (generation != _generation) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        await _stopLocation();
        position = null;
        draft?.gap();
        locationMessage = permission == LocationPermission.deniedForever
            ? 'run_permission_settings'
            : 'run_permission_denied';
        return;
      }
      final precision = await location.accuracy();
      if (generation != _generation) return;
      if (precision == LocationAccuracyStatus.reduced) {
        await _stopLocation();
        if (generation != _generation) return;
        position = null;
        draft?.gap();
        locationMessage = 'run_precise_required';
        return;
      }
      if (_positions != null) return;
      locationMessage = 'run_gps_acquiring';
      _services = location.serviceStatus.listen((status) {
        if (generation != _generation) return;
        if (status == ServiceStatus.disabled) {
          position = null;
          draft?.gap();
          locationMessage = 'run_location_disabled';
          unawaited(_stopLocation());
          _notify();
        }
      }, onError: (Object _) {});
      _positions = location
          .positions(title: title, text: text)
          .listen(
            (fix) {
              if (generation != _generation) return;
              if (position != null && !fix.time.isAfter(position!.time)) return;
              if (fix.usableAt(now)) {
                position = fix;
                locationMessage = 'run_gps_ready';
              } else {
                position = null;
                locationMessage = 'run_gps_acquiring';
              }
              draft?.addFix(fix, now);
              _notify();
            },
            onError: (Object _) {
              if (generation != _generation) return;
              position = null;
              draft?.gap();
              locationMessage = 'run_gps_outage';
              unawaited(_stopLocation());
              _notify();
            },
            onDone: () {
              if (generation != _generation) return;
              position = null;
              draft?.gap();
              locationMessage = 'run_gps_outage';
              unawaited(_stopLocation());
              _notify();
            },
          );
      _startTimer();
    } catch (_) {
      if (generation == _generation) {
        position = null;
        draft?.gap();
        locationMessage = 'run_gps_outage';
        await _stopLocation();
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!hasFix && locationMessage == 'run_gps_ready') {
        draft?.gap();
        locationMessage = 'run_gps_outage';
      }
      if (draft?.phase == RunPhase.recording && timer.tick % 5 == 0) {
        // shortcut: 5s checkpoints; use a journal if every fix must survive process death.
        unawaited(checkpoint());
      }
      _notify();
    });
  }

  Future<void> start() async {
    if (!canStart) return;
    draft = RecordedRun(
      id: const Uuid().v4(),
      userId: _owner!,
      startedAt: now,
      firstFix: position!,
    );
    await checkpoint();
    _notify();
  }

  Future<void> pause() async {
    draft?.pause(now);
    await checkpoint();
    _notify();
  }

  Future<void> resume() async {
    if (_owner != _currentUserId()) return;
    draft?.resume(now);
    _startTimer();
    await checkpoint();
    _notify();
  }

  Future<void> finish() async {
    draft?.finish(now);
    _timer?.cancel();
    _timer = null;
    _notify();
    await _stopLocation();
    await checkpoint();
  }

  Future<void> releasePreviewLocation() async {
    if (draft != null && draft!.phase != RunPhase.finished) return;
    _timer?.cancel();
    _timer = null;
    await _stopLocation();
  }

  Future<Activity?> save(String name) async {
    final run = draft;
    final generation = _generation;
    if (saving ||
        run == null ||
        run.phase != RunPhase.finished ||
        run.userId != _currentUserId()) {
      return null;
    }
    saving = true;
    error = null;
    _notify();
    try {
      if (!await checkpoint()) return null;
      if (generation != _generation || run.userId != _currentUserId()) {
        return null;
      }
      final result = await _client
          .rpc(
            'save_recorded_run',
            params: {
              'p_id': run.id,
              'p_started_at': run.startedAt.toUtc().toIso8601String(),
              'p_distance_m': run.distanceM,
              'p_active_ms': run.activeMs,
              'p_segments': run.routeJson,
              'p_name': name,
            },
          )
          .timeout(const Duration(seconds: 30));
      final activity = Activity.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
      if (activity.id != run.id || activity.userId != run.userId) {
        throw const FormatException('Unexpected saved run');
      }
      if (generation != _generation) return null;
      // Delete only after the server confirms this stable ID. Lost replies are retryable.
      _deletingId = run.id;
      await _writes;
      await _draftStore.delete(run.userId);
      if (identical(draft, run)) draft = null;
      return generation == _generation ? activity : null;
    } catch (_) {
      if (identical(draft, run)) error = 'run_save_error';
      return null;
    } finally {
      if (_deletingId == run.id) _deletingId = null;
      if (generation == _generation) {
        saving = false;
        _notify();
      }
    }
  }

  Future<bool> discard() async {
    if (saving || _owner == null) return false;
    final owner = _owner!;
    final generation = _generation;
    await finish();
    final run = draft;
    _deletingId = run?.id;
    try {
      await _writes;
      if (generation != _generation) return false;
      await _draftStore.delete(owner);
      if (generation != _generation) return false;
      draft = null;
      recoveryFailed = false;
      error = null;
      _notify();
      return true;
    } catch (_) {
      error = 'run_storage_error';
      _notify();
      return false;
    } finally {
      if (_deletingId == run?.id) _deletingId = null;
    }
  }

  Future<List<List<RunFix>>?> loadRoute(String activityId) async {
    final userId = _currentUserId();
    if (userId == null) return null;
    final row = await _client
        .from('activity_routes')
        .select('segments')
        .eq('activity_id', activityId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null || _currentUserId() != userId
        ? null
        : parseRunSegments(row['segments'] as List);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    unawaited(_auth?.cancel());
    unawaited(_stopLocation());
    super.dispose();
  }
}
