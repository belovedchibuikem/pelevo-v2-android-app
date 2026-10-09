import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/gifts/gift_screens.dart';
import 'support/api_adapter.dart';
import 'support/gift_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/screen/gift-coin-store',
          builder: (_, _) => const CoinStoreScreen(),
        ),
        GoRoute(
          path: '/screen/gift-wallet',
          builder: (_, _) => const CoinWalletScreen(),
        ),
        GoRoute(
          path: '/screen/gift-purchase-success',
          builder: (_, _) => const PurchaseResultScreen(success: true),
        ),
        GoRoute(
          path: '/screen/gift-purchase-failed',
          builder: (_, _) => const PurchaseResultScreen(success: false),
        ),
        GoRoute(
          path: '/screen/gift-receipt',
          builder: (_, _) => const GiftReceiptScreen(),
        ),
        GoRoute(
          path: '/screen/reels',
          builder: (_, _) => const Scaffold(body: Text('Reels')),
        ),
        GoRoute(
          path: '/screen/profile-help',
          builder: (_, _) => const Scaffold(body: Text('Help')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
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
    await tester.pumpAndSettle();
  }

  ApiAdapter giftsAdapter() => ApiAdapter((request) {
    return jsonResponse(switch (request.path) {
      '/me/age-majority' => {'confirmed': true},
      '/gifts/wallet' => giftWalletFixture(),
      '/gifts/packs' => giftPacksFixture(),
      '/gifts/catalog' => giftCatalogFixture(),
      '/gifts/wallet/activity' => [giftActivityFixture()],
      _ =>
        request.path.startsWith('/gifts/')
            ? giftReceiptFixture(id: request.path.split('/').last)
            : throw StateError(request.path),
    });
  });

  testWidgets('coin store binds server balance and packs without naira', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/gift-coin-store',
      adapter: giftsAdapter(),
    );
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Choose a coin pack'), findsOneWidget);
    expect(find.text('1200 coins'), findsOneWidget);
    expect(find.text('₦1,900'), findsNothing);
    expect(find.text('1250'), findsNothing);
    await tester.tap(find.textContaining('I confirm I am 18'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Purchase not completed'), findsOneWidget);
    expect(
      find.text('In-app purchases are not available on this device.'),
      findsWidgets,
    );
  });

  testWidgets('coin wallet shows ledger event types instead of invented copy', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/gift-wallet',
      adapter: giftsAdapter(),
    );
    expect(find.text('100 coins'), findsOneWidget);
    expect(find.text('iap.verified'), findsOneWidget);
    expect(find.text('Bought 1,200 coins'), findsNothing);
  });

  testWidgets('purchase success stays empty without a verified receipt', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/gift-purchase-success',
      adapter: giftsAdapter(),
    );
    expect(find.text('Coins added!'), findsOneWidget);
    expect(find.text('No completed purchase is available yet.'), findsOneWidget);
    expect(find.text('1200 coins were securely added to your Pelevo wallet.'), findsNothing);
  });

  testWidgets('gift receipt stays empty without a selected gift', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/gift-receipt',
      adapter: giftsAdapter(),
    );
    expect(find.text('No gift receipt is available yet.'), findsOneWidget);
    expect(find.text('Your Applause was sent to Creator.'), findsNothing);
  });
}
