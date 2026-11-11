import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:pelevo/features/search/directory/feed_address.dart';
import 'package:pelevo/features/search/directory/feed_health.dart';
import 'package:pelevo/features/search/directory/rss_channel.dart';

abstract final class DirectoryIds {
  static bool isShow(String id) => id.startsWith('dirshow_');
  static bool isEpisode(String id) => id.startsWith('direp_');

  static String showId(String feedKey) =>
      'dirshow_${sha256.convert(utf8.encode(feedKey)).toString().substring(0, 20)}';

  static String episodeId(String feedKey, String guid) =>
      'direp_${sha256.convert(utf8.encode('$feedKey\n$guid')).toString().substring(0, 24)}';
}

class DirectoryCandidate {
  const DirectoryCandidate({
    required this.id,
    required this.title,
    required this.source,
    this.author,
    this.artworkUrl,
    this.feedUrl,
    this.feedKey,
    this.externalId,
    this.showId,
    this.episodeCount,
    this.inCatalog = false,
    this.health = FeedHealth.alive,
  });

  final String id;
  final String title;
  final String source;
  final String? author;
  final String? artworkUrl;
  final String? feedUrl;
  final String? feedKey;
  final String? externalId;
  final String? showId;
  final int? episodeCount;
  final bool inCatalog;
  final FeedHealth health;

  bool get canAdd => health == FeedHealth.alive && title.trim().isNotEmpty;

  String get sourceLabel => switch (source) {
    'apple' => 'Apple Podcasts',
    'podcast_index' => 'Podcast Index',
    'rss' => 'RSS feed',
    _ => 'Podcast directory',
  };

  DirectoryCandidate copyWith({
    bool? inCatalog,
    String? showId,
    FeedHealth? health,
    String? feedUrl,
    String? feedKey,
  }) => DirectoryCandidate(
    id: id,
    title: title,
    source: source,
    author: author,
    artworkUrl: artworkUrl,
    feedUrl: feedUrl ?? this.feedUrl,
    feedKey: feedKey ?? this.feedKey,
    externalId: externalId,
    showId: showId ?? this.showId,
    episodeCount: episodeCount,
    inCatalog: inCatalog ?? this.inCatalog,
    health: health ?? this.health,
  );

  /// Keeps one row when Apple and Podcast Index return the same feed.
  DirectoryCandidate mergeWith(DirectoryCandidate other) {
    final catalog = inCatalog || other.inCatalog;
    return DirectoryCandidate(
      id: id,
      title: title,
      source: source,
      author: (author == null || author!.isEmpty) ? other.author : author,
      artworkUrl:
          (artworkUrl == null || artworkUrl!.isEmpty)
              ? other.artworkUrl
              : artworkUrl,
      feedUrl: feedUrl ?? other.feedUrl,
      feedKey: feedKey ?? other.feedKey,
      externalId: externalId ?? other.externalId,
      showId: showId ?? other.showId,
      episodeCount: _larger(episodeCount, other.episodeCount),
      inCatalog: catalog,
      health: health == FeedHealth.dead ? health : other.health,
    );
  }
}

int? _larger(int? left, int? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left > right ? left : right;
}

/// Drops dead rows and collapses candidates that share a feed identity.
List<DirectoryCandidate> mergeDirectoryCandidates(
  List<DirectoryCandidate> items,
) {
  final order = <String>[];
  final byKey = <String, DirectoryCandidate>{};
  for (final item in items) {
    if (!item.canAdd) continue;
    final key = item.feedKey ?? item.id;
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = item;
      order.add(key);
    } else {
      byKey[key] = existing.mergeWith(item);
    }
  }
  return [for (final key in order) byKey[key]!];
}

/// Matches a directory row to a show already returned by Pelevo search.
String? matchingCatalogShowId(
  DirectoryCandidate candidate,
  List<({String id, String title, String? author})> shows,
) {
  if (candidate.inCatalog &&
      candidate.showId != null &&
      candidate.showId!.isNotEmpty &&
      !DirectoryIds.isShow(candidate.showId!)) {
    return candidate.showId;
  }
  final title = candidate.title.trim().toLowerCase();
  final author = candidate.author?.trim().toLowerCase();
  for (final show in shows) {
    if (show.title.trim().toLowerCase() != title) continue;
    final host = show.author?.trim().toLowerCase();
    if (author == null ||
        author.isEmpty ||
        host == null ||
        host.isEmpty ||
        host == author) {
      return show.id;
    }
  }
  return null;
}

