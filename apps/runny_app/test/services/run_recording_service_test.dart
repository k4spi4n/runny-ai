import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runny_app/models/recorded_run.dart';
import 'package:runny_app/services/run_draft_store.dart';
import 'package:runny_app/services/run_location_source.dart';
import 'package:runny_app/services/run_recording_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryDraftStore implements RunDraftStore {
  final values = <String, String>{};
  bool failWrites = false;
  Future<void> Function()? afterDelete;
  @override
  Future<String?> read(String userId) async => values[userId];
  @override
  Future<void> write(String userId, String value) async {
    if (failWrites) throw StateError('Disk full');
    values[userId] = value;
  }

  @override
  Future<void> delete(String userId) async {
    values.remove(userId);
    await afterDelete?.call();
  }
}

class FakeRunLocation extends RunLocationSource {
  final fixes = StreamController<RunFix>.broadcast(sync: true);
  final services = StreamController<ServiceStatus>.broadcast(sync: true);
  bool isEnabled = true;
  LocationPermission access = LocationPermission.whileInUse;
  LocationAccuracyStatus precision = LocationAccuracyStatus.precise;
  @override
  Future<bool> enabled() async => isEnabled;
  @override
  Future<LocationPermission> permission() async => access;
  @override
  Future<LocationPermission> requestPermission() async => access;
  @override
  Future<LocationAccuracyStatus> accuracy() async => precision;
  @override
  Stream<ServiceStatus> get serviceStatus => services.stream;
  @override
  Stream<RunFix> positions({required String title, required String text}) =>
      fixes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime clock;
  late String? owner;
  late MemoryDraftStore store;
  late FakeRunLocation location;
  late RunRecordingService recorder;
  late SupabaseClient client;
  late List<Map<String, dynamic>> saves;
  Map<String, dynamic>? committed;
  bool loseReply = false;
  Completer<void>? replyGate;

