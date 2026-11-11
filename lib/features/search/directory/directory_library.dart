import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:pelevo/features/search/directory/directory_models.dart';
import 'package:pelevo/features/search/directory/rss_channel.dart';

abstract class DirectoryStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

class PreferencesDirectoryStore implements DirectoryStore {
  const PreferencesDirectoryStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) => _preferences.setString(key, value);
}

class MemoryDirectoryStore implements DirectoryStore {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class StoredDirectoryEpisode {
  const StoredDirectoryEpisode({
    required this.id,
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.description,
    this.artworkUrl,
    this.publishedAt,
    this.durationSeconds,
  });

  final String id;
  final String guid;
  final String title;
  final String audioUrl;
  final String? description;
  final String? artworkUrl;
  final DateTime? publishedAt;
  final int? durationSeconds;
}

class StoredDirectoryShow {
  const StoredDirectoryShow({
    required this.id,
    required this.feedKey,
    required this.feedUrl,
    required this.title,
    required this.episodes,
    required this.syncedAt,
    required this.following,
    this.author,
    this.artworkUrl,
    this.description,
    this.source = 'rss',
    this.externalId,
    this.feedState = 'ok',
    this.feedError,
  });

  final String id;
  final String feedKey;
  final String feedUrl;
  final String title;
  final String? author;
  final String? artworkUrl;
  final String? description;
  final String source;
  final String? externalId;
  final bool following;
  final DateTime syncedAt;
  final String feedState;
  final String? feedError;
  final List<StoredDirectoryEpisode> episodes;

  bool isStaleAt(DateTime now) =>
      now.difference(syncedAt) >= const Duration(minutes: 15);

