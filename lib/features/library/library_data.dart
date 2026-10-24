import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

const _invalidLibrary = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Library details could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw _invalidLibrary;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidLibrary;
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
  throw _invalidLibrary;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  return _count(value);
}

bool _flag(Object? value) {
  if (value is bool) return value;
  if (value == 1 || value == '1' || value == 'true') return true;
  if (value == 0 || value == '0' || value == 'false') return false;
  throw _invalidLibrary;
}

DateTime? _optionalDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) throw _invalidLibrary;
  final parsed =
      DateTime.tryParse(value) ??
      DateTime.tryParse(value.replaceFirst(' ', 'T'));
  if (parsed == null) throw _invalidLibrary;
  return parsed;
}

const _libraryPageLimit = 50;

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidLibrary;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _listBody(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidLibrary;
  }
  return _maps(body['data']);
}

class LibraryEpisode {
  const LibraryEpisode({
    required this.id,
    required this.showId,
    required this.title,
    this.showTitle,
    this.artworkUrl,
    this.durationSeconds,
    this.positionSeconds,
    this.completed,
    this.playedAt,
  });

  factory LibraryEpisode.parse(Map<String, dynamic> data) {
    final played =
        _optionalDate(data, 'played_at') ?? _optionalDate(data, 'saved_at');
    return LibraryEpisode(
      id: _text(data, 'id'),
      showId: _text(data, 'show_id'),
      title: _text(data, 'title'),
      showTitle: _optionalText(data, 'show_title'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      durationSeconds: _optionalCount(data['duration_seconds']),
      positionSeconds: _optionalCount(data['position_seconds']),
      completed: data['completed'] == null ? null : _flag(data['completed']),
      playedAt: played,
    );
  }

  final String id, showId, title;
  final String? showTitle, artworkUrl;
  final int? durationSeconds, positionSeconds;
  final bool? completed;
  final DateTime? playedAt;

  String get subtitle {
    final show = showTitle ?? '';
    final duration =
        durationSeconds == null ? null : formatCatalogDuration(durationSeconds!);
    return [show, duration].where((part) => part != null && part.isNotEmpty).join(' · ');
  }

  double get progress {
    final duration = durationSeconds ?? 0;
    final position = positionSeconds ?? 0;
    if (completed == true) return 1;
    if (duration <= 0) return 0;
    return (position / duration).clamp(0, 1);
  }
}

class LibraryShow {
  const LibraryShow({
    required this.id,
    required this.title,
    required this.notificationsEnabled,
    this.author,
    this.artworkUrl,
  });

  factory LibraryShow.parse(Map<String, dynamic> data) => LibraryShow(
    id: _text(data, 'id'),
    title: _text(data, 'title'),
    author: _optionalText(data, 'author'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    notificationsEnabled: _flag(data['notifications_enabled']),
  );

  final String id, title;
  final String? author, artworkUrl;
  final bool notificationsEnabled;
}

class LibraryPlaylist {
  const LibraryPlaylist({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.version,
    required this.itemCount,
    this.description,
    this.artworkUrl,
    this.ownerName,
    this.isOwner = true,
    this.items = const [],
  });

  factory LibraryPlaylist.parse(Map<String, dynamic> data, {bool detailed = false}) {
    final items =
        detailed
            ? _maps(data['items']).map(LibraryEpisode.parse).toList(growable: false)
            : const <LibraryEpisode>[];
    return LibraryPlaylist(
      id: _text(data, 'id'),
      name: _text(data, 'name'),
      description: _optionalText(data, 'description'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      ownerName: _optionalText(data, 'owner_name'),
      isPublic: _flag(data['is_public']),
      isOwner: data['is_owner'] == null ? true : _flag(data['is_owner']),
      version: _count(data['version']),
      itemCount: _count(data['item_count']),
      items: items,
    );
  }

  final String id, name;
  final String? description, artworkUrl, ownerName;
  final bool isPublic, isOwner;
  final int version, itemCount;
  final List<LibraryEpisode> items;

  String get countLabel => '$itemCount episode${itemCount == 1 ? '' : 's'}';

  String get visibilityLabel => isPublic ? 'Public' : 'Private';
}

class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.version,
    required this.itemCount,
    this.description,
    this.artworkUrl,
    this.isPublic = false,
    this.isOwner = true,
    this.items = const [],
  });

