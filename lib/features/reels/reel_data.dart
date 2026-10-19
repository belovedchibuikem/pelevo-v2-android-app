import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/player/play_location.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/reels/reels_monetization_service.dart';

const _invalidReel = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Reel data could not be verified. Please retry.',
);

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String && RegExp(r'^\d+$').hasMatch(value)) {
    return int.parse(value);
  }
  throw _invalidReel;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  return _count(value);
}

bool _flag(Object? value) {
  if (value is bool) return value;
  if (value == 1 || value == '1') return true;
  if (value == 0 || value == '0') return false;
  throw _invalidReel;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidReel;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidReel;
  return value as String?;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidReel;
  }
  final data = body['data'];
  if (data is! List) {
    throw _invalidReel;
  }
  final rows = <Map<String, dynamic>>[];
  for (final row in data) {
    if (row is! Map) {
      throw _invalidReel;
    }
    rows.add(Map<String, dynamic>.from(row));
  }
  return rows;
}

bool _httpUrl(String? value) =>
    value != null &&
    (value.startsWith('http://') || value.startsWith('https://'));

enum ReelsFeedKind { forYou, following, trending }

class ReelAdDue {
  const ReelAdDue({
    required this.impressionId,
    required this.expiresAt,
    required this.adUnitKey,
  });

  factory ReelAdDue.fromApi(Map<String, dynamic> data) => ReelAdDue(
    impressionId: _text(data, 'ad_impression_id'),
    expiresAt: DateTime.parse(_text(data, 'expires_at')),
    adUnitKey: _text(data, 'ad_unit_key'),
  );

  final String impressionId;
  final DateTime expiresAt;
  final String adUnitKey;
}

class ReelHeartbeatResult {
  const ReelHeartbeatResult({
    required this.serverWatchedMs,
    required this.isValidView,
    this.adDue,
  });

  final int serverWatchedMs;
  final bool isValidView;
  final ReelAdDue? adDue;
}

class PublishedReel {
  const PublishedReel({
    required this.id,
    required this.creatorProfileId,
    required this.creatorName,
    required this.creatorHandle,
    required this.likesCount,
    required this.commentsCount,
    required this.savesCount,
    this.viewsCount = 0,
    required this.liked,
    required this.saved,
    required this.following,
    this.caption,
    this.title,
    this.mediaUrl,
    this.thumbnailPath,
    this.creatorAvatarUrl,
    this.durationMs,
    this.publishedAt,
    this.showId,
    this.episodeId,
    this.episodeTitle,
    this.showTitle,
    this.showArtworkUrl,
    this.episodeDurationSeconds,
  });

  factory PublishedReel.fromApi(Map<String, dynamic> data) {
    return PublishedReel(
      id: _text(data, 'id'),
      creatorProfileId: _text(data, 'creator_profile_id'),
      creatorName: _text(data, 'creator_name'),
      creatorHandle: _optionalText(data, 'creator_handle') ?? '',
      caption:
          _optionalText(data, 'caption') ?? _optionalText(data, 'description'),
      title: _optionalText(data, 'title'),
      mediaUrl: _optionalText(data, 'media_url'),
      thumbnailPath: _optionalText(data, 'thumbnail_path'),
      durationMs: _optionalCount(data['duration_ms']),
      publishedAt: _optionalText(data, 'published_at'),
      showId: data['show_id'] == null ? null : '${data['show_id']}',
      episodeId: data['episode_id'] == null ? null : '${data['episode_id']}',
      episodeTitle: _optionalText(data, 'episode_title'),
      showTitle: _optionalText(data, 'show_title'),
      showArtworkUrl: _optionalText(data, 'show_artwork_url'),
      episodeDurationSeconds: _optionalCount(data['episode_duration_seconds']),
      likesCount: _count(data['likes_count']),
      commentsCount: _count(data['comments_count']),
      savesCount: _count(data['saves_count']),
      viewsCount: _optionalCount(data['views_count']) ?? 0,
      liked: _flag(data['liked']),
      saved: _flag(data['saved']),
      following: _flag(data['following']),
      creatorAvatarUrl: _optionalText(data, 'creator_avatar_url'),
    );
  }

