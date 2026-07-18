/// Tạo prompt phân tích với tên đầy đủ của hoạt động.
String formatActivityAnalysisPrompt({
  required String template,
  required String? activityName,
  required String fallbackName,
}) {
  final normalizedName = activityName?.trim();
  final displayName = normalizedName == null || normalizedName.isEmpty
      ? fallbackName
      : normalizedName;
  return template.replaceFirst('%s', displayName);
}
