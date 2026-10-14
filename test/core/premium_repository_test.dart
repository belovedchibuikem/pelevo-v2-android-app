import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_store.dart';
import '../support/api_adapter.dart';
import '../support/premium_fixture.dart';

void main() {
  PremiumRepository repository(Dio dio) => PremiumRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('plans parse public price fields', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/premium/plans');
        return jsonResponse([premiumPlanFixture()]);
      }),
    );
    final plans = await repository(dio).plans(CancelToken());
    expect(plans.single.name, 'Pelevo Plus Monthly');
    expect(plans.single.priceLabel, 'NGN 25.00 / month');
  });

  test('checkout rejects hashes and references', () {
    expect(
      () => PremiumCheckout.parse({
        ...premiumCheckoutFixture(),
        'request_hash': 'abc',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => PremiumCheckout.parse({
        ...premiumCheckoutFixture(),
        'idempotency_key': 'key',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => PremiumCheckout.parse({
        ...premiumCheckoutFixture(),
        'provider_reference': 'ref',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(PremiumCheckout.parse(premiumCheckoutFixture()).state, 'pending');
  });

  test('checkout posts idempotency and plan', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/premium/checkout');
        expect(request.headers['Idempotency-Key'], 'premium-once');
        expect(request.data['plan_id'], 'plan-monthly');
        expect(request.data['provider'], 'paystack');
        return jsonResponse(premiumCheckoutFixture(), status: 201);
      }),
    );
    final checkout = await repository(dio).checkout(
      planId: 'plan-monthly',
      provider: 'paystack',
      idempotencyKey: 'premium-once',
    );
    expect(checkout.checkoutUrl, 'https://paystack.test/pay');
  });

  test('plus removes home and search ads for an active listener or creator', () {
    expect(pelevoPlusRemovesAds(null), isFalse);
    expect(
      pelevoPlusRemovesAds(PremiumAccount.parse(premiumAccountFixture())),
      isFalse,
    );
    expect(
      pelevoPlusRemovesAds(
        PremiumAccount.parse(
          premiumAccountFixture(entitlement: premiumEntitlementFixture()),
        ),
      ),
      isTrue,
    );
  });

  test('restored store products match the Plus plan, not a payout gateway', () {
    final plans = [
      PremiumPlan.parse(
        premiumPlanFixture(
          id: 'plan-monthly',
          slug: 'plus-monthly',
          interval: 'month',
        ),
      ),
      PremiumPlan.parse(
        premiumPlanFixture(
          id: 'plan-yearly-trial',
          slug: 'plus-3-month-trial',
          interval: 'year',
          trialMonths: 3,
        ),
      ),
      PremiumPlan.parse(
        premiumPlanFixture(
          id: 'plan-yearly',
          slug: 'plus-yearly',
          interval: 'year',
        ),
      ),
    ];
    expect(
      planForPlusProduct(plans, PremiumStore.monthlyProductId)?.id,
      'plan-monthly',
    );
    expect(
      planForPlusProduct(plans, PremiumStore.yearlyProductId)?.id,
      'plan-yearly',
    );
    expect(planForPlusProduct(plans, 'paystack'), isNull);
  });
}
