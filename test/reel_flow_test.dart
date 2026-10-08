import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/reels/create_reel_screens.dart';
import 'package:pelevo/features/reels/reel_ad_service.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reel_create_service.dart';
import 'package:pelevo/features/reels/reels_monetization_screens.dart';
import 'package:pelevo/features/reels/reels_monetization_service.dart';
import 'package:pelevo/features/reels/creator_public_screens.dart';
import 'package:pelevo/features/reels/reels_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/api_adapter.dart';
import 'support/profile_fixture.dart';
import 'support/reel_fixture.dart';
import 'support/gift_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReelCreateService.instance.activeDraft = null;
  });
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
        GoRoute(path: '/screen/reels', builder: (_, _) => const ReelsScreen()),
        GoRoute(
          path: '/screen/reels-drafts',
          builder: (_, _) => const ReelDraftsScreen(),
        ),
        GoRoute(
          path: '/screen/reels-editor',
          builder: (_, _) => const ReelEditorScreen(),
        ),
        GoRoute(
          path: '/screen/reels-record',
          builder: (_, _) => const Scaffold(body: Text('Record Reel')),
        ),
        GoRoute(
          path: '/screen/reels-monetization',
          builder: (_, _) => const ReelsMonetizationScreen(),
        ),
        GoRoute(
          path: '/screen/reels-monetization-progress',
          builder:
              (_, _) => const ReelsMonetizationScreen(
                forceStage: ReelsMonetizationStage.progressing,
              ),
        ),
        GoRoute(
          path: '/screen/reels-monetization-eligible',
          builder:
              (_, _) => const ReelsMonetizationScreen(
                forceStage: ReelsMonetizationStage.eligible,
              ),
        ),
        GoRoute(
          path: '/screen/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/screen/claim-podcast',
          builder: (_, _) => const Scaffold(body: Text('Claim')),
        ),
        GoRoute(
          path: '/screen/podcast-details',
          builder: (_, _) => const Scaffold(body: Text('Podcast')),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Play Episode')),
        ),
        GoRoute(
          path: '/screen/creator-profile',
          builder: (_, _) => const PublicCreatorProfileScreen(),
        ),
        GoRoute(
          path: '/screen/profile-edit',
          builder: (_, _) => const Scaffold(body: Text('Edit profile page')),
        ),
        GoRoute(
          path: '/screen/creator-stories',
          builder: (_, _) => const Scaffold(body: Text('Creator Stories')),
        ),
        GoRoute(
          path: '/screen/saved-reels',
          builder: (_, _) => const SavedReelsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        reelAdPageFactoryProvider.overrideWithValue(
          const _FakeReelAdPageFactory(),
        ),
        initialAuthSessionProvider.overrideWithValue(
          const AuthSession(
            accessToken: 'test-access',
            refreshToken: 'test-refresh',
            deviceId: 'test-device',
            user: {
              'id': 'test-user',
              'name': 'Test user',
              'capabilities': {'creator_access': true},
            },
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

  ApiAdapter feedAdapter() => ApiAdapter((request) {
    if (request.path == '/me') {
      return jsonResponse(profileFixture());
    }
    if (request.path == '/reels/for-you') {
      return jsonResponse([publishedReelFixture()]);
    }
    if (request.path == '/reels/following' ||
        request.path == '/reels/trending') {
      return jsonResponse(<Map<String, dynamic>>[]);
    }
    if (request.path == '/reels/saved') {
      return jsonResponse([
        publishedReelFixture(id: 'reel-saved', caption: 'Saved reel caption.'),
      ]);
    }
    if (request.path == '/reels/drafts') {
      if (request.method == 'POST') {
        return jsonResponse(
          reelDraftFixture(caption: '${request.data['caption']}'),
          status: 201,
        );
      }
      return jsonResponse([reelDraftFixture()]);
    }
    if (request.path == '/reels/monetization') {
      return jsonResponse(reelMonetizationFixture());
    }
    if (request.path == '/reels/monetization/opt-in') {
      return jsonResponse(
        reelMonetizationFixture(
          eligible: true,
          optedIn: true,
          followers: 120,
          qualifiedViews: 2000,
        ),
      );
    }
    if (RegExp(r'^/reels/[^/]+/like$').hasMatch(request.path)) {
      return jsonResponse({'liked': true});
    }
    if (RegExp(r'^/creators/[^/]+/follow$').hasMatch(request.path)) {
      return jsonResponse({'following': true}, status: 201);
    }
    if (request.path == '/creators/creator-1') {
      return jsonResponse({
        'id': 'creator-1',
        'display_name': 'Ada Creator',
        'handle': 'ada_creator',
        'bio': 'African stories on the go.',
        'avatar_url': null,
        'verified': true,
        'is_self': false,
        'following': false,
        'stats': {'followers': 12, 'following': 3, 'reels': 1, 'podcasts': 1},
        'shows': [
          {
            'id': 'show-1',
            'title': 'Ada Daily',
            'author': 'Ada',
            'artwork_url': null,
          },
        ],
      });
    }
    if (request.path == '/creators/creator-1/reels' ||
        request.path == '/creators/self-1/reels') {
      return jsonResponse([publishedReelFixture()]);
    }
    if (request.path == '/creators/self-1') {
      return jsonResponse({
        'id': 'self-1',
        'display_name': 'My Studio',
        'handle': 'my_studio',
        'bio': 'This is my public profile.',
        'avatar_url': null,
        'verified': true,
        'is_self': true,
        'following': false,
        'stats': {'followers': 4, 'following': 1, 'reels': 1, 'podcasts': 0},
        'shows': <Map<String, dynamic>>[],
      });
    }
    if (request.path == '/studio/episodes') {
      return jsonResponse(<Map<String, dynamic>>[]);
    }
    if (RegExp(r'^/reels/[^/]+/view-heartbeat$').hasMatch(request.path)) {
      return jsonResponse({
        'qualified': true,
        'counted': true,
        'server_watched_ms': 30000,
        'is_valid_view': true,
        'ad_due': null,
      });
    }
    if (RegExp(r'^/reels/[^/]+/not-interested$').hasMatch(request.path)) {
      return jsonResponse({'not_interested': true});
    }
    if (request.path == '/reports') {
      return jsonResponse({'id': 'report-1'}, status: 201);
    }
    if (request.path == '/gifts/catalog') {
      return jsonResponse([giftTypeFixture()]);
    }
    if (request.path == '/gifts/wallet') {
      return jsonResponse(giftWalletFixture());
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('reels feed binds server creator and count', (tester) async {
    await mount(tester, location: '/screen/reels', adapter: feedAdapter());
    expect(find.text('Ada Creator'), findsWidgets);
    expect(find.text('Published reel caption.'), findsOneWidget);
    expect(find.textContaining('Linked to Podcast Episode'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Jay Shetty'), findsNothing);
    expect(find.text('12.4K'), findsNothing);

    final surface = tester.getRect(
      find.byKey(const ValueKey('active-reel-surface')),
    );
    await tester.tapAt(Offset(surface.left + 8, surface.center.dy));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await tester.tap(find.byKey(const ValueKey('active-reel-surface')));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('No reels found'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    expect(find.text('Published reel caption.'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('monetization progress uses server thresholds', (tester) async {
    await mount(
      tester,
      location: '/screen/reels-monetization-progress',
      adapter: feedAdapter(),
    );
    expect(find.text('Monetize Your Reels'), findsOneWidget);
    expect(find.text('12 / 100'), findsOneWidget);
    expect(find.text('40 / 1000'), findsOneWidget);
    expect(find.text('₦128,450.00'), findsNothing);
    expect(find.textContaining('GTBank'), findsNothing);
  });

  testWidgets('eligible opt-in follows the server', (tester) async {
    await mount(
      tester,
      location: '/screen/reels-monetization-eligible',
      adapter: feedAdapter(),
    );
    expect(find.text("You're Eligible!"), findsOneWidget);
    await tester.tap(find.text('Opt In Now →'));
    await tester.pumpAndSettle();
    expect(find.text("You're Monetized!"), findsOneWidget);
    expect(find.text('Earnings series is not available yet.'), findsOneWidget);
  });

  testWidgets('server drafts list caption and editor does not fake publish', (
    tester,
  ) async {
    ReelCreateService.instance.activeDraft = null;
    await mount(
      tester,
      location: '/screen/reels-drafts',
      adapter: feedAdapter(),
    );
    expect(find.text('Draft reel'), findsOneWidget);
    await tester.tap(find.text('Draft reel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Reel'), findsOneWidget);
    await tester.tap(find.text('Publish Reel'));
    await tester.pump();
    expect(find.textContaining('without media'), findsOneWidget);
    expect(find.text('Reel published'), findsNothing);
  });

  testWidgets('creator name opens a public profile with their reels', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/creator-profile?id=creator-1',
      adapter: feedAdapter(),
    );
    expect(find.text('Ada Creator'), findsWidgets);
    expect(find.text('African stories on the go.'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Ada Daily'), findsOneWidget);
    expect(find.text('No published reels yet.'), findsNothing);
  });

  testWidgets('tapping a reel creator name opens their public profile', (
    tester,
  ) async {
    await mount(tester, location: '/screen/reels', adapter: feedAdapter());
    await tester.tap(find.text('Ada Creator').last);
    await tester.pumpAndSettle();
    expect(find.text('African stories on the go.'), findsOneWidget);
    expect(find.text('Follow'), findsWidgets);
    expect(find.text('Ada Daily'), findsOneWidget);
  });

  testWidgets('reel owner sees their own public profile', (tester) async {
    await mount(
      tester,
      location: '/screen/creator-profile?id=self-1',
      adapter: feedAdapter(),
    );
    expect(find.text('My Studio'), findsWidgets);
    expect(find.text('This is my public profile.'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('linked episode chip opens the episode', (tester) async {
    await mount(tester, location: '/screen/reels', adapter: feedAdapter());
    expect(find.textContaining('Linked to Podcast Episode'), findsOneWidget);
    await tester.tap(find.text('Listen Now'));
    await tester.pumpAndSettle();
    expect(find.text('Play Episode'), findsOneWidget);
  });

  testWidgets('saved reels screen plays bookmarked captions', (tester) async {
    await mount(
      tester,
      location: '/screen/saved-reels',
      adapter: feedAdapter(),
    );
    expect(find.text('Saved reel caption.'), findsOneWidget);
    expect(find.text('Ada Creator'), findsWidgets);
  });

  testWidgets('reel player exposes share gift and more actions', (
    tester,
  ) async {
    await mount(tester, location: '/screen/reels', adapter: feedAdapter());
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('Gift'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);

    var copied = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          copied = args['text'] as String? ?? '';
          return null;
        }
        return null;
      },
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Not interested'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    await tester.tap(find.text('Copy link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(copied, contains('/reels/reel-1'));
  });

  testWidgets('not interested hides the reel from the current feed', (
    tester,
  ) async {
    await mount(tester, location: '/screen/reels', adapter: feedAdapter());
    await tester.tap(find.byTooltip('More options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Not interested'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Published reel caption.'), findsNothing);
  });
}

final class _FakeReelAdPageFactory implements ReelAdPageFactory {
  const _FakeReelAdPageFactory();

  @override
  Widget build({
    required Key key,
    required ReelAdDue due,
    required String feedSessionId,
    required bool isActive,
    required VoidCallback onUnavailable,
  }) {
    return ColoredBox(
      key: key,
      color: Colors.black,
      child: const Center(child: Text('Test native ad')),
    );
  }
}
