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
  });

    factory AiJob.parse(Map<String, dynamic> data) {
    final output = data['output'];
    String? text;
    if (output is Map<String, dynamic>) {
      text = _optionalText(output, 'text');
    } else if (output != null) {
      throw _invalidAi;
    }
    return AiJob(
      id: _text(data, 'id'),
      type: _text(data, 'type'),
      state: _text(data, 'state'),
      outputText: text,
    );
  }

  final String id, type, state;
  final String? outputText;

  bool get queued => state == 'queued' || state == 'processing';
  bool get completed => state == 'completed';
}

class AiRecommendation {
  const AiRecommendation({
    required this.id,
    required this.title,
    this.showId,
    this.reason,
  });

  factory AiRecommendation.parse(Map<String, dynamic> data) => AiRecommendation(
    id: _text(data, 'id'),
    title: _text(data, 'title'),
    showId: _optionalText(data, 'show_id'),
    reason: _optionalText(data, 'reason'),
  );

  final String id, title;
  final String? showId, reason;
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

  Future<List<AiRecommendation>> recommendations(CancelToken token) async {
    try {
      final data = requireApiData(
        (await _dio.get<Map<String, dynamic>>(
          '/home/recommendations',
          cancelToken: token,
        )).data,
      );
      return _maps(data['items']).map(AiRecommendation.parse).toList(growable: false);
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
  String build() => 'Summarize this episode';
  void set(String value) => state = value;
}

class AiNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedAiJobIdProvider =
    NotifierProvider<SelectedAiJobIdNotifier, String?>(SelectedAiJobIdNotifier.new);

final selectedAiQuestionProvider =
    NotifierProvider<SelectedAiQuestionNotifier, String>(SelectedAiQuestionNotifier.new);

final aiNoticeProvider =
    NotifierProvider<AiNoticeNotifier, String?>(AiNoticeNotifier.new);

final aiRepositoryProvider = Provider((ref) => AiRepository(ref.watch(dioProvider)));

final aiRecommendationsProvider = FutureProvider.autoDispose<List<AiRecommendation>>((
  ref,
) async {
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
  return ref.watch(aiRepositoryProvider).job(id, token);
}, retry: (count, error) => null);
