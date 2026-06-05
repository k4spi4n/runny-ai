// Models cho Issue #30: Quản lý và theo dõi cân nặng.

/// Một lần ghi nhận cân nặng.
class WeightLog {
  final String id;
  final double weightKg;
  final DateTime loggedAt;
  final String? note;

  WeightLog({
    required this.id,
    required this.weightKg,
    required this.loggedAt,
    this.note,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String),
      note: json['note'] as String?,
    );
  }
}

/// Tổng quan tiến trình cân nặng của người dùng.
class WeightGoal {
  final double? current;
  final double? target;
  final double? start;

  WeightGoal({this.current, this.target, this.start});

  bool get hasGoal => target != null && start != null && current != null;

  /// Đang giảm cân (mục tiêu thấp hơn mốc bắt đầu) hay tăng cân.
  bool get isLosing => hasGoal && target! < start!;

  /// Tổng số kg cần thay đổi từ mốc bắt đầu tới mục tiêu.
  double get totalDelta => hasGoal ? (start! - target!).abs() : 0;

  /// Số kg đã thay đổi đúng hướng tính từ mốc bắt đầu.
  double get achievedDelta {
    if (!hasGoal) return 0;
    final moved = isLosing ? (start! - current!) : (current! - start!);
    return moved.clamp(0, totalDelta).toDouble();
  }

  /// Số kg còn lại để đạt mục tiêu (>= 0).
  double get remaining {
    if (!hasGoal) return 0;
    final left = isLosing ? (current! - target!) : (target! - current!);
    return left < 0 ? 0 : left;
  }

  /// Tỉ lệ hoàn thành 0..1.
  double get progress {
    if (!hasGoal || totalDelta == 0) return 0;
    return (achievedDelta / totalDelta).clamp(0, 1).toDouble();
  }

  bool get reached => hasGoal && remaining <= 0.0001;

  factory WeightGoal.fromProfile(Map<String, dynamic> json) {
    double? toD(dynamic v) => v == null ? null : (v as num).toDouble();
    return WeightGoal(
      current: toD(json['weight_kg']),
      target: toD(json['target_weight_kg']),
      start: toD(json['start_weight_kg']),
    );
  }
}
