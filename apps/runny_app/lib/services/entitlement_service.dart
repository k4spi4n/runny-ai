import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_models.dart';
import 'subscription_service.dart';

abstract interface class EntitlementDataSource {
  String? get currentUserId;

  Future<Object?> getEntitlementStatus();
}

class SupabaseEntitlementDataSource implements EntitlementDataSource {
  SupabaseEntitlementDataSource(this._supabase);

  final SupabaseClient _supabase;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<Object?> getEntitlementStatus() =>
      _supabase.rpc('get_entitlement_status');
}

/// Tier quyền lợi của người dùng. Nguồn sự thật ở server (RPC check_ai_access);
/// đây là bản phản chiếu phía client để quyết định UX (gate nút, banner trial).
enum AccessTier { unknown, trial, paid, free }

/// Quản lý trạng thái entitlement: tier hiện tại, ngày hết trial, subscription
/// đang hoạt động. Provider này CHỈ phục vụ UX — gate chi phí thật nằm ở Edge
/// Function. Đừng coi nó là rào chắn an ninh.
class EntitlementProvider extends ChangeNotifier {
  /// Độ dài trial (ngày) — phải khớp với `interval '14 days'` ở migration
  /// paywall (handle_new_user + backfill trial_ends_at).
  static const int trialLengthDays = 14;

  final SubscriptionService _subscriptionService;
  final EntitlementDataSource _dataSource;

  EntitlementProvider({
    SubscriptionService? subscriptionService,
    EntitlementDataSource? dataSource,
    SupabaseClient? supabase,
  }) : _subscriptionService = subscriptionService ?? SubscriptionService(),
       _dataSource =
           dataSource ??
           SupabaseEntitlementDataSource(supabase ?? Supabase.instance.client);

  AccessTier _tier = AccessTier.unknown;
  DateTime? _trialEndsAt;
  UserSubscription? _subscription;
  bool _loading = false;

  AccessTier get tier => _tier;
  bool get isPaid => _tier == AccessTier.paid;
  bool get isTrial => _tier == AccessTier.trial;
  bool get isFree => _tier == AccessTier.free;
  bool get loading => _loading;
  DateTime? get trialEndsAt => _trialEndsAt;
  UserSubscription? get subscription => _subscription;

  /// Ngày tạo tài khoản, suy từ mốc hết trial (trial_ends_at = created_at + 14d).
  /// Dùng để lập lịch nhắc nâng cấp theo tuổi tài khoản.
  DateTime? get accountCreatedAt =>
      _trialEndsAt?.subtract(const Duration(days: trialLengthDays));

  /// Số ngày còn lại của trial (làm tròn lên), 0 nếu đã hết / không áp dụng.
  int get trialDaysLeft {
    final end = _trialEndsAt;
    if (end == null) return 0;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inMinutes / (60 * 24)).ceil();
  }

  /// Mọi tier đều có thể thử các lớp AI đã biết. Hạn mức thật được áp nguyên tử
  /// theo user + feature ở server; free có quota rất thấp, paid/trial thoáng hơn.
  bool canUse(String feature) =>
      const {'onboarding', 'chat', 'plan', 'vision', 'food'}.contains(feature);

  /// Tải lại tier từ Supabase. Gọi sau đăng nhập, khi mở Dashboard, và sau khi
  /// quay lại từ cổng thanh toán.
  Future<void> refresh() async {
    if (_dataSource.currentUserId == null) {
      _tier = AccessTier.unknown;
      _trialEndsAt = null;
      _subscription = null;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final sub = await _subscriptionService.getActiveSubscription();
      final entitlement = await _dataSource.getEntitlementStatus();
      final trialRaw = entitlement is Map ? entitlement['trial_ends_at'] : null;
      _trialEndsAt = trialRaw is String ? DateTime.tryParse(trialRaw) : null;
      _subscription = sub;

      final tier = entitlement is Map ? entitlement['tier'] : null;
      _tier = switch (tier) {
        'paid' => AccessTier.paid,
        'trial' => AccessTier.trial,
        'free' => AccessTier.free,
        _ => sub != null && sub.isActive ? AccessTier.paid : AccessTier.unknown,
      };
    } catch (e) {
      debugPrint('Entitlement refresh failed: $e');
      // Giữ tier hiện tại nếu lỗi mạng — tránh hạ quyền oan người dùng.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
