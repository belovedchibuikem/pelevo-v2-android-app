import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/browse/browse_data.dart';
import '../support/api_adapter.dart';
import '../support/browse_fixture.dart';
import '../support/account_feed_fixture.dart';

void main() {
  test('browse categories category detail and following parse public fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/browse') {
        return jsonResponse(browseCategoriesFixture());
      }
      if (request.path == '/browse/music') {
        return jsonResponse(
          browseCategoryPageFixture(
            id: '2',
            name: 'Music',
            slug: 'music',
            shows: [browseShowFixture(id: 'show-music', title: 'Lagos Mix')],
          ),
        );
      }
      if (request.path.startsWith('/browse/')) {
        return jsonResponse(browseCategoryPageFixture());
      }
      if (request.path == '/me/following') {
        return jsonResponse([followedShowFixture('one')]);
      }
      if (request.path == '/shows/show-1/follow') {
        return jsonResponse({'following': true});
      }
      throw StateError('${request.method} ${request.path}');
    });
    final repository = BrowseRepository(dio);

    final categories = await repository.categories();
    expect(categories.first.name, 'Technology');
    expect(categories.last.isMusic, isTrue);

    final page = await repository.category('technology');
    expect(page.category.slug, 'technology');
    expect(page.shows.single.title, 'Owned Show');
    expect(seen.path, '/browse/technology');

    final music = await repository.category('music');
    expect(music.shows.single.title, 'Lagos Mix');

    final following = await repository.following();
    expect(following.single.title, 'Server show one');

    await repository.follow('show-1');
  });

  test('browse category rejects a missing name', () {
    expect(
      () => BrowseCategory.fromApi({'id': '1', 'slug': 'technology'}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
