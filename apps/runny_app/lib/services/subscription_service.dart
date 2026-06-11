
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

  Future<void> subscribe(SubscriptionPlan plan) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // In a real app, you would integrate with a payment gateway here (Stripe, Apple Pay, etc.)
    // For this demo, we'll just create the subscription directly.
    
    DateTime endDate;
    switch (plan.durationType) {
      case SubscriptionDuration.weekly:
        endDate = DateTime.now().add(const Duration(days: 7));
        break;
      case SubscriptionDuration.monthly:
        endDate = DateTime.now().add(const Duration(days: 30));
        break;
      case SubscriptionDuration.yearly:
        endDate = DateTime.now().add(const Duration(days: 365));
        break;
    }

    // Deactivate previous active subscriptions if any
    await _supabase
        .from('user_subscriptions')
        .update({'status': 'cancelled'})
        .eq('user_id', user.id)
        .eq('status', 'active');

    await _supabase.from('user_subscriptions').insert({
      'user_id': user.id,
      'plan_id': plan.id,
      'status': 'active',
      'start_date': DateTime.now().toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    await _supabase
        .from('user_subscriptions')
        .update({'cancel_at_period_end': true})
        .eq('id', subscriptionId);
  }
}
