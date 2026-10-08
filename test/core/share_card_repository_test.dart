import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/share_cards/share_card_data.dart';
import '../support/api_adapter.dart';
import '../support/catalog_fixture.dart';
import '../support/share_card_fixture.dart';

void main() {
  ShareCardRepository repository(Dio dio) => ShareCardRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('templates and cards stay public', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/share-card-templates') {
          return jsonResponse([shareCardTemplateFixture()]);
        }
        if (request.path == '/share-cards') {
          return jsonResponse([shareCardFixture()]);
        }
        if (request.path == '/share-cards/$shareCardId') {
          return jsonResponse(shareCardDetailFixture());
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final token = CancelToken();
    final templates = await repository(dio).templates(token);
    expect(templates.single.name, 'Pelevo Standard');
    expect(templates.single.version, 1);

    final cards = await repository(dio).list(token);
    expect(cards.single.id, shareCardId);
    expect(cards.single.url, shareCardUrl);
    expect(cards.single.quote, 'Ep. 124 - The Shift Life');

    final detail = await repository(dio).show(shareCardId, token);
    expect(detail.events, isEmpty);
    expect(detail.subjectId, catalogEpisodeId);
  });

  test('create posts template subject and payload', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/share-cards');
        final data = Map<String, dynamic>.from(request.data as Map);
        expect(data['template_id'], shareCardTemplateId);
        expect(data['subject_type'], 'episode');
        expect(data['subject_id'], catalogEpisodeId);
        return jsonResponse(shareCardFixture(), status: 201);
      }),
    );
    final card = await repository(dio).create(
      templateId: shareCardTemplateId,
      subjectType: 'episode',
      subjectId: catalogEpisodeId,
      payload: {'variant': 'qr', 'quote': 'Ep. 124 - The Shift Life'},
    );
    expect(card.url, shareCardUrl);
    expect(card.state, 'ready');
  });

  test('share cards reject missing ids and unknown subject types', () {
    expect(
      () => ShareCard.parse({
        ...shareCardFixture(),
        'id': '',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ShareCard.parse({
        ...shareCardFixture(),
        'subject_type': 'playlist',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(() => ShareCard.parse(shareCardFixture()), returnsNormally);
  });
}
