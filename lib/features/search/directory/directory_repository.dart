import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/search/directory/directory_http.dart';
import 'package:pelevo/features/search/directory/directory_library.dart';
import 'package:pelevo/features/search/directory/directory_models.dart';
import 'package:pelevo/features/search/directory/directory_rate_limiter.dart';
import 'package:pelevo/features/search/directory/feed_address.dart';
import 'package:pelevo/features/search/directory/feed_health.dart';

class DirectoryRepository {
  DirectoryRepository({
    required Dio api,
    required Dio external,
    required DirectoryStore Function() readStore,
    DirectoryHttp? http,
    DirectoryLibrary? library,
    PodcastIndexCredentials podcastIndex =
        PodcastIndexCredentials.fromEnvironment,
    DirectoryRateLimiter? limiter,
  }) : _api = api,
       _readStore = readStore,
       _http =
           http ??
           DirectoryHttp(
             external: external,
             podcastIndex: podcastIndex,
             limiter: limiter,
           ),
       _library = library;

  final Dio _api;
  final DirectoryStore Function() _readStore;
  final DirectoryHttp _http;
  DirectoryLibrary? _library;
  final Map<String, ({DateTime at, DirectorySearchResult result})> _cache = {};
  final Map<String, Future<bool>> _refreshing = {};
  final Map<String, DateTime> _cooldownUntil = {};

  DirectoryLibrary get library => _library ??= DirectoryLibrary(_readStore());

  StoredDirectoryShow? storedShow(String id) => library.findShow(id);

  StoredDirectoryEpisode? storedEpisode(String id) => library.findEpisode(id);

  StoredDirectoryShow? showForEpisode(String episodeId) =>
      library.showForEpisode(episodeId);

  bool refreshScheduled(String id) =>
      _refreshing.containsKey(id) || _cooling(id);