class DirectorySearchResult {
  const DirectorySearchResult({
    required this.query,
    required this.candidates,
    this.unavailableMessage,
  });

  final String query;
  final List<DirectoryCandidate> candidates;
  final String? unavailableMessage;

  bool get isEmpty => candidates.isEmpty && unavailableMessage == null;
}

class DirectorySubscription {
  const DirectorySubscription({
    required this.showId,
    required this.alreadyInCatalog,
    required this.storedLocally,
  });

  final String showId;
  final bool alreadyInCatalog;
  final bool storedLocally;
}

class PodcastIndexCredentials {
  const PodcastIndexCredentials({required this.key, required this.secret});

  final String key;
  final String secret;

  static const fromEnvironment = PodcastIndexCredentials(
    key: String.fromEnvironment('PODCAST_INDEX_API_KEY'),
    secret: String.fromEnvironment('PODCAST_INDEX_API_SECRET'),
  );

  bool get enabled => key.trim().isNotEmpty && secret.trim().isNotEmpty;

  Map<String, String> headers({DateTime? now, String userAgent = 'Pelevo'}) {
    final unix = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final hash = sha1.convert(utf8.encode('$key$secret$unix')).toString();
    return {
      'User-Agent': userAgent,
      'X-Auth-Key': key,
      'X-Auth-Date': '$unix',
      'Authorization': hash,
    };
  }
}

DirectoryCandidate? candidateFromApple(Map<String, dynamic> row) {
  final id = row['collectionId'];
  final title = row['collectionName'];
  final feed = row['feedUrl'];
  if (id == null || title is! String || title.trim().isEmpty) return null;
  if (feed is! String || feed.trim().isEmpty) return null;
  final address = FeedAddress.tryParse(feed);
  if (address == null) return null;
  final external = '$id';
  return DirectoryCandidate(
    id: 'apple:$external',
    title: title.trim(),
    source: 'apple',
    author: row['artistName'] is String ? (row['artistName'] as String).trim() : null,
    artworkUrl:
        row['artworkUrl600'] is String
            ? row['artworkUrl600'] as String
            : row['artworkUrl100'] is String
            ? row['artworkUrl100'] as String
            : null,
    feedUrl: address.uri.toString(),
    feedKey: address.key,
    externalId: external,
    episodeCount: _count(row['trackCount']),
  );
}

DirectoryCandidate? candidateFromPodcastIndex(Map<String, dynamic> row) {
  if (row['dead'] == 1 || row['dead'] == true) return null;
  final id = row['id'];
  final title = row['title'];
  final feed = row['url'] ?? row['originalUrl'];
  if (id == null || title is! String || title.trim().isEmpty) return null;
  if (feed is! String || feed.trim().isEmpty) return null;
  final address = FeedAddress.tryParse(feed);
  if (address == null) return null;
  final external = '$id';
  return DirectoryCandidate(
    id: 'podcastindex:$external',
    title: title.trim(),
    source: 'podcast_index',
    author: row['author'] is String ? (row['author'] as String).trim() : null,
    artworkUrl:
        row['artwork'] is String
            ? row['artwork'] as String
            : row['image'] is String
            ? row['image'] as String
            : null,
    feedUrl: address.uri.toString(),
    feedKey: address.key,
    externalId: external,
    episodeCount: _count(row['episodeCount']),
  );
}

DirectoryCandidate candidateFromChannel({
  required FeedAddress address,
  required RssChannel channel,
  String source = 'rss',
}) => DirectoryCandidate(
  id: 'rss:${DirectoryIds.showId(address.key)}',
  title: channel.title,
  source: source,
  author: channel.author,
  artworkUrl: channel.artworkUrl,
  feedUrl: address.uri.toString(),
  feedKey: address.key,
  episodeCount: channel.episodes.length,
);

int? _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
