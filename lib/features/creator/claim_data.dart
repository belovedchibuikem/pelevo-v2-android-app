import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

const _invalidClaim = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Claim details could not be loaded. Please try again.',
);

class ClaimShow {
  const ClaimShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
    this.description,
    this.episodeCount,
    this.claimedByViewer = false,
  });

  factory ClaimShow.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.trim().isEmpty) {
      throw _invalidClaim;
    }
    return ClaimShow(
      id: '$id',
      title: '${json['title'] ?? ''}',
      author: json['author'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      description: json['description'] as String?,
      episodeCount: (json['episodes_count'] as num?)?.toInt(),
      claimedByViewer: json['claimed_by_viewer'] == true,
    );
  }

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
  final String? description;
  final int? episodeCount;
  final bool claimedByViewer;
}

class ClaimEpisode {
  const ClaimEpisode({
    required this.id,
    required this.title,
    this.publishedAt,
    this.artworkUrl,
  });

  factory ClaimEpisode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.trim().isEmpty) {
      throw _invalidClaim;
    }
    return ClaimEpisode(
      id: '$id',
      title: '${json['title'] ?? ''}',
      publishedAt: json['published_at'] as String?,
      artworkUrl: json['artwork_url'] as String?,
    );
  }

  final String id;
  final String title;
  final String? publishedAt;
  final String? artworkUrl;
}

class ClaimStart {
  const ClaimStart({
    required this.claimId,
    required this.state,
    required this.method,
    this.maskedDestination,
    this.challenge,
    this.expiresAt,
    this.challengeExpiresAt,
  });

  factory ClaimStart.fromApi(Map<String, dynamic> data, {required String method}) {
    final claimId = data['claim_id'];
    final state = data['state'];
    if (claimId is! String ||
        claimId.isEmpty ||
        state is! String ||
        state.isEmpty) {
      throw _invalidClaim;
    }
    return ClaimStart(
      claimId: claimId,
      state: state,
      method: method,
      maskedDestination: data['masked_destination'] as String?,
      challenge: data['challenge'] as String?,
      expiresAt: data['expires_at'] as String?,
      challengeExpiresAt: data['challenge_expires_at'] as String?,
    );
  }

  final String claimId;
  final String state;
  final String method;
  final String? maskedDestination;
  final String? challenge;
  final String? expiresAt;
  final String? challengeExpiresAt;
}

class ClaimStatus {
  const ClaimStatus({
    required this.id,
    required this.showId,
    required this.method,
    required this.state,
    this.destinationMasked,
    this.attempts,
    this.maxAttempts,
    this.challengeExpiresAt,
    this.decisionReason,
  });

  factory ClaimStatus.fromApi(Map<String, dynamic> data) {
    final id = data['id'];
    final showId = data['show_id'];
    final method = data['method'];
    final state = data['state'];
    if (id == null ||
        '$id'.isEmpty ||
        showId == null ||
        '$showId'.isEmpty ||
        method is! String ||
        state is! String) {
      throw _invalidClaim;
    }
    return ClaimStatus(
      id: '$id',
      showId: '$showId',
      method: method,
      state: state,
      destinationMasked: data['destination_masked'] as String?,
      attempts: (data['attempts'] as num?)?.toInt(),
      maxAttempts: (data['max_attempts'] as num?)?.toInt(),
      challengeExpiresAt: data['challenge_expires_at'] as String?,
      decisionReason: data['decision_reason'] as String?,
    );
  }

  final String id;
  final String showId;
  final String method;
  final String state;
  final String? destinationMasked;
  final int? attempts;
  final int? maxAttempts;
  final String? challengeExpiresAt;
  final String? decisionReason;

  bool get isVerified => state == 'verified';
  bool get isFailed =>
      state == 'rejected' || state == 'expired' || state == 'disputed';
  bool get isInReview =>
      state == 'review' || state == 'verifying' || state == 'pending';
}

class ClaimSummary {
  const ClaimSummary({
    required this.id,
    required this.showId,
    required this.method,
    required this.state,
    required this.showTitle,
    this.showAuthor,
    this.showArtworkUrl,
    this.decisionReason,
    this.challenge,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  factory ClaimSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final showId = json['show_id'];
    if (id == null || '$id'.isEmpty || showId == null || '$showId'.isEmpty) {
      throw _invalidClaim;
    }
    return ClaimSummary(
      id: '$id',
      showId: '$showId',
      method: '${json['method'] ?? 'description'}',
      state: '${json['state'] ?? 'pending'}',
      showTitle: '${json['show_title'] ?? ''}',
      showAuthor: json['show_author'] as String?,
      showArtworkUrl: json['show_artwork_url'] as String?,
      decisionReason: json['decision_reason'] as String?,
      challenge: json['challenge'] as String?,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      expiresAt: json['expires_at'] as String?,
    );
  }

  final String id;
  final String showId;
  final String method;
  final String state;
  final String showTitle;
  final String? showAuthor;
  final String? showArtworkUrl;
  final String? decisionReason;
  final String? challenge;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? expiresAt;

  bool get isVerified => state == 'verified';
  bool get isFailed =>
      state == 'rejected' || state == 'expired' || state == 'disputed';
  bool get isInReview => state == 'review' || state == 'verifying';
  bool get needsAction => state == 'pending';

  bool get canDelete => !isVerified;

  String get stateLabel => switch (state) {
    'verified' => 'Approved',
    'review' => 'Under manual review',
    'verifying' => 'Checking your RSS feed',
    'pending' =>
      method == 'description'
          ? 'Code not found yet — action needed'
          : 'Waiting for email code',
    'rejected' => 'Not approved',
    'expired' => 'Expired',
    'disputed' => 'Disputed',
    _ => state,
  };

  ClaimShow get show => ClaimShow(
    id: showId,
    title: showTitle,
    author: showAuthor,
    artworkUrl: showArtworkUrl,
  );

  ClaimStart get start => ClaimStart(
    claimId: id,
    state: state,
    method: method,
    challenge: challenge,
    expiresAt: expiresAt,
  );

  ClaimStatus get status => ClaimStatus(
    id: id,
    showId: showId,
    method: method,
    state: state,
    decisionReason: decisionReason,
  );
}

class ClaimDraft {
  const ClaimDraft({this.show, this.start, this.status});

