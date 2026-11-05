import 'run_draft_store_stub.dart'
    if (dart.library.io) 'run_draft_store_io.dart'
    as platform;

abstract class RunDraftStore {
  factory RunDraftStore() => platform.createDraftStore();
  Future<String?> read(String userId);
  Future<void> write(String userId, String value);
  Future<void> delete(String userId);
}
