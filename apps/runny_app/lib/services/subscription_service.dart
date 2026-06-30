
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_models.dart';

class SubscriptionService {
  final _supabase = Supabase.instance.client;

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _supabase
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price', ascending: true);
    
    return (response as List).map((json) => SubscriptionPlan.fromJson(json)).toList();
  }

  Future<UserSubscription?> getActiveSubscription() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('user_subscriptions')
        .select('*, subscription_plans(*)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();
    
    if (response == null) return null;
    return UserSubscription.fromJson(response);
  }

  /// Tạo liên kết thanh toán PayOS cho [plan] qua Edge Function
  /// `payos-create-payment` và trả về `checkoutUrl` để client mở.
  /// Việc kích hoạt/gia hạn subscription do webhook `payos-webhook` thực hiện
  /// sau khi thanh toán thành công (không tin client tự ghi subscription).
  Future<String> createPaymentLink(SubscriptionPlan plan) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final res = await _supabase.functions.invoke(
      'payos-create-payment',
      body: {'plan_id': plan.id},
    );

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

  Future<void> cancelSubscription(String subscriptionId) async {
    await _supabase
        .from('user_subscriptions')
        .update({'cancel_at_period_end': true})
        .eq('id', subscriptionId);
  }
}
