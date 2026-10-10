import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/home/home_data.dart';
import '../support/api_adapter.dart';

void main() {
  test('cache never crosses accounts or appears when signed out', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'schema_version': 2, 'rails': []}),
    );
    final cache = MemoryHomeFeedCache();
    final owner = HomeRepository(dio, cache, 'account-a');
    await owner.fetch();
    expect(owner.cached(), isNotNull);
    expect(HomeRepository(dio, cache, 'account-b').cached(), isNull);
    expect(HomeRepository(dio, cache, null).cached(), isNull);
    await expectLater(
      HomeRepository(dio, cache, null).fetch(),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('home cache expires after a day and stays unmarked before that', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    final cache = MemoryHomeFeedCache();
    final repository = HomeRepository(dio, cache, 'account-a');
    const payload = {
      'schema_version': 2,
      'rails': <Map<String, dynamic>>[],
    };

    Future<void> save(Duration age) {
      return cache.put(
        'home_feed_v4:account-a',
        jsonEncode({
          'saved_at': DateTime.now()
              .toUtc()
              .subtract(age)
              .toIso8601String(),
          'data': payload,
        }),
      );
    }

    await save(const Duration(hours: 30));
    expect(repository.cached(), isNull);

    await save(const Duration(hours: 2));
    expect(repository.cached()?.stale, isFalse);

    await save(const Duration(minutes: 5));
    expect(repository.cached()?.stale, isFalse);
  });

  test('cache is rendered before network without offline banner by default', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'schema_version': 2, 'rails': []}),
    );
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');
    await repository.fetch();
    final values = await repository.watch().toList();
    expect(values.map((value) => value.stale), [false, false]);
  });

  test('slow home fetch keeps cached feed without offline banner', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'schema_version': 2, 'rails': []}),
    );
    await repository.fetch();
    dio.httpClientAdapter = ApiAdapter((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      return jsonResponse({'schema_version': 2, 'rails': []});
    });
    final values = await repository.watch().toList();
    expect(values.map((value) => value.stale), [false, false]);
  });

  test('failed home fetch keeps cached feed without offline banner', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'schema_version': 2, 'rails': []}),
    );
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');
    await repository.fetch();
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse(null, status: 500),
    );
    final values = await repository.watch().toList();
    expect(values.first.stale, isFalse);
    expect(values.last.stale, isFalse);
  });

  test('connection failure keeps the saved feed without an offline state', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'schema_version': 2, 'rails': []}),
    );
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');
    await repository.fetch();
    dio.httpClientAdapter = ApiAdapter(
      (_) => throw DioException(
        requestOptions: RequestOptions(path: '/home/feed'),
        type: DioExceptionType.connectionError,
      ),
    );
    final values = await repository.watch().toList();
    expect(values.first.stale, isFalse);
    expect(values.last.stale, isFalse);
  });

  test(
    'authentication failure is surfaced even when cached content exists',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
      addTearDown(() => dio.close(force: true));
      dio.httpClientAdapter = ApiAdapter(
        (_) => jsonResponse({'schema_version': 2, 'rails': []}),
      );
      final repository = HomeRepository(
        dio,
        MemoryHomeFeedCache(),
        'account-a',
      );
      await repository.fetch();
      dio.httpClientAdapter = ApiAdapter(
        (_) => jsonResponse(null, status: 401),
      );
      await expectLater(
        repository.watch(),
        emitsInOrder([
          isA<HomeFeed>(),
          emitsError(isA<DioException>()),
          emitsDone,
        ]),
      );
    },
  );

  test('discover, charts and playlists parse destination envelopes', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      return jsonResponse(switch (request.path) {
        '/home/discover' => {
          'editors_picks': [
            {
              'id': 'editorial-1',
              'type': 'editorial_playlist',
              'title': 'Voices desk',
              'subtitle': 'Editor selected',
            },
          ],
          'trending': [
            {
              'id': 'ep-1',
              'type': 'episode',
              'title': 'Fresh episode',
              'show_title': 'Discover Show',
              'rank': 1,
            },
          ],
          'new_episodes': [
            {
              'id': 'ep-1',
              'type': 'episode',
              'title': 'Fresh episode',
              'show_title': 'Discover Show',
            },
          ],
        },
        '/home/charts' => {
          'podcasts': [
            {
              'id': 'show-1',
              'type': 'show',
              'title': 'Ranked Show',
              'subtitle': 'Ada',
              'rank': 1,
            },
          ],
          'music': <Map<String, dynamic>>[],
          'audiobooks': <Map<String, dynamic>>[],
        },
        '/home/playlists' => {
          'yours': [
            {
              'id': 'pl-1',
              'type': 'playlist',
              'title': 'Morning desk',
              'item_count': 2,
            },
          ],
          'live': [
            {
              'id': 'live-1',
              'type': 'live',
              'title': 'The Midday desk',
              'subtitle': 'Layi',
              'viewer_count': 12,
            },
          ],
        },
        _ => throw StateError(request.path),
      });
    });
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');

    final discover = await repository.discover();
    expect(discover.editorsPicks.single.title, 'Voices desk');
    expect(discover.trending.single.rank, 1);
    expect(discover.newEpisodes.single.showTitle, 'Discover Show');

    final charts = await repository.charts();
    expect(charts.podcasts.single.subtitle, 'Ada');
    expect(charts.music, isEmpty);
    expect(charts.audiobooks, isEmpty);

    final playlists = await repository.playlists();
    expect(playlists.yours.single.itemCount, 2);
    expect(playlists.live.single.viewerCount, 12);
  });

  test('destination payloads reject invented list shapes', () {
    expect(
      () => HomeDiscoverPage.fromApi({'editors_picks': 'seeded'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => HomeChartsPage.fromApi({
        'podcasts': {'title': 'AfroBeats Now'},
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => HomePlaylistsPage.fromApi({'yours': 'Morning Motivation'}),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('rail requests send only supplied filter query params', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse({
        'schema_version': 2,
        'rail': {
          'id': 'quick_listen',
          'key': 'quick_listen',
          'type': 'episodes',
          'title': 'Quick Listen',
          'subtitle': 'Short episodes that fit your time',
          'items': <Map<String, dynamic>>[],
        },
      });
    });
    final repository = HomeRepository(dio, MemoryHomeFeedCache(), 'account-a');
    final rail = await repository.rail(
      'quick_listen',
      minDurationSeconds: 1800,
    );
    expect(seen.path, '/home/rails/quick_listen');
    expect(seen.queryParameters, {'min_duration': 1800});
    expect(rail.subtitle, 'Short episodes that fit your time');
    expect(rail.items, isEmpty);
  });

  test('rail responses without a rail object are rejected', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({'accepted': true}),
    );
    await expectLater(
      HomeRepository(dio, MemoryHomeFeedCache(), 'account-a').rail('trending'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
