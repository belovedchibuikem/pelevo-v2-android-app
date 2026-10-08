import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/stats/podcast_stats_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in podcastStatsScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/library-1',
          builder: (_, _) => const Scaffold(body: Text('Library')),
        ),
        GoRoute(
          path: '/screen/podcast-details',
          builder: (_, _) => const Scaffold(body: Text('Podcast')),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/browse',
          builder: (_, _) => const Scaffold(body: Text('Browse')),
        ),
        GoRoute(
          path: '/screen/downloads-1',
          builder: (_, _) => const Scaffold(body: Text('Downloads')),
        ),
        GoRoute(
          path: '/screen/share-card-home',
          builder: (_, _) => const Scaffold(body: Text('Share Card')),
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

  ApiAdapter adapter() => ApiAdapter((request) {
    if (request.path == '/stats/me') {
      return jsonResponse(catalogStatsFixture());
    }
    if (request.path == '/player/session') {
      return jsonResponse(catalogPlayerSessionFixture());
    }
    if (request.path == '/library/recent') {
      return jsonResponse([catalogRecentEpisodeFixture()]);
    }
    if (request.path == '/episodes/$catalogEpisodeId') {
      return jsonResponse(catalogEpisodeFixture(detailed: true));
    }
    if (request.path == '/queue') {
      return jsonResponse(catalogQueueFixture());
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('overview formats listening seconds instead of 8h 42m', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/stats-overview',
      adapter: adapter(),
    );
    expect(find.text('2 min'), findsWidgets);
    expect(find.text('8h 42m'), findsNothing);
    expect(find.text('+18% vs week'), findsNothing);
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
  });

  testWidgets('shows and achievements bind presented lists', (tester) async {
    await mount(tester, location: '/screen/stats-shows', adapter: adapter());
    expect(find.text('Most Played'), findsOneWidget);
    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('The Mindset Mentor'), findsNothing);
  });

  testWidgets('share comparison keeps chrome without invented deltas', (
    tester,
  ) async {
    await mount(tester, location: '/screen/stats-share', adapter: adapter());
    expect(find.text('Share Comparison'), findsOneWidget);
    expect(find.text('+24%'), findsNothing);
    expect(find.text('32h 18m'), findsNothing);
  });
}
