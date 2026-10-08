import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

class HomeItem {
  const HomeItem({
    required this.id,
    required this.type,
    required this.title,
    this.showId,
    this.showTitle,
    this.artworkUrl,
    this.durationSeconds,
    this.durationLabel,
    this.positionSeconds,
    this.slug,
    this.subtitle,
    this.description,
    this.rank,
    this.itemCount,
    this.viewerCount,
    this.countryCode,
    this.matchPercent,
    this.reason,
    this.playCount,
    this.playCountLabel,
    this.publishedLabel,
    this.badge,
    this.badgeColor,
    this.icon,
    this.color,
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) => HomeItem(
    id: _requiredHomeString(json, 'id'),
    type: '${json['type'] ?? 'episode'}',
    title: '${json['title'] ?? ''}',
    showId: json['show_id'] == null ? null : '${json['show_id']}',
    showTitle: json['show_title'] as String?,
    artworkUrl: _sanitizeArtworkUrl(json['artwork_url'] as String?),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    durationLabel: json['duration_label'] as String?,
    positionSeconds: (json['position_seconds'] as num?)?.toInt(),
    slug: json['slug'] as String?,
    subtitle: json['subtitle'] as String?,
    description: json['description'] as String?,
    rank: (json['rank'] as num?)?.toInt(),
    itemCount: (json['item_count'] as num?)?.toInt(),
    viewerCount: (json['viewer_count'] as num?)?.toInt(),
    countryCode: json['country_code'] as String?,
    matchPercent: (json['match_percent'] as num?)?.toInt(),
    reason: json['reason'] as String?,
    playCount: (json['play_count'] as num?)?.toInt(),
    playCountLabel: json['play_count_label'] as String?,
    publishedLabel: json['published_label'] as String?,
    badge: json['badge'] as String?,
    badgeColor: json['badge_color'] as String?,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
  );

  final String id;
  final String type;
  final String title;
  final String? showId;
  final String? showTitle;
  final String? artworkUrl;
  final int? durationSeconds;
  final String? durationLabel;
  final int? positionSeconds;
  final String? slug;
  final String? subtitle;
  final String? description;
  final int? rank;
  final int? itemCount;
  final int? viewerCount;
  final String? countryCode;
  final int? matchPercent;
  final String? reason;
  final int? playCount;
  final String? playCountLabel;
  final String? publishedLabel;
  final String? badge;
  final String? badgeColor;
  final String? icon;
  final String? color;

  HomeItem copyWith({
    int? positionSeconds,
    bool clearPosition = false,
  }) => HomeItem(
    id: id,
    type: type,
    title: title,
    showId: showId,
    showTitle: showTitle,
    artworkUrl: artworkUrl,
    durationSeconds: durationSeconds,
    durationLabel: durationLabel,
    positionSeconds: clearPosition ? null : (positionSeconds ?? this.positionSeconds),
    slug: slug,
    subtitle: subtitle,
    description: description,
    rank: rank,
    itemCount: itemCount,
    viewerCount: viewerCount,
    countryCode: countryCode,
    matchPercent: matchPercent,
    reason: reason,
    playCount: playCount,
    playCountLabel: playCountLabel,
    publishedLabel: publishedLabel,
    badge: badge,
    badgeColor: badgeColor,
    icon: icon,
    color: color,
  );
}

class HomeInspiration {
  const HomeInspiration({required this.title, required this.subtitle});

  factory HomeInspiration.fromJson(Map<String, dynamic> json) =>
      HomeInspiration(
        title: '${json['title'] ?? ''}',
        subtitle: '${json['subtitle'] ?? ''}',
      );

  final String title;
  final String subtitle;
}

class HomeRail {
  const HomeRail({
    required this.id,
    required this.key,
    required this.type,
    required this.title,
    required this.items,
    this.subtitle,
    this.seeAllUrl,
    this.inspiration,
  });