  factory LibraryCollection.parse(Map<String, dynamic> data, {bool detailed = false}) {
    final raw = detailed ? data['items'] : const [];
    final items = <LibraryCollectionItem>[];
    for (final row in _maps(raw)) {
      items.add(LibraryCollectionItem.parse(row));
    }
    return LibraryCollection(
      id: _text(data, 'id'),
      name: _text(data, 'name'),
      description: _optionalText(data, 'description'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      isPublic: data.containsKey('is_public') ? _flag(data['is_public']) : false,
      isOwner: data.containsKey('is_owner') ? _flag(data['is_owner']) : true,
      version: _count(data['version']),
      itemCount: _count(data['item_count']),
      items: items,
    );
  }

  final String id, name;
  final String? description, artworkUrl;
  final bool isPublic, isOwner;
  final int version, itemCount;
  final List<LibraryCollectionItem> items;

  String get countLabel => '$itemCount item${itemCount == 1 ? '' : 's'}';
}

class LibraryCollectionItem {
  const LibraryCollectionItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.artworkUrl,
    this.showId,
  });

  factory LibraryCollectionItem.parse(Map<String, dynamic> data) {
    final type = _text(data, 'collectable_type');
    if (type != 'episode' && type != 'show') throw _invalidLibrary;
    return LibraryCollectionItem(
      id: _text(data, 'id'),
      type: type,
      title: _text(data, 'title'),
      subtitle: _optionalText(data, 'show_title') ?? _optionalText(data, 'author'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      showId: _optionalText(data, 'show_id'),
    );
  }

  final String id, type, title;
  final String? subtitle, artworkUrl, showId;
}

class LibraryOverview {
  const LibraryOverview({
    required this.savedCount,
    required this.savedReelsCount,
    required this.likedCount,
    required this.showsCount,
    required this.downloadsCount,
    required this.recentCount,
    required this.playlists,
    required this.collections,
  });

  factory LibraryOverview.parse(Map<String, dynamic> data) => LibraryOverview(
    savedCount: _count(data['saved_count']),
    savedReelsCount: _optionalCount(data['saved_reels_count']) ?? 0,
    likedCount: _count(data['liked_count']),
    showsCount: _count(data['shows_count']),
    downloadsCount: _count(data['downloads_count']),
    recentCount: _count(data['recent_count'] ?? 0),
    playlists: _maps(data['playlists']).map(LibraryPlaylist.parse).toList(growable: false),
    collections:
        _maps(data['collections']).map(LibraryCollection.parse).toList(growable: false),
  );

  final int savedCount, savedReelsCount, likedCount, showsCount, downloadsCount, recentCount;
  final List<LibraryPlaylist> playlists;
  final List<LibraryCollection> collections;
}

class LibrarySettings {
  const LibrarySettings(this.hideCompleted, this.sort, this.version);

  factory LibrarySettings.parse(Map<String, dynamic> data) {
    final sort = _text(data, 'sort');
    if (sort != 'recent' && sort != 'title' && sort != 'oldest') {
      throw _invalidLibrary;
    }
    return LibrarySettings(_flag(data['hide_completed']), sort, _count(data['version']));
  }

  final bool hideCompleted;
  final String sort;
  final int version;

  int get sortIndex => sort == 'title' ? 1 : sort == 'oldest' ? 2 : 0;
}

class LibraryDownload {
  const LibraryDownload({
    required this.downloadId,
    required this.episodeId,
    required this.title,
    this.showId,
    this.showTitle,
    this.artworkUrl,
    this.authorizedUntil,
  });

