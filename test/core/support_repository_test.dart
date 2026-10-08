import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/profile/support_data.dart';
import '../support/api_adapter.dart';
import '../support/cms_fixture.dart';

void main() {
  late Dio dio;
  late SupportRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
    repository = SupportRepository(dio);
  });
  tearDown(() => dio.close(force: true));

  test('CMS uses only the expected published document response', () async {
    dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.path, '/cms/help');
      return jsonResponse(cmsFixture('help'));
    });
    final page = await repository.page(CmsDocument.help);
    expect(page.sections.single.title, 'How do earnings work?');
    expect(page.intro, 'Content supplied by the API.');
    expect(page.version, 2);
  });

  test(
    'missing, mismatched and malformed CMS data are not replaced with sample content',
    () {
      for (final data in [
        {...cmsFixture('help'), 'slug': 'privacy'},
        {...cmsFixture('help'), 'version': null},
        {...cmsFixture('help'), 'published_at': 'invalid'},
        {
          ...cmsFixture('help'),
          'sections': [{}],
        },
      ]) {
        expect(
          () => CmsPage.fromApi(data, CmsDocument.help),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );

  test(
    'ticket submission forwards its retry identifier and returns a confirmed receipt',
    () async {
      final key = newSupportRequestId();
      dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.path, '/support/tickets');
        expect(request.data, {
          'subject': 'Help',
          'message': 'My message',
          'priority': 'normal',
          'client_request_id': key,
        });
        return jsonResponse({
          'id': 'server-ticket-id',
          'state': 'open',
        }, status: 201);
      });
      final receipt = await repository.ticket(
        subject: ' Help ',
        message: ' My message ',
        requestId: key,
      );
      expect(receipt.id, 'server-ticket-id');
      expect(receipt.state, 'open');
    },
  );

  test(
    'rating feedback sends its selected rating, not a locally invented result',
    () async {
      dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.path, '/support/feedback');
        expect(request.data['rating'], 3);
        expect(request.data['type'], 'rating');
        return jsonResponse({'id': 'feedback-id', 'state': 'new'}, status: 201);
      });
      expect(
        (await repository.feedback(
          type: 'rating',
          message: 'Feedback',
          rating: 3,
          requestId: newSupportRequestId(),
        )).id,
        'feedback-id',
      );
    },
  );

  test(
    'a successful envelope without a receipt is not treated as a submitted request',
    () async {
      dio.httpClientAdapter = ApiAdapter(
        (request) => jsonResponse({'accepted': true}),
      );
      await expectLater(
        repository.ticket(
          subject: 'Help',
          message: 'Message',
          requestId: newSupportRequestId(),
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
}
