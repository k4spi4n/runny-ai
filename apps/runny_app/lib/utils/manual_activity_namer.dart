/// Creates the default, human-readable title for a manually logged run.
class ManualActivityNamer {
  const ManualActivityNamer._();

  static String create({
    required double distanceKm,
    required DateTime startedAt,
    required String titleTemplate,
    required String morningLabel,
    required String afternoonLabel,
    required String eveningLabel,
  }) {
    final distance = _formatDistance(distanceKm);
    final timeOfDay = _timeOfDay(
      startedAt.hour,
      morningLabel: morningLabel,
      afternoonLabel: afternoonLabel,
      eveningLabel: eveningLabel,
    );
    return titleTemplate
        .replaceFirst('%s', distance)
        .replaceFirst('%s', timeOfDay);
  }

  static String _formatDistance(double distanceKm) {
    if (distanceKm == distanceKm.truncateToDouble()) {
      return distanceKm.toInt().toString();
    }
    return distanceKm.toString();
  }

  static String _timeOfDay(
    int hour, {
    required String morningLabel,
    required String afternoonLabel,
    required String eveningLabel,
  }) {
    if (hour >= 5 && hour < 12) return morningLabel;
    if (hour >= 12 && hour < 18) return afternoonLabel;
    return eveningLabel;
  }
}
