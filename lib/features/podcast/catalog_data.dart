import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidCatalog = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Catalog details could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw _invalidCatalog;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidCatalog;
  return value as String?;
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw _invalidCatalog;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  return _count(value);
}

bool _flag(Object? value) {
  if (value is bool) return value;
  throw _invalidCatalog;
}

bool _optionalFlag(Object? value) {
  if (value == null) return false;
  return _flag(value);
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List) throw _invalidCatalog;
  final rows = <Map<String, dynamic>>[];
  for (final row in data) {
    if (row is Map<String, dynamic>) {
      rows.add(row);
    } else if (row is Map) {
      rows.add(Map<String, dynamic>.from(row));
    } else {
      throw _invalidCatalog;
    }
  }
  return rows;
}

bool _playbackLooksComplete(int positionSeconds, int? durationSeconds) {
  final duration = durationSeconds ?? 0;
  if (duration < 30 || positionSeconds <= 0) return false;
  final remaining = duration - positionSeconds;
  return remaining <= 15 ||
      positionSeconds >= (duration * 0.95).floor();
}

class CatalogCategory {
  const CatalogCategory(this.name, this.slug);
  final String name, slug;
}

class CatalogShow {
  const CatalogShow({
    required this.id,
    required this.title,
    required this.episodesCount,
    required this.followerCount,
    required this.ratingCount,
    required this.following,
    required this.notificationsEnabled,
    required this.claimedByViewer,
    required this.categories,
    this.author,
    this.artworkUrl,
    this.description,
    this.language,
    this.countryCode,
    this.explicit,
    this.ratingAverage,
    this.feedState,
    this.feedError,
    this.episodesSyncing = false,
  });

  factory CatalogShow.parse(Map<String, dynamic> data) {
    final categories = data['categories'];
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['title'] is! String ||
        (data['title'] as String).isEmpty ||
        categories is! List ||
        categories.any((row) => row is! Map<String, dynamic>)) {
      throw _invalidCatalog;
    }
    final parsed = <CatalogCategory>[];
    for (final row in categories.whereType<Map<String, dynamic>>()) {
      parsed.add(CatalogCategory(_text(row, 'name'), _text(row, 'slug')));
    }
    return CatalogShow(
      id: data['id'] as String,
      title: data['title'] as String,
      author: _optionalText(data, 'author'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      description: _optionalText(data, 'description'),
      language: _optionalText(data, 'language'),
      countryCode: _optionalText(data, 'country_code'),
      explicit: _optionalText(data, 'explicit'),
      episodesCount: _count(data['episodes_count']),
      followerCount: _count(data['follower_count']),
      ratingAverage: _optionalText(data, 'rating_average'),
      ratingCount: _count(data['rating_count']),
      following: _flag(data['following']),
      notificationsEnabled: _flag(data['notifications_enabled']),
      claimedByViewer: _flag(data['claimed_by_viewer']),
      categories: parsed,
      feedState: _optionalText(data, 'feed_state'),
      feedError: _optionalText(data, 'feed_error'),
      episodesSyncing: data['episodes_syncing'] == true,
    );
  }

  final String id, title;
  final String? author, artworkUrl, description, language, countryCode, explicit;
  final int episodesCount, followerCount, ratingCount;
  final String? ratingAverage;
  final bool following, notificationsEnabled, claimedByViewer;
  final List<CatalogCategory> categories;
  final String? feedState;
  final String? feedError;
  final bool episodesSyncing;

  CatalogShow copyWith({bool? episodesSyncing, bool? following}) => CatalogShow(
    id: id,
    title: title,
    author: author,
    artworkUrl: artworkUrl,
    description: description,
    language: language,
    countryCode: countryCode,
    explicit: explicit,
    episodesCount: episodesCount,
    followerCount: followerCount,
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
    following: following ?? this.following,
    notificationsEnabled: notificationsEnabled,
    claimedByViewer: claimedByViewer,
    categories: categories,
    feedState: feedState,
    feedError: feedError,
    episodesSyncing: episodesSyncing ?? this.episodesSyncing,
  );

  bool get feedFailed =>
      feedState == 'failed' ||
      feedState == 'stale' ||
      (feedError != null && feedError!.trim().isNotEmpty);

  String get emptyEpisodesMessage {
    final error = feedError?.toLowerCase() ?? '';
    if (feedFailed && (error.contains('404') || error.contains('not found'))) {
      return 'This podcast’s RSS feed is unavailable (404). Episodes can’t be loaded until the publisher fixes the feed.';
    }
    if (feedFailed) {
      return 'We couldn’t sync episodes from this podcast’s feed. Try Refresh, or pick another show.';
    }
    if (episodesSyncing) {
      return 'Episodes are syncing from the podcast feed…';
    }
    return 'No episodes are published yet.';
  }

