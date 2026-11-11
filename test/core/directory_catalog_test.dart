import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/search/directory/directory_http.dart';
import 'package:pelevo/features/search/directory/directory_library.dart';
import 'package:pelevo/features/search/directory/directory_models.dart';
import 'package:pelevo/features/search/directory/directory_rate_limiter.dart';
import 'package:pelevo/features/search/directory/directory_repository.dart';
import 'package:pelevo/features/search/directory/feed_address.dart';
import 'package:pelevo/features/search/directory/feed_health.dart';
import 'package:pelevo/features/search/directory/rss_channel.dart';

import '../support/api_adapter.dart';

void main() {
  test('feed keys ignore scheme, slash, and tracking parameters', () {
    final https = FeedAddress.tryParse(
      'https://feeds.example.com/serial/?utm_source=apple',
    );
    final http = FeedAddress.tryParse('http://feeds.example.com/serial');
    expect(https, isNotNull);
    expect(http?.key, https!.key);
    expect(FeedAddress.tryParse('http://127.0.0.1/feed'), isNull);
    expect(FeedAddress.tryParse('http://10.0.0.4/feed'), isNull);
    expect(FeedAddress.tryParse('https://localhost/feed'), isNull);
  });

  test('dead and unreachable feeds are classified from the response', () {
    expect(classifyFeedHttp(status: 404, body: 'missing'), FeedHealth.dead);
    expect(classifyFeedHttp(status: 200, body: '   '), FeedHealth.dead);
    expect(
      classifyFeedHttp(status: 200, body: '<rss><channel></channel></rss>'),
      FeedHealth.alive,
    );
    expect(classifyFeedHttp(status: 503), FeedHealth.unreachable);
    expect(classifyFeedHttp(status: 429), FeedHealth.unreachable);
  });

  test('rate limiter blocks a bucket and honors a remote block', () {
    var now = DateTime.utc(2026, 11, 11, 12);
    final limiter = DirectoryRateLimiter(
      applePerMinute: 2,
      clock: () => now,
    );
    expect(limiter.tryAcquire(DirectoryBucket.apple), isTrue);
    expect(limiter.tryAcquire(DirectoryBucket.apple), isTrue);
    expect(limiter.tryAcquire(DirectoryBucket.apple), isFalse);
    now = now.add(const Duration(seconds: 61));
    expect(limiter.tryAcquire(DirectoryBucket.apple), isTrue);
    limiter.block(DirectoryBucket.probe, const Duration(seconds: 30));
    expect(limiter.tryAcquire(DirectoryBucket.probe), isFalse);
    now = now.add(const Duration(seconds: 31));
    expect(limiter.tryAcquire(DirectoryBucket.probe), isTrue);
  });

  test('rss parser reads enclosures and skips items without audio', () {
    final channel = parseRssChannel('''
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Serial</title>
    <itunes:author>Sarah Koenig</itunes:author>
    <description>A &amp; reported story</description>
    <itunes:image href="https://img.example.com/cover.jpg"/>
    <item>
      <title>Episode 1</title>
      <guid>ep-1</guid>
      <enclosure url="https://cdn.example.com/1.mp3" type="audio/mpeg"/>
      <itunes:duration>1:02:03</itunes:duration>
      <pubDate>Wed, 11 Nov 2026 12:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Trailer</title>
      <guid>video</guid>
      <enclosure url="https://cdn.example.com/t.mp4" type="video/mp4"/>
    </item>
  </channel>
</rss>
''');
    expect(channel.title, 'Serial');
    expect(channel.author, 'Sarah Koenig');
    expect(channel.description, 'A & reported story');
    expect(channel.artworkUrl, 'https://img.example.com/cover.jpg');
    expect(channel.episodes, hasLength(1));
    expect(channel.episodes.single.guid, 'ep-1');
    expect(channel.episodes.single.durationSeconds, 3723);
    expect(channel.episodes.single.publishedAt, DateTime.utc(2026, 11, 11, 12));
  });

  test('apple and podcast index rows for one feed collapse', () {
    final apple = candidateFromApple({
      'collectionId': 10,
      'collectionName': 'Serial',
      'artistName': 'This American Life',
      'feedUrl': 'https://feeds.example.com/serial?utm_source=apple',
      'artworkUrl600': 'https://img.example.com/a.jpg',
      'trackCount': 12,
    });
    final indexed = candidateFromPodcastIndex({
      'id': 99,
      'title': 'Serial',
      'author': 'This American Life',
      'url': 'http://feeds.example.com/serial/',
      'image': 'https://img.example.com/b.jpg',
      'episodeCount': 40,
      'dead': 0,
    });
    final dead = candidateFromPodcastIndex({
      'id': 100,
      'title': 'Gone',
      'url': 'https://feeds.example.com/gone',
      'dead': 1,
    });
    expect(apple?.feedKey, indexed?.feedKey);
    expect(dead, isNull);
    final merged = mergeDirectoryCandidates([apple!, indexed!]);
    expect(merged, hasLength(1));
    expect(merged.single.episodeCount, 40);
    expect(merged.single.source, 'apple');
    expect(
      matchingCatalogShowId(merged.single, [
        (id: 'show-9', title: 'Serial', author: 'This American Life'),
      ]),
      'show-9',
    );
  });

  test('podcast index authorization is the documented sha1 header', () {
    final headers = const PodcastIndexCredentials(
      key: 'key',
      secret: 'secret',
    ).headers(now: DateTime.utc(2020, 1, 1));
    expect(headers['X-Auth-Date'], '1577836800');
    expect(headers['X-Auth-Key'], 'key');
    expect(
      headers['Authorization'],
      sha1.convert(utf8.encode('keysecret1577836800')).toString(),
    );
  });

  test('server directory results are used without calling Apple', () async {
    final api = Dio();
    final external = Dio();
    addTearDown(api.close);
    addTearDown(external.close);
    var externalCalls = 0;
    api.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/directory/search') {
        return jsonResponse({
          'query': 'serial',
          'candidates': [
            {
              'id': 'apple:10',
              'title': 'Serial',
              'author': 'Sarah',
              'source': 'apple',
              'artwork_url': 'https://img.example.com/a.jpg',
              'in_catalog': false,
              'episode_count': 12,
            },
          ],
        });
      }
      throw StateError(request.path);
    });
    external.httpClientAdapter = ApiAdapter((request) {
      externalCalls++;
      throw StateError(request.uri.toString());
    });
    final repository = DirectoryRepository(
      api: api,
      external: external,
      readStore: MemoryDirectoryStore.new,
      podcastIndex: const PodcastIndexCredentials(key: '', secret: ''),
    );

    final page = await repository.search('serial');
    expect(page.candidates.single.title, 'Serial');
    expect(page.candidates.single.id, 'apple:10');
    expect(externalCalls, 0);
  });

  test('a missing directory route searches Apple and Podcast Index', () async {
    final api = Dio();
    final external = Dio();
    addTearDown(api.close);
    addTearDown(external.close);
    api.httpClientAdapter = ApiAdapter(
      (request) => ResponseBody.fromString('missing', 404),
    );
    external.httpClientAdapter = ApiAdapter((request) {
      if (request.uri.host == 'itunes.apple.com') {
        return ResponseBody.fromString(
          jsonEncode({
            'results': [
              {
                'collectionId': 10,
                'collectionName': 'Serial',
                'artistName': 'This American Life',
                'feedUrl': 'https://feeds.example.com/serial?utm_source=apple',
                'artworkUrl600': 'https://img.example.com/a.jpg',
                'trackCount': 12,
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      if (request.uri.host == 'api.podcastindex.org') {
        expect(request.headers['X-Auth-Key'], 'key');
        return ResponseBody.fromString(
          jsonEncode({
            'feeds': [
              {
                'id': 99,
                'title': 'Serial',
                'author': 'This American Life',
                'url': 'http://feeds.example.com/serial/',
                'episodeCount': 40,
                'dead': 0,
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      throw StateError(request.uri.toString());
    });
    final repository = DirectoryRepository(
      api: api,
      external: external,
      readStore: MemoryDirectoryStore.new,
      podcastIndex: const PodcastIndexCredentials(key: 'key', secret: 'secret'),
    );

    final page = await repository.search('serial');
    expect(page.candidates, hasLength(1));
    expect(page.candidates.single.episodeCount, 40);
    expect(page.candidates.single.feedKey, 'feeds.example.com/serial');
  });

  test('a dead pasted feed is refused before it can be added', () async {
    final api = Dio();
    final external = Dio();
    addTearDown(api.close);
    addTearDown(external.close);
    api.httpClientAdapter = ApiAdapter(
      (request) => ResponseBody.fromString('missing', 404),
    );
    external.httpClientAdapter = ApiAdapter((request) {
      return ResponseBody.fromString('gone', 404, headers: {
        Headers.contentTypeHeader: ['text/plain'],
      });
    });
    final repository = DirectoryRepository(
      api: api,
      external: external,
      readStore: MemoryDirectoryStore.new,
    );

    final page = await repository.search('https://feeds.example.com/missing.xml');
    expect(page.candidates, isEmpty);
    expect(page.unavailableMessage, contains('unavailable'));
  });

  test('subscribe stores the feed locally when the catalog route is missing', () async {
    final api = Dio();
    final external = Dio();
    addTearDown(api.close);
    addTearDown(external.close);
    final store = MemoryDirectoryStore();
    api.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/search') {
        return jsonResponse({
          'query': 'feed',
          'shows': const [],
          'episodes': const [],
          'playlists': const [],
        });
      }
      if (request.path == '/directory/subscribe') {
        return ResponseBody.fromString('missing', 404);
      }
      throw StateError('${request.method} ${request.path}');
    });
    external.httpClientAdapter = ApiAdapter((request) {
      return ResponseBody.fromString(_rss(items: 1), 200, headers: {
        Headers.contentTypeHeader: ['application/rss+xml'],
      });
    });
    final repository = DirectoryRepository(
      api: api,
      external: external,
      readStore: () => store,
    );
    final candidate = candidateFromApple({
      'collectionId': 10,
      'collectionName': 'Serial',
      'artistName': 'Sarah',
      'feedUrl': 'https://feeds.example.com/serial',
      'trackCount': 1,
    })!;

    final added = await repository.subscribe(candidate);
    expect(added.storedLocally, isTrue);
    expect(added.showId, startsWith('dirshow_'));
    expect(repository.storedShow(added.showId)!.episodes, hasLength(1));
    expect(repository.storedShow(added.showId)!.following, isTrue);

    external.httpClientAdapter = ApiAdapter((request) {
      return ResponseBody.fromString(_rss(items: 2), 200, headers: {
        Headers.contentTypeHeader: ['application/rss+xml'],
      });
    });
    expect(
      await repository.refreshStored(added.showId, force: true),
      isTrue,
    );
    expect(repository.storedShow(added.showId)!.episodes, hasLength(2));
    expect(
      repository.storedShow(added.showId)!.episodes.map((episode) => episode.guid),
      containsAll(['ep-1', 'ep-2']),
    );
  });

  test('subscribe uses the catalog show and asks it to refresh', () async {
    final api = Dio();
    final external = Dio();
    addTearDown(api.close);
    addTearDown(external.close);
    final seen = <String>[];
    api.httpClientAdapter = ApiAdapter((request) {
      seen.add('${request.method} ${request.path}');
      if (request.path == '/search') {
        return jsonResponse({
          'query': 'feed',
          'shows': const [],
          'episodes': const [],
          'playlists': const [],
        });
      }
      if (request.path == '/directory/subscribe') {
        return jsonResponse({
          'show_id': 'show-9',
          'already_in_catalog': false,
          'episodes_syncing': true,
        });
      }
      if (request.path == '/shows/show-9/refresh') {
        return jsonResponse({'accepted': true});
      }
      throw StateError('${request.method} ${request.path}');
    });
    external.httpClientAdapter = ApiAdapter((request) {
      throw StateError('external ${request.uri}');
    });
    final repository = DirectoryRepository(
      api: api,
      external: external,
      readStore: MemoryDirectoryStore.new,
    );
    final candidate = candidateFromChannel(
      address: FeedAddress.tryParse('https://feeds.example.com/serial')!,
      channel: parseRssChannel(_rss(items: 1)),
    );

    final added = await repository.subscribe(candidate);
    expect(added.showId, 'show-9');
    expect(added.storedLocally, isFalse);
    expect(seen, contains('POST /shows/show-9/refresh'));
  });
}

String _rss({required int items}) => '''
<rss><channel><title>Serial</title><itunes:author>Sarah</itunes:author>
${[
  for (var index = 1; index <= items; index++)
    '<item><title>Episode $index</title><guid>ep-$index</guid>'
        '<enclosure url="https://cdn.example.com/$index.mp3" type="audio/mpeg"/>'
        '<pubDate>${index.toString().padLeft(2, '0')} Nov 2026 12:00:00 GMT</pubDate>'
        '</item>',
].join()}
</channel></rss>
''';
