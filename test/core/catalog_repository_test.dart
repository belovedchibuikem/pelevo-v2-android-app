import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import '../support/api_adapter.dart';
import '../support/catalog_fixture.dart';

void main() {
  CatalogRepository repository(Dio dio) => CatalogRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('show and episodes parse public fields', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/shows/$catalogShowId') {
          return jsonResponse(catalogShowFixture());
        }
        if (request.path == '/shows/$catalogShowId/episodes') {
          return jsonResponse(
            catalogEpisodesFixture(),
            meta: {'cursor': null, 'has_more': false, 'episodes_syncing': false},
          );
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final token = CancelToken();
    final show = await repository(dio).show(catalogShowId, token);
    expect(show.title, 'The Honest Bunch');
    expect(show.following, isTrue);
    expect(show.categories.single.name, 'Society & Culture');

    final page = await repository(dio).episodes(catalogShowId, token);
    expect(page.items.first.title, 'Ep. 124 - The Shift Life');
    expect(page.items.first.audioUrl, isNull);
    expect(page.hasMore, isFalse);
  });

  test('episodes page keeps cursor for load-more', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/shows/$catalogShowId/episodes');
        expect(request.queryParameters['limit'], 20);
        if (request.queryParameters['cursor'] == 'next-page') {
          return jsonResponse(
            [
              catalogEpisodeFixture(
                id: 'catalog-episode-3',
                title: 'Ep. 122 - Older',
              ),
            ],
            meta: {
              'cursor': null,
              'has_more': false,
              'episodes_syncing': false,
            },
          );
        }
        return jsonResponse(
          catalogEpisodesFixture(),
          meta: {
            'cursor': 'next-page',
            'has_more': true,
            'episodes_syncing': false,
          },
        );
      }),
    );
    final first = await repository(dio).episodes(catalogShowId, CancelToken());
    expect(first.hasMore, isTrue);
    expect(first.cursor, 'next-page');
    final second = await repository(
      dio,
    ).episodes(catalogShowId, CancelToken(), cursor: first.cursor);
    expect(second.items.single.id, 'catalog-episode-3');
    expect(second.hasMore, isFalse);
  });

  test('related cards do not invent follower counts', () {
    expect(
      CatalogRelatedShow.parse(catalogRelatedShowFixture()).title,
      'Ranked Show',
    );
    expect(
      () => CatalogShow.parse(catalogRelatedShowFixture()),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('episode detail requires audio_url and chapters stay compact', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        if (request.path == '/episodes/$catalogEpisodeId/chapters') {
          return jsonResponse(catalogChaptersFixture());
        }
        if (request.path == '/episodes/$catalogEpisodeId/transcript') {
          return jsonResponse(catalogTranscriptFixture());
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final token = CancelToken();
    final episode = await repository(dio).episode(catalogEpisodeId, token);
    expect(episode.audioUrl, contains('shift-life'));
    final chapters = await repository(dio).chapters(catalogEpisodeId, token);
    expect(chapters.first.title, 'Introduction');
    final transcript = await repository(dio).transcript(catalogEpisodeId, token);
    expect(transcript, contains('quietly rewrite'));
  });

  test('queue items require show_id', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/queue');
        return jsonResponse(catalogQueueFixture());
      }),
    );
    final queue = await repository(dio).queue(CancelToken());
    expect(queue.items.single.episode.showId, catalogShowId);
    expect(queue.items.single.episode.title, 'Ep. 123 - Keep Going');
  });

  test('reorderCatalogQueueItems moves the selected row', () {
    const first = CatalogQueueItem(
      'q1',
      0,
      CatalogEpisode(id: 'a', showId: 's', title: 'A'),
    );
    const second = CatalogQueueItem(
      'q2',
      1,
      CatalogEpisode(id: 'b', showId: 's', title: 'B'),
    );
    final moved = reorderCatalogQueueItems([first, second], 1, 0);
    expect(moved.map((item) => item.episode.id).toList(), ['b', 'a']);
    expect(moved.first.position, 0);
  });

  test('queue notifier persists a new play order', () async {
    late RequestOptions seen;
    final dio = dioWith(
      ApiAdapter((request) {
        seen = request;
        if (request.path == '/queue' && request.method != 'PUT') {
          return jsonResponse(
            catalogQueueFixture(
              items: [
                {
                  'queue_item_id': 'q1',
                  'position': 0,
                  'id': 'a',
                  'show_id': catalogShowId,
                  'title': 'A',
                  'show_title': 'Show',
                  'duration_seconds': 60,
                  'artwork_url': null,
                },
                {
                  'queue_item_id': 'q2',
                  'position': 1,
                  'id': 'b',
                  'show_id': catalogShowId,
                  'title': 'B',
                  'show_title': 'Show',
                  'duration_seconds': 60,
                  'artwork_url': null,
                },
              ],
            ),
          );
        }
        if (request.path == '/queue/reorder') {
          return jsonResponse({'version': 2, 'count': 2});
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
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
      ],
    );
    addTearDown(container.dispose);

    final queue = await container.read(catalogQueueProvider.future);
    await container
        .read(catalogQueueProvider.notifier)
        .commitOrder(reorderCatalogQueueItems(queue.items, 1, 0));

    expect(seen.path, '/queue/reorder');
    expect(seen.data['episode_ids'], ['b', 'a']);
    expect(
      container.read(catalogQueueProvider).requireValue.items.first.episode.id,
      'b',
    );
  });

  test('queue mutations send versioned bodies', () async {
    late RequestOptions seen;
    final dio = dioWith(
      ApiAdapter((request) {
        seen = request;
        if (request.method == 'DELETE' &&
            request.path.startsWith('/queue/items/')) {
          return jsonResponse({'version': 3});
        }
        if (request.path == '/queue' && request.method == 'PUT') {
          return jsonResponse({'version': 4, 'count': 2});
        }
        if (request.path == '/queue' && request.method == 'GET') {
          return jsonResponse(catalogQueueFixture());
        }
        if (request.path == '/queue/reorder' && request.method == 'PUT') {
          return jsonResponse({'version': 6, 'count': 2});
        }
        if (request.path == '/queue' && request.method == 'DELETE') {
          return jsonResponse({'version': 5, 'count': 0});
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final repo = repository(dio);
    expect(await repo.removeQueueItem(catalogQueueItemId, 2), 3);
    expect(seen.path, '/queue/items/$catalogQueueItemId');
    expect(seen.data['version'], 2);

    expect(await repo.replaceQueue(['a', 'b'], 3), 4);
    expect(seen.method, 'PUT');
    expect(seen.path, '/queue');
    expect(seen.data['episode_ids'], ['a', 'b']);

    expect(await repo.replaceQueueRetry(['c']), 4);

    expect(await repo.reorderQueue(['b', 'a'], 5), 6);
    expect(seen.method, 'PUT');
    expect(seen.path, '/queue/reorder');
    expect(seen.data['episode_ids'], ['b', 'a']);
    expect(seen.data['version'], 5);

    expect(await repo.clearQueue(4), 5);
    expect(seen.method, 'DELETE');
    expect(seen.data['version'], 4);
  });

  test('library recent requires show_id and omits audio', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/library/recent');
        return jsonResponse([catalogRecentEpisodeFixture()]);
      }),
    );
    final recent = await repository(dio).libraryRecent(CancelToken());
    expect(recent.single.episode.title, 'Ep. 123 - Keep Going');
    expect(recent.single.episode.audioUrl, isNull);
    expect(recent.single.completed, isTrue);
  });

  test('follow and review stay on public receipts', () async {
    late RequestOptions seen;
    final dio = dioWith(
      ApiAdapter((request) {
        seen = request;
        if (request.path.endsWith('/follow')) {
          return jsonResponse({'following': request.method != 'DELETE'});
        }
        return jsonResponse(catalogReviewFixture(), status: 201);
      }),
    );
    final repo = repository(dio);
    await repo.follow(catalogShowId, following: true);
    expect(seen.method, 'POST');
    await repo.review(catalogShowId, rating: 5, body: 'Clear and useful.');
    expect(seen.path, '/shows/$catalogShowId/reviews');
  });
}
