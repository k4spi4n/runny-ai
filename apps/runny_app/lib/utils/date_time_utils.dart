DateTime dateWithTime(DateTime date, DateTime time) {
  if (date.isUtc) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );
  }
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    time.second,
    time.millisecond,
    time.microsecond,
  );
}