  final String id;
  final String creatorProfileId;
  final String creatorName;
  final String creatorHandle;
  final String? caption;
  final String? title;
  final String? mediaUrl;
  final String? thumbnailPath;
  final String? creatorAvatarUrl;
  final int? durationMs;
  final String? publishedAt;
  final String? showId;
  final String? episodeId;
  final String? episodeTitle;
  final String? showTitle;
  final String? showArtworkUrl;
  final int? episodeDurationSeconds;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final int viewsCount;
  final bool liked;
  final bool saved;
  final bool following;

  String get viewsLabel => '$viewsCount ${viewsCount == 1 ? 'view' : 'views'}';

  String get captionText => caption?.trim() ?? '';

  String get titleText => title?.trim() ?? '';

  String get handleLabel {
    final handle = creatorHandle.trim();
    if (handle.isEmpty) return '';
    return handle.startsWith('@') ? handle : '@$handle';
  }

  String? get imageUrl {
    for (final value in [thumbnailPath, mediaUrl, creatorAvatarUrl]) {
      if (_httpUrl(value)) return value;
    }
    return null;
  }

  String? get creatorImageUrl {
    if (_httpUrl(creatorAvatarUrl)) return creatorAvatarUrl;
    return imageUrl;
  }

  bool get hasLinkedEpisode =>
      (episodeId != null && episodeId!.isNotEmpty) ||
      (episodeTitle != null && episodeTitle!.trim().isNotEmpty);

  String get linkedChipLabel {
    final title = episodeTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'Linked episode';
  }

  String get linkedShowLabel {
    final title = showTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'Podcast';
  }

  String get linkedDurationLabel {
    final seconds = episodeDurationSeconds;
    if (seconds == null || seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  PublishedReel copyWith({
    int? likesCount,
    int? commentsCount,
    int? savesCount,
    bool? liked,
    bool? saved,
    bool? following,
  }) => PublishedReel(
    id: id,
    creatorProfileId: creatorProfileId,
    creatorName: creatorName,
    creatorHandle: creatorHandle,
    title: title,
    caption: caption,
    mediaUrl: mediaUrl,
    thumbnailPath: thumbnailPath,
    creatorAvatarUrl: creatorAvatarUrl,
    durationMs: durationMs,
    publishedAt: publishedAt,
    showId: showId,
    episodeId: episodeId,
    episodeTitle: episodeTitle,
    showTitle: showTitle,
    showArtworkUrl: showArtworkUrl,
    episodeDurationSeconds: episodeDurationSeconds,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    savesCount: savesCount ?? this.savesCount,
    viewsCount: viewsCount,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    following: following ?? this.following,
  );
}

class PublicCreatorShow {
  const PublicCreatorShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
  });

  factory PublicCreatorShow.fromApi(Map<String, dynamic> data) {
    return PublicCreatorShow(
      id: _text(data, 'id'),
      title: _text(data, 'title'),
      author: _optionalText(data, 'author'),
      artworkUrl: _optionalText(data, 'artwork_url'),
    );
  }

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
}

class PublicCreatorProfile {
  const PublicCreatorProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.verified,
    required this.isSelf,
    required this.following,
    required this.followers,
    required this.followingCount,
    required this.reelsCount,
    required this.podcastsCount,
    required this.shows,
    this.bio,
    this.avatarUrl,
  });

  factory PublicCreatorProfile.fromApi(Map<String, dynamic> data) {
    final stats = data['stats'];
    final shows = data['shows'];
    if (stats is! Map<String, dynamic> ||
        shows is! List ||
        shows.any((row) => row is! Map<String, dynamic>)) {
      throw _invalidReel;
    }
    return PublicCreatorProfile(
      id: _text(data, 'id'),
      displayName: _text(data, 'display_name'),
      handle: _optionalText(data, 'handle') ?? '',
      bio: _optionalText(data, 'bio'),
      avatarUrl: _optionalText(data, 'avatar_url'),
      verified: _flag(data['verified']),
      isSelf: _flag(data['is_self']),
      following: _flag(data['following']),
      followers: _count(stats['followers']),
      followingCount: _count(stats['following']),
      reelsCount: _count(stats['reels']),
      podcastsCount: _count(stats['podcasts']),
      shows: shows
          .whereType<Map<String, dynamic>>()
          .map(PublicCreatorShow.fromApi)
          .toList(growable: false),
    );
  }

  final String id;
  final String displayName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final bool verified;
  final bool isSelf;
  final bool following;
  final int followers;
  final int followingCount;
  final int reelsCount;
  final int podcastsCount;
  final List<PublicCreatorShow> shows;

  String get handleLabel {
    final value = handle.trim();
    if (value.isEmpty) return '';
    return value.startsWith('@') ? value : '@$value';
  }
}

