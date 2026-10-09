import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/premium/premium_system_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/premium_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
  }) => ApiAdapter((request) {
    if (request.path == '/me') return jsonResponse(profileFixture());
    if (request.path == '/premium/plans') {
      return jsonResponse(plans ?? [premiumPlanFixture()]);
    }
    if (request.path == '/premium/me') {
      return jsonResponse(premiumAccountFixture());
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

  testWidgets('plans bind the server name instead of invented naira copy', (
    tester,
  ) async {
    await mount(tester, location: '/screen/premium-plans', adapter: _adapter());
    expect(find.text('Pelevo Plus Monthly'), findsOneWidget);
    expect(find.text('₦1,600 / month'), findsOneWidget);
    expect(find.text('NGN 25.00 / month'), findsNothing);
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
      adapter: _adapter(
        plans: [
          premiumPlanFixture(),
          premiumPlanFixture(
            id: 'plan-trial',
            slug: 'plus-3-month-trial',
            name: '3 Months Free',
            priceMinor: 1600000,
            interval: 'year',
            trialMonths: 3,
          ),
        ],
      ),
    );
    expect(find.text('3 Months Free'), findsOneWidget);
    expect(find.text('3 months free'), findsOneWidget);
    expect(find.text('Free for 3 months, then ₦16,000 / year'), findsOneWidget);
    expect(find.text('Your 3-month free trial is selected.'), findsOneWidget);
    expect(find.text('Claim Offer'), findsOneWidget);
  });
}
