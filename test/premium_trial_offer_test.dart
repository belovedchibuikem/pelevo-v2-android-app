import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_trial_banner.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('shows on every 8th session after an 8-day quiet period', () {
    final first = DateTime.utc(2026, 10, 1);
    expect(
      premiumTrialShouldShow(
        premium: false,
        sessionCount: 8,
        lastShownAt: null,
        now: first,
      ),
      isTrue,
    );
    expect(
      premiumTrialShouldShow(
        premium: false,
        sessionCount: 7,
        lastShownAt: null,
        now: first,
      ),
      isFalse,
    );
    expect(
      premiumTrialShouldShow(
        premium: true,
        sessionCount: 8,
        lastShownAt: null,
        now: first,
      ),
      isFalse,
    );
    expect(
      premiumTrialShouldShow(
        premium: false,
        sessionCount: 16,
        lastShownAt: first,
        now: first.add(const Duration(days: 7)),
      ),
      isFalse,
    );
    expect(
      premiumTrialShouldShow(
        premium: false,
        sessionCount: 16,
        lastShownAt: first,
        now: first.add(const Duration(days: 8)),
      ),
      isTrue,
    );
  });

  test('local sessions survive and the server decision wins', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final remote = _ScriptedRemote();
    final coordinator = PremiumTrialCoordinator(
      store: PremiumTrialLocalStore(preferences),
      remote: remote,
      sessionId: () => 'session-fixed',
      clock: () => DateTime.utc(2026, 10, 9),
    );
    remote.evaluation = const PremiumTrialEvaluation(
      premium: false,
      eligible: true,
      sessionCount: 8,
      lastShownAt: null,
      planId: 'plan-trial',
    );
    expect(await coordinator.shouldPresent('user-1'), isTrue);
    expect(await coordinator.shouldPresent('user-1'), isTrue);
    expect(remote.sessions, ['session-fixed']);

    remote.fail = true;
    remote.premiumWhenOffline = false;
    final offline = PremiumTrialCoordinator(
      store: PremiumTrialLocalStore(preferences),
      remote: remote,
      sessionId: () => 'session-nine',
      clock: () => DateTime.utc(2026, 10, 9),
    );
    expect(await offline.shouldPresent('user-1'), isFalse);
    expect(
      preferences.getInt('pelevo.promo.plus-1-month-trial.user-1.sessions'),
      9,
    );
  });

  test('offline hides the offer when Premium status is unknown', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final remote = _ScriptedRemote()..fail = true;
    final coordinator = PremiumTrialCoordinator(
      store: PremiumTrialLocalStore(preferences),
      remote: remote,
      sessionId: () => 'session-1',
    );
    expect(await coordinator.shouldPresent('user-1'), isFalse);
  });

  testWidgets(
    'banner claims the trial and still lets the screen receive taps',
    (tester) async {
      final remote = _ScriptedRemote();
      final coordinator = PremiumTrialCoordinator(
        store: PremiumTrialLocalStore(await _prefs()),
        remote: remote,
        sessionId: () => 'banner-session',
        clock: () => DateTime.utc(2026, 10, 9),
      );
      remote.evaluation = const PremiumTrialEvaluation(
        premium: false,
        eligible: true,
        sessionCount: 8,
        lastShownAt: null,
        planId: 'plan-trial',
      );
      var keptListening = 0;
      final router = GoRouter(
        initialLocation: '/screen/home-feed',
        routes: [
          GoRoute(
            path: '/screen/home-feed',
            builder:
                (_, _) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => keptListening++,
                      child: const Text('Keep listening'),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/screen/premium-plans',
            builder: (_, _) => const Scaffold(body: Text('Paywall')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialAuthSessionProvider.overrideWithValue(
              const AuthSession(
                accessToken: 'token',
                refreshToken: 'refresh',
                deviceId: 'device',
                user: {'id': 'user-1', 'name': 'Listener'},
              ),
            ),
            premiumTrialCoordinatorProvider.overrideWithValue(coordinator),
          ],
          child: MaterialApp.router(
            theme: PelevoTheme.dark,
            routerConfig: router,
            builder:
                (context, child) => Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    PremiumTrialBannerHost(router: router),
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Claim Offer'), findsOneWidget);
      expect(find.text('Try 1 Month Free'), findsOneWidget);
      expect(
        find.text(
          'Enjoy ad-free and offline podcast listening on Pelevo Plus.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep listening'));
      await tester.pump();
      expect(keptListening, 1);

      await tester.tap(find.text('Claim Offer'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/screen/premium-plans',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['offer'],
        'plus-1-month-trial',
      );
      expect(remote.shown, 1);
    },
  );

  testWidgets('dismiss hides the banner without opening the paywall', (
    tester,
  ) async {
    final remote =
        _ScriptedRemote()
          ..evaluation = const PremiumTrialEvaluation(
            premium: false,
            eligible: true,
            sessionCount: 8,
            lastShownAt: null,
            planId: 'plan-trial',
          );
    final router = GoRouter(
      initialLocation: '/screen/home-feed',
      routes: [
        GoRoute(
          path: '/screen/home-feed',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAuthSessionProvider.overrideWithValue(
            const AuthSession(
              accessToken: 'token',
              refreshToken: 'refresh',
              deviceId: 'device',
              user: {'id': 'user-1', 'name': 'Listener'},
            ),
          ),
          premiumTrialCoordinatorProvider.overrideWithValue(
            PremiumTrialCoordinator(
              store: PremiumTrialLocalStore(await _prefs()),
              remote: remote,
              sessionId: () => 'dismiss-session',
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: PelevoTheme.dark,
          routerConfig: router,
          builder:
              (context, child) => Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  PremiumTrialBannerHost(router: router),
                ],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Claim Offer'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/screen/home-feed');
    expect(remote.shown, 1);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

class _ScriptedRemote implements PremiumTrialRemote {
  PremiumTrialEvaluation evaluation = const PremiumTrialEvaluation(
    premium: false,
    eligible: false,
    sessionCount: 1,
    lastShownAt: null,
    planId: null,
  );
  bool fail = false;
  bool? premiumWhenOffline;
  final List<String> sessions = [];
  int shown = 0;

  @override
  Future<void> markShown() async {
    shown++;
  }

  @override
  Future<bool?> readPremiumActive() async =>
      fail ? premiumWhenOffline : evaluation.premium;

  @override
  Future<PremiumTrialEvaluation> recordSession(String sessionId) async {
    if (fail) throw StateError('offline');
    if (!sessions.contains(sessionId)) sessions.add(sessionId);
    return evaluation;
  }
}
