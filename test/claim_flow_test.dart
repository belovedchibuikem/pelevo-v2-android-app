import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/claim_data.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/creator/podcast_claim_screens.dart';
import 'support/api_adapter.dart';
import 'support/claim_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
    ClaimDraft draft = const ClaimDraft(),
  }) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/screen/claim-podcast',
          builder: (_, _) => const ClaimPodcastScreen(),
        ),
        GoRoute(
          path: '/screen/claim-method',
          builder: (_, _) => const ClaimMethodScreen(),
        ),
        GoRoute(
          path: '/screen/claim-rss',
          builder: (_, _) => const ClaimRssScreen(),
        ),
        GoRoute(
          path: '/screen/claim-enter-code',
          builder: (_, _) => const ClaimEnterCodeScreen(),
        ),
        GoRoute(
          path: '/screen/claim-success',
          builder: (_, _) => const ClaimSuccessScreen(),
        ),
        GoRoute(
          path: '/screen/claim-failed',
          builder: (_, _) => const ClaimFailedScreen(),
        ),
        GoRoute(
          path: '/screen/claim-manual-code',
          builder: (_, _) => const ClaimManualCodeScreen(),
        ),
        GoRoute(
          path: '/screen/relationship-podcast',
          builder: (_, _) => const Scaffold(body: Text('Podcast page')),
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
            accessToken: 'test',
            refreshToken: 'refresh',
            deviceId: 'device',
            user: {'id': 'test-user', 'name': 'Listener'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (draft.show != null || draft.start != null) {
      if (draft.show != null) {
        container.read(claimDraftProvider.notifier).selectShow(draft.show!);
      }
      if (draft.start != null) {
        container.read(claimDraftProvider.notifier).rememberStart(draft.start!);
      }
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: PelevoTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('claim continue stays disabled until a searched show is selected', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/claim-podcast',
      adapter: ApiAdapter(
        (request) => jsonResponse({
          'shows': [claimShowFixture()],
        }),
      ),
    );

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Owned');
    await tester.ensureVisible(find.text('Search'));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('The Relationship Podcast'), findsNothing);
    await tester.ensureVisible(find.text('Owned Show'));
    await tester.tap(find.text('Owned Show'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('email verify uses the server result instead of a seeded code', (
    tester,
  ) async {
    var verified = false;
    await mount(
      tester,
      location: '/screen/claim-enter-code',
      draft: ClaimDraft(
        show: ClaimShow.fromJson(claimShowFixture()),
        start: ClaimStart.fromApi(claimStartFixture(), method: 'email'),
      ),
      adapter: ApiAdapter((request) {
        if (request.path.endsWith('/verify')) {
          expect(request.data, {'code': '123456'});
          verified = true;
          return jsonResponse({'claim_id': 'claim-1', 'state': 'verified'});
        }
        if (request.path == '/me') {
          return jsonResponse(
            profileFixture()..['capabilities'] = {'creator_access': true},
          );
        }
        return jsonResponse({'accepted': true});
      }),
    );

    expect(find.text('hello@therelationshippodcast.com'), findsNothing);
    expect(find.text('o****@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.ensureVisible(find.text('Verify Code'));
    await tester.tap(find.text('Verify Code'));
    await tester.pumpAndSettle();
    expect(verified, isTrue);
    expect(find.text('You’re verified!'), findsOneWidget);
    expect(find.textContaining('Owned Show'), findsOneWidget);
  });

  testWidgets('wrong email code stays on the enter-code screen', (tester) async {
    await mount(
      tester,
      location: '/screen/claim-enter-code',
      draft: ClaimDraft(
        show: ClaimShow.fromJson(claimShowFixture()),
        start: ClaimStart.fromApi(claimStartFixture(), method: 'email'),
      ),
      adapter: ApiAdapter(
        (request) => jsonResponse(null, status: 422),
      ),
    );

    await tester.enterText(find.byType(TextField), '000000');
    await tester.ensureVisible(find.text('Verify Code'));
    await tester.tap(find.text('Verify Code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter verification code'), findsWidgets);
    expect(find.text('You’re verified!'), findsNothing);
  });
}
