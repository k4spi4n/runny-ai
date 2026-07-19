class OnboardingMetrics {
  const OnboardingMetrics({
    required this.weightKg,
    required this.heightCm,
    this.maxHr,
  });

  static const double minWeightKg = 20;
  static const double maxWeightKg = 300;
  static const double minHeightCm = 90;
  static const double maxHeightCm = 250;
  static const int minMaxHr = 80;
  static const int maxMaxHr = 230;

  final double weightKg;
  final double heightCm;
  final int? maxHr;

  double get bmi {
    final heightInM = heightCm / 100;
    return double.parse(
      (weightKg / (heightInM * heightInM)).toStringAsFixed(2),
    );
  }

  static OnboardingMetrics? tryParse({
    required String weight,
    required String height,
    required String maxHr,
  }) {
    final parsedWeight = double.tryParse(weight.trim().replaceAll(',', '.'));
    final parsedHeight = double.tryParse(height.trim().replaceAll(',', '.'));
    final trimmedMaxHr = maxHr.trim();
    final parsedMaxHr = trimmedMaxHr.isEmpty
        ? null
        : int.tryParse(trimmedMaxHr);

    if (parsedWeight == null ||
        parsedHeight == null ||
        parsedWeight < minWeightKg ||
        parsedWeight > maxWeightKg ||
        parsedHeight < minHeightCm ||
        parsedHeight > maxHeightCm ||
        (trimmedMaxHr.isNotEmpty &&
            (parsedMaxHr == null ||
                parsedMaxHr < minMaxHr ||
                parsedMaxHr > maxMaxHr))) {
      return null;
    }

    return OnboardingMetrics(
      weightKg: parsedWeight,
      heightCm: parsedHeight,
      maxHr: parsedMaxHr,
    );
  }

  Map<String, dynamic> toProfileUpdate({String? gender}) => {
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'bmi': bmi,
    'max_hr': maxHr,
    'gender': gender,
  };
}
