import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidCatalog = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Earn catalog could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidCatalog;
  return value;
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
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw _invalidCatalog;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  return _count(value);
}

int _positiveInt(Object? value) {
  final parsed = _count(value);
  if (parsed <= 0) throw _invalidCatalog;
  return parsed;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidCatalog;
  }
  final data = body['data'];
  if (data is! List) throw _invalidCatalog;
  final rows = <Map<String, dynamic>>[];
  for (final row in data) {
    if (row is! Map) throw _invalidCatalog;
    rows.add(Map<String, dynamic>.from(row));
  }
  return rows;
}

class EarnShow {
  const EarnShow({
    required this.id,
    required this.title,
    required this.episodeCount,
    this.author,
    this.artworkUrl,
    this.niche,
  });

  factory EarnShow.fromApi(Map<String, dynamic> data) {
    return EarnShow(
      id: _text(data, 'id'),
      title: _text(data, 'title'),
      author: _optionalText(data, 'author'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      episodeCount: _count(data['episodes_count']),
      niche: _optionalText(data, 'niche'),
    );
  }

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
  final int episodeCount;
  final String? niche;

  String get host =>
      (author == null || author!.isEmpty) ? 'Host unavailable' : author!;
}

class EarnEpisode {
  const EarnEpisode({
    required this.id,
    required this.showId,
    required this.showTitle,
    required this.title,
    required this.durationSeconds,
    this.showAuthor,
    this.artworkUrl,
    this.audioUrl,
    this.niche,
    this.coins,
    this.lockedUntil,
  });

