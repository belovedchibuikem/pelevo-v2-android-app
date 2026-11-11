import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/search/directory/directory_models.dart';
import 'package:pelevo/features/search/directory/directory_rate_limiter.dart';
import 'package:pelevo/features/search/directory/feed_address.dart';
import 'package:pelevo/features/search/directory/feed_health.dart';
import 'package:pelevo/features/search/directory/rss_channel.dart';

class FetchedFeed {
  const FetchedFeed({
    required this.address,
    required this.health,
    this.channel,
    this.message,
  });

  final FeedAddress address;
  final FeedHealth health;
  final RssChannel? channel;
  final String? message;
}

/// HTTP access to Apple Podcasts, Podcast Index, and publisher feeds.
class DirectoryHttp {
  DirectoryHttp({
    required Dio external,
    DirectoryRateLimiter? limiter,
    this.podcastIndex = PodcastIndexCredentials.fromEnvironment,
    this.userAgent = 'Pelevo',
  }) : _external = external,
       _limiter = limiter ?? DirectoryRateLimiter();

  final Dio _external;
  final DirectoryRateLimiter _limiter;
  final PodcastIndexCredentials podcastIndex;
  final String userAgent;

  DirectoryRateLimiter get limiter => _limiter;

  Future<List<DirectoryCandidate>> searchApple(
    String query, {
    CancelToken? cancelToken,
  }) async {
    _acquire(DirectoryBucket.apple);
    final response = await _external.get<Map<String, dynamic>>(
      'https://itunes.apple.com/search',
      queryParameters: {
        'term': query,
        'media': 'podcast',
        'entity': 'podcast',
        'limit': 20,
      },
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code < 600,
      ),
    );
    _honorRetry(DirectoryBucket.apple, response.statusCode, response.headers);
    if (response.statusCode == 429) {
      throw _busy(DirectoryBucket.apple);
    }
    if (response.statusCode != 200) {
      throw const ApiFailure(
        code: 'DIRECTORY_UNAVAILABLE',
        message: 'Apple Podcasts search is unavailable. Try again.',
      );
    }
    final results = response.data?['results'];
    if (results is! List) return const [];
    final candidates = <DirectoryCandidate>[];
    for (final row in results) {
      if (row is! Map) continue;
      final candidate = candidateFromApple(Map<String, dynamic>.from(row));
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  Future<List<DirectoryCandidate>> searchPodcastIndex(
    String query, {
    CancelToken? cancelToken,
    DateTime? now,
  }) async {
    if (!podcastIndex.enabled) return const [];
    _acquire(DirectoryBucket.podcastIndex);
    final response = await _external.get<Map<String, dynamic>>(
      'https://api.podcastindex.org/api/1.0/search/byterm',
      queryParameters: {'q': query, 'max': 20},
      cancelToken: cancelToken,
      options: Options(
        headers: podcastIndex.headers(now: now, userAgent: userAgent),
        responseType: ResponseType.json,
        validateStatus: (code) => code != null && code < 600,
      ),
    );
    _honorRetry(
      DirectoryBucket.podcastIndex,
      response.statusCode,
      response.headers,
    );
    if (response.statusCode == 429) {
      throw _busy(DirectoryBucket.podcastIndex);
    }
    if (response.statusCode != 200) {
      throw const ApiFailure(
        code: 'DIRECTORY_UNAVAILABLE',
        message: 'Podcast Index search is unavailable. Try again.',
      );
    }
    final feeds = response.data?['feeds'];
    if (feeds is! List) return const [];
    final candidates = <DirectoryCandidate>[];
    for (final row in feeds) {
      if (row is! Map) continue;
      final candidate = candidateFromPodcastIndex(Map<String, dynamic>.from(row));
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  Future<FetchedFeed> fetchFeed(
    FeedAddress address, {
    CancelToken? cancelToken,
  }) async {
    _acquire(DirectoryBucket.probe);
    final response = await _readCapped(address.uri, cancelToken: cancelToken);
    if (!FeedAddress.isPublicHost(response.finalUri.host)) {
      return FetchedFeed(
        address: address,
        health: FeedHealth.dead,
        message: 'That feed address can’t be added.',
      );
    }
    final resolved =
        FeedAddress.tryParse(response.finalUri.toString()) ?? address;
    final health = classifyFeedHttp(status: response.status, body: response.body);
    if (health != FeedHealth.alive) {
      return FetchedFeed(
        address: resolved,
        health: health,
        message: feedHealthMessage(health),
      );
    }
    try {
      final channel = parseRssChannel(response.body);
      return FetchedFeed(
        address: resolved,
        health: FeedHealth.alive,
        channel: channel,
      );
    } on FormatException catch (error) {
      return FetchedFeed(
        address: resolved,
        health: FeedHealth.dead,
        message: error.message,
      );
    }
  }

  void _acquire(DirectoryBucket bucket) {
    if (_limiter.tryAcquire(bucket)) return;
    throw _busy(bucket);
  }

  ApiFailure _busy(DirectoryBucket bucket) {
    final wait = _limiter.retryAfter(bucket);
    final seconds = wait.inSeconds.clamp(1, 120);
    return ApiFailure(
      code: 'RATE_LIMITED',
      message: 'Podcast search is busy. Try again in $seconds seconds.',
    );
  }

  void _honorRetry(DirectoryBucket bucket, int? status, Headers headers) {
    if (status != 429) return;
    final retry = headers.value('retry-after');
    final seconds = int.tryParse(retry ?? '');
    _limiter.block(
      bucket,
      Duration(seconds: seconds == null || seconds <= 0 ? 60 : seconds),
    );
  }

  Future<({int status, String body, Uri finalUri})> _readCapped(
    Uri uri, {
    CancelToken? cancelToken,
    int maxBytes = 1500000,
  }) async {
    final response = await _external.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 4,
        receiveTimeout: const Duration(seconds: 12),
        validateStatus: (code) => code != null && code < 600,
        headers: {'User-Agent': userAgent, 'Accept': 'application/rss+xml, application/xml, text/xml, */*'},
      ),
    );
    _honorRetry(DirectoryBucket.probe, response.statusCode, response.headers);
    if (response.statusCode == 429) {
      throw _busy(DirectoryBucket.probe);
    }
    final stream = response.data?.stream;
    final builder = BytesBuilder(copy: false);
    var cancelled = false;
    if (stream != null) {
      try {
        await for (final chunk in stream) {
          if (cancelToken?.isCancelled == true) {
            cancelled = true;
            break;
          }
          builder.add(chunk);
          if (builder.length >= maxBytes) break;
        }
      } catch (error) {
        if (error is DioException && CancelToken.isCancel(error)) rethrow;
      }
    }
    if (cancelled) {
      throw DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.cancel,
      );
    }
    return (
      status: response.statusCode ?? 0,
      body: utf8.decode(builder.takeBytes(), allowMalformed: true),
      finalUri: response.realUri,
    );
  }
}
