
enum SubscriptionDuration {
  weekly,
  monthly,
  yearly,
}

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String currency;
  final SubscriptionDuration durationType;
  final List<String> benefits;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.durationType,
    required this.benefits,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      currency: json['currency'],
      durationType: SubscriptionDuration.values.firstWhere(
        (e) => e.name == json['duration_type'],
      ),
      benefits: List<String>.from(json['benefits'] ?? []),
      isActive: json['is_active'],
    );
  }
}

class UserSubscription {
  final String id;
  final String userId;
  final String planId;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final bool cancelAtPeriodEnd;
  final SubscriptionPlan? plan;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.cancelAtPeriodEnd,
    this.plan,
  });

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      userId: json['user_id'],
      planId: json['plan_id'],
      status: json['status'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      cancelAtPeriodEnd: json['cancel_at_period_end'],
      plan: json['subscription_plans'] != null 
          ? SubscriptionPlan.fromJson(json['subscription_plans'])
          : null,
    );
  }
}