  factory EarnEpisode.fromApi(Map<String, dynamic> data) {
    final untilRaw = data['locked_until'];
    if (untilRaw != null && untilRaw is! String) throw _invalidCatalog;
    final until =
        untilRaw is String && untilRaw.isNotEmpty
            ? DateTime.tryParse(untilRaw)
            : null;
    if (untilRaw is String && untilRaw.isNotEmpty && until == null) {
      throw _invalidCatalog;
    }
    return EarnEpisode(
      id: _text(data, 'id'),
      showId: _text(data, 'show_id'),
      showTitle: _text(data, 'show_title'),
      showAuthor: _optionalText(data, 'show_author'),
      title: _text(data, 'title'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      durationSeconds: _count(data['duration_seconds']),
      audioUrl: _optionalText(data, 'audio_url'),
      niche: _optionalText(data, 'niche'),
      coins: data['coins'] == null ? null : _count(data['coins']),
      lockedUntil: until,
    );
  }

  final String id;
  final String showId;
  final String showTitle;
  final String? showAuthor;
  final String title;
  final String? artworkUrl;
  final int durationSeconds;
  final String? audioUrl;
  final String? niche;
  final int? coins;
  final DateTime? lockedUntil;

  Duration get duration => Duration(seconds: durationSeconds);

  bool get isLocked {
    final until = lockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  int get reward =>
      coins ??
      (durationSeconds < 600
          ? 1
          : durationSeconds < 1200
          ? 2
          : 3);
}

class EarnShowSection {
  const EarnShowSection(this.label, this.shows);
  final String? label;
  final List<EarnShow> shows;
}

class EarnCatalog {
  const EarnCatalog(this.shows, this.episodes);
  final List<EarnShow> shows;
  final List<EarnEpisode> episodes;

  List<EarnShowSection> get sections {
    final grouped = <String, List<EarnShow>>{};
    final loose = <EarnShow>[];
    for (final show in shows) {
      final niche = show.niche?.trim();
      if (niche == null || niche.isEmpty) {
        loose.add(show);
      } else {
        (grouped[niche] ??= []).add(show);
      }
    }
    if (grouped.isEmpty) {
      final shuffled = [...loose]..shuffle(_dailyRandom());
      return [EarnShowSection(null, shuffled)];
    }
    final names = grouped.keys.toList()..sort();
    final result = [
      for (final name in names) EarnShowSection(name, grouped[name]!),
    ];
    if (loose.isNotEmpty) {
      final shuffled = [...loose]..shuffle(_dailyRandom());
      result.add(EarnShowSection('More', shuffled));
    }
    return result;
  }

  List<EarnShow> get orderedShows => [
    for (final section in sections) ...section.shows,
  ];

  List<EarnEpisode> episodesForShow(String showId) =>
      episodes.where((episode) => episode.showId == showId).toList();

  EarnShow? showById(String id) {
    for (final show in shows) {
      if (show.id == id) return show;
    }
    return null;
  }

  EarnEpisode? episodeById(String id) {
    for (final episode in episodes) {
      if (episode.id == id) return episode;
    }
    return null;
  }
}

Random _dailyRandom() {
  final now = DateTime.now().toUtc();
  return Random(now.year * 1000 + now.month * 50 + now.day);
}

class EarnAccess {
  const EarnAccess({required this.allowed, required this.country});

  factory EarnAccess.fromApi(Map<String, dynamic> data) {
    final allowed = data['allowed'];
    if (allowed is! bool) throw _invalidCatalog;
    final country = data['country'];
    if (country != null && (country is! String || country.length != 2)) {
      throw _invalidCatalog;
    }
    return EarnAccess(allowed: allowed, country: country as String?);
  }

  final bool allowed;
  final String? country;
}

class EarnSessionStart {
  const EarnSessionStart({
    required this.id,
    required this.episodeId,
    required this.expectedAward,
    required this.nonce,
    required this.lockHours,
    this.resumePosition,
    this.lastSequence,
  });

  factory EarnSessionStart.fromApi(Map<String, dynamic> data) {
    final nonce = _text(data, 'nonce');
    if (nonce.length != 64) throw _invalidCatalog;
    return EarnSessionStart(
      id: _text(data, 'id'),
      episodeId: _text(data, 'episode_id'),
      expectedAward: _positiveInt(data['expected_award']),
      nonce: nonce,
      lockHours: _positiveInt(data['lock_hours']),
      resumePosition: _optionalCount(data['resume_position']),
      lastSequence: _optionalCount(data['last_sequence']),
    );
  }

  final String id;
  final String episodeId;
  final int expectedAward;
  final String nonce;
  final int lockHours;
  final int? resumePosition;
  final int? lastSequence;
}

class EarnAward {
  const EarnAward({
    required this.id,
    required this.episodeId,
    required this.coins,
    required this.lockedUntil,
  });

  factory EarnAward.fromApi(Map<String, dynamic> data) {
    final coins = _count(data['coins']);
    final until = DateTime.tryParse('${data['locked_until'] ?? ''}');
    if (until == null) throw _invalidCatalog;
    return EarnAward(
      id: _text(data, 'id'),
      episodeId: _text(data, 'episode_id'),
      coins: coins,
      lockedUntil: until,
    );
  }

  final String id;
  final String episodeId;
  final int coins;
  final DateTime lockedUntil;
}

class EarnHeartbeatResult {
  const EarnHeartbeatResult({
    required this.verifiedSeconds,
    required this.requiredSeconds,
    this.award,
  });

  factory EarnHeartbeatResult.fromApi(Map<String, dynamic> data) {
    if (data['accepted'] != true) throw _invalidCatalog;
    final rawAward = data['award'];
    return EarnHeartbeatResult(
      verifiedSeconds: _optionalCount(data['verified_seconds']),
      requiredSeconds: _optionalCount(data['required_seconds']),
      award:
          rawAward is Map
              ? EarnAward.fromApi(Map<String, dynamic>.from(rawAward))
              : null,
    );
  }

  /// Null when talking to an older API during a rolling deployment.
  final int? verifiedSeconds;
  final int? requiredSeconds;
  final EarnAward? award;
}

class EarnPage<T> {
  const EarnPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.hasMore,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  final bool hasMore;

  bool get hasPrevious => page > 1;
}

EarnPage<T> _earnPage<T>(
  Map<String, dynamic>? body,
  T Function(Map<String, dynamic> data) parse,
) {
  final rows = _maps(body).map(parse).toList();
  final meta = body?['meta'];
  final map =
      meta is Map ? Map<String, dynamic>.from(meta) : const <String, dynamic>{};
  int number(Object? value, int fallback) {
    if (value is int && value > 0) return value;
    final parsed = int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  final page = number(map['page'], 1);
  final lastPage = number(map['last_page'], page);
  return EarnPage(
    items: rows,
    page: page,
    lastPage: lastPage < page ? page : lastPage,
    total: number(map['total'], rows.length),
    hasMore: map['has_more'] == true,
  );
}

class EarnCatalogRepository {
  EarnCatalogRepository(this._dio);
  final Dio _dio;

  Future<EarnAccess> access({CancelToken? token}) async {
    try {
      return EarnAccess.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/earn/access',
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

  Future<EarnCatalog> catalog({String? showId, CancelToken? token}) async {
    try {
      final showsBody =
          (await _dio.get<Map<String, dynamic>>(
            '/earn/shows',
            cancelToken: token,
          )).data;
      final episodesBody =
          (await _dio.get<Map<String, dynamic>>(
            '/earn/episodes',
            queryParameters: {if (showId != null) 'show_id': showId},
            cancelToken: token,
          )).data;
      final shows = _maps(showsBody).map(EarnShow.fromApi).toList();
      final episodes = _maps(episodesBody).map(EarnEpisode.fromApi).toList();
      if (shows.map((show) => show.id).toSet().length != shows.length ||
          episodes.map((episode) => episode.id).toSet().length !=
              episodes.length) {
        throw _invalidCatalog;
      }
      return EarnCatalog(shows, episodes);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnPage<EarnShow>> shows({
    String? query,
    int page = 1,
    CancelToken? token,
  }) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/earn/shows',
            queryParameters: {
              'page': page,
              'per_page': 10,
              if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            },
            cancelToken: token,
          )).data;
      return _earnPage(body, EarnShow.fromApi);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnPage<EarnEpisode>> episodes({
    String? showId,
    String? query,
    int page = 1,
    CancelToken? token,
  }) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/earn/episodes',
            queryParameters: {
              'page': page,
              'per_page': 10,
              if (showId != null) 'show_id': showId,
              if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            },
            cancelToken: token,
          )).data;
      return _earnPage(body, EarnEpisode.fromApi);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnSessionStart> start(String episodeId, {CancelToken? token}) async {
    try {
      return EarnSessionStart.fromApi(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/earn/episodes/$episodeId/sessions',
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

  Future<EarnHeartbeatResult> heartbeat({
    required String sessionId,
    required int position,
    required int sequence,
    required int elapsedSeconds,
    required int mediaDurationSeconds,
    required String nonce,
    required String integrityToken,
    bool foreground = true,
    bool audioActive = true,
    CancelToken? token,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/earn/sessions/$sessionId/heartbeat',
          data: {
            'position': position,
            'sequence': sequence,
            'elapsed_seconds': elapsedSeconds,
            'media_duration_seconds': mediaDurationSeconds,
            'playback_rate': 1,
            'foreground': foreground,
            'audio_active': audioActive,
            'integrity_token': integrityToken,
            'nonce': nonce,
          },
          cancelToken: token,
        )).data,
      );
      return EarnHeartbeatResult.fromApi(data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnAward> complete({
    required String sessionId,
    required String idempotencyKey,
    CancelToken? token,
  }) async {
    try {
      return EarnAward.fromApi(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/earn/sessions/$sessionId/complete',
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
}

final earnCatalogRepositoryProvider = Provider(
  (ref) => EarnCatalogRepository(ref.watch(dioProvider)),
);

final earnAccessProvider = FutureProvider<EarnAccess>((ref) {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(earnCatalogRepositoryProvider).access(token: token);
}, retry: (count, error) => null);

final earnCatalogProvider = FutureProvider<EarnCatalog>((ref) {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(earnCatalogRepositoryProvider).catalog(token: token);
}, retry: (count, error) => null);

class SelectedEarnEpisodeNotifier extends Notifier<EarnEpisode?> {
  @override
  EarnEpisode? build() => null;
  void select(EarnEpisode? episode) => state = episode;
}

final selectedEarnEpisodeProvider =
    NotifierProvider<SelectedEarnEpisodeNotifier, EarnEpisode?>(
      SelectedEarnEpisodeNotifier.new,
    );

ApiFailure earnFailure(Object error) => profileFailure(error);