class ReelDraftRecord {
  const ReelDraftRecord({
    required this.id,
    this.caption,
    this.title,
    this.state,
    this.showId,
    this.episodeId,
    this.durationMs,
    this.updatedAt,
  });

  factory ReelDraftRecord.fromApi(Map<String, dynamic> data) {
    return ReelDraftRecord(
      id: _text(data, 'id'),
      caption: _optionalText(data, 'caption'),
      title: _optionalText(data, 'title'),
      state: _optionalText(data, 'state'),
      showId: data['show_id'] == null ? null : '${data['show_id']}',
      episodeId: data['episode_id'] == null ? null : '${data['episode_id']}',
      durationMs: _optionalCount(data['duration_ms']),
      updatedAt: _optionalText(data, 'updated_at'),
    );
  }

  final String id;
  final String? caption;
  final String? title;
  final String? state;
  final String? showId;
  final String? episodeId;
  final int? durationMs;
  final String? updatedAt;

  String get displayTitle {
    final named = title?.trim();
    if (named != null && named.isNotEmpty) return named;
    final value = caption?.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Draft';
  }
}

class ReelRelatedShow {
  const ReelRelatedShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
  });

  factory ReelRelatedShow.fromApi(Map<String, dynamic> data) {
    return ReelRelatedShow(
      id: _text(data, 'id'),
      title: _text(data, 'title'),
      author: _optionalText(data, 'author'),
      artworkUrl: _optionalText(data, 'artwork_url'),
    );
  }

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
}

class ReelMonetizationProfile {
  const ReelMonetizationProfile({
    required this.creatorProfileId,
    required this.eligible,
    required this.optedIn,
    required this.followers,
    required this.qualifiedViews,
    required this.minFollowers,
    required this.minViews,
    this.evaluatedAt,
    this.optedInAt,
  });

  factory ReelMonetizationProfile.fromApi(Map<String, dynamic> data) {
    return ReelMonetizationProfile(
      creatorProfileId: _text(data, 'creator_profile_id'),
      eligible: _flag(data['eligible']),
      optedIn: _flag(data['opted_in']),
      followers: _count(data['followers']),
      qualifiedViews: _count(data['qualified_views']),
      minFollowers: _count(data['min_followers']),
      minViews: _count(data['min_views']),
      evaluatedAt: _optionalText(data, 'evaluated_at'),
      optedInAt: _optionalText(data, 'opted_in_at'),
    );
  }

  final String creatorProfileId;
  final bool eligible;
  final bool optedIn;
  final int followers;
  final int qualifiedViews;
  final int minFollowers;
  final int minViews;
  final String? evaluatedAt;
  final String? optedInAt;

  ReelsMonetizationStage get stage {
    if (optedIn) return ReelsMonetizationStage.monetized;
    if (eligible) return ReelsMonetizationStage.eligible;
    return ReelsMonetizationStage.progressing;
  }

  double get followersProgress =>
      minFollowers <= 0 ? 1 : (followers / minFollowers).clamp(0.0, 1.0);

  double get viewsProgress =>
      minViews <= 0 ? 1 : (qualifiedViews / minViews).clamp(0.0, 1.0);

  bool get followersMet => followers >= minFollowers;
  bool get viewsMet => qualifiedViews >= minViews;

  String get followersLabel => '$followers / $minFollowers';
  String get viewsLabel => '$qualifiedViews / $minViews';
}

class ReelRepository {
  const ReelRepository(this._dio);
  final Dio _dio;

