String formatPace(
  double? paceMinutesPerKm, {
  String invalid = '-:--',
  bool zeroAsValid = false,
}) {
  if (paceMinutesPerKm == null ||
      !paceMinutesPerKm.isFinite ||
      paceMinutesPerKm < 0 ||
      (paceMinutesPerKm == 0 && !zeroAsValid)) {
    return invalid;
  }
  final totalSeconds = (paceMinutesPerKm * 60).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatDurationMinutes(double? durationMinutes, {String invalid = '--'}) {
  if (durationMinutes == null ||
      !durationMinutes.isFinite ||
      durationMinutes < 0) {
    return invalid;
  }
  final totalSeconds = (durationMinutes * 60).round();
  final hours = totalSeconds ~/ 3600;
  final remaining = totalSeconds % 3600;
  final minutes = remaining ~/ 60;
  final seconds = remaining % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
