import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/library/library_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/library_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/reel_fixture.dart';

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
        for (final spec in libraryScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/ai-hub',
          builder: (_, _) => const Scaffold(body: Text('Popular Tools')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode')),
        ),
        GoRoute(
          path: '/screen/stats-overview',
          builder: (_, _) => const Scaffold(body: Text('Stats')),
        ),
        GoRoute(
          path: '/screen/queue-up-next',
          builder: (_, _) => const Scaffold(body: Text('Queue')),
        ),
        GoRoute(
          path: '/screen/permissions-intro',
          builder: (_, _) => const Scaffold(body: Text('Permissions')),
        ),
        GoRoute(
          path: '/screen/notifications-1',
          builder: (_, _) => const Scaffold(body: Text('Inbox')),
        ),
        GoRoute(
          path: '/screen/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/screen/downloads-1',
          builder: (_, _) => const Scaffold(body: Text('Downloads Manager')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        selectedPlaylistIdProvider.overrideWith(CatalogHarnessPlaylistId.new),
        selectedCollectionIdProvider.overrideWith(CatalogHarnessCollectionId.new),
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

  ApiAdapter libraryAdapter() => ApiAdapter((request) {
    if (request.path == '/me') {
      return jsonResponse(profileFixture());
    }
    if (request.path == '/library') {
      return jsonResponse(libraryOverviewFixture());
    }
    if (request.path == '/playlists') {
      if (request.queryParameters['scope'] == 'others') {
        return jsonResponse(<Map<String, dynamic>>[]);
      }
      return jsonResponse([libraryPlaylistFixture()]);
    }
    if (request.path == '/queue') {
      if (request.method == 'PUT') {
        return jsonResponse({'version': 1, 'count': 0});
      }
      return jsonResponse({'version': 0, 'items': <Map<String, dynamic>>[]});
    }
    if (request.path == '/playlists/$libraryPlaylistId') {
      return jsonResponse(libraryPlaylistFixture(detailed: true));
    }
    if (request.path == '/library/shows') {
      return jsonResponse([libraryShowRowFixture()]);
    }
    if (request.path == '/library/saved') {
      return jsonResponse([
        libraryEpisodeFixture(savedAt: '2026-09-09T12:00:00Z'),
      ]);
    }
    if (request.path == '/reels/saved') {
      return jsonResponse([
        publishedReelFixture(id: 'reel-saved', caption: 'Saved reel caption.'),
      ]);
    }
    if (request.path == '/library/liked') {
      return jsonResponse([libraryEpisodeFixture()]);
    }
    if (request.path == '/library/recent') {
      return jsonResponse([
        libraryEpisodeFixture(
          position: 900,
          completed: false,
        )..['played_at'] = '2026-09-09T12:00:00Z',
      ]);
    }
    if (request.path == '/downloads') {
      return jsonResponse([libraryDownloadFixture()]);
    }
    if (request.path == '/collections') {
      return jsonResponse([libraryCollectionFixture()]);
    }
    if (request.path == '/collections/$libraryCollectionId') {
      return jsonResponse(libraryCollectionFixture(detailed: true));
    }
    if (request.path == '/episodes/$catalogEpisodeId') {
      return jsonResponse(catalogEpisodeFixture(detailed: true));
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('library home and playlist details bind server names', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/library-1',
      adapter: libraryAdapter(),
    );
    expect(find.text('Playlists'), findsWidgets);
    await tester.tap(find.text('Playlists').first);
    await tester.pumpAndSettle();
    expect(find.text('Mindset & Growth'), findsOneWidget);

    await tester.tap(find.text('Mindset & Growth'));
    await tester.pumpAndSettle();
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Mindset & Growth'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Playlists'), findsWidgets);
  });

  testWidgets('library sections fetch lists including recently played', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/library-1',
      adapter: libraryAdapter(),
    );
    await tester.tap(find.text('Recently Played'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Your Shows'));
    await tester.tap(find.text('Your Shows'));
    await tester.pumpAndSettle();
    expect(find.text('The Honest Bunch'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('History'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
  });

  testWidgets('empty playlist play all stays honest', (tester) async {
    await mount(
      tester,
      location: '/screen/library-3',
      adapter: ApiAdapter((request) {
        if (request.path == '/playlists/$libraryPlaylistId') {
          return jsonResponse(
            libraryPlaylistFixture(itemCount: 0, detailed: true)
              ..['items'] = <Map<String, dynamic>>[],
          );
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.tap(find.text('Play All'));
    await tester.pumpAndSettle();
    expect(find.text('This playlist has no episodes yet.'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('playlist play all opens the player', (tester) async {
    await mount(
      tester,
      location: '/screen/library-3',
      adapter: libraryAdapter(),
    );
    await tester.tap(find.text('Play All'));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
  });

  testWidgets('owner playlist keeps remove and reorder under each episode', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/library-3',
      adapter: libraryAdapter(),
    );
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('The Honest Bunch'), findsOneWidget);
    expect(find.byTooltip('Remove from playlist'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('collection details show the description and share in place', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/library-9',
      adapter: libraryAdapter(),
    );
    expect(find.text('Sunday Reset'), findsOneWidget);
    expect(find.text('Quiet episodes for Sunday.'), findsOneWidget);

    await tester.tap(find.text('Sunday Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);
    expect(find.byTooltip('Add'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Share Card'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('saved reels appear in the library', (tester) async {
    await mount(
      tester,
      location: '/screen/library-13',
      adapter: libraryAdapter(),
    );
    expect(find.text('Saved reel caption.'), findsOneWidget);
    expect(find.text('Ada Creator'), findsOneWidget);
    expect(find.text('Play all'), findsOneWidget);
  });
}
