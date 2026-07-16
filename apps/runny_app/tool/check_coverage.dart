import 'dart:io';

const _minimumCoverage = <String, double>{
  'lib/utils/activity_parser.dart': 80,
  'lib/services/activity_screenshot_import_service.dart': 35,
  'lib/services/ai_insight_service.dart': 80,
  'lib/services/entitlement_service.dart': 80,
  'lib/services/subscription_service.dart': 45,
  'lib/services/training_service.dart': 6,
};

void main(List<String> args) {
  final lcov = File(args.isEmpty ? 'coverage/lcov.info' : args.single);
  if (!lcov.existsSync()) {
    stderr.writeln('Coverage report not found: ${lcov.path}');
    exitCode = 2;
    return;
  }

  final coverage = <String, ({int found, int hit})>{};
  String? source;
  var found = 0;
  var hit = 0;

  for (final rawLine in lcov.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      source = line.substring(3).replaceAll(r'\', '/');
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && source != null) {
      coverage[source] = (found: found, hit: hit);
      source = null;
    }
  }

  var failed = false;
  for (final threshold in _minimumCoverage.entries) {
    final record = coverage[threshold.key];
    if (record == null || record.found == 0) {
      stderr.writeln('FAIL ${threshold.key}: missing from LCOV');
      failed = true;
      continue;
    }
    final percent = 100 * record.hit / record.found;
    final status = percent >= threshold.value ? 'PASS' : 'FAIL';
    stdout.writeln(
      '$status ${threshold.key}: '
      '${percent.toStringAsFixed(1)}% '
      '(${record.hit}/${record.found}, minimum ${threshold.value.toStringAsFixed(1)}%)',
    );
    failed |= percent < threshold.value;
  }

  final services = coverage.entries.where(
    (entry) => entry.key.startsWith('lib/services/'),
  );
  final serviceFound = services.fold<int>(
    0,
    (total, entry) => total + entry.value.found,
  );
  final serviceHit = services.fold<int>(
    0,
    (total, entry) => total + entry.value.hit,
  );
  final servicePercent = serviceFound == 0
      ? 0.0
      : 100 * serviceHit / serviceFound;
  stdout.writeln(
    'INFO all instrumented services: '
    '${servicePercent.toStringAsFixed(1)}% '
    '($serviceHit/$serviceFound; long-term target 50.0%)',
  );

  if (failed) exitCode = 1;
}