  Future<List<PublishedReel>> feed(ReelsFeedKind kind, {int? limit}) async {
    final path = switch (kind) {
      ReelsFeedKind.forYou => '/reels/for-you',
      ReelsFeedKind.following => '/reels/following',
      ReelsFeedKind.trending => '/reels/trending',
    };
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: {if (limit != null) 'limit': limit},
        )).data,
      ).map(PublishedReel.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PublishedReel> reel(String id) async {
    try {
      return PublishedReel.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/reels/${Uri.encodeComponent(id)}',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<PublishedReel>> savedReels() async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>('/reels/saved')).data,
      ).map(PublishedReel.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<ReelDraftRecord>> drafts() async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>('/reels/drafts')).data,
      ).map(ReelDraftRecord.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ReelDraftRecord> saveDraft({
    String? id,
    String? title,
    String? caption,
    String? episodeId,
    String? showId,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (title != null) 'title': title,
        if (caption != null) 'caption': caption,
        if (episodeId != null) 'episode_id': episodeId,
        if (showId != null) 'show_id': showId,
      };
      final response =
          id == null
              ? await _dio.post<Map<String, dynamic>>(
                '/reels/drafts',
                data: payload,
              )
              : await _dio.patch<Map<String, dynamic>>(
                '/reels/drafts/$id',
                data: payload,
              );
      return ReelDraftRecord.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> deleteDraft(String id) async {
    try {
      requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/reels/drafts/$id')).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> deleteReel(String id) async {
    try {
      requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/reels/$id')).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ReelMonetizationProfile> monetization() async {
    try {
      return ReelMonetizationProfile.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/reels/monetization')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ReelMonetizationProfile> optIn() async {
    try {
      return ReelMonetizationProfile.fromApi(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/reels/monetization/opt-in',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> like(String id, {required bool liked}) async {
    try {
      requireApiData(
        (await (liked
                ? _dio.post<Map<String, dynamic>>('/reels/$id/like')
                : _dio.delete<Map<String, dynamic>>('/reels/$id/like')))
            .data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> save(String id, {required bool saved}) async {
    try {
      requireApiData(
        (await (saved
                ? _dio.post<Map<String, dynamic>>('/reels/$id/save')
                : _dio.delete<Map<String, dynamic>>('/reels/$id/save')))
            .data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> notInterested(String id) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels/$id/not-interested',
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ReelHeartbeatResult> heartbeat(
    String id, {
    required String sessionId,
    required String feedSessionId,
    required int sequence,
    required int playbackPositionMs,
    required bool completed,
    required bool appForeground,
    required bool audible,
    required bool adEligible,
  }) async {
    try {
      final location = await PlayLocation.instance.fields();
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels/$id/view-heartbeat',
          data: {
            'session_id': sessionId,
            'feed_session_id': feedSessionId,
            'sequence': sequence,
            'playback_position_ms': playbackPositionMs,
            'completed': completed,
            'app_foreground': appForeground,
            'audible': audible,
            'ad_eligible': adEligible,
            if (location.isNotEmpty) 'location': location,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        )).data,
      );
      final due = data['ad_due'];
      return ReelHeartbeatResult(
        serverWatchedMs: _count(data['server_watched_ms']),
        isValidView: _flag(data['is_valid_view']),
        adDue:
            due is Map
                ? ReelAdDue.fromApi(Map<String, dynamic>.from(due))
                : null,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> confirmAdImpression(
    ReelAdDue due, {
    required String feedSessionId,
    required String clientEventId,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels/ad-impressions/${due.impressionId}/watched',
          data: {
            'feed_session_id': feedSessionId,
            'client_event_id': clientEventId,
          },
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> bounceAdImpression(
    ReelAdDue due, {
    required String feedSessionId,
    required String reason,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels/ad-impressions/${due.impressionId}/bounce',
          data: {'feed_session_id': feedSessionId, 'reason': reason},
        )).data,
      );
    } on Object {
      // Bounce is best-effort; the server expiry job remains authoritative.
    }
  }

  Future<void> recordAdPaidEstimate(
    ReelAdDue due, {
    required int valueMicros,
    required String currencyCode,
    required String precision,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels/ad-impressions/${due.impressionId}/paid',
          data: {
            'value_micros': valueMicros,
            'currency_code': currencyCode,
            'precision': precision,
          },
        )).data,
      );
    } on Object {
      // Estimated paid events are telemetry only.
    }
  }

  Future<void> followCreator(
    String creatorProfileId, {
    required bool follow,
  }) async {
    try {
      requireApiData(
        (await (follow
                ? _dio.post<Map<String, dynamic>>(
                  '/creators/$creatorProfileId/follow',
                )
                : _dio.delete<Map<String, dynamic>>(
                  '/creators/$creatorProfileId/follow',
                )))
            .data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PublicCreatorProfile> creatorProfile(String creatorProfileId) async {
    try {
      return PublicCreatorProfile.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/creators/$creatorProfileId',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<PublishedReel>> creatorReels(String creatorProfileId) async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>(
          '/creators/$creatorProfileId/reels',
          queryParameters: {'limit': 50},
        )).data,
      ).map(PublishedReel.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ReelRelatedShow> relatedShow(String reelId) async {
    try {
      return ReelRelatedShow.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/reels/$reelId/related-show',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> report({
    required String reelId,
    required String reason,
    String? details,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'reportable_type': 'reel',
            'reportable_id': reelId,
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
}

final reelRepositoryProvider = Provider<ReelRepository>(
  (ref) => ReelRepository(ref.watch(dioProvider)),
);

final reelsFeedProvider = FutureProvider.autoDispose
    .family<List<PublishedReel>, ReelsFeedKind>((ref, kind) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(reelRepositoryProvider).feed(kind);
    }, retry: (count, error) => null);

final reelByIdProvider = FutureProvider.autoDispose
    .family<PublishedReel, String>((ref, id) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(reelRepositoryProvider).reel(id);
    }, retry: (count, error) => null);

final savedReelsProvider = FutureProvider.autoDispose<List<PublishedReel>>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(reelRepositoryProvider).savedReels();
}, retry: (count, error) => null);

class SelectedCreatorProfileIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

class SelectedCreatorReelIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedCreatorProfileIdProvider =
    NotifierProvider<SelectedCreatorProfileIdNotifier, String?>(
      SelectedCreatorProfileIdNotifier.new,
    );

final selectedCreatorReelIdProvider =
    NotifierProvider<SelectedCreatorReelIdNotifier, String?>(
      SelectedCreatorReelIdNotifier.new,
    );

final publicCreatorProfileProvider = FutureProvider.autoDispose
    .family<PublicCreatorProfile, String>((ref, id) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(reelRepositoryProvider).creatorProfile(id);
    }, retry: (count, error) => null);

final publicCreatorReelsProvider = FutureProvider.autoDispose
    .family<List<PublishedReel>, String>((ref, id) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(reelRepositoryProvider).creatorReels(id);
    }, retry: (count, error) => null);

final reelDraftsProvider = FutureProvider.autoDispose<List<ReelDraftRecord>>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(reelRepositoryProvider).drafts();
}, retry: (count, error) => null);

final reelsMonetizationProvider =
    FutureProvider.autoDispose<ReelMonetizationProfile>((ref) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(reelRepositoryProvider).monetization();
    }, retry: (count, error) => null);

class EditingReelDraftNotifier extends Notifier<ReelDraftRecord?> {
  @override
  ReelDraftRecord? build() => null;

  void select(ReelDraftRecord? value) => state = value;
}

final editingReelDraftProvider =
    NotifierProvider<EditingReelDraftNotifier, ReelDraftRecord?>(
      EditingReelDraftNotifier.new,
    );

ApiFailure reelFailure(Object error) => profileFailure(error);

String newReelViewSessionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-${hex(8)}${hex(9)}-${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

/// Prevents view-heartbeat floods. After 3s of playback the old gate sent
/// a POST on every progress tick (~4/sec), which filled nginx workers.
final class ReelHeartbeatGate {
  static const intervalMs = 8000;

  final _lastMs = <String, int>{};
  final _inflight = <String>{};
  final _sequences = <String, int>{};
  final _completionSent = <String>{};
  final sessions = <String, String>{};
  final String feedSessionId = newReelViewSessionId();

  bool allow(String reelId, int watchedMs, {bool completed = false}) {
    if (_inflight.contains(reelId)) return false;
    if (completed && _completionSent.contains(reelId)) return false;
    final last = _lastMs[reelId];
    if (!completed && last != null && watchedMs - last < intervalMs) {
      return false;
    }
    _lastMs[reelId] = watchedMs;
    if (completed) _completionSent.add(reelId);
    _inflight.add(reelId);
    sessions.putIfAbsent(reelId, newReelViewSessionId);
    return true;
  }

  void done(String reelId) => _inflight.remove(reelId);

  int nextSequence(String reelId) {
    final next = (_sequences[reelId] ?? 0) + 1;
    _sequences[reelId] = next;
    return next;
  }
}
