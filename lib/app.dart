import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/firebase_push.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:pelevo/features/live/live_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'package:pelevo/features/profile/support_data.dart';
import 'package:pelevo/core/deep_links/pelevo_deep_links.dart';
import 'package:pelevo/features/share_cards/share_link_resolver_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/theme/pelevo_appearance.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/library/library_utility_screens.dart';
import 'package:pelevo/features/home/home_see_all_screens.dart';
import 'package:pelevo/features/onboarding/entry_flow_screens.dart';
import 'package:pelevo/features/player/playback_insight_screens.dart';
import 'package:pelevo/features/gifts/gift_data.dart';
import 'package:pelevo/features/gifts/gift_service.dart';
import 'package:pelevo/features/premium/plus_store_sync.dart';
import 'package:pelevo/features/premium/premium_system_screens.dart';
import 'package:pelevo/features/premium/premium_trial_banner.dart';
import 'package:pelevo/features/search/discovery_detail_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:pelevo/features/showcase/screens/catalog_screen.dart';
import 'package:responsive_framework/responsive_framework.dart';

final List<PelevoScreenSpec> pelevoScreens = List.unmodifiable([
  ...entryFlowScreens,
  ...homeSeeAllScreens,
  ...discoveryDetailScreens,
  ...playbackInsightScreens,
  ...libraryUtilityScreens,
  ...premiumSystemScreens,
  ...liveListenerScreens,
]);

const _creatorOnlyReelScreens = {
  'reels-create',
  'reels-record',
  'reels-upload',
  'reels-drafts',
  'reels-editor',
  'creator-create-reel',
};

bool _isPublicPath(String path, String? screenId) {
  if (path == '/' ||
      path.startsWith('/legal/') ||
      path == '/live' ||
      path.startsWith('/live/') ||
      path.startsWith('/s/') ||
      path.startsWith('/episodes/') ||
      path.startsWith('/shows/') ||
      path.startsWith('/playlists/') ||
      path.startsWith('/collections/') ||
      path.startsWith('/reels/') ||
      path.startsWith('/creator/') ||
      path.startsWith('/creators/')) {
    return true;
  }
  return screenId == 'splash' ||
      (screenId?.startsWith('onboarding-') ?? false) ||
      ((screenId?.startsWith('auth-') ?? false) &&
          screenId != 'auth-account-created');
}

String? _openCreatorProfile(BuildContext context, GoRouterState state) {
  final id = state.pathParameters['id']?.trim() ?? '';
  if (id.isEmpty) return '/screen/home-feed';
  ProviderScope.containerOf(
    context,
  ).read(selectedCreatorProfileIdProvider.notifier).select(id);
  return Uri(
    path: '/screen/creator-profile',
    queryParameters: {'id': id},
  ).toString();
}

