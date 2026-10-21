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

  test(
    'plus removes home and search ads for an active listener or creator',
    () {
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
      expect(
        pelevoPlusRemovesAds(
          PremiumAccount.parse(
            premiumAccountFixture(
              entitlement: premiumEntitlementFixture(state: 'in_grace_period'),
            ),
          ),
        ),
        isTrue,
      );
      expect(
        pelevoPlusRemovesAds(
          PremiumAccount.parse(
            premiumAccountFixture(
              entitlement: premiumEntitlementFixture(state: 'expired'),
            ),
          ),
        ),
        isFalse,
      );
      expect(
        pelevoPlusRemovesAds(
          PremiumAccount.parse(
            premiumAccountFixture(
              entitlement: premiumEntitlementFixture(state: 'canceled'),
            ),
          ),
        ),
        isFalse,
      );
    },
  );

  test('store account token is the user UUID and nothing else', () {
    expect(
      storeAccountToken('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'),
      'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    );
    expect(storeAccountToken(' test-user '), isNull);
    expect(storeAccountToken(''), isNull);
    expect(storeAccountToken(null), isNull);
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

  test('charges keep the billed currency exponent', () {
    expect(formatPremiumAmount(160000, 'NGN'), 'NGN 1600.00');
    expect(formatPremiumAmount(6999, 'ZAR'), 'ZAR 69.99');
    expect(formatPremiumAmount(1800, 'XOF'), 'XOF 1800');
    expect(formatPremiumAmount(1800, 'XAF'), 'XAF 1800');
    expect(formatPremiumPrice(2500, 'NGN', 'month'), 'NGN 25.00 / month');
  });

  test('billing country comes from the subscription, not a profile guess', () {
    final subscription = PremiumSubscription.parse({
      'id': 'sub-1',
      'state': 'active',
      'provider': 'google',
      'current_period_start': '2026-09-10T00:00:00Z',
      'current_period_end': '2026-10-10T00:00:00Z',
      'plan_id': 'plan-monthly',
      'billing_country_code': 'za',
      'billing_currency': 'zar',
      'is_in_intro_offer': true,
    });
    expect(subscription.billingCountryCode, 'ZA');
    expect(subscription.billingCurrency, 'ZAR');
    expect(subscription.isInIntroOffer, isTrue);
    expect(subscription.billingLabel, 'Billed in South Africa (ZAR)');
    expect(
      () => PremiumSubscription.parse({
        'id': 'sub-1',
        'state': 'active',
        'provider': 'google',
        'current_period_start': '2026-09-10T00:00:00Z',
        'current_period_end': '2026-10-10T00:00:00Z',
        'plan_id': 'plan-monthly',
        'billing_country_code': 'Nigeria',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('store management links stay on the billing platform', () {
    expect(
      plusStoreSubscriptionUri(
        provider: 'google',
        productId: PremiumStore.monthlyProductId,
      ).toString(),
      'https://play.google.com/store/account/subscriptions?package=com.Podemeraldltd.pelevo&sku=pelevo_plus_monthly',
    );
    expect(plusStoreSubscriptionUri(provider: 'apple')?.host, 'apps.apple.com');
    expect(plusStoreSubscriptionUri(provider: 'paystack'), isNull);
    expect(
      storeAccountToken('6f9619ff-8b86-d011-b42d-00cf4fc964ff'),
      '6f9619ff-8b86-d011-b42d-00cf4fc964ff',
    );
    expect(storeAccountToken('listener@pelevo.com'), isNull);
  });
}
