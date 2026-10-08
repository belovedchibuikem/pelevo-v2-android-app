import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/creator_audience_screens.dart';
import 'package:pelevo/features/creator/creator_content_screens.dart';
import 'package:pelevo/features/creator/creator_management_screens.dart';
import 'package:pelevo/features/creator/creator_monetization_screens.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/creator/podcast_claim_screens.dart';
import 'support/api_adapter.dart';
import 'support/claim_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/studio_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/screen/creator-studio',
          builder: (_, _) => const CreatorStudioScreen(),
        ),
        GoRoute(
          path: '/screen/creator-dashboard',
          builder: (_, _) => const CreatorDashboardScreen(),
        ),
        GoRoute(
          path: '/screen/claim-podcast',
          builder: (_, _) => const ClaimPodcastScreen(),
        ),
        GoRoute(
          path: '/screen/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/screen/creator-episodes',
          builder: (_, _) => const CreatorEpisodesScreen(),
        ),
        GoRoute(
          path: '/screen/creator-episode-details',
          builder: (_, _) => const CreatorEpisodeDetailsScreen(),
        ),
        GoRoute(
          path: '/screen/creator-studios',
          builder: (_, _) => const CreatorStudiosScreen(),
        ),
        GoRoute(
          path: '/screen/creator-add-studio',
          builder: (_, _) => const CreatorAddStudioScreen(),
        ),
        GoRoute(
          path: '/screen/creator-new-episode',
          builder: (_, _) => const CreatorNewEpisodeScreen(),
        ),
        GoRoute(
          path: '/screen/creator-go-live',
          builder: (_, _) => const CreatorGoLiveScreen(),
        ),
        GoRoute(
          path: '/screen/creator-tax-information',
          builder: (_, _) => const CreatorTaxInformationScreen(),
        ),
        GoRoute(
          path: '/screen/creator-payout-currency',
          builder: (_, _) => const CreatorPayoutCurrencyScreen(),
        ),
        GoRoute(
          path: '/screen/creator-payout-schedule',
          builder: (_, _) => const CreatorPayoutScheduleScreen(),
        ),
        GoRoute(
          path: '/screen/claim-method',
          builder: (_, _) => const ClaimMethodScreen(),
        ),
        GoRoute(
          path: '/screen/creator-reels',
          builder: (_, _) => const CreatorReelsScreen(),
        ),
        GoRoute(
          path: '/screen/creator-reel-details',
          builder: (_, _) => const CreatorReelDetailsScreen(),
        ),
        GoRoute(
          path: '/screen/creator-create-reel',
          builder: (_, _) => const CreatorCreateReelScreen(),
        ),
        GoRoute(
          path: '/screen/creator-monetization',
          builder: (_, _) => const CreatorMonetizationScreen(),
        ),
        GoRoute(
          path: '/screen/creator-transactions',
          builder: (_, _) => const CreatorTransactionHistoryScreen(),
        ),
        GoRoute(
          path: '/screen/creator-transaction-details',
          builder: (_, _) => const CreatorTransactionDetailsScreen(),
        ),
        GoRoute(
          path: '/screen/creator-payout-settings',
          builder: (_, _) => const CreatorPayoutSettingsScreen(),
        ),
        GoRoute(
          path: '/screen/creator-add-payout',
          builder: (_, _) => const CreatorAddPayoutMethodScreen(),
        ),
        GoRoute(
          path: '/screen/creator-audience',
          builder: (_, _) => const CreatorAudienceScreen(),
        ),
        GoRoute(
          path: '/screen/creator-audience-followers',
          builder: (_, _) => const CreatorAudienceFollowersScreen(),
        ),
        GoRoute(
          path: '/screen/creator-audience-supporters',
          builder: (_, _) => const CreatorAudienceSupportersScreen(),
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
            user: {'id': 'test-user', 'name': 'Listener', 'handle': 'owner'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
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
  }

  ApiAdapter workspaceAdapter() => ApiAdapter((request) {
    if (request.path == '/me') {
      return jsonResponse(profileFixture());
    }
    if (request.path == '/reels/drafts') {
      return jsonResponse(studioReelDraftFixture(), status: 201);
    }
    if (request.path == '/studio/episodes' && request.method == 'POST') {
      return jsonResponse(studioEpisodeDraftFixture(), status: 201);
    }
    if (request.path == '/studio/live' && request.method == 'POST') {
      return jsonResponse(studioLiveFixture(state: 'scheduled'), status: 201);
    }
    if (RegExp(r'^/studio/live/[^/]+$').hasMatch(request.path)) {
      return jsonResponse(studioLiveFixture());
    }
    if (request.path == '/studio/payout-settings' && request.method == 'PUT') {
      return jsonResponse(studioPayoutSettingsFixture());
    }
    if (request.path == '/studio/episodes/ep-1') {
      return jsonResponse(studioEpisodeFixture());
    }
    if (request.path == '/studio/reels/reel-1') {
      return jsonResponse(studioReelFixture());
    }
    if (request.path == '/reels/reel-1' && request.method == 'DELETE') {
      return jsonResponse({'deleted': true});
    }
    if (request.path == '/studio/transactions/txn-1') {
      return jsonResponse(studioTransactionFixture());
    }
    if (request.path == '/payout-methods' && request.method == 'POST') {
      return jsonResponse(studioPayoutMethodFixture(), status: 201);
    }
    return jsonResponse(switch (request.path) {
      '/studio' => studioProfileFixture(),
      '/studio/shows' => [studioShowFixture()],
      '/studio/episodes' => [studioEpisodeFixture()],
      '/studio/reels' => [studioReelFixture()],
      '/studio/audience' => studioAudienceFixture(),
      '/studio/audience/followers' => [studioFollowerFixture()],
      '/studio/audience/supporters' => [studioSupporterFixture()],
      '/studio/monetization' => studioMonetizationFixture(),
      '/studio/transactions' => [studioTransactionFixture()],
      '/studio/payout-settings' => studioPayoutSettingsFixture(),
      '/payout-methods' => [studioPayoutMethodFixture()],
      '/studios' => studioTeamFixture(),
      '/search' => {'shows': [claimShowFixture()]},
      _ => throw StateError(request.path),
    });
  });

  testWidgets('studio hub binds the claimed show instead of seeded copy', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-studio',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Studio Owner'), findsOneWidget);
    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('View all studios (1)'), findsOneWidget);
    expect(find.text('Adesola Adeyemi'), findsNothing);
    expect(find.text('The Relationship Podcast'), findsNothing);
    expect(find.text('18.4K'), findsNothing);
    expect(find.text('126K'), findsNothing);
  });

  testWidgets('dashboard shows only server audience and episode fields', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-dashboard',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('Listeners'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Show followers'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Fresh episode'), findsOneWidget);
    expect(find.text('2026-09-09'), findsOneWidget);
    expect(find.text('18.4K'), findsNothing);
    expect(find.text('126K'), findsNothing);
    expect(find.text('2.7K hrs'), findsNothing);
    expect(find.text('12.5%'), findsNothing);
    expect(find.text('Ep 42: The conversation,\nnobody expected...'), findsNothing);
  });

  testWidgets('missing claim keeps the claim CTA and hides seeded studio', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-studio',
      adapter: ApiAdapter(
        (_) => errorResponse(
          status: 403,
          code: 'CLAIM_REQUIRED',
          message: 'A verified show claim is required.',
        ),
      ),
    );

    expect(find.text('A verified show claim is required.'), findsOneWidget);
    expect(find.text('Claim a podcast'), findsOneWidget);
    expect(find.text('Adesola Adeyemi'), findsNothing);
    expect(find.text('The Relationship Podcast'), findsNothing);

    await tester.tap(find.text('Claim a podcast'));
    await tester.pumpAndSettle();
    expect(find.text('Claim your podcast'), findsOneWidget);
  });

  testWidgets('episodes list binds server titles and hides invented plays', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-episodes',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('Fresh episode'), findsOneWidget);
    expect(find.text('2026-09-09 · 20:56'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('The Relationship Podcast'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
    expect(find.text('Ep 42: The conversation\nnobody expected...'), findsNothing);
    expect(find.text('Search creator episodes is not available yet.'), findsNothing);
  });

  testWidgets('episode details use the selected server episode', (tester) async {
    await mount(
      tester,
      location: '/screen/creator-episodes',
      adapter: workspaceAdapter(),
    );

    await tester.ensureVisible(find.text('Fresh episode'));
    await tester.tap(find.text('Fresh episode'));
    await tester.pumpAndSettle();
    expect(find.text('Episode Details'), findsOneWidget);
    expect(find.text('Fresh episode'), findsOneWidget);
    expect(find.text('2026-09-09 · 20:56'), findsOneWidget);
    expect(find.text('Streams'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
    expect(find.text('Ep 42: The conversation\nnobody expected...'), findsNothing);
  });

  testWidgets('episodes keep the claim CTA when studio access is missing', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-episodes',
      adapter: ApiAdapter(
        (_) => errorResponse(
          status: 403,
          code: 'CLAIM_REQUIRED',
          message: 'A verified show claim is required.',
        ),
      ),
    );

    expect(find.text('A verified show claim is required.'), findsOneWidget);
    expect(find.text('Claim a podcast'), findsOneWidget);
    expect(find.text('Fresh episode'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
  });

  testWidgets('reels list binds server captions and hides invented views', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-reels',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Studio reel'), findsOneWidget);
    expect(find.text('Linked to Fresh episode · 2026-09-09'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('I can’t believe she\nsaid this!'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
    expect(find.text('2.8K'), findsNothing);
    expect(find.text('Linked to Ep 42: The conversation nobody expected...'), findsNothing);
  });

  testWidgets('creator can delete a reel from studio options', (tester) async {
    await mount(
      tester,
      location: '/screen/creator-reels',
      adapter: workspaceAdapter(),
    );

    await tester.tap(find.byTooltip('Content options'));
    await tester.pumpAndSettle();
    expect(find.text('Delete reel'), findsOneWidget);
    await tester.tap(find.text('Delete reel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete reel?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Reel deleted'), findsOneWidget);
  });

  testWidgets('reel details use the selected server reel', (tester) async {
    await mount(
      tester,
      location: '/screen/creator-reels',
      adapter: workspaceAdapter(),
    );

    await tester.ensureVisible(find.text('Studio reel'));
    await tester.tap(find.text('Studio reel'));
    await tester.pumpAndSettle();
    expect(find.text('Reel Details'), findsOneWidget);
    expect(find.text('Studio reel'), findsOneWidget);
    expect(find.textContaining('Linked to Fresh episode'), findsOneWidget);
    expect(find.text('Views'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
    expect(find.text('I can’t believe she\nsaid this!'), findsNothing);
  });

  testWidgets('reels keep the claim CTA when studio access is missing', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-reels',
      adapter: ApiAdapter(
        (_) => errorResponse(
          status: 403,
          code: 'CLAIM_REQUIRED',
          message: 'A verified show claim is required.',
        ),
      ),
    );

    expect(find.text('A verified show claim is required.'), findsOneWidget);
    expect(find.text('Claim a podcast'), findsOneWidget);
    expect(find.text('Studio reel'), findsNothing);
    expect(find.text('12.4K'), findsNothing);
  });

  testWidgets('create reel picks a claimed episode instead of seeded titles', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-create-reel',
      adapter: workspaceAdapter(),
    );

    expect(find.text('From an Episode'), findsOneWidget);
    await tester.tap(find.text('From an Episode'));
    await tester.pumpAndSettle();
    expect(find.text('Select an episode'), findsOneWidget);
    expect(find.text('Ep 42: The conversation nobody expected'), findsNothing);
    expect(find.text('The Relationship Podcast'), findsNothing);

    await tester.tap(find.text('Select an episode'));
    await tester.pumpAndSettle();
    expect(find.text('Change linked episode'), findsOneWidget);
    await tester.tap(find.text('Fresh episode'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh episode'), findsOneWidget);
    expect(find.textContaining('Linked · Owned Show'), findsOneWidget);
  });

  testWidgets('create reel saves a draft and does not fake publish', (
    tester,
  ) async {
    late RequestOptions saved;
    await mount(
      tester,
      location: '/screen/creator-create-reel',
      adapter: ApiAdapter((request) {
        if (request.path == '/reels/drafts') {
          saved = request;
          return jsonResponse(studioReelDraftFixture(), status: 201);
        }
        if (request.path == '/studio/episodes/ep-1') {
          return jsonResponse(studioEpisodeFixture());
        }
        if (request.path == '/studio/reels/reel-1') {
          return jsonResponse(studioReelFixture());
        }
        return jsonResponse(switch (request.path) {
          '/studio' => studioProfileFixture(),
          '/studio/shows' => [studioShowFixture()],
          '/studio/episodes' => [studioEpisodeFixture()],
          '/studio/reels' => [studioReelFixture()],
          '/studio/audience' => studioAudienceFixture(),
          '/studios' => studioTeamFixture(),
          _ => throw StateError(request.path),
        });
      }),
    );

    await tester.tap(find.text('From an Episode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select an episode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fresh episode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Draft title');
    await tester.enterText(find.byType(TextField).at(1), 'Draft reel');
    await tester.ensureVisible(find.text('Create Reel'));
    await tester.tap(find.text('Create Reel'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Description'), findsWidgets);
    expect(find.text('Create New Reel'), findsOneWidget);
    expect(find.text('Reel created'), findsNothing);

    await tester.ensureVisible(find.text('Save as Draft'));
    await tester.tap(find.text('Save as Draft'));
    await tester.pumpAndSettle();
    expect(saved.method, 'POST');
    expect(saved.data['title'], 'Draft title');
    expect(saved.data['caption'], 'Draft reel');
    expect(saved.data['episode_id'], 'ep-1');
    expect(find.text('Your Reels'), findsOneWidget);
  });

  testWidgets('monetization binds coins and hides invented naira', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-monetization',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('90 PCN'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Earn'), findsWidgets);
    expect(find.text('Reels'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Listener Ada'), findsOneWidget);
    expect(find.text('The Relationship Podcast'), findsNothing);
    expect(find.text('₦72,430.00'), findsNothing);
    expect(find.text('₦128,450.00'), findsNothing);
    expect(find.text('BlessedP'), findsNothing);
    expect(find.text('18.4K'), findsNothing);
  });

  testWidgets('transactions bind the server gift and open details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    await mount(
      tester,
      location: '/screen/creator-transactions',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Gift from Listener Ada'), findsOneWidget);
    expect(find.text('+90 PCN'), findsWidgets);
    expect(find.text('BlessedP'), findsNothing);
    expect(find.text('₦5,000.00'), findsNothing);

    await tester.tap(find.text('Gift from Listener Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Details'), findsOneWidget);
    expect(find.text('Thank you'), findsOneWidget);
    expect(find.text('gift-studio-1'), findsOneWidget);
    expect(find.text('TXN-20240509-102400-BLESSEDP'), findsNothing);
  });

  testWidgets('payout settings bind the saved method instead of seeded bank copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-payout-settings',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Access Bank'), findsOneWidget);
    expect(find.text('•••• 1234'), findsOneWidget);
    expect(find.text('NGN'), findsOneWidget);
    expect(find.text('Noble Stan'), findsNothing);
    expect(find.text('Access Bank PLC'), findsNothing);
    expect(find.text('₦72,430.00'), findsNothing);
    expect(find.text('₦10,000.00'), findsNothing);
  });

  testWidgets('add payout posts a bank destination and does not fake success', (
    tester,
  ) async {
    late RequestOptions saved;
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-add-payout',
      adapter: ApiAdapter((request) {
        if (request.path == '/payout-methods' && request.method == 'POST') {
          saved = request;
          return jsonResponse(studioPayoutMethodFixture(), status: 201);
        }
        if (request.path == '/studio/transactions/txn-1') {
          return jsonResponse(studioTransactionFixture());
        }
        return jsonResponse(switch (request.path) {
          '/studio' => studioProfileFixture(),
          '/studio/shows' => [studioShowFixture()],
          '/studio/episodes' => [studioEpisodeFixture()],
          '/studio/reels' => [studioReelFixture()],
          '/studio/audience' => studioAudienceFixture(),
          '/studio/audience/followers' => [studioFollowerFixture()],
          '/studio/audience/supporters' => [studioSupporterFixture()],
          '/studio/monetization' => studioMonetizationFixture(),
          '/studio/transactions' => [studioTransactionFixture()],
          '/studio/payout-settings' => studioPayoutSettingsFixture(),
          '/payout-methods' => [studioPayoutMethodFixture()],
          '/studios' => studioTeamFixture(),
          _ => throw StateError(request.path),
        });
      }),
    );

    await tester.ensureVisible(find.byKey(const Key('payout-bank')));
    await tester.tap(find.byKey(const Key('payout-bank')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Access Bank').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0123456789');
    await tester.ensureVisible(find.text('Save Payout Method'));
    await tester.tap(find.text('Save Payout Method'));
    await tester.pumpAndSettle();
    expect(saved.method, 'POST');
    expect(saved.data['provider'], 'paystack');
    expect(saved.data['kind'], 'bank');
    expect(saved.data['destination']['account_number'], '0123456789');
    expect(saved.data['destination']['bank_code'], '044');
    expect(find.text('Payout Settings'), findsOneWidget);
  });

  testWidgets('audience binds follower counts instead of seeded 18.4K', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-audience',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Listener Ada'), findsOneWidget);
    expect(find.text('18.4K'), findsNothing);
    expect(find.text('2.8K'), findsNothing);
    expect(find.text('BlessedP'), findsNothing);
    expect(find.text('+11.2%'), findsNothing);
  });

  testWidgets('followers and supporters use server listener names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    await mount(
      tester,
      location: '/screen/creator-audience-followers',
      adapter: workspaceAdapter(),
    );
    expect(find.text('Listener Ada'), findsOneWidget);
    expect(find.textContaining('@ada_listener'), findsOneWidget);
    expect(find.text('BlessedP'), findsNothing);
    expect(find.text('96%'), findsNothing);

    await tester.tap(find.text('Listener Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Top Supporters'), findsOneWidget);
    expect(find.text('100 coins received from 1 supporters.'), findsOneWidget);
    expect(find.text('12,900 coins received from 148 supporters this month.'), findsNothing);
  });

  testWidgets('monetization keeps the claim CTA when studio access is missing', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-monetization',
      adapter: ApiAdapter(
        (_) => errorResponse(
          status: 403,
          code: 'CLAIM_REQUIRED',
          message: 'A verified show claim is required.',
        ),
      ),
    );

    expect(find.text('A verified show claim is required.'), findsOneWidget);
    expect(find.text('Claim a podcast'), findsOneWidget);
    expect(find.text('₦72,430.00'), findsNothing);
  });

  testWidgets('new episode saves a draft and does not fake publish', (
    tester,
  ) async {
    late RequestOptions saved;
    await mount(
      tester,
      location: '/screen/creator-new-episode',
      adapter: ApiAdapter((request) {
        if (request.path == '/studio/episodes' && request.method == 'POST') {
          saved = request;
          return jsonResponse(studioEpisodeDraftFixture(), status: 201);
        }
        return workspaceAdapter().fetch(request, null, null);
      }),
    );

    expect(find.text('The Relationship Podcast'), findsNothing);
    await tester.ensureVisible(find.text('Publish Episode'));
    await tester.tap(find.text('Publish Episode'));
    await tester.pumpAndSettle();
    expect(find.text('New Episode'), findsOneWidget);
    expect(find.text('Episode published'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Studio draft');
    await tester.ensureVisible(find.text('Save as Draft'));
    await tester.tap(find.text('Save as Draft'));
    await tester.pumpAndSettle();
    expect(saved.method, 'POST');
    expect(saved.data['title'], 'Studio draft');
    expect(saved.data['show_id'], 'show-1');
    expect(find.text('Episodes'), findsWidgets);
  });

  testWidgets('go live posts a claimed show instead of seeded topics', (
    tester,
  ) async {
    late RequestOptions created;
    late RequestOptions started;
    await mount(
      tester,
      location: '/screen/creator-go-live',
      adapter: ApiAdapter((request) {
        if (request.path == '/studio/live' && request.method == 'POST') {
          created = request;
          return jsonResponse(studioLiveFixture(state: 'scheduled'), status: 201);
        }
        if (RegExp(r'^/studio/live/[^/]+$').hasMatch(request.path)) {
          started = request;
          return jsonResponse(studioLiveFixture());
        }
        return workspaceAdapter().fetch(request, null, null);
      }),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('Relationships'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Studio live');
    await tester.ensureVisible(find.text('Go Live Now'));
    await tester.tap(find.text('Go Live Now'));
    await tester.pumpAndSettle();
    expect(created.method, 'POST');
    expect(created.data['title'], 'Studio live');
    expect(created.data['show_id'], 'show-1');
    expect(started.method, 'PATCH');
    expect(started.data['state'], 'live');
    expect(find.text('Live room started'), findsNothing);
  });

  testWidgets('tax currency and schedule save server slices without naira', (
    tester,
  ) async {
    late RequestOptions tax;
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-tax-information',
      adapter: ApiAdapter((request) {
        if (request.path == '/studio/payout-settings' &&
            request.method == 'PUT') {
          tax = request;
          return jsonResponse(studioPayoutSettingsFixture());
        }
        return workspaceAdapter().fetch(request, null, null);
      }),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'NG');
    await tester.enterText(fields.at(1), 'Ada Owner');
    await tester.enterText(fields.at(2), 'TIN-1');
    await tester.ensureVisible(find.text('Save Tax Information'));
    await tester.tap(find.text('Save Tax Information'));
    await tester.pumpAndSettle();
    expect(tax.data['country_code'], 'NG');
    expect(tax.data['tax_details']['legal_name'], 'Ada Owner');
    expect(find.text('Payout Settings'), findsOneWidget);
  });

  testWidgets('studios list claimed shows instead of seeded podcasts', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-studios',
      adapter: workspaceAdapter(),
    );

    expect(find.text('Owned Show'), findsOneWidget);
    expect(find.text('2 episodes · 4 followers'), findsOneWidget);
    expect(find.text('The Relationship Podcast'), findsNothing);
    expect(find.text('Love, Actually'), findsNothing);
    expect(find.text('18.4K followers'), findsNothing);

    await tester.tap(find.text('Owned Show'));
    await tester.pumpAndSettle();
    expect(find.text('Owned Show'), findsWidgets);
  });

  testWidgets('add studio searches the catalog before claim-method', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-add-studio',
      adapter: workspaceAdapter(),
    );

    await tester.enterText(find.byType(TextField), 'Owned Show');
    await tester.tap(find.text('Find Podcast'));
    await tester.pumpAndSettle();
    expect(find.text('Owned Show'), findsWidgets);
    await tester.tap(find.text('Owned Show').last);
    await tester.pumpAndSettle();
    expect(find.text('Verify Ownership'), findsOneWidget);
  });

  testWidgets('payout schedule saves ledger units instead of naira', (
    tester,
  ) async {
    late RequestOptions saved;
    tester.view.physicalSize = const Size(430, 1800);
    await mount(
      tester,
      location: '/screen/creator-payout-schedule',
      adapter: ApiAdapter((request) {
        if (request.path == '/studio/payout-settings' &&
            request.method == 'PUT') {
          saved = request;
          return jsonResponse(studioPayoutSettingsFixture());
        }
        return workspaceAdapter().fetch(request, null, null);
      }),
    );

    expect(find.text('10000 PCN'), findsOneWidget);
    expect(find.textContaining('₦'), findsNothing);
    await tester.tap(find.text('Every 7 days'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Payout Schedule'));
    await tester.tap(find.text('Save Payout Schedule'));
    await tester.pumpAndSettle();
    expect(saved.data['schedule'], 'weekly');
    expect(saved.data['minimum_amount'], 10000);
    expect(find.text('Payout Settings'), findsOneWidget);
  });
}