  final ClaimShow? show;
  final ClaimStart? start;
  final ClaimStatus? status;

  ClaimDraft copyWith({
    ClaimShow? show,
    ClaimStart? start,
    ClaimStatus? status,
    bool clearStart = false,
    bool clearStatus = false,
  }) => ClaimDraft(
    show: show ?? this.show,
    start: clearStart ? null : (start ?? this.start),
    status: clearStatus ? null : (status ?? this.status),
  );
}

class ClaimDraftNotifier extends Notifier<ClaimDraft> {
  @override
  ClaimDraft build() => const ClaimDraft();

  void selectShow(ClaimShow show) {
    state = ClaimDraft(show: show);
  }

  void rememberStart(ClaimStart start) {
    state = state.copyWith(start: start, clearStatus: true);
  }

  void rememberStatus(ClaimStatus status) {
    state = state.copyWith(status: status);
  }

  void resume(ClaimSummary claim) {
    state = ClaimDraft(
      show: claim.show,
      start: claim.start,
      status: claim.status,
    );
  }
}

class ClaimRepository {
  const ClaimRepository(this._dio);

  final Dio _dio;

  Future<List<ClaimShow>> searchShows(String query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {
        'q': query.trim(),
        'limit': 12,
        'type': 'show',
      },
    );
    final data = requireApiData(response.data);
    final shows = data['shows'];
    if (shows is! List) {
      throw _invalidClaim;
    }
    return shows
        .whereType<Map<String, dynamic>>()
        .map(ClaimShow.fromJson)
        .toList(growable: false);
  }

  Future<ClaimShow> fetchShow(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/shows/${Uri.encodeComponent(id)}',
    );
    return ClaimShow.fromJson(requireApiData(response.data));
  }

  Future<List<ClaimEpisode>> episodes(String showId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/shows/${Uri.encodeComponent(showId)}/episodes',
      queryParameters: {'limit': 2},
    );
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw _invalidClaim;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidClaim;
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ClaimEpisode.fromJson)
        .toList(growable: false);
  }

  Future<ClaimStart> startClaim({
    required String showId,
    required String method,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shows/${Uri.encodeComponent(showId)}/claims',
      data: {'method': method},
    );
    return ClaimStart.fromApi(requireApiData(response.data), method: method);
  }

  Future<List<ClaimSummary>> listClaims() async {
    final response = await _dio.get<Map<String, dynamic>>('/claims');
    final body = response.data;
    if (body == null || body['ok'] != true || body['data'] is! List) {
      throw _invalidClaim;
    }
    return (body['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ClaimSummary.fromJson)
        .toList(growable: false);
  }

  Future<void> deleteClaim(String claimId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/claims/${Uri.encodeComponent(claimId)}',
    );
    requireApiData(response.data);
  }

  Future<ClaimStatus> readClaim(String claimId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/claims/${Uri.encodeComponent(claimId)}',
    );
    return ClaimStatus.fromApi(requireApiData(response.data));
  }

  Future<ClaimStart> verify({
    required String claimId,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/claims/${Uri.encodeComponent(claimId)}/verify',
      data: {'code': code},
    );
    return ClaimStart.fromApi(requireApiData(response.data), method: 'email');
  }

  Future<ClaimStart> resend(String claimId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/claims/${Uri.encodeComponent(claimId)}/challenge',
    );
    final data = requireApiData(response.data);
    return ClaimStart(
      claimId: '${data['claim_id'] ?? claimId}',
      state: 'pending',
      method: 'email',
      maskedDestination: data['masked_destination'] as String?,
      challengeExpiresAt: data['challenge_expires_at'] as String?,
    );
  }

  Future<ClaimStatus> confirmDescription(String claimId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/claims/${Uri.encodeComponent(claimId)}/description/confirm',
    );
    final data = requireApiData(response.data);
    return ClaimStatus(
      id: '${data['claim_id'] ?? claimId}',
      showId: '',
      method: 'description',
      state: '${data['state'] ?? 'verifying'}',
    );
  }
}

final claimRepositoryProvider = Provider<ClaimRepository>(
  (ref) => ClaimRepository(ref.watch(dioProvider)),
);

final myClaimsProvider = FutureProvider.autoDispose<List<ClaimSummary>>(
  (ref) => ref.watch(claimRepositoryProvider).listClaims(),
);

final claimDraftProvider = NotifierProvider<ClaimDraftNotifier, ClaimDraft>(
  ClaimDraftNotifier.new,
);