  String get host =>
      (author == null || author!.isEmpty) ? 'Host unavailable' : author!;

  String get categoryLabel =>
      categories.isEmpty
          ? 'Podcast'
          : 'Podcast · ${categories.map((item) => item.name).join(' · ')}';

  String get ratingLine {
    final average = ratingAverage;
    final rating =
        average == null || average.isEmpty ? '—' : '★ $average ($ratingCount)';
    return '$rating · $followerCount Followers';
  }
}

class CatalogEpisodesPage {
  const CatalogEpisodesPage({
    required this.items,
    this.cursor,
    this.hasMore = false,
    this.episodesSyncing = false,
  });

  final List<CatalogEpisode> items;
  final String? cursor;
  final bool hasMore;
  final bool episodesSyncing;
}

class CatalogEpisodesState {
  const CatalogEpisodesState({
    this.items = const [],
    this.cursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.episodesSyncing = false,
  });

  final List<CatalogEpisode> items;
  final String? cursor;
  final bool hasMore;
  final bool loadingMore;
  final bool episodesSyncing;

  CatalogEpisodesState copyWith({
    List<CatalogEpisode>? items,
    String? cursor,
    bool? hasMore,
    bool? loadingMore,
    bool? episodesSyncing,
    bool clearCursor = false,
  }) => CatalogEpisodesState(
    items: items ?? this.items,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    episodesSyncing: episodesSyncing ?? this.episodesSyncing,
  );
}

class CatalogEpisode {
  const CatalogEpisode({
    required this.id,
    required this.showId,
    required this.title,
    this.description,
    this.artworkUrl,
    this.durationSeconds,
    this.publishedAt,
    this.showTitle,
    this.showAuthor,
    this.audioUrl,
    this.positionSeconds = 0,
    this.completed = false,
    this.played = false,
  });