  factory HomeRail.fromJson(Map<String, dynamic> json) => HomeRail(
    id: _requiredHomeString(json, 'id'),
    key: _requiredHomeString(json, 'key'),
    type: _requiredHomeString(json, 'type'),
    title: _requiredHomeString(json, 'title'),
    subtitle: json['subtitle'] as String?,
    seeAllUrl: json['see_all_url'] as String?,
    inspiration:
        json['inspiration'] is Map<String, dynamic>
            ? HomeInspiration.fromJson(json['inspiration'] as Map<String, dynamic>)
            : null,
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HomeItem.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String key;
  final String type;
  final String title;
  final String? subtitle;
  final String? seeAllUrl;
  final HomeInspiration? inspiration;
  final List<HomeItem> items;

  HomeRail copyWith({List<HomeItem>? items}) => HomeRail(
    id: id,
    key: key,
    type: type,
    title: title,
    items: items ?? this.items,
    subtitle: subtitle,
    seeAllUrl: seeAllUrl,
    inspiration: inspiration,
  );
}

class HomeFeed {
  const HomeFeed({
    required this.schemaVersion,
    required this.rails,
    this.stale = false,
  });

  final bool stale;
  HomeFeed asStale() =>
      HomeFeed(schemaVersion: schemaVersion, rails: rails, stale: true);

  factory HomeFeed.fromJson(Map<String, dynamic> json) => HomeFeed(
    schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
    rails: (json['rails'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HomeRail.fromJson)
        .toList(growable: false),
  );

  final int schemaVersion;
  final List<HomeRail> rails;
}

class HomeDiscoverPage {
  const HomeDiscoverPage({
    required this.editorsPicks,
    required this.trending,
    required this.newEpisodes,
  });

  factory HomeDiscoverPage.fromApi(Map<String, dynamic> data) {
    return HomeDiscoverPage(
      editorsPicks: _homeItems(data['editors_picks']),
      trending: _homeItems(data['trending']),
      newEpisodes: _homeItems(data['new_episodes']),
    );
  }

  final List<HomeItem> editorsPicks;
  final List<HomeItem> trending;
  final List<HomeItem> newEpisodes;
}

class HomeChartsPage {
  const HomeChartsPage({
    required this.podcasts,
    required this.music,
    required this.audiobooks,
  });

  factory HomeChartsPage.fromApi(Map<String, dynamic> data) {
    return HomeChartsPage(
      podcasts: _homeItems(data['podcasts']),
      music: _homeItems(data['music']),
      audiobooks: _homeItems(data['audiobooks']),
    );
  }

  final List<HomeItem> podcasts;
  final List<HomeItem> music;
  final List<HomeItem> audiobooks;

  List<HomeItem> segment(int index) => switch (index) {
    1 => music,
    2 => audiobooks,
    _ => podcasts,
  };
}

class HomePlaylistsPage {
  const HomePlaylistsPage({required this.yours, required this.live});

  factory HomePlaylistsPage.fromApi(Map<String, dynamic> data) {
    return HomePlaylistsPage(
      yours: _homeItems(data['yours']),
      live: _homeItems(data['live']),
    );
  }

  final List<HomeItem> yours;
  final List<HomeItem> live;
}

class HomeRailRequest {
  const HomeRailRequest(
    this.key, {
    this.minDurationSeconds,
    this.maxDurationSeconds,
    this.countryCode,
  });

  final String key;
  final int? minDurationSeconds;
  final int? maxDurationSeconds;
  final String? countryCode;

  @override
  bool operator ==(Object other) =>
      other is HomeRailRequest &&
      other.key == key &&
      other.minDurationSeconds == minDurationSeconds &&
      other.maxDurationSeconds == maxDurationSeconds &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(
    key,
    minDurationSeconds,
    maxDurationSeconds,
    countryCode,
  );
}

List<HomeItem> _homeItems(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'Home content could not be loaded. Please try again.',
    );
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(HomeItem.fromJson)
      .toList(growable: false);
}

class HomeRepository {
  const HomeRepository(this._dio, this._cache, this._userId);
  final Dio _dio;
  final HomeFeedCache _cache;
  final String? _userId;
  String get _cacheKey => 'home_feed_v4:$_userId';

