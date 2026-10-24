import 'dart:async';

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
      path.startsWith('/reels/')) {
    return true;
  }
  return screenId == 'splash' ||
      (screenId?.startsWith('onboarding-') ?? false) ||
      ((screenId?.startsWith('auth-') ?? false) &&
          screenId != 'auth-account-created');
}

final GoRouter pelevoRouter = GoRouter(
  initialLocation: '/screen/splash',
  refreshListenable: PodcastCreatorService.instance,
  observers: [pelevoRouteObserver],
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context, listen: false);
    final session = container.read(authSessionProvider);
    final preview = kDebugMode && container.read(catalogPreviewProvider);
    final segments = state.uri.pathSegments;
    final id =
        segments.length == 2 && segments.first == 'screen'
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
      builder:
          (context, state) => switch (state.pathParameters['document']) {
            'terms' => const LegalDocumentScreen(document: CmsDocument.terms),
            'privacy' => const LegalDocumentScreen(
              document: CmsDocument.privacy,
            ),
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
      builder:
          (context, state) =>
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
    GoRoute(
      path: '/creators/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        ProviderScope.containerOf(
          context,
        ).read(selectedCreatorProfileIdProvider.notifier).select(id);
        return Uri(
          path: '/screen/creator-profile',
          queryParameters: {'id': id},
        ).toString();
      },
    ),
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

class _PelevoAppState extends ConsumerState<PelevoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PelevoNotificationRouter.bindGo(pelevoRouter.go);
      if (ref.read(authSessionProvider).userId != null) {
        unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      pelevoRouter.refresh();
      if (next.userId != null && next.userId != previous?.userId) {
        unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
      }
    });
    return MaterialApp.router(
      title: 'Pelevo',
      debugShowCheckedModeBanner: false,
      theme: PelevoTheme.light,
      darkTheme: PelevoTheme.dark,
      themeMode: ref.watch(pelevoThemeModeProvider),
      routerConfig: pelevoRouter,
      builder:
          (context, child) => ResponsiveBreakpoints.builder(
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