  factory CatalogEpisode.parse(Map<String, dynamic> data, {bool detailed = false}) {
    final id = _text(data, 'id');
    final showId = _text(data, 'show_id');
    if (data['title'] is! String || (data['title'] as String).isEmpty) {
      throw _invalidCatalog;
    }
    final published = _optionalText(data, 'published_at');
    if (published != null && DateTime.tryParse(published) == null) {
      throw _invalidCatalog;
    }
    final audio = _optionalText(data, 'audio_url');
    if (detailed && (audio == null || audio.isEmpty)) throw _invalidCatalog;
    final position = _optionalCount(data['position_seconds']) ?? 0;
    final duration = _optionalCount(data['duration_seconds']);
    final completed =
        _optionalFlag(data['completed']) ||
        _playbackLooksComplete(position, duration);
    return CatalogEpisode(
      id: id,
      showId: showId,
      title: data['title'] as String,
      description: _optionalText(data, 'description'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      durationSeconds: _optionalCount(data['duration_seconds']),
      publishedAt: published == null ? null : DateTime.parse(published),
      showTitle: _optionalText(data, 'show_title'),
      showAuthor: _optionalText(data, 'show_author'),
      audioUrl: audio,
      positionSeconds: position,
      completed: completed,
      played: _optionalFlag(data['played']) || completed || position > 0,
    );
  }

  final String id, showId, title;
  final String? description, artworkUrl, showTitle, showAuthor, audioUrl;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final int positionSeconds;
  final bool completed;
  final bool played;

  CatalogEpisode copyWith({
    int? positionSeconds,
    bool? completed,
    bool? played,
  }) => CatalogEpisode(
    id: id,
    showId: showId,
    title: title,
    description: description,
    artworkUrl: artworkUrl,
    durationSeconds: durationSeconds,
    publishedAt: publishedAt,
    showTitle: showTitle,
    showAuthor: showAuthor,
    audioUrl: audioUrl,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    completed: completed ?? this.completed,
    played: played ?? this.played,
  );

  /// Merge in-memory playback (now playing / episode list) onto a fetched episode
  /// so completion can show before a network refetch lands.
  CatalogEpisode overlayLivePlayback({
    CatalogEpisode? nowPlaying,
    Iterable<CatalogEpisode> listed = const [],
  }) {
    var next = this;
    if (nowPlaying != null && nowPlaying.id == id) {
      next = next.copyWith(
        positionSeconds: nowPlaying.positionSeconds,
        completed: nowPlaying.completed || next.completed,
        played: nowPlaying.played || next.played,
      );
    }
    for (final item in listed) {
      if (item.id != id) continue;
      return next.copyWith(
        positionSeconds: item.positionSeconds,
        completed: item.completed || next.completed,
        played: item.played || next.played,
      );
    }
    return next;
  }

  String get subtitle {
    final date =
        publishedAt == null
            ? null
            : '${publishedAt!.year}-${publishedAt!.month.toString().padLeft(2, '0')}-${publishedAt!.day.toString().padLeft(2, '0')}';
    final duration =
        durationSeconds == null ? null : formatCatalogDuration(durationSeconds!);
    return [date, duration].whereType<String>().join(' · ');
  }
}

class CatalogChapter {
  const CatalogChapter(this.id, this.title, this.startsAtSeconds);
  factory CatalogChapter.parse(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['title'] is! String ||
        (data['title'] as String).isEmpty) {
      throw _invalidCatalog;
    }
    return CatalogChapter(
      data['id'] as String,
      data['title'] as String,
      _count(data['starts_at_seconds']),
    );
  }
  final String id, title;
  final int startsAtSeconds;
  String get timestamp {
    final minutes = startsAtSeconds ~/ 60;
    final seconds = startsAtSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class CatalogReview {
  const CatalogReview(this.id, this.rating, this.reviewerName, this.createdAt, this.body);
  factory CatalogReview.parse(Map<String, dynamic> data) {
    final created = _text(data, 'created_at');
    final date = DateTime.tryParse(created);
    if (date == null) throw _invalidCatalog;
    final rating = _count(data['rating']);
    if (rating < 1 || rating > 5) throw _invalidCatalog;
    return CatalogReview(
      _text(data, 'id'),
      rating,
      _text(data, 'reviewer_name'),
      date,
      _optionalText(data, 'body'),
    );
  }
  final String id, reviewerName;
  final int rating;
  final DateTime createdAt;
  final String? body;
}

class CatalogNote {
  const CatalogNote(this.body, this.positionSeconds, this.version);
  factory CatalogNote.parse(Map<String, dynamic> data) {
    return CatalogNote(
      _optionalText(data, 'body'),
      _optionalCount(data['position_seconds']),
      _count(data['version']),
    );
  }
  final String? body;
  final int? positionSeconds;
  final int version;
}

class CatalogPlayback {
  const CatalogPlayback(this.owner, this.episodeId, this.positionSeconds, this.completed, this.version);
  factory CatalogPlayback.parse(Map<String, dynamic> data, String owner) {
    if (data['user_id'] != owner || data['episode_id'] is! String) {
      throw _invalidCatalog;
    }
    return CatalogPlayback(
      owner,
      data['episode_id'] as String,
      _count(data['position_seconds']),
      _flag(data['completed']),
      _count(data['version']),
    );
  }
  final String owner, episodeId;
  final int positionSeconds, version;
  final bool completed;
}

class CatalogPlayerSession {
  const CatalogPlayerSession(this.episodeId, this.playing, this.playbackRate, this.version);
  factory CatalogPlayerSession.parse(Map<String, dynamic> data) {
    final rate = data['playback_rate'];
    if (rate is! num) throw _invalidCatalog;
    return CatalogPlayerSession(
      _optionalText(data, 'episode_id'),
      _flag(data['playing']),
      rate.toDouble(),
      _count(data['version']),
    );
  }
  final String? episodeId;
  final bool playing;
  final double playbackRate;
  final int version;
}

class CatalogRelatedShow {
  const CatalogRelatedShow(this.id, this.title, this.author, this.artworkUrl);
  factory CatalogRelatedShow.parse(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['title'] is! String ||
        (data['title'] as String).isEmpty) {
      throw _invalidCatalog;
    }
    return CatalogRelatedShow(
      data['id'] as String,
      data['title'] as String,
      data['author'] is String ? data['author'] as String : null,
      data['artwork_url'] is String ? data['artwork_url'] as String : null,
    );
  }
  final String id, title;
  final String? author, artworkUrl;
}

class CatalogQueueItem {
  const CatalogQueueItem(this.queueItemId, this.position, this.episode);
  final String queueItemId;
  final int position;
  final CatalogEpisode episode;
}

class CatalogQueue {
  const CatalogQueue(this.version, this.items);
  final int version;
  final List<CatalogQueueItem> items;

