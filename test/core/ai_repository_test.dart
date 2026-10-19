import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/ai/ai_data.dart';
import '../support/api_adapter.dart';
import '../support/ai_fixture.dart';

void main() {
  AiRepository repository(Dio dio) => AiRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('recommendations parse title and reason without match scores', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/home/recommendations');
        return jsonResponse(aiRecommendationsFixture());
      }),
    );
    final items = await repository(dio).recommendations(CancelToken());
    expect(items.single.title, 'The Honest Bunch');
    expect(items.single.reason, 'From your listening history');
    expect(items.single.artworkUrl, isNull);
  });

  test('recommendations keep show artwork from the server', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        final body = aiRecommendationsFixture();
        (body['items'] as List).single['artwork_url'] =
            'https://cdn.pelevo.com/shows/honest.jpg';
        return jsonResponse(body);
      }),
    );
    final items = await repository(dio).recommendations(CancelToken());
    expect(items.single.artworkUrl, 'https://cdn.pelevo.com/shows/honest.jpg');
  });

  test('completed jobs expose output text only', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/ai/jobs/$aiJobId');
        return jsonResponse(
          aiJobFixture(
            state: 'completed',
            outputText: 'Queued jobs return text when complete.',
          ),
        );
      }),
    );
    final job = await repository(dio).job(aiJobId, CancelToken());
    expect(job.completed, isTrue);
    expect(job.outputText, contains('Queued jobs'));
  });

  test('create job receipts require type and queued state', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/ai/jobs');
        expect(request.data['type'], 'summary');
        return jsonResponse(aiJobFixture(), status: 202);
      }),
    );
    final job = await repository(
      dio,
    ).createJob(type: 'summary', input: {'episode_id': 'catalog-episode-1'});
    expect(job.type, 'summary');
    expect(job.state, 'queued');
  });

  test('job output that is not a text map is rejected', () {
    expect(
      () => AiJob.parse({
        'id': aiJobId,
        'type': 'summary',
        'state': 'completed',
        'output': 'plain-string',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });
}