  setUp(() async {
    clock = DateTime.utc(2026, 11, 3);
    owner = 'runner-a';
    store = MemoryDraftStore();
    location = FakeRunLocation();
    saves = [];
    committed = null;
    loseReply = false;
    replyGate = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/save_recorded_run');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        saves.add(body);
        committed ??= {
          'id': body['p_id'],
          'user_id': owner,
          'started_at': body['p_started_at'],
          'distance_km': (body['p_distance_m'] as num) / 1000,
          'duration_min': (body['p_active_ms'] as num) / 60000,
          'has_gps_route': true,
        };
        if (loseReply) throw http.ClientException('Response lost after commit');
        await replyGate?.future;
        return http.Response(
          jsonEncode(committed),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    recorder = RunRecordingService(
      client,
      store: store,
      location: location,
      now: () => clock,
      currentUserId: () => owner,
      watchAuth: false,
    );
    await recorder.ready;
  });

  tearDown(() async {
    recorder.dispose();
    await location.fixes.close();
    await location.services.close();
    await client.dispose();
  });

  Future<void> prepare() => recorder.prepare(title: 'GPS', text: 'GPS active');
  void fix(double latitude) =>
      location.fixes.add(RunFix(latitude, 106, clock, 5));
  void advance(int seconds) => clock = clock.add(Duration(seconds: seconds));
  Future<void> start() async {
    await prepare();
    fix(10);
    expect(recorder.canStart, isTrue);
    await recorder.start();
  }

  test(
    'permission and location-service recovery gate Start on a fresh fix',
    () async {
      location.isEnabled = false;
      await prepare();
      expect(recorder.locationMessage, 'run_location_disabled');
      expect(recorder.canStart, isFalse);
      location.isEnabled = true;
      location.access = LocationPermission.denied;
      await prepare();
      expect(recorder.locationMessage, 'run_permission_denied');
      location.access = LocationPermission.deniedForever;
      await prepare();
      expect(recorder.locationMessage, 'run_permission_settings');
      location.access = LocationPermission.whileInUse;
      await prepare();
      expect(recorder.canStart, isFalse);
      fix(10);
      expect(recorder.canStart, isTrue);
      advance(11);
      expect(recorder.canStart, isFalse);
    },
  );

  test(
    'pause and GPS errors preserve active timer and separate segments',
    () async {
      await start();
      advance(5);
      fix(10.0002);
      await recorder.pause();
      advance(30);
      fix(11);
      expect(recorder.draft!.elapsedMs(clock), 5000);
      await recorder.resume();
      advance(1);
      fix(11);
      location.fixes.addError(StateError('GPS unavailable'));
      await Future<void>.delayed(Duration.zero);
      advance(20);
      expect(recorder.draft!.elapsedMs(clock), 26000);
      await prepare();
      fix(12);
      await recorder.finish();
      expect(recorder.draft!.segments.length, 3);
      expect(recorder.draft!.distanceM, closeTo(22.24, 0.1));
      expect(store.values[owner], isNotNull);
    },
  );

  test(
    'approximate permission blocks recording until precise access is enabled',
    () async {
      location.precision = LocationAccuracyStatus.reduced;
      await prepare();
      expect(recorder.locationMessage, 'run_precise_required');
      expect(location.fixes.hasListener, isFalse);
      fix(10);
      expect(recorder.livePosition, isNull);
      expect(recorder.canStart, isFalse);
      location.precision = LocationAccuracyStatus.precise;
      await prepare();
      fix(10);
      expect(recorder.canStart, isTrue);
      location.precision = LocationAccuracyStatus.reduced;
      await prepare();
      expect(recorder.livePosition, isNull);
      expect(recorder.canStart, isFalse);
      expect(location.fixes.hasListener, isFalse);
    },
  );

  test(
    'map exposes only fresh accurate fixes and recovers on the next update',
    () async {
      await prepare();
      fix(10);
      expect(recorder.livePosition?.latitude, 10);
      advance(11);
      expect(recorder.livePosition, isNull);
      expect(recorder.canStart, isFalse);
      fix(10.0001);
      expect(recorder.livePosition?.latitude, 10.0001);
      location.fixes.add(
        RunFix(30, 106, clock.subtract(const Duration(seconds: 30)), 5),
      );
      expect(recorder.livePosition?.latitude, 10.0001);
      advance(1);
      location.fixes.add(RunFix(30, 106, clock, 200));
      expect(recorder.livePosition, isNull);
      advance(1);
      fix(10.0002);
      expect(recorder.livePosition?.latitude, 10.0002);
      expect(recorder.canStart, isTrue);
    },
  );

  test(
    'lost save response retains draft and retries the same immutable ID',
    () async {
      await start();
      advance(5);
      fix(10.0002);
      await recorder.finish();
      final id = recorder.draft!.id;
      loseReply = true;
      expect(await recorder.save('Outdoor run'), isNull);
      expect(committed!['id'], id); // Server already committed.
      expect(recorder.draft!.id, id);
      expect(store.values[owner], isNotNull);
      expect(recorder.error, 'run_save_error');
      loseReply = false;
      final saved = await recorder.save('Outdoor run');
      expect(saved!.id, id);
      expect(saved.hasGpsRoute, isTrue);
      expect(saves.length, 2);
      expect(saves[0], saves[1]);
      expect(recorder.draft, isNull);
      expect(store.values[owner], isNull);
    },
  );

  test('failed local persistence blocks upload and can be retried', () async {
    await start();
    store.failWrites = true;
    await recorder.finish();
    expect(await recorder.save('Outdoor run'), isNull);
    expect(saves, isEmpty);
    expect(recorder.error, 'run_storage_error');
    store.failWrites = false;
    expect(await recorder.save('Outdoor run'), isNotNull);
  });

  test('simultaneous save taps submit only one request', () async {
    await start();
    await recorder.finish();
    replyGate = Completer<void>();
    final saving = recorder.save('Outdoor run');
    await Future<void>.delayed(Duration.zero);
    expect(await recorder.save('Outdoor run'), isNull);
    replyGate!.complete();
    expect(await saving, isNotNull);
    expect(saves.length, 1);
  });

  test(
    'a lifecycle checkpoint cannot recreate a confirmed saved draft',
    () async {
      await start();
      await recorder.finish();
      final deleting = Completer<void>();
      final releaseDelete = Completer<void>();
      store.afterDelete = () async {
        deleting.complete();
        await releaseDelete.future;
      };
      final saving = recorder.save('Outdoor run');
      await deleting.future;
      await recorder.checkpoint();
      releaseDelete.complete();
      expect(await saving, isNotNull);
      expect(store.values[owner], isNull);
    },
  );

  test('a save reply for a different ID cannot remove the draft', () async {
    await start();
    await recorder.finish();
    committed = {
      'id': 'another-run',
      'user_id': owner,
      'started_at': clock.toIso8601String(),
      'distance_km': 0,
      'duration_min': 0,
    };
    expect(await recorder.save('Outdoor run'), isNull);
    expect(store.values[owner], isNotNull);
    expect(recorder.draft, isNotNull);
  });

  test('a delayed save reply cannot open a previous account run', () async {
    await start();
    await recorder.finish();
    replyGate = Completer<void>();
    final saving = recorder.save('Outdoor run');
    await Future<void>.delayed(Duration.zero);
    owner = 'runner-b';
    await recorder.retryRecovery();
    replyGate!.complete();
    expect(await saving, isNull);
    expect(recorder.draft, isNull);
    expect(store.values['runner-a'], isNotNull);
  });

  test(
    'unfinished checkpoint restores as a finished draft without counting downtime',
    () async {
      await start();
      advance(10);
      await recorder.checkpoint();
      final id = recorder.draft!.id;
      recorder.dispose();
      advance(3600);
      recorder = RunRecordingService(
        client,
        store: store,
        location: location,
        now: () => clock,
        currentUserId: () => owner,
        watchAuth: false,
      );
      await recorder.ready;
      expect(recorder.draft!.id, id);
      expect(recorder.draft!.phase, RunPhase.finished);
      expect(recorder.draft!.elapsedMs(clock), 10000);
      expect(store.values[owner], isNotNull);
      expect(await recorder.discard(), isTrue);
      expect(store.values[owner], isNull);
    },
  );

  test(
    'switching accounts hides GPS and keeps each owner draft separate',
    () async {
      await start();
      final id = recorder.draft!.id;
      owner = 'runner-b';
      await recorder.retryRecovery();
      expect(recorder.draft, isNull);
      expect(recorder.position, isNull);
      expect(store.values['runner-a'], isNotNull);
      expect(await recorder.save('Wrong owner'), isNull);
      owner = 'runner-a';
      await recorder.retryRecovery();
      expect(recorder.draft!.id, id);
    },
  );
}
