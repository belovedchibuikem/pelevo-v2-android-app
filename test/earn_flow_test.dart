import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/earn/earn_screens.dart';
import 'package:pelevo/features/earn/earn_wallet_data.dart';
import 'package:pelevo/features/earn/withdrawal_screens.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'support/api_adapter.dart';
import 'support/earn_fixture.dart';

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
          path: '/screen/earn',
          builder: (_, _) => const EarnHomeScreen(),
        ),
        GoRoute(
          path: '/screen/earn-player',
          builder: (_, _) => const EarnPlayerScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw',
          builder: (_, _) => const WithdrawHomeScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw-setup-flutterwave',
          builder: (_, _) => const WithdrawSetupFlutterwaveScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw-amount',
          builder: (_, _) => const WithdrawAmountScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw-review',
          builder: (_, _) => const WithdrawReviewScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw-success',
          builder: (_, _) => const WithdrawSuccessScreen(),
        ),
        GoRoute(
          path: '/screen/earn-wallet',
          builder: (_, _) => const EarnWalletScreen(),
        ),
        GoRoute(
          path: '/screen/withdraw-history',
          builder: (_, _) => const WithdrawHistoryScreen(),
        ),
        GoRoute(
          path: '/screen/profile-invite',
          builder: (_, _) => const ProfileInviteScreen(),
        ),
        GoRoute(
          path: '/screen/share-card-home',
          builder: (_, _) => const Scaffold(body: Text('Share cards')),
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

  testWidgets('earn catalog retries after failure and opens a real episode', (
    tester,
  ) async {
    var failed = true;
    await mount(
      tester,
      location: '/screen/earn',
      adapter: ApiAdapter((request) {
        if (request.path == '/earn/access') {
          return jsonResponse({'allowed': true, 'country': 'US'});
        }
        if (request.path == '/earn/wallet') {
          return jsonResponse(earnWalletFixture());
        }
        if (failed) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(
          request.path == '/earn/shows'
              ? earnShowsFixture()
              : earnEpisodesFixture(),
        );
      }),
    );
    expect(find.text('The Honest Bunch'), findsNothing);
    failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('1 coin = \$0.004 USD'), findsOneWidget);
    await tester.tap(find.text('Train Your Mind Daily'));
    await tester.pumpAndSettle();
    expect(find.text('Earn Playback'), findsOneWidget);
  });

  testWidgets('flutterwave setup collects a Nigerian bank account', (
    tester,
  ) async {
    var posted = false;
    await mount(
      tester,
      location: '/screen/withdraw-setup-flutterwave',
      adapter: ApiAdapter((request) {
        if (request.path == '/payout-methods') posted = true;
        return jsonResponse(earnWalletFixture());
      }),
    );
    expect(find.text('Set up Bank Transfer'), findsOneWidget);
    expect(find.text('Account number'), findsOneWidget);
    expect(find.textContaining('not offered by the payout API'), findsNothing);
    await tester.tap(find.text('Verify & Link Bank Transfer'));
    await tester.pumpAndSettle();
    expect(posted, isFalse);
  });

  testWidgets('confirmed withdrawal shows the server receipt only', (
    tester,
  ) async {
    var posted = false;
    await mount(
      tester,
      location: '/screen/withdraw-review',
      adapter: ApiAdapter((request) {
        if (request.path == '/payout-methods') {
          return jsonResponse([earnPayoutMethodFixture()]);
        }
        if (request.path == '/earn/wallet') {
          return jsonResponse(earnWalletFixture());
        }
        if (request.path == '/withdrawals' && request.method == 'POST') {
          posted = true;
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          return jsonResponse(earnWithdrawalFixture(), status: 201);
        }
        return jsonResponse(earnWalletFixture());
      }),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WithdrawReviewScreen)),
    );
    container
        .read(withdrawDraftProvider.notifier)
        .select(EarnPayoutMethod.parse(earnPayoutMethodFixture()));
    container.read(withdrawDraftProvider.notifier).setCoins(BigInt.from(1250));
    await tester.pump();
    await tester.tap(find.text('Confirm Withdrawal'));
    await tester.pumpAndSettle();
    expect(posted, isTrue);
    expect(find.text('Withdrawal queued'), findsOneWidget);
    expect(find.textContaining('1250 coins will process'), findsOneWidget);
  });

  testWidgets('invite screen binds the server code and copies the deep link', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/profile-invite',
      adapter: ApiAdapter(
        (request) => jsonResponse(
          inviteFixture(),
          status: request.method == 'POST' ? 201 : 200,
        ),
      ),
    );
    expect(find.text('PELEVOTEST1'), findsOneWidget);
    expect(find.text('PELEVO-ADESOLA'), findsNothing);
    expect(find.text('Copy Invite Code'), findsOneWidget);
  });

  testWidgets('earn stays closed when the connection is not in the US', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/earn',
      adapter: ApiAdapter((request) {
        if (request.path == '/earn/access') {
          return jsonResponse({'allowed': false, 'country': null});
        }
        return jsonResponse(earnShowsFixture());
      }),
    );
    expect(find.text("You're not on a US IP"), findsOneWidget);
    expect(find.text('VPN is allowed'), findsNothing);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.text('The Honest Bunch'), findsNothing);
    expect(find.text('Reward Rules'), findsNothing);
  });

  testWidgets('a locked earn episode cannot open playback', (tester) async {
    await mount(
      tester,
      location: '/screen/earn',
      adapter: ApiAdapter((request) {
        if (request.path == '/earn/access') {
          return jsonResponse({'allowed': true, 'country': 'US'});
        }
        if (request.path == '/earn/wallet') {
          return jsonResponse(earnWalletFixture());
        }
        if (request.path == '/earn/shows') {
          return jsonResponse(earnShowsFixture());
        }
        return jsonResponse([
          earnEpisodeFixture(
            title: 'Locked Episode',
            lockedUntil: '2099-01-01T00:00:00Z',
            audioUrl: null,
          ),
        ]);
      }),
    );
    expect(find.text('Locked Episode'), findsWidgets);
    await tester.tap(find.text('Locked Episode').first);
    await tester.pumpAndSettle();
    expect(find.text('Earn Playback'), findsNothing);
    expect(find.textContaining('locked for 72 hours'), findsOneWidget);
  });
}
