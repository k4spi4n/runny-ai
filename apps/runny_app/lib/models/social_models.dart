// Models cho Phân hệ 4: Động lực & Tương tác.

/// Một huy hiệu trong danh mục kèm trạng thái đạt được của user hiện tại.
class BadgeProgress {
  final String code;
  final String name;
  final String description;
  final String icon;
  final String thresholdType;
  final num thresholdValue;
  final DateTime? earnedAt;

  BadgeProgress({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.thresholdType,
    required this.thresholdValue,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  factory BadgeProgress.fromJson(Map<String, dynamic> json, {DateTime? earnedAt}) {
    return BadgeProgress(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String? ?? 'emoji_events',
      thresholdType: json['threshold_type'] as String,
      thresholdValue: json['threshold_value'] as num,
      earnedAt: earnedAt,
    );
  }
}

/// Một dòng trên bảng xếp hạng.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final double totalDistanceKm;
  final int activityCount;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalDistanceKm,
    required this.activityCount,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Runner',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      activityCount: (json['activity_count'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Một gợi ý bạn chạy.
class MatchSuggestion {
  final String userId;
  final String displayName;
  final String? city;
  final String? bio;
  final double? preferredPace;
  final double? avgPace;
  final double totalDistanceKm;
  final bool sameCity;

  MatchSuggestion({
    required this.userId,
    required this.displayName,
    this.city,
    this.bio,
    this.preferredPace,
    this.avgPace,
    required this.totalDistanceKm,
    required this.sameCity,
  });

  /// Pace hiển thị: ưu tiên pace mong muốn, sau đó pace trung bình thực tế.
  double? get effectivePace => preferredPace ?? avgPace;

  factory MatchSuggestion.fromJson(Map<String, dynamic> json) {
    return MatchSuggestion(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Runner',
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      preferredPace: (json['preferred_pace_min_per_km'] as num?)?.toDouble(),
      avgPace: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      sameCity: json['same_city'] as bool? ?? false,
    );
  }
}

/// Một lời mời/kết nối ghép đôi.
class RunMatch {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final bool isIncoming;
  final String otherDisplayName;
  final String? otherCity;

  RunMatch({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.isIncoming,
    required this.otherDisplayName,
    this.otherCity,
  });

  factory RunMatch.fromJson(Map<String, dynamic> json, {required bool isIncoming}) {
    // Khi isIncoming: "other" là người gửi (requester); ngược lại là người nhận.
    final requester = json['requester'] as Map<String, dynamic>?;
    final addressee = json['addressee'] as Map<String, dynamic>?;
    final other = isIncoming ? requester : addressee;
    return RunMatch(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: json['status'] as String,
      isIncoming: isIncoming,
      otherDisplayName: other?['display_name'] as String? ?? 'Runner',
      otherCity: other?['city'] as String?,
    );
  }
}
