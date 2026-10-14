import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidSearch = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Search results could not be verified. Please retry.',
);

String _id(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is int) return '$value';
  if (value is num && value == value.roundToDouble()) return '${value.toInt()}';
  throw _invalidSearch;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num) return '$value';
  throw _invalidSearch;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) return '$value';
  return null;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 0) return parsed;
  }
  return null;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value == null) return const [];
  Iterable<dynamic> items;
  if (value is List) {
    items = value;
  } else if (value is Map) {
    items = value.values;
  } else {
    throw _invalidSearch;
  }
  final rows = <Map<String, dynamic>>[];
  for (final row in items) {
    final map = _asMap(row);
    if (map != null) rows.add(map);
  }
  return rows;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidSearch;
  }
  return _list(body['data']);
}

T? _tryParse<T>(T Function() parse) {
  try {
    return parse();
  } on ApiFailure {
    return null;
  } catch (_) {
    return null;
  }
}

class SearchShow {
  const SearchShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
    this.description,
    this.following = false,
  });

  factory SearchShow.fromApi(Map<String, dynamic> data) => SearchShow(
    id: _id(data['id']),
    title: _text(data, 'title'),
    author: _optionalText(data, 'author'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    description: _optionalText(data, 'description'),
    following: data['following'] == true,
  );

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
  final String? description;
  final bool following;

  SearchShow copyWith({bool? following}) => SearchShow(
    id: id,
    title: title,
    author: author,
    artworkUrl: artworkUrl,
    description: description,
    following: following ?? this.following,
  );

  String get subtitle {
    final host = author?.trim();
    if (host == null || host.isEmpty) return 'Podcast';
    return host;
  }
}

class SearchEpisode {
  const SearchEpisode({
    required this.id,
    required this.title,
    this.showId,
    this.showTitle,
    this.artworkUrl,
    this.publishedAt,
    this.durationSeconds,
  });

  factory SearchEpisode.fromApi(Map<String, dynamic> data) => SearchEpisode(
    id: _id(data['id']),
    title: _text(data, 'title'),
    showId: data['show_id'] == null ? null : _id(data['show_id']),
    showTitle: _optionalText(data, 'show_title'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    publishedAt: _optionalText(data, 'published_at'),
    durationSeconds: _optionalCount(data['duration_seconds']),
  );

  final String id;
  final String title;
  final String? showId;
  final String? showTitle;
  final String? artworkUrl;
  final String? publishedAt;
  final int? durationSeconds;

  String get subtitle {
    final show = showTitle?.trim();
    if (show == null || show.isEmpty) return 'Episode';
    return show;
  }
}

class SearchPlaylist {
  const SearchPlaylist({
    required this.id,
    required this.title,
    this.description,
    this.artworkUrl,
    this.itemCount,
    this.source = 'editorial',
    this.ownerName,
  });

  factory SearchPlaylist.fromApi(Map<String, dynamic> data) => SearchPlaylist(
    id: _id(data['id']),
    title: _text(data, 'title'),
    description: _optionalText(data, 'description'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    itemCount: _optionalCount(data['item_count']),
    source: _optionalText(data, 'source') ?? 'editorial',
    ownerName: _optionalText(data, 'owner_name'),
  );

  final String id;
  final String title;
  final String? description;
  final String? artworkUrl;
  final int? itemCount;
  final String source;
  final String? ownerName;

  bool get isUserPlaylist => source == 'user';

  String get subtitle {
    final count = itemCount;
    final countLabel =
        count == null ? 'Playlist' : '$count item${count == 1 ? '' : 's'}';
    final owner = ownerName?.trim();
    if (owner == null || owner.isEmpty) return countLabel;
    return '$countLabel · $owner';
  }
}

class SearchPage {
  const SearchPage({
    required this.query,
    required this.shows,
    required this.episodes,
    required this.playlists,
  });

  factory SearchPage.fromApi(Map<String, dynamic> data) {
    final query = data['query'];
    return SearchPage(
      query: query is String ? query : (query == null ? '' : '$query'),
      shows:
          _list(data['shows'])
              .map((row) => _tryParse(() => SearchShow.fromApi(row)))
              .whereType<SearchShow>()
              .toList(growable: false),
      episodes:
          _list(data['episodes'])
              .map((row) => _tryParse(() => SearchEpisode.fromApi(row)))
              .whereType<SearchEpisode>()
              .toList(growable: false),
      playlists:
          _list(data['playlists'])
              .map((row) => _tryParse(() => SearchPlaylist.fromApi(row)))
              .whereType<SearchPlaylist>()
              .toList(growable: false),
    );
  }

  final String query;
  final List<SearchShow> shows;
  final List<SearchEpisode> episodes;
  final List<SearchPlaylist> playlists;

  int get resultCount => shows.length + episodes.length + playlists.length;

  bool get isEmpty => resultCount == 0;

  List<String> get suggestions {
    final titles = <String>[];
    for (final item in [...shows.map((show) => show.title), ...playlists.map((playlist) => playlist.title)]) {
      if (item.trim().isEmpty || titles.contains(item)) continue;
      titles.add(item);
    }
    return titles;
  }
}

class RecentSearch {
  const RecentSearch({
    required this.id,
    required this.query,
    this.searchedAt,
  });

  factory RecentSearch.fromApi(Map<String, dynamic> data) => RecentSearch(
    id: _id(data['id']),
    query: _text(data, 'query'),
    searchedAt: _optionalText(data, 'searched_at'),
  );