  CatalogQueue copyWith({int? version, List<CatalogQueueItem>? items}) =>
      CatalogQueue(version ?? this.version, items ?? this.items);
}

List<CatalogQueueItem> reorderCatalogQueueItems(
  List<CatalogQueueItem> items,
  int oldIndex,
  int newIndex,
) {
  final next = [...items];
  if (newIndex > oldIndex) newIndex -= 1;
  if (oldIndex < 0 ||
      oldIndex >= next.length ||
      newIndex < 0 ||
      newIndex >= next.length) {
    return items;
  }
  final item = next.removeAt(oldIndex);
  next.insert(newIndex, item);
  return [
    for (var i = 0; i < next.length; i++)
      CatalogQueueItem(next[i].queueItemId, i, next[i].episode),
  ];
}

class CatalogRecentEpisode {
  const CatalogRecentEpisode(
    this.episode,
    this.positionSeconds,
    this.completed,
    this.playedAt,
  );

  factory CatalogRecentEpisode.parse(Map<String, dynamic> data) {
    final played = _optionalText(data, 'played_at');
    final at = played == null ? null : DateTime.tryParse(played);
    if (played != null && at == null) throw _invalidCatalog;
    return CatalogRecentEpisode(
      CatalogEpisode.parse({
        'id': data['id'],
        'show_id': data['show_id'],
        'title': data['title'],
        'show_title': data['show_title'],
        'artwork_url': data['artwork_url'],
        'duration_seconds': data['duration_seconds'],
      }),
      _count(data['position_seconds']),
      _flag(data['completed']),
      at,
    );
  }

  final CatalogEpisode episode;
  final int positionSeconds;
  final bool completed;
  final DateTime? playedAt;

  String get subtitle {
    final show = episode.showTitle;
    final played =
        playedAt == null
            ? null
            : '${playedAt!.year}-${playedAt!.month.toString().padLeft(2, '0')}-${playedAt!.day.toString().padLeft(2, '0')}';
    final duration =
        episode.durationSeconds == null
            ? null
            : formatCatalogDuration(episode.durationSeconds!);
    return [show, played, duration].whereType<String>().join(' · ');
  }
}

String formatCatalogDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '$minutes min';
}

String formatCatalogClock(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$remainder';
  return '$minutes:$remainder';
}

class CatalogRepository {
  CatalogRepository(this._dio);
  final Dio _dio;