  factory LibraryDownload.parse(Map<String, dynamic> data) {
    final until = _optionalText(data, 'authorized_until');
    if (until != null && DateTime.tryParse(until) == null) throw _invalidLibrary;
    return LibraryDownload(
      downloadId: _text(data, 'download_id'),
      episodeId: _text(data, 'id'),
      title: _text(data, 'title'),
      showId: _optionalText(data, 'show_id'),
      showTitle: _optionalText(data, 'show_title'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      authorizedUntil: until == null ? null : DateTime.parse(until),
    );
  }

  final String downloadId, episodeId, title;
  final String? showId, showTitle, artworkUrl;
  final DateTime? authorizedUntil;
}

class DownloadSettings {
  const DownloadSettings(
    this.wifiOnly,
    this.autoDownloadNew,
    this.autoDeleteCompleted,
    this.maxStorageMb,
    this.version,
  );

  factory DownloadSettings.parse(Map<String, dynamic> data) => DownloadSettings(
    _flag(data['wifi_only']),
    data['auto_download_new'] == null
        ? false
        : _flag(data['auto_download_new']),
    _flag(data['auto_delete_completed']),
    _count(data['max_storage_mb']),
    _count(data['version']),
  );

  final bool wifiOnly, autoDownloadNew, autoDeleteCompleted;
  final int maxStorageMb, version;
}

class AutoDownloadEpisode {
  const AutoDownloadEpisode({required this.episodeId, required this.title});

  factory AutoDownloadEpisode.parse(Map<String, dynamic> data) {
    final id = data['id'];
    if (id == null || '$id'.isEmpty) throw _invalidLibrary;
    return AutoDownloadEpisode(
      episodeId: '$id',
      title: data['title'] is String ? data['title'] as String : '',
    );
  }

  final String episodeId;
  final String title;
}

class LibraryRepository {
  LibraryRepository(this._dio);
  final Dio _dio;

  Future<LibraryOverview> overview(CancelToken token) async {
    try {
      return LibraryOverview.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/library', cancelToken: token)).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryEpisode>> saved(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/library/saved',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryEpisode>> liked(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/library/liked',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryShow>> shows(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/library/shows',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryShow.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryEpisode>> recent(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/library/recent',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryPlaylist>> playlists(
    CancelToken token, {
    String scope = 'mine',
  }) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/playlists',
          queryParameters: {
            'limit': _libraryPageLimit,
            if (scope != 'mine') 'scope': scope,
          },
          cancelToken: token,
        )).data,
      ).map(LibraryPlaylist.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryPlaylist> playlist(String id, CancelToken token) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(id)}',
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

