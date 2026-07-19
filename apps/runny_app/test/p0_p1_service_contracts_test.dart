import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:runny_app/models/subscription_models.dart';
import 'package:runny_app/services/edge_function_result.dart';
import 'package:runny_app/services/entitlement_service.dart';
import 'package:runny_app/services/paywall_exception.dart';
import 'package:runny_app/services/subscription_service.dart';
import 'package:runny_app/services/training_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateNiceMocks([
  MockSpec<EntitlementDataSource>(),
  MockSpec<SubscriptionService>(),
  MockSpec<SubscriptionDataSource>(),
  MockSpec<TrainingPlanJobClient>(),
])
import 'p0_p1_service_contracts_test.mocks.dart';

SubscriptionPlan _plan() => SubscriptionPlan(
  id: '20000000-0000-4000-8000-000000000001',
  name: 'Runny tháng',
  price: 99000,
  currency: 'VND',
  durationType: SubscriptionDuration.monthly,
  benefits: const ['AI'],
  isActive: true,
);

Map<String, dynamic> _planJson() => {
  'id': '20000000-0000-4000-8000-000000000001',
  'name': 'Runny tháng',
  'price': 99000,
  'currency': 'VND',
  'duration_type': 'monthly',
  'benefits': ['AI'],
  'is_active': true,
};

Map<String, dynamic> _subscriptionJson() => {
  'id': '30000000-0000-4000-8000-000000000001',
  'user_id': '10000000-0000-4000-8000-000000000001',
  'plan_id': '20000000-0000-4000-8000-000000000001',
  'status': 'active',
  'start_date': '2026-07-01T00:00:00Z',
  'end_date': '2099-08-01T00:00:00Z',
  'cancel_at_period_end': false,
  'subscription_plans': _planJson(),
};