  StoredDirectoryShow copyWith({
    String? title,
    String? author,
    String? artworkUrl,
    String? description,
    bool? following,
    DateTime? syncedAt,
    String? feedState,
    String? feedError,
    bool clearFeedError = false,
    List<StoredDirectoryEpisode>? episodes,
  }) => StoredDirectoryShow(
    id: id,
    feedKey: feedKey,
    feedUrl: feedUrl,
    title: title ?? this.title,
    author: author ?? this.author,
    artworkUrl: artworkUrl ?? this.artworkUrl,
    description: description ?? this.description,
    source: source,
    externalId: externalId,
    following: following ?? this.following,
    syncedAt: syncedAt ?? this.syncedAt,
    feedState: feedState ?? this.feedState,
    feedError: clearFeedError ? null : (feedError ?? this.feedError),
    episodes: episodes ?? this.episodes,
  );
}

class DirectoryLibrary {
  DirectoryLibrary(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'directory.subscriptions.v1';

  final DirectoryStore _store;
  final DateTime Function() _clock;

  StoredDirectoryShow? findShow(String id) {
    for (final show in _read()) {
      if (show.id == id) return show;
    }
    return null;
  }

  StoredDirectoryShow? findByFeedKey(String feedKey) {
    for (final show in _read()) {
      if (show.feedKey == feedKey) return show;
    }
    return null;
  }

  StoredDirectoryEpisode? findEpisode(String id) {
    for (final show in _read()) {
      for (final episode in show.episodes) {
        if (episode.id == id) return episode;
      }
    }
    return null;
  }

  StoredDirectoryShow? showForEpisode(String episodeId) {
    for (final show in _read()) {
      for (final episode in show.episodes) {
        if (episode.id == episodeId) return show;
      }
    }
    return null;
  }

  /// Inserts a feed, or merges episodes when that feed is already stored.
  Future<StoredDirectoryShow> importChannel({
    required String feedUrl,
    required String feedKey,
    required RssChannel channel,
    required String source,
    String? externalId,
  }) async {
    final existing = findByFeedKey(feedKey);
    final show = _fromChannel(
      id: existing?.id ?? DirectoryIds.showId(feedKey),
      feedUrl: feedUrl,
      feedKey: feedKey,
      channel: channel,
      source: existing?.source ?? source,
      externalId: existing?.externalId ?? externalId,
      following: true,
      previous: existing,
    );
    await _saveReplacing(show);
    return show;
  }

  Future<StoredDirectoryShow> updateFromChannel(
    StoredDirectoryShow current,
    RssChannel channel, {
    String? feedError,
    String feedState = 'ok',
  }) async {
    final show = _fromChannel(
      id: current.id,
      feedUrl: current.feedUrl,
      feedKey: current.feedKey,
      channel: channel,
      source: current.source,
      externalId: current.externalId,
      following: current.following,
      previous: current,
      feedState: feedState,
      feedError: feedError,
    );
    await _saveReplacing(show);
    return show;
  }

  Future<StoredDirectoryShow> markFeedFailure(
    StoredDirectoryShow current, {
    required String message,
    required bool dead,
  }) async {
    final show = current.copyWith(
      syncedAt: _clock().toUtc(),
      feedState: dead ? 'failed' : 'stale',
      feedError: message,
    );
    await _saveReplacing(show);
    return show;
  }

  Future<void> setFollowing(String id, {required bool following}) async {
    final current = findShow(id);
    if (current == null) {
      throw StateError('Podcast is not on this device.');
    }
    await _saveReplacing(current.copyWith(following: following));
  }

  StoredDirectoryShow _fromChannel({
    required String id,
    required String feedUrl,
    required String feedKey,
    required RssChannel channel,
    required String source,
    required bool following,
    String? externalId,
    StoredDirectoryShow? previous,
    String feedState = 'ok',
    String? feedError,
  }) {
    final incoming = <String, StoredDirectoryEpisode>{};
    for (final episode in channel.episodes) {
      final stored = StoredDirectoryEpisode(
        id: DirectoryIds.episodeId(feedKey, episode.guid),
        guid: episode.guid,
        title: episode.title,
        audioUrl: episode.audioUrl,
        description: episode.description,
        artworkUrl: episode.artworkUrl ?? channel.artworkUrl,
        publishedAt: episode.publishedAt,
        durationSeconds: episode.durationSeconds,
      );
      incoming[episode.guid] = stored;
    }
    if (previous != null) {
      for (final episode in previous.episodes) {
        incoming.putIfAbsent(episode.guid, () => episode);
      }
    }
    final episodes = incoming.values.toList()
      ..sort((a, b) {
        final left = a.publishedAt;
        final right = b.publishedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    if (episodes.length > 80) {
      episodes.removeRange(80, episodes.length);
    }
    return StoredDirectoryShow(
      id: id,
      feedKey: feedKey,
      feedUrl: feedUrl,
      title: channel.title,
      author: channel.author ?? previous?.author,
      artworkUrl: channel.artworkUrl ?? previous?.artworkUrl,
      description: channel.description ?? previous?.description,
      source: source,
      externalId: externalId,
      following: following,
      syncedAt: _clock().toUtc(),
      feedState: feedState,
      feedError: feedError,
      episodes: episodes,
    );
  }

  List<StoredDirectoryShow> _read() {
    final raw = _store.read(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final row in decoded)
          if (row is Map) _showFromJson(Map<String, dynamic>.from(row)),
      ].whereType<StoredDirectoryShow>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveReplacing(StoredDirectoryShow show) async {
    final shows = [for (final item in _read()) if (item.id != show.id) item];
    shows.add(show);
    await _store.write(
      storageKey,
      jsonEncode([for (final item in shows) _showToJson(item)]),
    );
  }

  StoredDirectoryShow? _showFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final feedKey = json['feedKey'];
    final feedUrl = json['feedUrl'];
    final title = json['title'];
    final synced = json['syncedAt'];
    if (id is! String ||
        feedKey is! String ||
        feedUrl is! String ||
        title is! String ||
        synced is! String) {
      return null;
    }
    final syncedAt = DateTime.tryParse(synced);
    if (syncedAt == null) return null;
    final episodes = <StoredDirectoryEpisode>[];
    final rows = json['episodes'];
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) continue;
        final episode = _episodeFromJson(Map<String, dynamic>.from(row));
        if (episode != null) episodes.add(episode);
      }
    }
    return StoredDirectoryShow(
      id: id,
      feedKey: feedKey,
      feedUrl: feedUrl,
      title: title,
      author: json['author'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      description: json['description'] as String?,
      source: json['source'] is String ? json['source'] as String : 'rss',
      externalId: json['externalId'] as String?,
      following: json['following'] == true,
      syncedAt: syncedAt,
      feedState: json['feedState'] is String ? json['feedState'] as String : 'ok',
      feedError: json['feedError'] as String?,
      episodes: episodes,
    );
  }

  StoredDirectoryEpisode? _episodeFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final guid = json['guid'];
    final title = json['title'];
    final audio = json['audioUrl'];
    if (id is! String || guid is! String || title is! String || audio is! String) {
      return null;
    }
    final published = json['publishedAt'];
    return StoredDirectoryEpisode(
      id: id,
      guid: guid,
      title: title,
      audioUrl: audio,
      description: json['description'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      durationSeconds: json['durationSeconds'] is int ? json['durationSeconds'] as int : null,
    );
  }

  Map<String, dynamic> _showToJson(StoredDirectoryShow show) => {
    'id': show.id,
    'feedKey': show.feedKey,
    'feedUrl': show.feedUrl,
    'title': show.title,
    'author': show.author,
    'artworkUrl': show.artworkUrl,
    'description': show.description,
    'source': show.source,
    'externalId': show.externalId,
    'following': show.following,
    'syncedAt': show.syncedAt.toUtc().toIso8601String(),
    'feedState': show.feedState,
    'feedError': show.feedError,
    'episodes': [
      for (final episode in show.episodes)
        {
          'id': episode.id,
          'guid': episode.guid,
          'title': episode.title,
          'audioUrl': episode.audioUrl,
          'description': episode.description,
          'artworkUrl': episode.artworkUrl,
          'publishedAt': episode.publishedAt?.toUtc().toIso8601String(),
          'durationSeconds': episode.durationSeconds,
        },
    ],
  };
}
