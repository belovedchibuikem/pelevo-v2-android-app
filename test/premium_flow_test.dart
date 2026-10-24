import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/premium/premium_store.dart';
import 'package:pelevo/features/premium/premium_system_screens.dart';
import 'package:pelevo/features/premium/storefront_price.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/premium_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
    Map<String, StorefrontPrice>? quotes,
  }) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localeTestValue = const Locale('en', 'NG');
    if (quotes != null) {
      PremiumStore.instance.debugInstallQuotes(quotes);
    }
    addTearDown(PremiumStore.instance.debugClearQuotes);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in premiumSystemScreens.where(
          (item) => item.section == 'Pelevo Premium',
        ))
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/home-feed',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/screen/auth-sign-in',
          builder: (_, _) => const Scaffold(body: Text('Sign in')),
        ),
        GoRoute(
          path: '/screen/browse',
          builder: (_, _) => const Scaffold(body: Text('Browse')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        selectedShowIdProvider.overrideWith(CatalogHarnessShowId.new),
        selectedEpisodeIdProvider.overrideWith(CatalogHarnessEpisodeId.new),
        initialAuthSessionProvider.overrideWithValue(
          const AuthSession(
            accessToken: 'test-access',
            refreshToken: 'test-refresh',
            deviceId: 'test-device',
            user: {'id': 'test-user', 'name': 'Test user'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PelevoTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
  }

  ApiAdapter _adapter({
    void Function(RequestOptions request)? onCheckout,
    List<Map<String, dynamic>>? plans,
    Map<String, dynamic>? account,
  }) => ApiAdapter((request) {
    if (request.path == '/me') return jsonResponse(profileFixture());
    if (request.path == '/premium/plans') {
      return jsonResponse(plans ?? [premiumPlanFixture()]);
    }
    if (request.path == '/premium/me') {
      return jsonResponse(account ?? premiumAccountFixture());
    }
    if (request.path == '/premium/invoices') {
      return jsonResponse([premiumInvoiceFixture()]);
    }
    if (request.path == '/premium/exclusive') {
      return jsonResponse([premiumExclusiveFixture()]);
    }
    if (request.path == '/premium/checkout' && request.method == 'POST') {
      onCheckout?.call(request);
      return jsonResponse(premiumCheckoutFixture(), status: 201);
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('restore uses the store and does not list unused gateways', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-restore',
      adapter: _adapter(),
    );
    expect(find.text('paystack'), findsNothing);
    expect(find.text('flutterwave'), findsNothing);
    expect(find.text('paypal'), findsNothing);
    expect(find.text('Payment reference'), findsNothing);
    expect(
      find.textContaining('Pelevo Plus is billed through Google Play.'),
      findsOneWidget,
    );
    expect(find.text('Restore Purchase'), findsWidgets);
  });

  testWidgets('plans bind the server name instead of invented naira copy', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-plans',
      adapter: _adapter(),
      quotes: {
        PremiumStore.monthlyProductId: const StorefrontPrice(
          priceString: '₦1,600.00',
          currencyCode: 'NGN',
        ),
      },
    );
    expect(find.text('Pelevo Plus Monthly'), findsOneWidget);
    expect(find.text('₦1,600.00'), findsOneWidget);
    expect(find.text('Subscribe for ₦1,600.00'), findsOneWidget);
    expect(find.text('NGN 25.00 / month'), findsNothing);
    expect(find.text(r'$10.50 / month'), findsNothing);
  });

  testWidgets('plans wait for the store instead of converting a shelf price', (
    tester,
  ) async {
    await mount(tester, location: '/screen/premium-plans', adapter: _adapter());
    expect(find.text(storefrontPricePending), findsOneWidget);
    expect(find.text('NGN 25.00 / month'), findsNothing);
    expect(find.text(r'$10.50 / month'), findsNothing);
    expect(find.textContaining('₦'), findsNothing);
  });

  testWidgets(
    'live pay securely uses the store and does not claim entitlement',
    (tester) async {
      var posted = false;
      await mount(
        tester,
        location: '/screen/premium-payment',
        adapter: _adapter(onCheckout: (_) => posted = true),
      );
      await tester.ensureVisible(find.text('Pay Securely'));
      await tester.tap(find.text('Pay Securely'));
      await tester.pumpAndSettle();
      expect(posted, isFalse);
      expect(find.text('You’re All Set!'), findsNothing);
      expect(
        find.text(
          'Pelevo Plus is purchased through Google Play or the App Store.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('offer query selects the 3-month trial on the paywall', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-plans?offer=plus-3-month-trial',
      quotes: {
        PremiumStore.monthlyProductId: const StorefrontPrice(
          priceString: '₦1,600.00',
          currencyCode: 'NGN',
          introductoryPeriodLabel: '3 months',
          introductoryPriceIsFree: true,
        ),
        PremiumStore.yearlyProductId: const StorefrontPrice(
          priceString: 'R699.99',
          currencyCode: 'ZAR',
          introductoryPeriodLabel: '3 months',
          introductoryPriceIsFree: true,
        ),
      },
      adapter: _adapter(
        plans: [
          premiumPlanFixture(
            id: 'plan-monthly',
            slug: 'plus-monthly',
            name: 'Monthly',
            priceMinor: 160000,
            interval: 'month',
            trialMonths: 3,
          ),
          premiumPlanFixture(
            id: 'plan-yearly',
            slug: 'plus-yearly',
            name: 'Annual',
            priceMinor: 1760000,
            interval: 'year',
            trialMonths: 3,
          ),
        ],
      ),
    );
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('3 months free'), findsNWidgets(2));
    expect(find.text('1 month free'), findsNothing);
    expect(
      find.text('Free for your first 3 months, then ₦1,600.00'),
      findsOneWidget,
    );
    expect(
      find.text('Free for your first 3 months, then R699.99'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$10.50'), findsNothing);
    expect(find.textContaining(r'$105.00'), findsNothing);
    expect(find.text('Your 3-month free trial is selected.'), findsOneWidget);
    expect(
      find.text(
        'Choose Monthly or Annual. Billing starts automatically when the 3 months end.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim Offer'), findsOneWidget);
    expect(find.textContaining('Promo:'), findsNothing);
  });

  testWidgets('a paid store intro is shown with the store price', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-plans',
      quotes: {
        PremiumStore.monthlyProductId: const StorefrontPrice(
          priceString: 'KES 419.00',
          currencyCode: 'KES',
          introductoryPriceString: 'KES 199.00',
          introductoryPeriodLabel: 'month',
        ),
      },
      adapter: _adapter(),
    );

    expect(
      find.text('Promo: Get your first month for only KES 199.00!'),
      findsOneWidget,
    );
    expect(
      find.text('Pay only KES 199.00 for your first month, then KES 419.00'),
      findsOneWidget,
    );
    expect(find.text('Subscribe for KES 199.00'), findsOneWidget);
    expect(find.text('Start Free Trial'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('a grace-period membership stays labeled and entitled', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-subscription',
      adapter: _adapter(
        account: premiumAccountFixture(
          entitlement: premiumEntitlementFixture(state: 'in_grace_period'),
          subscription: {
            'id': 'sub-1',
            'state': 'in_grace_period',
            'provider': 'google',
            'current_period_start': '2026-09-10T00:00:00Z',
            'current_period_end': '2026-10-10T00:00:00Z',
            'plan_id': 'plan-monthly',
          },
        ),
      ),
    );
    expect(find.text('Grace period'), findsOneWidget);
    expect(find.text('Expired'), findsNothing);
    expect(find.textContaining('Auto-renew is off'), findsNothing);
  });

  testWidgets('turning off auto-renew keeps Plus until the paid period ends', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-subscription',
      adapter: _adapter(
        account: premiumAccountFixture(
          entitlement: premiumEntitlementFixture(),
          subscription: {
            'id': 'sub-1',
            'state': 'active',
            'provider': 'apple',
            'current_period_start': '2026-09-10T00:00:00Z',
            'current_period_end': '2026-10-10T00:00:00Z',
            'plan_id': 'plan-monthly',
            'cancel_at': '2026-10-10T00:00:00Z',
          },
        ),
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Canceled'), findsNothing);
    expect(
      find.textContaining(
        'Auto-renew is off. Pelevo Plus stays available until the period you already paid for ends.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a moved storefront is labeled from the billed country', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/premium-subscription',
      adapter: _adapter(
        plans: [
          premiumPlanFixture(
            id: 'plan-monthly',
            slug: 'plus-monthly',
            interval: 'month',
          ),
        ],
        account: premiumAccountFixture(
          entitlement: premiumEntitlementFixture(),
          subscription: {
            'id': 'sub-1',
            'state': 'active',
            'provider': 'google',
            'current_period_start': '2026-09-10T00:00:00Z',
            'current_period_end': '2026-10-10T00:00:00Z',
            'plan_id': 'plan-monthly',
            'billing_country_code': 'ZA',
            'billing_currency': 'ZAR',
            'is_in_intro_offer': true,
          },
        ),
      ),
    );
    expect(find.textContaining('Billed in South Africa (ZAR)'), findsOneWidget);
    expect(find.textContaining('Introductory offer'), findsOneWidget);
    expect(find.textContaining('Nigeria'), findsNothing);
    expect(
      find.text('Contact support to cancel your subscription'),
      findsNothing,
    );
    expect(find.text('Cancel Subscription'), findsOneWidget);
  });
}
