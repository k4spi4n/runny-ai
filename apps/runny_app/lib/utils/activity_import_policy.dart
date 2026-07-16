const int maxActivityImportFiles = 10;
const int maxActivityImportFileBytes = 25 * 1024 * 1024;
const int maxActivityImportBatchBytes = 50 * 1024 * 1024;

bool shouldAttachCurrentWeather(DateTime startedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final age = reference.toUtc().difference(startedAt.toUtc());
  return age >= const Duration(minutes: -30) && age <= const Duration(hours: 3);
}