  Future<CatalogShow> show(String id, CancelToken token) async {
    try {
      return CatalogShow.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/shows/${Uri.encodeComponent(id)}',
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogEpisodesPage> episodes(
    String showId,
    CancelToken token, {
    String? cursor,
    String? q,
    int limit = 20,
  }) async {
    try {
      final query = q?.trim();
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/shows/${Uri.encodeComponent(showId)}/episodes',
            queryParameters: {
              'limit': limit.clamp(1, 50),
              if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
              if (query != null && query.isNotEmpty) 'q': query,
            },
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      final meta = body?['meta'];
      if (meta is! Map) throw _invalidCatalog;
      final next = meta['cursor'];
      if (next != null && next is! String) throw _invalidCatalog;
      if (meta['has_more'] is! bool) throw _invalidCatalog;
      if (meta['has_more'] == false && next != null) throw _invalidCatalog;
      if (meta['has_more'] == true &&
          (next == null || (next as String).isEmpty || next == cursor)) {
        throw _invalidCatalog;
      }
      final items =
          _maps(body?['data']).map(CatalogEpisode.parse).toList(growable: false);
      if (items.map((item) => item.id).toSet().length != items.length) {
        throw _invalidCatalog;
      }
      return CatalogEpisodesPage(
        items: items,
        cursor: meta['has_more'] == true ? next as String : null,
        hasMore: meta['has_more'] == true,
        episodesSyncing: meta['episodes_syncing'] == true,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<CatalogRelatedShow>> related(String showId, CancelToken token) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/shows/${Uri.encodeComponent(showId)}/related',
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      return _maps(body?['data']).map(CatalogRelatedShow.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<CatalogReview>> reviews(String showId, CancelToken token) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/shows/${Uri.encodeComponent(showId)}/reviews',
            queryParameters: {'limit': 20},
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      return _maps(body?['data']).map(CatalogReview.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> follow(String showId, {required bool following}) async {
    try {
      final path = '/shows/${Uri.encodeComponent(showId)}/follow';
      final data = requireApiData(
        (following
                ? await _dio.post<Map<String, dynamic>>(path)
                : await _dio.delete<Map<String, dynamic>>(path))
            .data,
      );
      if (data['following'] != following) throw _invalidCatalog;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> refreshShow(String showId) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/shows/${Uri.encodeComponent(showId)}/refresh',
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> notifications(String showId, {required bool enabled}) async {
    try {
      final data = requireApiData(
        (await _dio.put<Map<String, dynamic>>(
          '/shows/${Uri.encodeComponent(showId)}/notifications',
          data: {'enabled': enabled},
        )).data,
      );
      if (data['notifications_enabled'] != enabled) throw _invalidCatalog;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> review(String showId, {required int rating, String? body}) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/shows/${Uri.encodeComponent(showId)}/reviews',
          data: {'rating': rating, if (body != null && body.isNotEmpty) 'body': body},
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogEpisode> episode(String id, CancelToken token) async {
    try {
      return CatalogEpisode.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/episodes/${Uri.encodeComponent(id)}',
            cancelToken: token,
          )).data,
        ),
        detailed: true,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<CatalogChapter>> chapters(String episodeId, CancelToken token) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/episodes/${Uri.encodeComponent(episodeId)}/chapters',
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      return _maps(body?['data']).map(CatalogChapter.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<String> transcript(String episodeId, CancelToken token) async {
    try {
      final data = requireApiData(
        (await _dio.get<Map<String, dynamic>>(
          '/episodes/${Uri.encodeComponent(episodeId)}/transcript',
          cancelToken: token,
        )).data,
      );
      return _text(data, 'content');
    } on ApiFailure catch (error) {
      if (error.code == 'NOT_FOUND' || error.statusCode == 404) return '';
      rethrow;
    } on DioException catch (error) {
      final failure = apiFailureFromDio(error);
      if (failure.code == 'NOT_FOUND' || failure.statusCode == 404) return '';
      throw failure;
    }
  }

  Future<CatalogNote> notes(String episodeId, CancelToken token) async {
    try {
      return CatalogNote.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/episodes/${Uri.encodeComponent(episodeId)}/notes',
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogNote> saveNote(
    String episodeId, {
    required String body,
    required int version,
    int? positionSeconds,
  }) async {
    try {
      return CatalogNote.parse(
        requireApiData(
          (await _dio.put<Map<String, dynamic>>(
            '/episodes/${Uri.encodeComponent(episodeId)}/notes',
            data: {
              'body': body,
              'version': version,
              if (positionSeconds != null) 'position_seconds': positionSeconds,
            },
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogPlayback> playback(String episodeId, String owner, CancelToken token) async {
    try {
      return CatalogPlayback.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/playback/${Uri.encodeComponent(episodeId)}',
            cancelToken: token,
          )).data,
        ),
        owner,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogPlayback> savePlayback(
    String episodeId,
    String owner, {
    required int positionSeconds,
    required bool completed,
    required int version,
  }) async {
    try {
      return CatalogPlayback.parse(
        requireApiData(
          (await _dio.put<Map<String, dynamic>>(
            '/playback/${Uri.encodeComponent(episodeId)}',
            data: {
              'position_seconds': positionSeconds,
              'completed': completed,
              'version': version,
            },
          )).data,
        ),
        owner,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogPlayerSession> playerSession(CancelToken token) async {
    try {
      return CatalogPlayerSession.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/player/session',
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogPlayerSession> savePlayerSession({
    String? episodeId,
    required bool playing,
    required double playbackRate,
    required int version,
  }) async {
    try {
      return CatalogPlayerSession.parse(
        requireApiData(
          (await _dio.patch<Map<String, dynamic>>(
            '/player/session',
            data: {
              'episode_id': episodeId,
              'playing': playing,
              'playback_rate': playbackRate,
              'version': version,
            },
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<CatalogQueue> queue(CancelToken token) async {
    try {
      final data = requireApiData(
        (await _dio.get<Map<String, dynamic>>('/queue', cancelToken: token)).data,
      );
      return CatalogQueue(
        _count(data['version']),
        [
          for (final row in _maps(data['items']))
            CatalogQueueItem(
              _text(row, 'queue_item_id'),
              _count(row['position']),
              CatalogEpisode.parse(row),
            ),
        ],
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<int> addToQueue(String episodeId, int version) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/episodes/${Uri.encodeComponent(episodeId)}/queue',
          data: {'version': version},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  /// Loads the current queue and appends (or play-next) without using the
  /// auto-dispose provider, which cancels one-shot reads before POST.
  Future<int> enqueueEpisode(String episodeId, {bool playNext = false}) async {
    ApiFailure? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final current = await queue(CancelToken());
        if (playNext) {
          final ids = [
            episodeId,
            ...current.items
                .map((item) => item.episode.id)
                .where((id) => id != episodeId),
          ];
          return await replaceQueue(ids, current.version);
        }
        return await addToQueue(episodeId, current.version);
      } on ApiFailure catch (error) {
        last = error;
        if (error.code == 'CANCELLED' || error.code != 'VERSION_CONFLICT') {
          rethrow;
        }
      }
    }
    throw last ?? _invalidCatalog;
  }

  Future<int> removeQueueItem(String queueItemId, int version) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/queue/items/${Uri.encodeComponent(queueItemId)}',
          data: {'version': version},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<int> removeEpisodeFromQueue(String episodeId, int version) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/episodes/${Uri.encodeComponent(episodeId)}/queue',
          data: {'version': version},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> reportEpisode({
    required String episodeId,
    required String reason,
    String? details,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'reportable_type': 'episode',
            'reportable_id': episodeId,
            'reason': reason,
            if (details != null && details.isNotEmpty) 'details': details,
          },
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<int> replaceQueue(List<String> episodeIds, int version) async {
    try {
      final data = requireApiData(
        (await _dio.put<Map<String, dynamic>>(
          '/queue',
          data: {'version': version, 'episode_ids': episodeIds},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<int> replaceQueueRetry(List<String> episodeIds) async {
    ApiFailure? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final current = await queue(CancelToken());
        return await replaceQueue(episodeIds, current.version);
      } on ApiFailure catch (error) {
        last = error;
        if (error.code == 'CANCELLED' || error.code != 'VERSION_CONFLICT') {
          rethrow;
        }
      }
    }
    throw last ?? _invalidCatalog;
  }

  Future<int> reorderQueue(List<String> episodeIds, int version) async {
    try {
      final data = requireApiData(
        (await _dio.put<Map<String, dynamic>>(
          '/queue/reorder',
          data: {'version': version, 'episode_ids': episodeIds},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<int> clearQueue(int version) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/queue',
          data: {'version': version},
        )).data,
      );
      return _count(data['version']);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<CatalogRecentEpisode>> libraryRecent(CancelToken token) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/library/recent',
            queryParameters: {'limit': 20},
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      return _maps(
        body?['data'],
      ).map(CatalogRecentEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<String> authorizeDownload(String episodeId) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/episodes/${Uri.encodeComponent(episodeId)}/downloads',
        )).data,
      );
      final url = data['url'];
      if (data['episode_id'] != episodeId || url is! String || url.isEmpty) {
        throw _invalidCatalog;
      }
      return url;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

class SelectedShowIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

class SelectedEpisodeIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedShowIdProvider =
    NotifierProvider<SelectedShowIdNotifier, String?>(SelectedShowIdNotifier.new);

final selectedEpisodeIdProvider =
    NotifierProvider<SelectedEpisodeIdNotifier, String?>(
      SelectedEpisodeIdNotifier.new,
    );

/// Optional resume hint from Home Continue Listening (consumed by full player).
class PlaybackResumeHintNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setSeconds(int? seconds) => state = seconds;
  void clear() => state = null;
}

final playbackResumeHintProvider =
    NotifierProvider<PlaybackResumeHintNotifier, int?>(
      PlaybackResumeHintNotifier.new,
    );

/// Episode actually loaded in the audio handler — independent of details browsing.
class NowPlayingEpisodeIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final nowPlayingEpisodeIdProvider =
    NotifierProvider<NowPlayingEpisodeIdNotifier, String?>(
      NowPlayingEpisodeIdNotifier.new,
    );

/// Full episode metadata for the mini-player, set as soon as Play is tapped.
class NowPlayingEpisodeNotifier extends Notifier<CatalogEpisode?> {
  @override
  CatalogEpisode? build() => null;

  void set(CatalogEpisode? episode) {
    state = episode;
    ref.read(nowPlayingEpisodeIdProvider.notifier).select(episode?.id);
  }
}

final nowPlayingEpisodeProvider =
    NotifierProvider<NowPlayingEpisodeNotifier, CatalogEpisode?>(
      NowPlayingEpisodeNotifier.new,
    );

/// Set when the user explicitly taps Play. Full player must not auto-start
/// merely because [selectedEpisodeIdProvider] changed (episode details).
class PlaybackPlayIntentNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void arm() => state = true;
  void clear() => state = false;
  bool consume() {
    if (!state) return false;
    state = false;
    return true;
  }
}

final playbackPlayIntentProvider =
    NotifierProvider<PlaybackPlayIntentNotifier, bool>(
      PlaybackPlayIntentNotifier.new,
    );

enum PlaybackQueueSource { standalone, playlist }

class PlaybackQueueSourceNotifier extends Notifier<PlaybackQueueSource> {
  @override
  PlaybackQueueSource build() => PlaybackQueueSource.standalone;

  void set(PlaybackQueueSource source) => state = source;
}

final playbackQueueSourceProvider =
    NotifierProvider<PlaybackQueueSourceNotifier, PlaybackQueueSource>(
      PlaybackQueueSourceNotifier.new,
    );

final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(ref.watch(dioProvider)),
);

final catalogShowProvider = FutureProvider.autoDispose<CatalogShow>((ref) async {
  final id = ref.watch(selectedShowIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).show(id, token);
}, retry: (count, error) => null);

class CatalogEpisodeQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value.trim();

  void clear() => state = '';
}

final catalogEpisodeQueryProvider =
    NotifierProvider<CatalogEpisodeQueryNotifier, String>(
      CatalogEpisodeQueryNotifier.new,
    );

class CatalogEpisodesNotifier extends AsyncNotifier<CatalogEpisodesState> {
  CancelToken? _token;
  final _seenCursors = <String>{};

  String get _query {
    final value = ref.read(catalogEpisodeQueryProvider).trim();
    return value;
  }

  @override
  Future<CatalogEpisodesState> build() async {
    final id = ref.watch(selectedShowIdProvider);
    final query = ref.watch(catalogEpisodeQueryProvider).trim();
    if (id == null || id.isEmpty) throw _invalidCatalog;
    _token?.cancel();
    _seenCursors.clear();
    final token = _token = CancelToken();
    ref.onDispose(() => token.cancel());
    final page = await ref
        .watch(catalogRepositoryProvider)
        .episodes(id, token, q: query.isEmpty ? null : query);
    return CatalogEpisodesState(
      items: page.items,
      cursor: page.cursor,
      hasMore: page.hasMore,
      episodesSyncing: page.episodesSyncing,
    );
  }

  Future<void> refreshFirstPage() async {
    final id = ref.read(selectedShowIdProvider);
    if (id == null || id.isEmpty) return;
    final previous = state.asData?.value;
    final query = _query;
    _token?.cancel();
    final token = _token = CancelToken();
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .episodes(id, token, q: query.isEmpty ? null : query);
      if (token.isCancelled) return;
      _seenCursors.clear();
      state = AsyncData(
        CatalogEpisodesState(
          items: page.items,
          cursor: page.cursor,
          hasMore: page.hasMore,
          episodesSyncing: page.episodesSyncing,
        ),
      );
    } catch (error, stack) {
      if (token.isCancelled) return;
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> loadMore() async {
    final id = ref.read(selectedShowIdProvider);
    final current = state.asData?.value;
    final query = _query;
    if (id == null ||
        id.isEmpty ||
        current == null ||
        current.loadingMore ||
        !current.hasMore ||
        current.cursor == null) {
      return;
    }
    final cursor = current.cursor!;
    if (_seenCursors.contains(cursor)) {
      state = AsyncData(current.copyWith(hasMore: false, clearCursor: true));
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    final token = CancelToken();
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .episodes(
            id,
            token,
            cursor: cursor,
            q: query.isEmpty ? null : query,
          );
      if (!ref.mounted) return;
      _seenCursors.add(cursor);
      final merged = <String, CatalogEpisode>{
        for (final item in current.items) item.id: item,
        for (final item in page.items) item.id: item,
      };
      state = AsyncData(
        CatalogEpisodesState(
          items: merged.values.toList(growable: false),
          cursor: page.cursor,
          hasMore: page.hasMore,
          episodesSyncing: page.episodesSyncing,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  void markListened(
    String episodeId, {
    required int positionSeconds,
    required bool completed,
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    final played = completed || positionSeconds > 0;
    if (!played) return;
    var changed = false;
    final items = current.items.map((item) {
      if (item.id != episodeId ||
          (item.played == played &&
              item.completed == completed &&
              item.positionSeconds == positionSeconds)) {
        return item;
      }
      changed = true;
      return item.copyWith(
        positionSeconds: positionSeconds,
        completed: completed,
        played: played,
      );
    }).toList(growable: false);
    if (changed) {
      state = AsyncData(current.copyWith(items: items));
    }
  }
}

final catalogEpisodesProvider = AsyncNotifierProvider.autoDispose<
  CatalogEpisodesNotifier,
  CatalogEpisodesState
>(CatalogEpisodesNotifier.new, retry: (count, error) => null);

final catalogReviewsProvider = FutureProvider.autoDispose<List<CatalogReview>>((
  ref,
) async {
  final id = ref.watch(selectedShowIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).reviews(id, token);
}, retry: (count, error) => null);

final catalogRelatedProvider = FutureProvider.autoDispose<List<CatalogRelatedShow>>((
  ref,
) async {
  final id = ref.watch(selectedShowIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).related(id, token);
}, retry: (count, error) => null);

final catalogEpisodeProvider = FutureProvider.autoDispose<CatalogEpisode>((
  ref,
) async {
  final id = ref.watch(selectedEpisodeIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).episode(id, token);
}, retry: (count, error) => null);

final catalogChaptersProvider = FutureProvider.autoDispose<List<CatalogChapter>>((
  ref,
) async {
  final id = ref.watch(selectedEpisodeIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).chapters(id, token);
}, retry: (count, error) => null);

final catalogTranscriptProvider = FutureProvider.autoDispose<String>((ref) async {
  final id = ref.watch(selectedEpisodeIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).transcript(id, token);
}, retry: (count, error) => null);

final catalogNotesProvider = FutureProvider.autoDispose<CatalogNote>((ref) async {
  final id = ref.watch(selectedEpisodeIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(catalogRepositoryProvider).notes(id, token);
}, retry: (count, error) => null);

final catalogPlayerSessionProvider =
    FutureProvider.autoDispose<CatalogPlayerSession>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(catalogRepositoryProvider).playerSession(token);
    }, retry: (count, error) => null);

class CatalogQueueNotifier extends AsyncNotifier<CatalogQueue> {
  @override
  Future<CatalogQueue> build() async {
    ref.watch(authSessionProvider);
    final token = CancelToken();
    ref.onDispose(token.cancel);
    return ref.watch(catalogRepositoryProvider).queue(token);
  }

  void previewOrder(List<CatalogQueueItem> items) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: items));
  }

  Future<void> commitOrder(List<CatalogQueueItem> items) async {
    final previous = state.asData?.value;
    if (previous == null) return;
    previewOrder(items);
    final ids = [for (final item in items) item.episode.id];
    final repo = ref.read(catalogRepositoryProvider);
    var version = previous.version;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final nextVersion = await repo.reorderQueue(ids, version);
          state = AsyncData(CatalogQueue(nextVersion, items));
          return;
        } on ApiFailure catch (error) {
          if (error.code == 'QUEUE_MISMATCH') {
            state = AsyncData(await repo.queue(CancelToken()));
            rethrow;
          }
          if (error.code != 'VERSION_CONFLICT') rethrow;
          version = (await repo.queue(CancelToken())).version;
        }
      }
    } catch (error, stack) {
      if (error is ApiFailure && error.code == 'QUEUE_MISMATCH') {
        Error.throwWithStackTrace(error, stack);
      }
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }
}

final catalogQueueProvider =
    AsyncNotifierProvider<CatalogQueueNotifier, CatalogQueue>(
      CatalogQueueNotifier.new,
    );

final catalogEpisodeByIdProvider = FutureProvider.autoDispose
    .family<CatalogEpisode, String>((ref, id) async {
      if (id.isEmpty) throw _invalidCatalog;
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(catalogRepositoryProvider).episode(id, token);
    }, retry: (count, error) => null);

final catalogLibraryRecentProvider =
    FutureProvider.autoDispose<List<CatalogRecentEpisode>>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(catalogRepositoryProvider).libraryRecent(token);
    }, retry: (count, error) => null);

final catalogPlaybackByIdProvider = FutureProvider.autoDispose
    .family<CatalogPlayback, String>((ref, id) async {
      final owner = ref.watch(authSessionProvider).user?['id'];
      if (id.isEmpty || owner is! String || owner.isEmpty) {
        throw _invalidCatalog;
      }
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(catalogRepositoryProvider).playback(id, owner, token);
    }, retry: (count, error) => null);

final catalogPlaybackProvider = FutureProvider.autoDispose<CatalogPlayback>((
  ref,
) async {
  final id = ref.watch(selectedEpisodeIdProvider);
  if (id == null || id.isEmpty) throw _invalidCatalog;
  return ref.watch(catalogPlaybackByIdProvider(id).future);
}, retry: (count, error) => null);

const missingCatalogShow = ApiFailure(
  code: 'NO_SHOW',
  message: 'Select a show from search, browse, or Home.',
);

const missingCatalogEpisode = ApiFailure(
  code: 'NO_EPISODE',
  message: 'Select an episode from a show, search, or Home.',
);

ApiFailure catalogFailure(Object error) => profileFailure(error);
