/// Converts a pace entered as `minutes:seconds` or decimal minutes per km.
double? parsePaceMinutesPerKm(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;

  if (!normalized.contains(':')) {
    final pace = double.tryParse(normalized);
    return pace != null && pace.isFinite && pace > 0 ? pace : null;
  }

  final parts = normalized.split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null ||
      seconds == null ||
      minutes < 0 ||
      seconds < 0 ||
      seconds >= 60) {
    return null;
  }

  final pace = minutes + seconds / 60;
  return pace > 0 ? pace : null;
}

/// Computes total duration in minutes from distance (km) and pace (min/km).
double? durationFromPace({
  required double distanceKm,
  required double paceMinutesPerKm,
}) {
  if (!distanceKm.isFinite ||
      !paceMinutesPerKm.isFinite ||
      distanceKm <= 0 ||
      paceMinutesPerKm <= 0) {
    return null;
  }
  return distanceKm * paceMinutesPerKm;
}