  Future<DirectorySearchResult> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3 && !FeedAddress.looksLikeUrl(trimmed)) {
      return DirectorySearchResult(query: trimmed, candidates: const []);
    }
    final cacheKey = trimmed.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(seconds: 45)) {
      return cached.result;
    }
    final result = await _searchUncached(trimmed, cancelToken);
    _cache[cacheKey] = (at: DateTime.now(), result: result);
    if (_cache.length > 30) _cache.remove(_cache.keys.first);
    return result;
  }

  Future<DirectorySubscription> subscribe(
    DirectoryCandidate candidate, {
    CancelToken? cancelToken,
  }) async {
    if (candidate.inCatalog &&
        candidate.showId != null &&
        candidate.showId!.isNotEmpty &&
        !DirectoryIds.isShow(candidate.showId!)) {
      return DirectorySubscription(
        showId: candidate.showId!,
        alreadyInCatalog: true,
        storedLocally: false,
      );
    }
    final feedUrl = candidate.feedUrl;
    if (feedUrl != null && feedUrl.isNotEmpty) {
      final existing = await _catalogShowForFeed(feedUrl, cancelToken);
      if (existing != null) {
        return DirectorySubscription(
          showId: existing,
          alreadyInCatalog: true,
          storedLocally: false,
        );
      }
    }
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/directory/subscribe',
        data: {
          'candidate_id': candidate.id,
          'source': candidate.source,
          if (candidate.externalId != null) 'external_id': candidate.externalId,
          if (feedUrl != null && feedUrl.isNotEmpty) 'feed_url': feedUrl,
          'title': candidate.title,
          if (candidate.author != null) 'author': candidate.author,
        },
        cancelToken: cancelToken,
      );
      final data = requireApiData(response.data);
      final showId = _showId(data);
      if (showId == null || DirectoryIds.isShow(showId)) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Pelevo could not confirm this podcast.',
        );
      }
      await _requestRefresh(showId);
      return DirectorySubscription(
        showId: showId,
        alreadyInCatalog: data['already_in_catalog'] == true,
        storedLocally: false,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      final duplicate = _duplicateShowId(error);
      if (duplicate != null) {
        return DirectorySubscription(
          showId: duplicate,
          alreadyInCatalog: true,
          storedLocally: false,
        );
      }
      final missing =
          error.response?.statusCode == 404 || error.response?.statusCode == 405;
      if (missing && feedUrl != null && feedUrl.isNotEmpty) {
        final stored = await _importFeed(feedUrl, candidate, cancelToken);
        return DirectorySubscription(
          showId: stored.id,
          alreadyInCatalog: false,
          storedLocally: true,
        );
      }
      throw apiFailureFromDio(error);
    }
  }

  /// Re-reads a device-stored feed so later episodes appear.
  Future<bool> refreshStored(
    String id, {
    bool force = false,
    CancelToken? cancelToken,
  }) {
    if (!DirectoryIds.isShow(id)) return Future.value(false);
    final current = _refreshing[id];
    if (current != null && !force) return current;
    if (!force && (_cooling(id) || storedShow(id)?.isStaleAt(DateTime.now()) != true)) {
      return Future.value(false);
    }
    final future = _refreshBody(id, cancelToken);
    _refreshing[id] = future;
    return future.whenComplete(() => _refreshing.remove(id));
  }

  Future<void> setFollowing(String id, {required bool following}) =>
      library.setFollowing(id, following: following);

  Future<DirectorySearchResult> _searchUncached(
    String query,
    CancelToken? cancelToken,
  ) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/directory/search',
        queryParameters: {'q': query},
        cancelToken: cancelToken,
      );
      return _resultFromApi(query, requireApiData(response.data));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final missing =
          error.response?.statusCode == 404 || error.response?.statusCode == 405;
      if (!missing) throw apiFailureFromDio(error);
    } on ApiFailure {
      rethrow;
    }
    return _searchOnDevice(query, cancelToken);
  }

  Future<DirectorySearchResult> _searchOnDevice(
    String query,
    CancelToken? cancelToken,
  ) async {
    if (FeedAddress.looksLikeUrl(query)) {
      final address = FeedAddress.tryParse(query);
      if (address == null) {
        return DirectorySearchResult(
          query: query,
          candidates: const [],
          unavailableMessage: 'That feed address can’t be added.',
        );
      }
      final fetched = await _http.fetchFeed(address, cancelToken: cancelToken);
      if (fetched.health != FeedHealth.alive || fetched.channel == null) {
        return DirectorySearchResult(
          query: query,
          candidates: const [],
          unavailableMessage:
              fetched.message ?? feedHealthMessage(fetched.health),
        );
      }
      final existing = await _catalogShowForFeed(
        fetched.address.uri.toString(),
        cancelToken,
      );
      var candidate = candidateFromChannel(
        address: fetched.address,
        channel: fetched.channel!,
      );
      if (existing != null) {
        candidate = candidate.copyWith(inCatalog: true, showId: existing);
      }
      return DirectorySearchResult(query: query, candidates: [candidate]);
    }

    final apple = await _http.searchApple(query, cancelToken: cancelToken);
    List<DirectoryCandidate> indexed = const [];
    if (_http.podcastIndex.enabled) {
      try {
        indexed = await _http.searchPodcastIndex(query, cancelToken: cancelToken);
      } on ApiFailure {
        // Apple results still stand when Podcast Index is rate limited.
        indexed = const [];
      }
    }
    return DirectorySearchResult(
      query: query,
      candidates: mergeDirectoryCandidates([...apple, ...indexed]),
    );
  }

  DirectorySearchResult _resultFromApi(String query, Map<String, dynamic> data) {
    final rows = data['candidates'];
    if (rows is! List) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Podcast directory results could not be verified.',
      );
    }
    final candidates = <DirectoryCandidate>[];
    var sawDead = false;
    for (final row in rows) {
      if (row is! Map) continue;
      final candidate = _candidateFromApi(Map<String, dynamic>.from(row));
      if (candidate == null) continue;
      if (!candidate.canAdd) {
        sawDead = true;
        continue;
      }
      candidates.add(candidate);
    }
    final merged = mergeDirectoryCandidates(candidates);
    return DirectorySearchResult(
      query: data['query'] is String ? data['query'] as String : query,
      candidates: merged,
      unavailableMessage:
          merged.isEmpty && sawDead
              ? feedHealthMessage(FeedHealth.dead)
              : data['unavailable_message'] is String
              ? data['unavailable_message'] as String
              : null,
    );
  }

  DirectoryCandidate? _candidateFromApi(Map<String, dynamic> row) {
    final id = row['id'];
    final title = row['title'];
    if (id is! String || id.trim().isEmpty || title is! String || title.trim().isEmpty) {
      return null;
    }
    final feed = row['feed_url'];
    final address = feed is String ? FeedAddress.tryParse(feed) : null;
    final state = row['feed_state'];
    final health = switch (state) {
      'dead' || 'failed' => FeedHealth.dead,
      'unreachable' || 'stale' => FeedHealth.unreachable,
      _ => FeedHealth.alive,
    };
    return DirectoryCandidate(
      id: id.trim(),
      title: title.trim(),
      source: row['source'] is String ? row['source'] as String : 'directory',
      author: row['author'] is String ? (row['author'] as String).trim() : null,
      artworkUrl: row['artwork_url'] is String ? row['artwork_url'] as String : null,
      feedUrl: address?.uri.toString(),
      feedKey: address?.key,
      externalId: row['external_id']?.toString(),
      showId: row['show_id']?.toString(),
      episodeCount: row['episode_count'] is int ? row['episode_count'] as int : null,
      inCatalog:
          row['in_catalog'] == true ||
          (row['show_id'] is String && (row['show_id'] as String).trim().isNotEmpty),
      health: health,
    );
  }

  Future<StoredDirectoryShow> _importFeed(
    String feedUrl,
    DirectoryCandidate candidate,
    CancelToken? cancelToken,
  ) async {
    final address = FeedAddress.tryParse(feedUrl);
    if (address == null) {
      throw const ApiFailure(
        code: 'FEED_UNAVAILABLE',
        message: 'That feed address can’t be added.',
      );
    }
    final known = library.findByFeedKey(address.key);
    if (known != null) return known;
    final fetched = await _http.fetchFeed(address, cancelToken: cancelToken);
    if (fetched.health != FeedHealth.alive || fetched.channel == null) {
      throw ApiFailure(
        code: 'FEED_UNAVAILABLE',
        message: fetched.message ?? feedHealthMessage(fetched.health),
      );
    }
    final again = library.findByFeedKey(fetched.address.key);
    if (again != null) return again;
    return library.importChannel(
      feedUrl: fetched.address.uri.toString(),
      feedKey: fetched.address.key,
      channel: fetched.channel!,
      source: candidate.source,
      externalId: candidate.externalId,
    );
  }

  Future<bool> _refreshBody(String id, CancelToken? cancelToken) async {
    final stored = storedShow(id);
    if (stored == null) return false;
    final address = FeedAddress.tryParse(stored.feedUrl);
    if (address == null) {
      await library.markFeedFailure(
        stored,
        message: 'That feed address can’t be added.',
        dead: true,
      );
      return true;
    }
    try {
      final fetched = await _http.fetchFeed(address, cancelToken: cancelToken);
      if (fetched.channel == null || fetched.health != FeedHealth.alive) {
        await library.markFeedFailure(
          stored,
          message: fetched.message ?? feedHealthMessage(fetched.health),
          dead: fetched.health == FeedHealth.dead,
        );
        return true;
      }
      await library.updateFromChannel(stored, fetched.channel!);
      return true;
    } on ApiFailure catch (error) {
      if (error.code == 'RATE_LIMITED') {
        _cooldownUntil[id] = DateTime.now().add(const Duration(minutes: 2));
        return false;
      }
      _cooldownUntil[id] = DateTime.now().add(const Duration(minutes: 10));
      return false;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return false;
      _cooldownUntil[id] = DateTime.now().add(const Duration(minutes: 10));
      return false;
    }
  }

  bool _cooling(String id) {
    final until = _cooldownUntil[id];
    return until != null && DateTime.now().isBefore(until);
  }

  Future<String?> _catalogShowForFeed(String feedUrl, CancelToken? cancelToken) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {'q': feedUrl, 'type': 'show', 'limit': 5},
        cancelToken: cancelToken,
      );
      final data = requireApiData(response.data);
      final shows = data['shows'];
      if (shows is! List || shows.isEmpty) return null;
      final first = shows.first;
      if (first is Map && first['id'] != null) {
        final id = '${first['id']}'.trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _requestRefresh(String showId) async {
    try {
      await _api.post<Map<String, dynamic>>(
        '/shows/${Uri.encodeComponent(showId)}/refresh',
      );
    } catch (_) {}
  }

  String? _showId(Map<String, dynamic> data) {
    final nested = data['show'];
    if (nested is Map && nested['id'] != null) return '${nested['id']}'.trim();
    final id = data['show_id'] ?? data['id'];
    if (id == null) return null;
    final text = '$id'.trim();
    return text.isEmpty ? null : text;
  }

  String? _duplicateShowId(DioException error) {
    final body = asApiJsonMap(error.response?.data);
    if (body == null) return null;
    final errorMap = asApiJsonMap(body['error']);
    final code = errorMap?['code']?.toString();
    if (code != 'DUPLICATE' && error.response?.statusCode != 409) return null;
    final data = asApiJsonMap(body['data']);
    final id = data?['show_id'] ?? data?['id'];
    if (id == null) return null;
    final text = '$id'.trim();
    return text.isEmpty ? null : text;
  }
}

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  final external = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/rss+xml, application/xml, text/xml, application/json, */*',
        'User-Agent': 'Pelevo',
      },
    ),
  );
  ref.onDispose(external.close);
  return DirectoryRepository(
    api: ref.watch(dioProvider),
    external: external,
    readStore: () => PreferencesDirectoryStore(ref.read(sharedPreferencesProvider)),
  );
});

final directorySearchProvider = FutureProvider.autoDispose
    .family<DirectorySearchResult, String>((ref, query) {
      ref.watch(authSessionProvider.select((session) => session.userId));
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref.watch(directoryRepositoryProvider).search(query, cancelToken: token);
    }, retry: (count, error) => null);
