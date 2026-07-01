import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_models.dart';
import 'subscription_service.dart';

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
  final SupabaseClient _supabase;

  EntitlementProvider({
    SubscriptionService? subscriptionService,
    SupabaseClient? supabase,
  })  : _subscriptionService = subscriptionService ?? SubscriptionService(),
        _supabase = supabase ?? Supabase.instance.client;

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

  /// Quy tắc gate phía client (đồng bộ với RPC check_ai_access):
  /// 'chat' luôn cho phép; 'plan'/'food' yêu cầu không phải tier free.
  bool canUse(String feature) {
    if (feature == 'plan' || feature == 'food') {
      return _tier != AccessTier.free;
    }
    return true;
  }

  /// Tải lại tier từ Supabase. Gọi sau đăng nhập, khi mở Dashboard, và sau khi
  /// quay lại từ cổng thanh toán.
  Future<void> refresh() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
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
      final profile = await _supabase
          .from('profiles')
          .select('trial_ends_at')
          .eq('id', user.id)
          .maybeSingle();

      final trialRaw = profile?['trial_ends_at'];
      _trialEndsAt = trialRaw is String ? DateTime.tryParse(trialRaw) : null;
      _subscription = sub;

      final now = DateTime.now();
      if (sub != null && sub.isActive) {
        _tier = AccessTier.paid;
      } else if (_trialEndsAt != null && _trialEndsAt!.isAfter(now)) {
        _tier = AccessTier.trial;
      } else {
        _tier = AccessTier.free;
      }
    } catch (e) {
      debugPrint('Entitlement refresh failed: $e');
      // Giữ tier hiện tại nếu lỗi mạng — tránh hạ quyền oan người dùng.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