void main() {
  group('EntitlementProvider', () {
    late MockEntitlementDataSource dataSource;
    late MockSubscriptionService subscriptionService;

    setUp(() {
      dataSource = MockEntitlementDataSource();
      subscriptionService = MockSubscriptionService();
    });

    test('clears client UX state when there is no signed-in user', () async {
      when(dataSource.currentUserId).thenReturn(null);
      final provider = EntitlementProvider(
        dataSource: dataSource,
        subscriptionService: subscriptionService,
      );

      await provider.refresh();

      expect(provider.tier, AccessTier.unknown);
      expect(provider.trialEndsAt, isNull);
      expect(provider.subscription, isNull);
      expect(provider.loading, isFalse);
      verifyNever(subscriptionService.getActiveSubscription());
      verifyNever(dataSource.getEntitlementStatus());
    });

    test('uses the server tier and trial timestamp', () async {
      when(dataSource.currentUserId).thenReturn('user-1');
      when(
        subscriptionService.getActiveSubscription(),
      ).thenAnswer((_) async => null);
      when(dataSource.getEntitlementStatus()).thenAnswer(
        (_) async => {'tier': 'trial', 'trial_ends_at': '2099-07-30T12:00:00Z'},
      );
      final provider = EntitlementProvider(
        dataSource: dataSource,
        subscriptionService: subscriptionService,
      );

      await provider.refresh();

      expect(provider.tier, AccessTier.trial);
      expect(provider.isTrial, isTrue);
      expect(provider.trialDaysLeft, greaterThan(0));
      expect(
        provider.accountCreatedAt,
        DateTime.parse(
          '2099-07-30T12:00:00Z',
        ).subtract(const Duration(days: 14)),
      );
      expect(provider.canUse('plan'), isTrue);
      expect(provider.canUse('vision'), isTrue);
    });

    test(
      'free tier exposes AI features while server enforces quotas',
      () async {
        when(dataSource.currentUserId).thenReturn('user-1');
        when(
          subscriptionService.getActiveSubscription(),
        ).thenAnswer((_) async => null);
        when(
          dataSource.getEntitlementStatus(),
        ).thenAnswer((_) async => {'tier': 'free', 'trial_ends_at': null});
        final provider = EntitlementProvider(
          dataSource: dataSource,
          subscriptionService: subscriptionService,
        );

        await provider.refresh();

        expect(provider.isFree, isTrue);
        expect(provider.canUse('chat'), isTrue);
        expect(provider.canUse('plan'), isTrue);
        expect(provider.canUse('vision'), isTrue);
        expect(provider.canUse('food'), isTrue);
        expect(provider.canUse('unknown'), isFalse);
      },
    );

    test('falls back to an active subscription for an unknown tier', () async {
      final subscription = UserSubscription.fromJson(_subscriptionJson());
      when(dataSource.currentUserId).thenReturn('user-1');
      when(
        subscriptionService.getActiveSubscription(),
      ).thenAnswer((_) async => subscription);
      when(
        dataSource.getEntitlementStatus(),
      ).thenAnswer((_) async => {'tier': 'unexpected'});
      final provider = EntitlementProvider(
        dataSource: dataSource,
        subscriptionService: subscriptionService,
      );

      await provider.refresh();

      expect(provider.tier, AccessTier.paid);
      expect(provider.subscription, same(subscription));
    });

    test('retains the last tier when refresh fails', () async {
      when(dataSource.currentUserId).thenReturn('user-1');
      when(
        subscriptionService.getActiveSubscription(),
      ).thenAnswer((_) async => null);
      when(
        dataSource.getEntitlementStatus(),
      ).thenAnswer((_) async => {'tier': 'free'});
      final provider = EntitlementProvider(
        dataSource: dataSource,
        subscriptionService: subscriptionService,
      );
      await provider.refresh();
      when(
        subscriptionService.getActiveSubscription(),
      ).thenThrow(Exception('offline'));

      await provider.refresh();

      expect(provider.tier, AccessTier.free);
      expect(provider.loading, isFalse);
    });
  });

  group('SubscriptionService', () {
    late MockSubscriptionDataSource dataSource;
    late SubscriptionService service;

    setUp(() {
      dataSource = MockSubscriptionDataSource();
      service = SubscriptionService(
        dataSource: dataSource,
        timestampMicros: () => 1234567890,
      );
    });

    test('maps plans and an active subscription', () async {
      when(dataSource.fetchPlans()).thenAnswer((_) async => [_planJson()]);
      when(dataSource.currentUserId).thenReturn('user-1');
      when(
        dataSource.fetchActiveSubscription('user-1'),
      ).thenAnswer((_) async => _subscriptionJson());

      final plans = await service.getPlans();
      final subscription = await service.getActiveSubscription();

      expect(plans.single.name, 'Runny tháng');
      expect(plans.single.durationType, SubscriptionDuration.monthly);
      expect(subscription?.isActive, isTrue);
      expect(subscription?.plan?.price, 99000);
    });

    test('does not query subscriptions without a user', () async {
      when(dataSource.currentUserId).thenReturn(null);

      expect(await service.getActiveSubscription(), isNull);
      verifyNever(dataSource.fetchActiveSubscription(any));
    });

    test('reuses one idempotency key for repeated payment attempts', () async {
      when(dataSource.currentUserId).thenReturn('user-1');
      when(dataSource.createPayment(any, any)).thenAnswer(
        (_) async => const EdgeFunctionResult(
          status: 200,
          data: {'checkoutUrl': 'https://pay.payos.vn/web/checkout123'},
        ),
      );

      final first = await service.createPaymentLink(_plan());
      final second = await service.createPaymentLink(_plan());
      final verification = verify(
        dataSource.createPayment(_plan().id, captureAny),
      );

      expect(first, second);
      expect(verification.callCount, 2);
      expect(verification.captured.toSet(), hasLength(1));
      expect(
        verification.captured.toSet().single,
        'pay:user-1:${_plan().id}:1234567890',
      );
    });

    test('accepts JSON text and surfaces provider errors', () async {
      when(dataSource.currentUserId).thenReturn('user-1');
      when(dataSource.createPayment(any, any)).thenAnswer(
        (_) async => const EdgeFunctionResult(
          status: 200,
          data: '{"checkoutUrl":"https://pay.payos.vn/web/from-json-response"}',
        ),
      );
      expect(
        await service.createPaymentLink(_plan()),
        'https://pay.payos.vn/web/from-json-response',
      );

      final failing = SubscriptionService(
        dataSource: dataSource,
        timestampMicros: () => 42,
      );
      when(dataSource.createPayment(any, any)).thenAnswer(
        (_) async => const EdgeFunctionResult(
          status: 503,
          data: {'error': 'Cổng thanh toán đang bận.'},
        ),
      );
      await expectLater(
        failing.createPaymentLink(_plan()),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Cổng thanh toán đang bận.'),
          ),
        ),
      );
    });

    test('rejects missing users and malformed success responses', () async {
      when(dataSource.currentUserId).thenReturn(null);
      await expectLater(
        service.createPaymentLink(_plan()),
        throwsA(isA<Exception>()),
      );

      when(dataSource.currentUserId).thenReturn('user-1');
      when(dataSource.createPayment(any, any)).thenAnswer(
        (_) async => const EdgeFunctionResult(status: 200, data: {}),
      );
      await expectLater(
        service.createPaymentLink(_plan()),
        throwsA(isA<Exception>()),
      );
    });

    test('cancellation goes through the server RPC data source', () async {
      when(dataSource.requestCancellation()).thenAnswer((_) async {});

      await service.cancelSubscription();

      verify(dataSource.requestCancellation()).called(1);
    });
  });

  group('TrainingService durable plan enqueue', () {
    late MockTrainingPlanJobClient planJobClient;
    late TrainingService service;

    setUp(() {
      planJobClient = MockTrainingPlanJobClient();
      service = TrainingService(
        supabase: SupabaseClient('http://localhost:54321', 'anon-key'),
        planJobClient: planJobClient,
      );
    });

    test(
      'sends bounded server-owned queue fields and returns schedule',
      () async {
        when(planJobClient.currentUserId).thenReturn('user-1');
        when(planJobClient.enqueue(any)).thenAnswer(
          (_) async => const EdgeFunctionResult(
            status: 202,
            data: {'schedule_id': 'schedule-1', 'status': 'pending'},
          ),
        );

        final scheduleId = await service.startPlanGeneration(
          goal: 'Hoàn thành 10K an toàn',
          startDate: DateTime(2026, 7, 20, 15),
          endDate: DateTime(2026, 8, 20, 8),
        );
        final body =
            verify(planJobClient.enqueue(captureAny)).captured.single
                as Map<String, Object?>;

        expect(scheduleId, 'schedule-1');
        expect(body['goal'], 'Hoàn thành 10K an toàn');
        expect(body['start_date'], '2026-07-20');
        expect(body['end_date'], '2026-08-20');
        expect(
          body['idempotency_key'],
          isA<String>().having(
            (value) => value,
            'shape',
            matches(RegExp(r'^plan:[0-9]+:[a-f0-9]{32}$')),
          ),
        );
        expect(body, isNot(contains('model')));
        expect(body, isNot(contains('system')));
      },
    );

    test('maps upgrade responses to PaywallException', () async {
      when(planJobClient.currentUserId).thenReturn('user-1');
      when(planJobClient.enqueue(any)).thenAnswer(
        (_) async => const EdgeFunctionResult(
          status: 402,
          data: {'error': 'upgrade_required'},
        ),
      );

      await expectLater(
        service.startPlanGeneration(
          goal: 'Tạo lịch marathon',
          startDate: DateTime(2026, 7, 20),
        ),
        throwsA(isA<PaywallException>()),
      );
    });

    test('rejects anonymous and malformed successful responses', () async {
      when(planJobClient.currentUserId).thenReturn(null);
      await expectLater(
        service.startPlanGeneration(
          goal: 'Tạo lịch 5K',
          startDate: DateTime(2026, 7, 20),
        ),
        throwsA(isA<Exception>()),
      );

      when(planJobClient.currentUserId).thenReturn('user-1');
      when(planJobClient.enqueue(any)).thenAnswer(
        (_) async => const EdgeFunctionResult(status: 200, data: {}),
      );
      await expectLater(
        service.createGoalBasedPlan(
          'Tạo lịch 5K',
          startDate: DateTime(2026, 7, 20),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
