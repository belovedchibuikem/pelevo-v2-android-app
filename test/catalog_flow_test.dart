import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/episode/episode_screens.dart';
import 'package:pelevo/features/player/full_player_screens.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/podcast/podcast_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/comment_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
    bool selectCatalog = true,
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
        for (final spec in [
          ...podcastScreens,
          ...episodeScreens,
          ...fullPlayerScreens,
        ])
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/search',
          builder: (_, _) => const Scaffold(body: Text('Search')),
        ),
        GoRoute(
          path: '/screen/share-card-preview',
          builder: (_, _) => const Scaffold(body: Text('Share Card')),
        ),
        GoRoute(
          path: '/screen/queue-up-next',
          builder: (_, _) => const Scaffold(body: Text('Queue')),
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
        if (selectCatalog) ...[
          selectedShowIdProvider.overrideWith(CatalogHarnessShowId.new),
          selectedEpisodeIdProvider.overrideWith(CatalogHarnessEpisodeId.new),
        ],
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

  ApiAdapter adapter() => ApiAdapter((request) {
    if (request.path == '/shows/$catalogShowId') {
      return jsonResponse(catalogShowFixture());
    }
    if (request.path == '/shows/$catalogShowId/episodes') {
      return jsonResponse(catalogEpisodesFixture(), meta: {'has_more': false});
    }
    if (request.path == '/shows/$catalogShowId/related') {
      return jsonResponse([catalogRelatedShowFixture()]);
    }
    if (request.path == '/shows/$catalogShowId/reviews') {
      if (request.method == 'POST') {
        return jsonResponse(catalogReviewFixture(), status: 201);
      }
      return jsonResponse([catalogReviewFixture()]);
    }
    if (request.path.endsWith('/follow')) {
      return jsonResponse({'following': request.method != 'DELETE'});
    }
    if (request.path == '/episodes/$catalogEpisodeId') {
      return jsonResponse(catalogEpisodeFixture(detailed: true));
    }
    if (request.path == '/episodes/$catalogEpisodeId/chapters') {
      return jsonResponse(catalogChaptersFixture());
    }
    if (request.path == '/episodes/$catalogEpisodeId/transcript') {
      return jsonResponse(catalogTranscriptFixture());
    }
    if (request.path == '/episodes/$catalogEpisodeId/notes') {
      return jsonResponse(catalogNoteFixture());
    }
    if (RegExp(r'^/playback/').hasMatch(request.path)) {
      return jsonResponse(catalogPlaybackFixture());
    }
    if (request.path == '/player/session') {
      return jsonResponse(catalogPlayerSessionFixture());
    }
    if (request.path == '/episodes/$catalogEpisodeId/queue') {
      return jsonResponse({'version': 2}, status: 201);
    }
    if (request.path == '/episodes/$catalogEpisodeId/downloads') {
      return jsonResponse({
        'episode_id': catalogEpisodeId,
        'url': 'https://cdn.example.invalid/shift-life.mp3',
        'expires_at': '2026-09-10T12:00:00Z',
        'authorization': 'test-download',
      });
    }
    if (request.path == '/queue') {
      return jsonResponse(catalogQueueFixture());
    }
    if (request.path == '/comments') {
      return jsonResponse(episodeCommentsFixture());
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('podcast details bind the selected show instead of seeds', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/podcast-details',
      adapter: adapter(),
    );
    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('Play Latest'), findsOneWidget);
    expect(find.text('Tea With Tay'), findsNothing);
    expect(find.text('25K Followers'), findsNothing);

    await tester.ensureVisible(find.text('Play Latest'));
    await tester.tap(find.text('Play Latest'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    expect(find.text('PLAYING FROM'), findsOneWidget);
  });

  testWidgets('a catalog deep link without a show stays empty', (tester) async {
    await mount(
      tester,
      location: '/screen/podcast-details',
      adapter: adapter(),
      selectCatalog: false,
    );
    expect(
      find.text('Select a show from search, browse, or Home.'),
      findsOneWidget,
    );
    expect(find.text('The Honest Bunch'), findsNothing);
  });

  testWidgets('episode details bind description and chapters from the API', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/episode-details',
      adapter: adapter(),
    );
    expect(find.text('Play Episode'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    await tester.ensureVisible(find.text('more'));
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    expect(find.text('In this episode:'), findsOneWidget);
    expect(find.text('Tolu A.'), findsNothing);
  });

  testWidgets('podcast episodes bind the selected show archive', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/podcast-episodes',
      adapter: adapter(),
    );
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    expect(find.text('Ep. 123 - Keep Going'), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add_rounded), findsWidgets);
    expect(find.byTooltip('Play Ep. 124 - The Shift Life'), findsOneWidget);
  });

  testWidgets('podcast reviews bind published listener reviews', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/podcast-reviews',
      adapter: adapter(),
    );
    expect(find.textContaining('Maya'), findsOneWidget);
    expect(
      find.textContaining('Every episode feels honest and useful.'),
      findsOneWidget,
    );
  });

  testWidgets('podcast related binds compact related cards', (tester) async {
    await mount(
      tester,
      location: '/screen/podcast-related',
      adapter: adapter(),
    );
    expect(find.text('Ranked Show'), findsOneWidget);
  });

  testWidgets('episode chapters bind timestamps from the API', (tester) async {
    await mount(
      tester,
      location: '/screen/episode-chapters',
      adapter: adapter(),
    );
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('The first big shift'), findsOneWidget);
  });

  testWidgets('episode transcript binds the published text', (tester) async {
    await mount(
      tester,
      location: '/screen/episode-transcript',
      adapter: adapter(),
    );
    expect(find.textContaining('quietly rewrite'), findsOneWidget);
  });

  testWidgets('episode notes stay empty until the owner row has a body', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/episode-notes',
      adapter: adapter(),
    );
    expect(find.text('No notes are saved for this episode.'), findsOneWidget);
  });

  testWidgets('player binds the selected episode instead of seeds', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/player-now-playing',
      adapter: adapter(),
    );
    expect(find.text('PLAYING FROM'), findsOneWidget);
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    expect(find.text('The Honest Bunch'), findsWidgets);
  });
}
