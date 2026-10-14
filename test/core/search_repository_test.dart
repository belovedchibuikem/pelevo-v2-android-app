import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/search/search_data.dart';
import '../support/api_adapter.dart';
import '../support/search_fixture.dart';

void main() {
  test('search page parses presented shows episodes and playlists', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/search') {
        final query = '${request.queryParameters['q']}';
        if (query.contains('unknown')) {
          return jsonResponse(searchPageFixture(query: query, shows: const [], episodes: const [], playlists: const []));
        }
        return jsonResponse(searchPageFixture(query: query));
      }
      if (request.path == '/search/recent') {
        if (request.method == 'DELETE') {
          return jsonResponse({'cleared': true});
        }
        return jsonResponse([recentSearchFixture()]);
      }
      if (request.path == '/search/voice') {
        return jsonResponse(searchPageFixture(query: '${request.data['transcript']}'));
      }
      if (request.path == '/shows/show-1/follow') {
        return jsonResponse({
          'following': request.method == 'POST',
        });
      }
      throw StateError('${request.method} ${request.path}');
    });
    final repository = SearchRepository(dio);

    final keyed = SearchPage.fromApi({
      'query': 'Apostle',
      'shows': {
        '01m2show': searchShowFixture(id: '01m2show', title: 'Apostle Hour'),
      },
      'episodes': const [],
      'playlists': const [],
    });
    expect(keyed.shows.single.title, 'Apostle Hour');

    final page = await repository.search(const SearchRequest('Owned'));
    expect(page.query, 'Owned');
    expect(page.shows.single.title, 'Owned Show');
    expect(page.episodes.single.title, 'Fresh episode');
    expect(page.playlists.single.itemCount, 1);
    expect(seen.queryParameters['preview'], isNull);

    final preview = await repository.search(
      const SearchRequest('Ow', preview: true),
    );
    expect(preview.shows.single.title, 'Owned Show');
    expect(seen.queryParameters['preview'], 1);

    final showsOnly = await repository.search(
      const SearchRequest('Owned', type: 'show'),
    );
    expect(showsOnly.shows.single.title, 'Owned Show');
    expect(seen.queryParameters['type'], 'show');
    expect(seen.queryParameters['preview'], isNull);

    final empty = await repository.search(const SearchRequest('unknown topic'));
    expect(empty.isEmpty, isTrue);

    final recent = await repository.recent();
    expect(recent.single.query, 'Technology');

    final voiced = await repository.voice('Owned');
    expect(voiced.query, 'Owned');

    expect(await repository.follow('show-1', following: true), isTrue);
    expect(await repository.follow('show-1', following: false), isFalse);
    await repository.clearRecent();
  });

  test('search show presentation rejects a missing title', () {
    expect(
      () => SearchShow.fromApi({'id': 'show-1'}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
