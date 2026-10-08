import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/library/library_data.dart';
import '../support/api_adapter.dart';
import '../support/catalog_fixture.dart';
import '../support/library_fixture.dart';

void main() {
  LibraryRepository repository(Dio dio) => LibraryRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('overview and playlist detail stay public', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/library') {
          return jsonResponse(libraryOverviewFixture());
        }
        if (request.path == '/playlists/$libraryPlaylistId') {
          return jsonResponse(libraryPlaylistFixture(detailed: true));
        }
        if (request.path == '/library/recent') {
          return jsonResponse([
            libraryEpisodeFixture(position: 90, completed: false)
              ..['played_at'] = '2026-09-09T12:00:00Z',
          ]);
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final token = CancelToken();
    final overview = await repository(dio).overview(token);
    expect(overview.playlists.single.name, 'Mindset & Growth');
    expect(overview.savedCount, 1);
    expect(overview.recentCount, 1);

    final playlist = await repository(dio).playlist(libraryPlaylistId, token);
    expect(playlist.items.single.title, 'Ep. 124 - The Shift Life');
    expect(playlist.items.single.id, catalogEpisodeId);

    final recent = await repository(dio).recent(token);
    expect(recent.single.positionSeconds, 90);
    expect(recent.single.progress, closeTo(90 / 2700, 0.001));
  });

  test('library episode rows reject audio and guid leaks', () {
    expect(
      () => LibraryEpisode.parse({
        ...libraryEpisodeFixture(),
        'audio_url': 'https://cdn.example.invalid/shift-life.mp3',
        'guid': 'secret-guid',
      }),
      returnsNormally,
    );
    expect(
      () => LibraryEpisode.parse({
        'id': catalogEpisodeId,
        'title': 'Missing show',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('downloads parse authorization without byte sizes', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/downloads');
        return jsonResponse([libraryDownloadFixture()]);
      }),
    );
    final downloads = await repository(dio).downloads(CancelToken());
    expect(downloads.single.downloadId, libraryDownloadId);
    expect(downloads.single.title, 'Ep. 124 - The Shift Life');
  });

  test('storage usage and delete wait for receipts', () async {
    var deleted = 0;
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture(offlineItems: 2));
        }
        if (request.path == '/downloads/$libraryDownloadId' &&
            request.method == 'DELETE') {
          deleted += 1;
          return jsonResponse({'deleted': true});
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final usage = await repository(dio).storage(CancelToken());
    expect(usage.offlineItems, 2);
    expect(usage.backupBytes, 0);
    await repository(dio).deleteDownload(libraryDownloadId);
    expect(deleted, 1);
  });
}
