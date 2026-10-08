import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/stats/stats_data.dart';
import '../support/api_adapter.dart';
import '../support/catalog_fixture.dart';

void main() {
  test('stats parse presented totals without evidence', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.path, '/stats/me');
      return jsonResponse(catalogStatsFixture());
    });
    final stats = await ListenerStatsRepository(dio).me(CancelToken());
    expect(stats.listeningSeconds, 120);
    expect(stats.downloadsCount, 0);
    expect(stats.shows.single.title, 'The Honest Bunch');
    expect(stats.achievements.single.name, 'First Episode');
    expect(stats.streak?.currentDays, 3);
  });

  test('stats reject achievement evidence', () {
    expect(
      () => ListenerStats.parse(
        catalogStatsFixture()..['achievements'] = [
          {
            'slug': 'first-episode',
            'name': 'First Episode',
            'description': 'Finished an episode',
            'earned_at': '2026-09-10T12:00:00Z',
            'evidence': {'plays': 1},
          },
        ],
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
}
