import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'run_draft_store.dart';

RunDraftStore createDraftStore() => FileRunDraftStore();

class FileRunDraftStore implements RunDraftStore {
  Future<File> _file(String userId) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw ArgumentError('Invalid user ID');
    }
    final root = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${root.path}/run_drafts',
    ).create(recursive: true);
    return File('${directory.path}/$userId.json');
  }

  @override
  Future<String?> read(String userId) async {
    final file = await _file(userId);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String userId, String value) async {
    final file = await _file(userId);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(String userId) async {
    final file = await _file(userId);
    if (await file.exists()) await file.delete();
  }
}
