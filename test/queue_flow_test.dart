import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/queue/queue_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';

void main() {
  Future<ProviderContainer> mount(
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
        for (final spec in queueScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/library-1',
          builder: (_, _) => const Scaffold(body: Text('Library')),
        ),
        GoRoute(
          path: '/screen/browse',
          builder: (_, _) => const Scaffold(body: Text('Browse')),
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
          path: '/screen/downloads-1',
          builder: (_, _) => const Scaffold(body: Text('Downloads')),
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
    return container;
  }

  testWidgets('up next binds server items instead of eight seeds', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/queue-up-next',
      adapter: ApiAdapter((request) {
        if (request.path == '/player/session') {
          return jsonResponse(catalogPlayerSessionFixture());
        }
        if (request.path == '/queue') {
          return jsonResponse(catalogQueueFixture());
        }
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('Up Next · 1 Episode'), findsOneWidget);
    expect(find.text('Ep. 123 - Keep Going'), findsOneWidget);
    expect(find.text('Ep. 125 - Stay Motivated'), findsNothing);
  });

  testWidgets('up next shows drag handles for each queued episode', (
    tester,
  ) async {
    var order = <String>['catalog-episode-2', 'catalog-episode-3'];
    final container = await mount(
      tester,
      location: '/screen/queue-up-next',
      adapter: ApiAdapter((request) {
        if (request.path == '/player/session') {
          return jsonResponse(catalogPlayerSessionFixture());
        }
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        if (request.path == '/queue/reorder') {
          final ids = (request.data as Map)['episode_ids'] as List<dynamic>;
          order = [for (final id in ids) '$id'];
          return jsonResponse({'version': 2, 'count': order.length});
        }
        if (request.path == '/queue') {
          return jsonResponse(
            catalogQueueFixture(
              version: order.first == 'catalog-episode-2' ? 1 : 2,
              items: [
                {
                  'queue_item_id': 'queue-item-1',
                  'position': 0,
                  'id': order[0],
                  'show_id': catalogShowId,
                  'title': order[0] == 'catalog-episode-2'
                      ? 'Ep. 123 - Keep Going'
                      : 'Ep. 125 - Stay Motivated',
                  'show_title': 'The Honest Bunch',
                  'duration_seconds': 2280,
                  'artwork_url': null,
                },
                {
                  'queue_item_id': 'queue-item-2',
                  'position': 1,
                  'id': order[1],
                  'show_id': catalogShowId,
                  'title': order[1] == 'catalog-episode-3'
                      ? 'Ep. 125 - Stay Motivated'
                      : 'Ep. 123 - Keep Going',
                  'show_title': 'The Honest Bunch',
                  'duration_seconds': 2100,
                  'artwork_url': null,
                },
              ],
            ),
          );
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('Ep. 123 - Keep Going'), findsWidgets);
    expect(find.text('Ep. 125 - Stay Motivated'), findsOneWidget);
    expect(find.textContaining('Plays next'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));

    final items = container.read(catalogQueueProvider).requireValue.items;
    expect(items.map((item) => item.episode.id).toList(), order);
  });

  testWidgets('empty queue chrome follows a zero-length list', (tester) async {
    await mount(
      tester,
      location: '/screen/queue-up-next',
      adapter: ApiAdapter((request) {
        if (request.path == '/player/session') {
          return jsonResponse(catalogPlayerSessionFixture(episodeId: null));
        }
        if (request.path == '/queue') {
          return jsonResponse(catalogQueueFixture(items: const []));
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('Your queue is empty'), findsOneWidget);
    expect(find.text('Browse Podcasts'), findsOneWidget);
  });

  testWidgets('clear waits for DELETE /queue', (tester) async {
    var cleared = false;
    await mount(
      tester,
      location: '/screen/queue-clear-confirm',
      adapter: ApiAdapter((request) {
        if (request.path == '/player/session') {
          return jsonResponse(catalogPlayerSessionFixture());
        }
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        if (request.path == '/queue') {
          if (request.method == 'DELETE') {
            cleared = true;
            return jsonResponse({'version': 2, 'count': 0});
          }
          return jsonResponse(
            catalogQueueFixture(items: cleared ? const <Map<String, dynamic>>[] : null),
          );
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.ensureVisible(find.widgetWithText(PelevoButton, 'Clear Queue'));
    await tester.tap(find.widgetWithText(PelevoButton, 'Clear Queue'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Your queue is empty'), findsOneWidget);
  });

  testWidgets('history binds recent plays and does not fake a clear', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/queue-history',
      adapter: ApiAdapter((request) {
        if (request.path == '/player/session') {
          return jsonResponse(catalogPlayerSessionFixture());
        }
        if (request.path == '/queue') {
          return jsonResponse(catalogQueueFixture());
        }
        if (request.path == '/library/recent') {
          return jsonResponse([catalogRecentEpisodeFixture()]);
        }
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('Ep. 123 - Keep Going'), findsOneWidget);
    expect(find.text('Ep. 120 - Boundaries'), findsNothing);
    await tester.tap(find.text('Clear History'));
    await tester.pumpAndSettle();
    expect(find.text('Clearing playback history is not offered yet.'), findsOneWidget);
    expect(find.text('History cleared'), findsNothing);
  });
}
