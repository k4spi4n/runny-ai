import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_models.dart';
import 'edge_function_result.dart';

abstract interface class SubscriptionDataSource {
  String? get currentUserId;

  Future<List<Map<String, dynamic>>> fetchPlans();

  Future<Map<String, dynamic>?> fetchActiveSubscription(String userId);

  Future<EdgeFunctionResult> createPayment(
    String planId,
    String idempotencyKey,
  );

  Future<void> requestCancellation();
}

class SupabaseSubscriptionDataSource implements SubscriptionDataSource {
  SupabaseSubscriptionDataSource(this._supabase);

  final SupabaseClient _supabase;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final response = await _supabase
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price', ascending: true);
    return (response as List)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveSubscription(String userId) async {
    final response = await _supabase
        .from('user_subscriptions')
        .select('*, subscription_plans(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  @override
  Future<EdgeFunctionResult> createPayment(
    String planId,
    String idempotencyKey,
  ) async {
    final response = await _supabase.functions.invoke(
      'payos-create-payment',
      body: {'plan_id': planId, 'idempotency_key': idempotencyKey},
    );
    return EdgeFunctionResult(status: response.status, data: response.data);
  }

  @override
  Future<void> requestCancellation() async {
    await _supabase.rpc('request_subscription_cancellation');
  }
}

class SubscriptionService {
  SubscriptionService({
    SubscriptionDataSource? dataSource,
    int Function()? timestampMicros,
  }) : _dataSource =
           dataSource ??
           SupabaseSubscriptionDataSource(Supabase.instance.client),
       _timestampMicros =
           timestampMicros ?? (() => DateTime.now().microsecondsSinceEpoch);

  final SubscriptionDataSource _dataSource;
  final int Function() _timestampMicros;
  final Map<String, String> _paymentIdempotencyKeys = {};

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _dataSource.fetchPlans();
    return response.map((json) => SubscriptionPlan.fromJson(json)).toList();
  }

  Future<UserSubscription?> getActiveSubscription() async {
    final userId = _dataSource.currentUserId;
    if (userId == null) return null;

    final response = await _dataSource.fetchActiveSubscription(userId);
    if (response == null) return null;
    return UserSubscription.fromJson(response);
  }

  /// Tạo liên kết thanh toán PayOS cho [plan] qua Edge Function
  /// `payos-create-payment` và trả về `checkoutUrl` để client mở.
  /// Việc kích hoạt/gia hạn subscription do webhook `payos-webhook` thực hiện
  /// sau khi thanh toán thành công (không tin client tự ghi subscription).
  Future<String> createPaymentLink(SubscriptionPlan plan) async {
    final userId = _dataSource.currentUserId;
    if (userId == null) throw Exception('User not logged in');
    final idempotencyKey = _paymentIdempotencyKeys.putIfAbsent(
      plan.id,
      () => 'pay:$userId:${plan.id}:${_timestampMicros()}',
    );

    final res = await _dataSource.createPayment(plan.id, idempotencyKey);

    if (res.status != 200) {
      final data = res.data;
      final msg = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Không tạo được liên kết thanh toán. Vui lòng thử lại.';
      throw Exception(msg);
    }

    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final url = data is Map ? data['checkoutUrl'] : null;
    if (url is! String || url.isEmpty) {
      throw Exception('Không tạo được liên kết thanh toán. Vui lòng thử lại.');
    }
    return url;
  }

  /// Đặt hủy-cuối-kỳ cho subscription active của chính người dùng.
  /// Đi qua RPC `request_subscription_cancellation` (SECURITY DEFINER) vì client
  /// KHÔNG còn quyền ghi thẳng vào `user_subscriptions` (chống tự cấp "paid").
  Future<void> cancelSubscription() async {
    await _dataSource.requestCancellation();
  }
}