  HomeFeed? cached() {
    if (_userId == null) return null;
    final raw = _cache.get(_cacheKey);
    if (raw is! String) return null;
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      final saved = DateTime.parse(record['saved_at'] as String);
      if (DateTime.now().toUtc().difference(saved) > const Duration(days: 7)) {
        return null;
      }
      // Fresh cache is shown without the offline banner; watch() marks stale
      // only after a failed connectivity probe (connection error / timeout).
      return HomeFeed.fromJson(record['data'] as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<HomeFeed> fetch({CancelToken? cancelToken}) async {
    if (_userId == null) {
      throw const ApiFailure(
        code: 'UNAUTHENTICATED',
        message: 'Sign in to load Home.',
      );
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/home/feed',
      cancelToken: cancelToken,
    );
    final data = requireApiData(response.data);
    final feed = HomeFeed.fromJson(data);
    try {
      await _cache.put(
        _cacheKey,
        jsonEncode({
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } on Object {
      // A full or unavailable cache must not hide successfully loaded content.
    }
    return feed;
  }

  Stream<HomeFeed> watch({CancelToken? cancelToken}) async* {
    final previous = cached();
    if (previous != null) yield previous;

    try {
      yield await fetch(cancelToken: cancelToken);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (previous == null ||
          status == 401 ||
          status == 403 ||
          status == 404 ||
          error.type == DioExceptionType.cancel) {
        rethrow;
      }
      if (_looksOffline(error)) {
        yield previous.asStale();
        return;
      }
      yield previous;
    }
  }

  bool _looksOffline(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.unknown &&
            error.error?.toString().toLowerCase().contains('socket') == true;
  }

  Future<HomeDiscoverPage> discover({CancelToken? cancelToken}) async {
    _requireUser();
    final response = await _dio.get<Map<String, dynamic>>(
      '/home/discover',
      cancelToken: cancelToken,
    );
    return HomeDiscoverPage.fromApi(requireApiData(response.data));
  }

  Future<HomeChartsPage> charts({CancelToken? cancelToken}) async {
    _requireUser();
    final response = await _dio.get<Map<String, dynamic>>(
      '/home/charts',
      cancelToken: cancelToken,
    );
    return HomeChartsPage.fromApi(requireApiData(response.data));
  }

  Future<HomePlaylistsPage> playlists({CancelToken? cancelToken}) async {
    _requireUser();
    final response = await _dio.get<Map<String, dynamic>>(
      '/home/playlists',
      cancelToken: cancelToken,
    );
    return HomePlaylistsPage.fromApi(requireApiData(response.data));
  }

  Future<HomeRail> rail(
    String key, {
    int? minDurationSeconds,
    int? maxDurationSeconds,
    String? countryCode,
    CancelToken? cancelToken,
  }) async {
    _requireUser();
    final response = await _dio.get<Map<String, dynamic>>(
      '/home/rails/$key',
      queryParameters: {
        if (minDurationSeconds != null) 'min_duration': minDurationSeconds,
        if (maxDurationSeconds != null) 'max_duration': maxDurationSeconds,
        if (countryCode != null) 'country': countryCode,
      },
      cancelToken: cancelToken,
    );
    final data = requireApiData(response.data);
    final rail = data['rail'];
    if (rail is! Map<String, dynamic>) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Home content could not be loaded. Please try again.',
      );
    }
    return HomeRail.fromJson(rail);
  }

  void _requireUser() {
    if (_userId == null) {
      throw const ApiFailure(
        code: 'UNAUTHENTICATED',
        message: 'Sign in to load Home.',
      );
    }
  }
}

abstract interface class HomeFeedCache {
  Object? get(String key);
  Future<void> put(String key, Object value);
}

class MemoryHomeFeedCache implements HomeFeedCache {
  final Map<String, Object> _values = {};

  @override
  Object? get(String key) => _values[key];

  @override
  Future<void> put(String key, Object value) async {
    _values[key] = value;
  }
}

class HiveHomeFeedCache implements HomeFeedCache {
  const HiveHomeFeedCache(this._box);

  final Box<dynamic> _box;

  @override
  Object? get(String key) => _box.get(key);

  @override
  Future<void> put(String key, Object value) => _box.put(key, value);
}

final homeFeedCacheProvider = Provider<HomeFeedCache>(
  (ref) => MemoryHomeFeedCache(),
);

String _requiredHomeString(Map<String, dynamic> json, String field) {
  final value = json[field];
  final text = switch (value) {
    String s => s,
    num n => '$n',
    _ => '',
  };
  if (text.trim().isEmpty) {
    throw const ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'Home content could not be loaded. Please try again.',
    );
  }
  return text;
}

String? _sanitizeArtworkUrl(String? url) {
  if (url == null) return null;
  final value = url.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  if (value.contains('?.') ||
      RegExp(
        r'\?\.(jpe?g|png|webp|gif|avif)$',
        caseSensitive: false,
      ).hasMatch(value)) {
    return null;
  }
  return value;
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(
    ref.watch(dioProvider),
    ref.watch(homeFeedCacheProvider),
    ref.watch(authSessionProvider.select((session) => session.userId)),
  ),
);

/// Immediate Continue Listening rows while the home feed refetch is in flight.
class ContinueListeningMemoryNotifier extends Notifier<List<HomeItem>> {
  @override
  List<HomeItem> build() => const [];

  void upsert(HomeItem item) {
    state = [
      item,
      ...state.where((existing) => existing.id != item.id),
    ];
  }

  void remove(String episodeId) {
    state = [
      for (final item in state)
        if (item.id != episodeId) item,
    ];
  }
}

final continueListeningMemoryProvider =
    NotifierProvider<ContinueListeningMemoryNotifier, List<HomeItem>>(
      ContinueListeningMemoryNotifier.new,
    );

HomeRail? mergeContinueListeningRail(
  HomeRail? rail,
  List<HomeItem> memory,
) {
  if (memory.isEmpty) return rail;
  final existing = rail?.items ?? const <HomeItem>[];
  final seen = {for (final item in memory) item.id};
  final merged = [
    ...memory,
    ...existing.where((item) => !seen.contains(item.id)),
  ];
  if (rail != null) return rail.copyWith(items: merged);
  return HomeRail(
    id: 'continue_listening',
    key: 'continue_listening',
    type: 'continue',
    title: 'Continue listening',
    items: merged,
  );
}

final homeFeedProvider = StreamProvider.autoDispose<HomeFeed>((ref) {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(homeRepositoryProvider).watch(cancelToken: cancel);
});

final homeDiscoverProvider = FutureProvider.autoDispose<HomeDiscoverPage>((
  ref,
) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(homeRepositoryProvider).discover(cancelToken: cancel);
});

final homeChartsProvider = FutureProvider.autoDispose<HomeChartsPage>((
  ref,
) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(homeRepositoryProvider).charts(cancelToken: cancel);
});

final homePlaylistsProvider = FutureProvider.autoDispose<HomePlaylistsPage>((
  ref,
) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(homeRepositoryProvider).playlists(cancelToken: cancel);
});

final homeRailProvider = FutureProvider.autoDispose
    .family<HomeRail, HomeRailRequest>((ref, request) async {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref
          .watch(homeRepositoryProvider)
          .rail(
            request.key,
            minDurationSeconds: request.minDurationSeconds,
            maxDurationSeconds: request.maxDurationSeconds,
            countryCode: request.countryCode,
            cancelToken: cancel,
          );
    });