  final String id;
  final String query;
  final String? searchedAt;
}

class SearchRequest {
  const SearchRequest(
    this.query, {
    this.preview = false,
    this.category,
    this.type,
    this.limit = 20,
  });

  final String query;
  final bool preview;
  final String? category;

  /// `show`, `episode`, `playlist`, or `person` when the server should search
  /// one collection. Null searches the full catalog.
  final String? type;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is SearchRequest &&
      other.query == query &&
      other.preview == preview &&
      other.category == category &&
      other.type == type &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(query, preview, category, type, limit);
}

class SearchUiState {
  const SearchUiState({
    this.submittedQuery = '',
    this.chip = 0,
    this.listening = false,
    this.voiceQuery,
    this.filterPublished = 0,
    this.unplayedOnly = false,
  });

  final String submittedQuery;
  final int chip;
  final bool listening;
  final String? voiceQuery;
  final int filterPublished;
  final bool unplayedOnly;

  SearchUiState copyWith({
    String? submittedQuery,
    int? chip,
    bool? listening,
    String? voiceQuery,
    bool clearVoiceQuery = false,
    int? filterPublished,
    bool? unplayedOnly,
  }) => SearchUiState(
    submittedQuery: submittedQuery ?? this.submittedQuery,
    chip: chip ?? this.chip,
    listening: listening ?? this.listening,
    voiceQuery: clearVoiceQuery ? null : (voiceQuery ?? this.voiceQuery),
    filterPublished: filterPublished ?? this.filterPublished,
    unplayedOnly: unplayedOnly ?? this.unplayedOnly,
  );
}

class SearchUiNotifier extends Notifier<SearchUiState> {
  @override
  SearchUiState build() => const SearchUiState();

  void submit(String query) {
    state = state.copyWith(
      submittedQuery: query.trim(),
      listening: false,
      chip: 0,
    );
  }

  void setChip(int chip) => state = state.copyWith(chip: chip);

  void listen() => state = state.copyWith(listening: true);

  void cancelVoice() =>
      state = state.copyWith(listening: false, clearVoiceQuery: true);

  void rememberVoice(String query) =>
      state = state.copyWith(listening: false, voiceQuery: query, submittedQuery: query);

  void setPublished(int value) => state = state.copyWith(filterPublished: value);

  void setUnplayed(bool value) => state = state.copyWith(unplayedOnly: value);

  void clearSubmitted() =>
      state = state.copyWith(submittedQuery: '', clearVoiceQuery: true, chip: 0);
}

class SearchRepository {
  const SearchRepository(this._dio);

  final Dio _dio;

  Future<SearchPage> search(
    SearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {
          'q': request.query.trim(),
          'limit': request.limit,
          if (request.preview) 'preview': 1,
          if (request.type != null && request.type!.trim().isNotEmpty)
            'type': request.type!.trim(),
          if (request.category != null && request.category!.trim().isNotEmpty)
            'category': request.category!.trim(),
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 20),
        ),
        cancelToken: cancelToken,
      );
      return SearchPage.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      // Let typeahead dispose cancel through without wrapping — provider swallows it.
      if (error.type == DioExceptionType.cancel || CancelToken.isCancel(error)) {
        rethrow;
      }
      throw apiFailureFromDio(error);
    }
  }

  Future<SearchPage> voice(String transcript, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/search/voice',
        data: {'transcript': transcript.trim()},
        cancelToken: cancelToken,
      );
      return SearchPage.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<RecentSearch>> recent({CancelToken? cancelToken}) async {
    try {
      final rows = _maps(
        (await _dio.get<Map<String, dynamic>>(
          '/search/recent',
          cancelToken: cancelToken,
        )).data,
      );
      return rows
          .map((row) => _tryParse(() => RecentSearch.fromApi(row)))
          .whereType<RecentSearch>()
          .toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> saveRecent(String query) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/search/recent',
          data: {'query': query.trim()},
        )).data,
      );
      if (data['saved'] != true) throw _invalidSearch;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> clearRecent() async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/search/recent')).data,
      );
      if (data['cleared'] != true) throw _invalidSearch;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> deleteRecent(String id) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/search/recent/${Uri.encodeComponent(id)}',
        )).data,
      );
      if (data['deleted'] != true) throw _invalidSearch;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<bool> follow(String showId, {required bool following}) async {
    try {
      final path = '/shows/${Uri.encodeComponent(showId)}/follow';
      final response =
          following
              ? await _dio.post<Map<String, dynamic>>(path)
              : await _dio.delete<Map<String, dynamic>>(path);
      final data = requireApiData(response.data);
      if (data['following'] != following) throw _invalidSearch;
      return following;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(dioProvider)),
);

final searchUiProvider = NotifierProvider<SearchUiNotifier, SearchUiState>(
  SearchUiNotifier.new,
);

final searchRecentProvider = FutureProvider.autoDispose<List<RecentSearch>>((
  ref,
) {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(searchRepositoryProvider).recent(cancelToken: token);
}, retry: (count, error) => null);

final searchPageProvider = FutureProvider.autoDispose
    .family<SearchPage, SearchRequest>((ref, request) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      final token = CancelToken();
      ref.onDispose(token.cancel);
      try {
        return await ref
            .watch(searchRepositoryProvider)
            .search(request, cancelToken: token);
      } on DioException catch (error) {
        if (error.type == DioExceptionType.cancel ||
            CancelToken.isCancel(error)) {
          throw const ApiFailure(
            code: 'CANCELLED',
            message: 'Request cancelled.',
          );
        }
        throw apiFailureFromDio(error);
      }
    }, retry: (count, error) => null);

ApiFailure searchFailure(Object error) => profileFailure(error);
