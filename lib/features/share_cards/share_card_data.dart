import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

const _invalidShareCard = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Share card details could not be verified. Please retry.',
);

const missingShareCard = ApiFailure(
  code: 'NO_SHARE_CARD',
  message: 'Select a share card first.',
);

const missingShareSubject = ApiFailure(
  code: 'NO_SHARE_SUBJECT',
  message: 'Choose an episode or show first.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidShareCard;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidShareCard;
  return value as String?;
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw _invalidShareCard;
}

DateTime _date(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) throw _invalidShareCard;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw _invalidShareCard;
  return parsed;
}

DateTime? _optionalDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String) throw _invalidShareCard;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw _invalidShareCard;
  return parsed;
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidShareCard;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _listBody(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidShareCard;
  }
  return _maps(body['data']);
}

const _subjectTypes = {'episode', 'reel', 'show'};
const _states = {'ready', 'scheduled'};
const _variants = {'qr', 'quote', 'minimal', 'show', 'playlist', 'stats'};

class ShareCardTemplate {
  const ShareCardTemplate({
    required this.id,
    required this.name,
    required this.version,
  });

  factory ShareCardTemplate.parse(Map<String, dynamic> data) =>
      ShareCardTemplate(
        id: _text(data, 'id'),
        name: _text(data, 'name'),
        version: _count(data['version']),
      );

  final String id, name;
  final int version;
}

class ShareCardEvent {
  const ShareCardEvent({
    required this.event,
    required this.createdAt,
    this.channel,
  });

  factory ShareCardEvent.parse(Map<String, dynamic> data) => ShareCardEvent(
    event: _text(data, 'event'),
    channel: _optionalText(data, 'channel'),
    createdAt: _date(data, 'created_at'),
  );

  final String event;
  final String? channel;
  final DateTime createdAt;
}

class ShareCard {
  const ShareCard({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.subjectType,
    required this.subjectId,
    required this.state,
    required this.createdAt,
    required this.url,
    this.scheduledAt,
    this.variant,
    this.quote,
    this.layout,
    this.events = const [],
  });

  factory ShareCard.parse(Map<String, dynamic> data) {
    final type = _text(data, 'subject_type');
    final state = _text(data, 'state');
    if (!_subjectTypes.contains(type) || !_states.contains(state)) {
      throw _invalidShareCard;
    }
    final variant = _optionalText(data, 'variant');
    if (variant != null && variant.isNotEmpty && !_variants.contains(variant)) {
      throw _invalidShareCard;
    }
    final events =
        data.containsKey('events')
            ? _maps(data['events'])
            : const <Map<String, dynamic>>[];
    return ShareCard(
      id: _text(data, 'id'),
      templateId: _text(data, 'template_id'),
      templateName: _text(data, 'template_name'),
      subjectType: type,
      subjectId: _text(data, 'subject_id'),
      state: state,
      createdAt: _date(data, 'created_at'),
      scheduledAt: _optionalDate(data, 'scheduled_at'),
      url: _text(data, 'url'),
      variant: variant,
      quote: _optionalText(data, 'quote'),
      layout: _optionalText(data, 'layout'),
      events: events.map(ShareCardEvent.parse).toList(growable: false),
    );
  }

  final String id, templateId, templateName, subjectType, subjectId, state, url;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final String? variant, quote, layout;
  final List<ShareCardEvent> events;

  String get title => (quote != null && quote!.isNotEmpty) ? quote! : subjectType;

  String get subtitle {
    final date = createdAt.toLocal();
    final stamp =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$subjectType · $state · $stamp';
  }

  int eventCount(String name) =>
      events.where((row) => row.event == name).length;
}

class ShareCardSubject {
  const ShareCardSubject({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.artworkUrl,
    this.showId,
  });

  final String type, id, title;
  final String? subtitle, artworkUrl, showId;

  bool get canPost => type == 'episode' || type == 'reel' || type == 'show';
}

class ShareCardRepository {
  ShareCardRepository(this._dio);
  final Dio _dio;

  Future<List<ShareCardTemplate>> templates(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/share-card-templates',
          cancelToken: token,
        )).data,
      ).map(ShareCardTemplate.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<ShareCard>> list(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/share-cards',
          cancelToken: token,
        )).data,
      ).map(ShareCard.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ShareCard> show(String id, CancelToken token) async {
    try {
      return ShareCard.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/share-cards/${Uri.encodeComponent(id)}',
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

  Future<ShareCard> create({
    required String templateId,
    required String subjectType,
    required String subjectId,
    required Map<String, String> payload,
    DateTime? scheduledAt,
  }) async {
    try {
      return ShareCard.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/share-cards',
            data: {
              'template_id': templateId,
              'subject_type': subjectType,
              'subject_id': subjectId,
              'payload': payload,
              if (scheduledAt != null)
                'scheduled_at': scheduledAt.toUtc().toIso8601String(),
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
}

final shareCardRepositoryProvider = Provider(
  (ref) => ShareCardRepository(ref.watch(dioProvider)),
);

final shareCardTemplatesProvider =
    FutureProvider.autoDispose<List<ShareCardTemplate>>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(shareCardRepositoryProvider).templates(token);
    }, retry: (count, error) => null);

final shareCardsProvider = FutureProvider.autoDispose<List<ShareCard>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(shareCardRepositoryProvider).list(token);
}, retry: (count, error) => null);

class SelectedShareCardIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedShareCardIdProvider =
    NotifierProvider<SelectedShareCardIdNotifier, String?>(
      SelectedShareCardIdNotifier.new,
    );

class LatestShareCardNotifier extends Notifier<ShareCard?> {
  @override
  ShareCard? build() => null;
  void select(ShareCard? card) => state = card;
}

final latestShareCardProvider =
    NotifierProvider<LatestShareCardNotifier, ShareCard?>(
      LatestShareCardNotifier.new,
    );

final shareCardProvider = FutureProvider.autoDispose<ShareCard>((ref) async {
  final id = ref.watch(selectedShareCardIdProvider);
  if (id == null || id.isEmpty) throw missingShareCard;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(shareCardRepositoryProvider).show(id, token);
}, retry: (count, error) => null);

class SelectedShareSubjectNotifier extends Notifier<ShareCardSubject?> {
  @override
  ShareCardSubject? build() => null;
  void select(ShareCardSubject? subject) => state = subject;
}

final selectedShareSubjectProvider =
    NotifierProvider<SelectedShareSubjectNotifier, ShareCardSubject?>(
      SelectedShareSubjectNotifier.new,
    );

class SelectedShareVariantNotifier extends Notifier<String> {
  @override
  String build() => 'show';
  void select(String variant) => state = variant;
}

final selectedShareVariantProvider =
    NotifierProvider<SelectedShareVariantNotifier, String>(
      SelectedShareVariantNotifier.new,
    );
