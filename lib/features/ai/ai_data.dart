import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

const _invalidAi = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'AI details could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidAi;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidAi;
  return value as String?;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidAi;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

class AiJob {
  const AiJob({
    required this.id,
    required this.type,
    required this.state,
    this.outputText,
    this.takeaways = const [],
    this.topics = const [],
  });

  factory AiJob.parse(Map<String, dynamic> data) {
    final output = data['output'];
    String? text;
    var takeaways = const <String>[];
    var topics = const <String>[];
    if (output is Map<String, dynamic>) {
      text = _optionalText(output, 'text');
      takeaways = _stringList(output['takeaways']);
      topics = _stringList(output['topics']);
    } else if (output != null) {
      throw _invalidAi;
    }
    return AiJob(
      id: _text(data, 'id'),
      type: _text(data, 'type'),
      state: _text(data, 'state'),
      outputText: text,
      takeaways: takeaways,
      topics: topics,
    );
  }

  final String id, type, state;
  final String? outputText;
  final List<String> takeaways;
  final List<String> topics;

  bool get queued => state == 'queued' || state == 'processing';
  bool get completed => state == 'completed';
}

class AiPick {
  const AiPick({
    required this.id,
    required this.title,
    required this.type,
    this.showId,
    this.showTitle,
    this.artworkUrl,
    this.reason,
  });

  factory AiPick.parse(Map<String, dynamic> data) => AiPick(
    id: _text(data, 'id'),
    title: _text(data, 'title'),
    type: _optionalText(data, 'type') ?? 'show',
    showId: _optionalText(data, 'show_id'),
    showTitle: _optionalText(data, 'show_title'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    reason: _optionalText(data, 'reason'),
  );

  final String id, title, type;
  final String? showId, showTitle, artworkUrl, reason;
}

class AiConversation {
  const AiConversation({required this.reply, required this.items});

  factory AiConversation.parse(Map<String, dynamic> data) => AiConversation(
    reply: _text(data, 'reply'),
    items: _maps(data['items']).map(AiPick.parse).toList(growable: false),
  );

  final String reply;
  final List<AiPick> items;
}

class AiLineup {
  const AiLineup({
    required this.title,
    required this.weekLabel,
    required this.intro,
    required this.items,
  });

  factory AiLineup.parse(Map<String, dynamic> data) => AiLineup(
    title: _text(data, 'title'),
    weekLabel: _text(data, 'week_label'),
    intro: _text(data, 'intro'),
    items: _maps(data['items']).map(AiPick.parse).toList(growable: false),
  );

  final String title, weekLabel, intro;
  final List<AiPick> items;
}

class AiRecommendation {
  const AiRecommendation({
    required this.id,
    required this.title,
    this.showId,
    this.artworkUrl,
    this.reason,
  });

  factory AiRecommendation.parse(Map<String, dynamic> data) => AiRecommendation(
    id: _text(data, 'id'),
    title: _text(data, 'title'),
    showId: _optionalText(data, 'show_id'),
    artworkUrl: _optionalText(data, 'artwork_url'),
    reason: _optionalText(data, 'reason'),
  );

  final String id, title;
  final String? showId, artworkUrl, reason;
}

class AiRepository {
  AiRepository(this._dio);
  final Dio _dio;

  Future<AiJob> createJob({
    required String type,
    required Map<String, dynamic> input,
  }) async {
    try {
      return AiJob.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/ai/jobs',
            data: {'type': type, 'input': input},
            options: Options(
              receiveTimeout: const Duration(seconds: 70),
              sendTimeout: const Duration(seconds: 20),
            ),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<AiJob> job(String id, CancelToken token) async {
    try {
      return AiJob.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/ai/jobs/${Uri.encodeComponent(id)}',
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

  Future<AiConversation> ask(String message, CancelToken token) async {
    try {
      return AiConversation.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/ai/ask',
            data: {'message': message.trim()},
            cancelToken: token,
            options: Options(receiveTimeout: const Duration(seconds: 40)),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<AiLineup> lineup(CancelToken token) async {
    try {
      return AiLineup.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/ai/lineup',
            cancelToken: token,
            options: Options(receiveTimeout: const Duration(seconds: 40)),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<AiRecommendation>> recommendations(CancelToken token) async {
    try {
      final data = requireApiData(
        (await _dio.get<Map<String, dynamic>>(
          '/home/recommendations',
          cancelToken: token,
        )).data,
      );
      return _maps(
        data['items'],
      ).map(AiRecommendation.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

class SelectedAiJobIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

class SelectedAiQuestionNotifier extends Notifier<String> {
  @override
  String build() => 'Something thoughtful about growth';
  void set(String value) => state = value;
}

class AiNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedAiJobIdProvider =
    NotifierProvider<SelectedAiJobIdNotifier, String?>(
      SelectedAiJobIdNotifier.new,
    );

final selectedAiQuestionProvider =
    NotifierProvider<SelectedAiQuestionNotifier, String>(
      SelectedAiQuestionNotifier.new,
    );

final aiNoticeProvider = NotifierProvider<AiNoticeNotifier, String?>(
  AiNoticeNotifier.new,
);

final aiRepositoryProvider = Provider(
  (ref) => AiRepository(ref.watch(dioProvider)),
);

final aiAskProvider = FutureProvider.autoDispose.family<AiConversation, String>(
  (ref, question) async {
    final token = CancelToken();
    ref.onDispose(token.cancel);
    return ref.watch(aiRepositoryProvider).ask(question, token);
  },
  retry: (count, error) => null,
);

final aiLineupProvider = FutureProvider.autoDispose<AiLineup>((ref) async {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(aiRepositoryProvider).lineup(token);
}, retry: (count, error) => null);

final aiRecommendationsProvider =
    FutureProvider.autoDispose<List<AiRecommendation>>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(aiRepositoryProvider).recommendations(token);
    }, retry: (count, error) => null);

const missingAiJob = ApiFailure(
  code: 'NO_AI_JOB',
  message: 'Generate a summary or chapters from the selected episode first.',
);

final aiJobProvider = FutureProvider.autoDispose<AiJob>((ref) async {
  final id = ref.watch(selectedAiJobIdProvider);
  if (id == null || id.isEmpty) throw missingAiJob;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  final repository = ref.watch(aiRepositoryProvider);
  var job = await repository.job(id, token);
  var waits = 0;
  while (job.queued && waits < 8 && !token.isCancelled) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (token.isCancelled) break;
    job = await repository.job(id, token);
    waits++;
  }
  return job;
}, retry: (count, error) => null);