  Future<LibraryPlaylist> createPlaylist({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/playlists',
            data: {
              'name': name,
              'description': description,
              'is_public': isPublic,
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

  Future<void> deletePlaylist(String id) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/playlists/${Uri.encodeComponent(id)}',
        )).data,
      );
      if (data['deleted'] != true) throw _invalidLibrary;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryPlaylist> addPlaylistItem({
    required String playlistId,
    required String episodeId,
    required int version,
  }) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(playlistId)}/items',
            data: {'episode_id': episodeId, 'version': version},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryPlaylist> updatePlaylist(
    LibraryPlaylist playlist, {
    required String name,
    String? description,
    required bool isPublic,
  }) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.put<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(playlist.id)}',
            data: {
              'name': name,
              'description': description,
              'is_public': isPublic,
              'version': playlist.version,
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

  Future<LibraryPlaylist> uploadPlaylistArtwork({
    required String playlistId,
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ApiFailure(
        code: 'VALIDATION',
        message: 'Choose a photo smaller than 5 MB.',
      );
    }
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(playlistId)}/artwork',
            data: FormData.fromMap({
              'artwork': MultipartFile.fromBytes(bytes, filename: filename),
            }),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryPlaylist> removePlaylistItem({
    required String playlistId,
    required String episodeId,
    required int version,
  }) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.delete<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(playlistId)}/items/${Uri.encodeComponent(episodeId)}',
            data: {'version': version},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryPlaylist> reorderPlaylistItems({
    required String playlistId,
    required List<String> episodeIds,
    required int version,
  }) async {
    try {
      return LibraryPlaylist.parse(
        requireApiData(
          (await _dio.put<Map<String, dynamic>>(
            '/playlists/${Uri.encodeComponent(playlistId)}/items/reorder',
            data: {'version': version, 'episode_ids': episodeIds},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<LibraryCollection>> collections(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/collections',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryCollection.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibraryCollection> collection(String id, CancelToken token) async {
    try {
      return LibraryCollection.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/collections/${Uri.encodeComponent(id)}',
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

  Future<LibraryCollection> createCollection(
    String name, {
    String? description,
    bool isPublic = false,
  }) async {
    try {
      return LibraryCollection.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/collections',
            data: {
              'name': name,
              'description': description,
              'is_public': isPublic,
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

  Future<LibraryCollection> updateCollection({
    required String id,
    required String name,
    required int version,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      return LibraryCollection.parse(
        requireApiData(
          (await _dio.put<Map<String, dynamic>>(
            '/collections/${Uri.encodeComponent(id)}',
            data: {
              'name': name,
              'description': description,
              'is_public': isPublic,
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

  Future<LibraryCollection> addCollectionItem({
    required String id,
    required String type,
    required String collectableId,
    required int version,
  }) async {
    try {
      return LibraryCollection.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/collections/${Uri.encodeComponent(id)}/items',
            data: {
              'collectable_type': type,
              'collectable_id': collectableId,
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

  Future<LibraryCollection> removeCollectionItem({
    required String id,
    required String type,
    required String collectableId,
    required int version,
  }) async {
    try {
      return LibraryCollection.parse(
        requireApiData(
          (await _dio.delete<Map<String, dynamic>>(
            '/collections/${Uri.encodeComponent(id)}/items/$type/${Uri.encodeComponent(collectableId)}',
            data: {'version': version},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/collections/${Uri.encodeComponent(id)}',
        )).data,
      );
      if (data['deleted'] != true) throw _invalidLibrary;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LibrarySettings> settings(CancelToken token) async {
    try {
      return LibrarySettings.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/library/settings',
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

  Future<LibrarySettings> saveSettings({
    required bool hideCompleted,
    required String sort,
    required int version,
  }) async {
    try {
      return LibrarySettings.parse(
        requireApiData(
          (await _dio.patch<Map<String, dynamic>>(
            '/library/settings',
            data: {
              'hide_completed': hideCompleted,
              'sort': sort,
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

  Future<List<LibraryDownload>> downloads(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/downloads',
          queryParameters: const {'limit': _libraryPageLimit},
          cancelToken: token,
        )).data,
      ).map(LibraryDownload.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<DownloadSettings> downloadSettings(CancelToken token) async {
    try {
      return DownloadSettings.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/downloads/settings',
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

  Future<DownloadSettings> saveDownloadSettings(
    DownloadSettings current, {
    bool? wifiOnly,
    bool? autoDownloadNew,
    bool? autoDeleteCompleted,
    int? maxStorageMb,
  }) async {
    try {
      return DownloadSettings.parse(
        requireApiData(
          (await _dio.patch<Map<String, dynamic>>(
            '/downloads/settings',
            data: {
              'wifi_only': wifiOnly ?? current.wifiOnly,
              'auto_download_new': autoDownloadNew ?? current.autoDownloadNew,
              'auto_delete_completed':
                  autoDeleteCompleted ?? current.autoDeleteCompleted,
              'max_storage_mb': maxStorageMb ?? current.maxStorageMb,
              'version': current.version,
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

  Future<List<AutoDownloadEpisode>> newEpisodeDownloads(CancelToken token) async {
    try {
      return _maps(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/downloads/new-episodes',
            cancelToken: token,
          )).data,
        ),
      ).map(AutoDownloadEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> deleteDownload(String downloadId) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/downloads/$downloadId')).data,
      );
      if (data['deleted'] != true) throw _invalidLibrary;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StorageUsage> storage(CancelToken token) async {
    try {
      return StorageUsage.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/storage', cancelToken: token)).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> clearStorageCache() async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/storage/cache')).data,
      );
      if (data['cleared'] != true) throw _invalidLibrary;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

class StorageUsage {
  const StorageUsage(this.backupBytes, this.offlineItems);

  factory StorageUsage.parse(Map<String, dynamic> data) => StorageUsage(
    _count(data['backup_bytes']),
    _count(data['offline_items']),
  );

  final int backupBytes, offlineItems;
}

class SelectedPlaylistIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

class SelectedCollectionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedPlaylistIdProvider =
    NotifierProvider<SelectedPlaylistIdNotifier, String?>(SelectedPlaylistIdNotifier.new);

final selectedCollectionIdProvider =
    NotifierProvider<SelectedCollectionIdNotifier, String?>(
      SelectedCollectionIdNotifier.new,
    );

final libraryRepositoryProvider = Provider(
  (ref) => LibraryRepository(ref.watch(dioProvider)),
);

final libraryOverviewProvider = FutureProvider.autoDispose<LibraryOverview>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).overview(token);
}, retry: (count, error) => null);

final libraryPlaylistsProvider = FutureProvider.autoDispose<List<LibraryPlaylist>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).playlists(token);
}, retry: (count, error) => null);

final libraryPublicPlaylistsProvider = FutureProvider.autoDispose<List<LibraryPlaylist>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).playlists(token, scope: 'others');
}, retry: (count, error) => null);

final libraryPlaylistProvider = FutureProvider.autoDispose<LibraryPlaylist>((ref) async {
  final id = ref.watch(selectedPlaylistIdProvider);
  if (id == null || id.isEmpty) throw _invalidLibrary;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).playlist(id, token);
}, retry: (count, error) => null);

final librarySavedProvider = FutureProvider.autoDispose<List<LibraryEpisode>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).saved(token);
}, retry: (count, error) => null);

final libraryLikedProvider = FutureProvider.autoDispose<List<LibraryEpisode>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).liked(token);
}, retry: (count, error) => null);

final libraryShowsProvider = FutureProvider.autoDispose<List<LibraryShow>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).shows(token);
}, retry: (count, error) => null);

final libraryRecentProvider = FutureProvider.autoDispose<List<LibraryEpisode>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).recent(token);
}, retry: (count, error) => null);

final libraryCollectionsProvider = FutureProvider.autoDispose<List<LibraryCollection>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).collections(token);
}, retry: (count, error) => null);

final libraryCollectionProvider = FutureProvider.autoDispose<LibraryCollection>((ref) async {
  final id = ref.watch(selectedCollectionIdProvider);
  if (id == null || id.isEmpty) throw _invalidLibrary;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).collection(id, token);
}, retry: (count, error) => null);

final librarySettingsProvider = FutureProvider.autoDispose<LibrarySettings>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).settings(token);
}, retry: (count, error) => null);

final libraryDownloadsProvider = FutureProvider.autoDispose<List<LibraryDownload>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).downloads(token);
}, retry: (count, error) => null);

final downloadSettingsProvider = FutureProvider.autoDispose<DownloadSettings>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).downloadSettings(token);
}, retry: (count, error) => null);

final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(libraryRepositoryProvider).storage(token);
}, retry: (count, error) => null);

class SelectedDownloadIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedDownloadIdProvider =
    NotifierProvider<SelectedDownloadIdNotifier, String?>(SelectedDownloadIdNotifier.new);

class SelectedDownloadIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void replace(Iterable<String> ids) => state = {...ids};
  void toggle(String id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
  }
}

final selectedDownloadIdsProvider =
    NotifierProvider<SelectedDownloadIdsNotifier, Set<String>>(
      SelectedDownloadIdsNotifier.new,
    );

const missingLibraryPlaylist = ApiFailure(
  code: 'NO_PLAYLIST',
  message: 'Select a playlist from your library.',
);

const missingLibraryCollection = ApiFailure(
  code: 'NO_COLLECTION',
  message: 'Select a collection from your library.',
);