final GoRouter pelevoRouter = GoRouter(
  initialLocation: '/screen/splash',
  refreshListenable: PodcastCreatorService.instance,
  observers: [pelevoRouteObserver],
  redirect: (context, state) {
    // pelevo://creator/{id} has path /{id}. Rewrite it before route matching
    // gives up with "no routes for location: pelevo://...".
    if (state.uri.scheme.toLowerCase() == 'pelevo') {
      final mapped = PelevoDeepLinks.routeLocation(state.uri);
      if (mapped != null && mapped != state.uri.path) return mapped;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final session = container.read(authSessionProvider);
    final preview = kDebugMode && container.read(catalogPreviewProvider);
    final segments = state.uri.pathSegments;
    final id = segments.length == 2 && segments.first == 'screen'
        ? segments.last
        : null;
    final publicEntry = _isPublicPath(state.uri.path, id);
    if (!preview &&
        !session.authenticated &&
        !publicEntry &&
        state.uri.path != '/') {
      return Uri(
        path: '/screen/auth-sign-in',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (id != null &&
        _creatorOnlyReelScreens.contains(id) &&
        !(preview
            ? PodcastCreatorService.instance.claimed
            : session.creatorAccess)) {
      return '/screen/claim-podcast';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/screen/splash'),
    GoRoute(
      path: '/legal/:document',
      builder: (context, state) => switch (state.pathParameters['document']) {
        'terms' => const LegalDocumentScreen(document: CmsDocument.terms),
        'privacy' => const LegalDocumentScreen(document: CmsDocument.privacy),
        _ => const _MissingScreen(),
      },
    ),
    GoRoute(path: '/live', builder: (context, state) => const LiveNowScreen()),
    GoRoute(
      path: '/live/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return LiveSessionScreen(sessionId: id);
      },
    ),
    GoRoute(
      path: '/s/:token',
      builder: (context, state) =>
          ShareLinkResolverScreen(token: state.pathParameters['token']!),
    ),
    GoRoute(
      path: '/playlists/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        ProviderScope.containerOf(
          context,
        ).read(selectedPlaylistIdProvider.notifier).select(id);
        return '/screen/library-3?id=$id';
      },
    ),
    GoRoute(
      path: '/collections/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        ProviderScope.containerOf(
          context,
        ).read(selectedCollectionIdProvider.notifier).select(id);
        return '/screen/library-11?id=$id';
      },
    ),
    GoRoute(
      path: '/shows/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        openCatalogShow(context, id);
        return '/screen/podcast-details';
      },
    ),
    GoRoute(
      path: '/episodes/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        final showId = state.uri.queryParameters['showId'];
        openCatalogEpisode(context, episodeId: id, showId: showId);
        return '/screen/episode-details';
      },
    ),
    GoRoute(
      path: '/reels/:id',
      redirect: (context, state) {
        // Feed focuses via query; keep reel id for future deep-link consumers.
        return Uri(
          path: '/screen/reels',
          queryParameters: {'reelId': state.pathParameters['id']},
        ).toString();
      },
    ),
    GoRoute(path: '/creators/:id', redirect: _openCreatorProfile),
    GoRoute(path: '/creator/:id', redirect: _openCreatorProfile),
    if (kDebugMode)
      GoRoute(
        path: '/catalog',
        builder: (context, state) => CatalogScreen(screens: pelevoScreens),
      ),
    GoRoute(
      path: '/screen/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        final screen = pelevoScreens.where((item) => item.id == id).firstOrNull;
        if (screen == null) {
          return const MaterialPage<void>(child: _MissingScreen());
        }
        return CustomTransitionPage<void>(
          key: ValueKey(state.uri.toString()),
          transitionDuration: PelevoMotion.normal,
          reverseTransitionDuration: PelevoMotion.fast,
          child: screen.builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
    ),
  ],
);

class PelevoApp extends ConsumerStatefulWidget {
  const PelevoApp({super.key});

  @override
  ConsumerState<PelevoApp> createState() => _PelevoAppState();
}

class _PelevoAppState extends ConsumerState<PelevoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Gift coins credit only after POST /iap/verify — wire before any purchase.
    GiftWalletService.instance.configureVerifier((purchase) async {
      final receipt = purchase.verificationData.serverVerificationData.trim();
      final fallback = purchase.purchaseID?.trim() ?? '';
      final token = receipt.isNotEmpty ? receipt : fallback;
      if (token.isEmpty) return false;
      // Play product verify needs the SKU; wrap the purchase token for the API.
      final payload =
          GiftWalletService.instance.storeProvider == 'google'
              ? jsonEncode({
                'purchaseToken': token,
                'productId': purchase.productID,
              })
              : token;
      final verified = await ref
          .read(giftRepositoryProvider)
          .verifyIap(
            store: GiftWalletService.instance.storeProvider,
            receipt: payload,
            productId: purchase.productID,
          );
      ref.read(lastVerifiedGiftPurchaseProvider.notifier).select(verified);
      return verified.coins > 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PelevoNotificationRouter.bindGo(pelevoRouter.go);
      final session = ref.read(authSessionProvider);
      if (session.userId != null) {
        unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
      }
      if (session.authenticated) {
        unawaited(
          ref.read(plusStoreSyncProvider).sync(accountId: session.userId),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final session = ref.read(authSessionProvider);
    if (!session.authenticated) return;
    unawaited(ref.read(plusStoreSyncProvider).sync(accountId: session.userId));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      pelevoRouter.refresh();
      if (next.userId != null && next.userId != previous?.userId) {
        unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
        if (next.authenticated) {
          unawaited(
            ref.read(plusStoreSyncProvider).sync(accountId: next.userId),
          );
        }
      }
    });
    return MaterialApp.router(
      title: 'Pelevo',
      debugShowCheckedModeBanner: false,
      theme: PelevoTheme.light,
      darkTheme: PelevoTheme.dark,
      themeMode: ref.watch(pelevoThemeModeProvider),
      routerConfig: pelevoRouter,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            PremiumTrialBannerHost(router: pelevoRouter),
          ],
        ),
        breakpoints: const [
          Breakpoint(start: 0, end: 359, name: MOBILE),
          Breakpoint(start: 360, end: 599, name: 'LARGE_MOBILE'),
          Breakpoint(start: 600, end: 1023, name: TABLET),
          Breakpoint(start: 1024, end: double.infinity, name: DESKTOP),
        ],
      ),
    );
  }
}

class _MissingScreen extends StatelessWidget {
  const _MissingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        'Screen not found',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ),
  );
}
