import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';

void main() {
  group('API envelope', () {
    test('returns normalized data from a successful response', () {
      expect(
        requireApiData({
          'ok': true,
          'data': {'id': 'user-1'},
          'meta': <String, dynamic>{},
          'error': null,
          'request_id': 'request-1',
        }),
        {'id': 'user-1'},
      );
    });

    test('preserves stable error fields and support reference', () {
      expect(
        () => requireApiData({
          'ok': false,
          'data': null,
          'error': {
            'code': 'VALIDATION_FAILED',
            'message': 'Please check the form.',
            'fields': {
              'email': ['The email is invalid.'],
            },
          },
          'request_id': 'request-2',
        }),
        throwsA(
          isA<ApiFailure>()
              .having((error) => error.code, 'code', 'VALIDATION_FAILED')
              .having(
                (error) => error.fields['email'],
                'email',
                'The email is invalid.',
              )
              .having((error) => error.requestId, 'request id', 'request-2'),
        ),
      );
    });

    test('rejects corrupt successful envelopes', () {
      expect(
        () => requireApiData({'ok': true, 'data': <dynamic>[]}),
        throwsA(isA<ApiFailure>()),
      );
    });

    test('uses Laravel server error message when the envelope is missing', () {
      expect(
        () => requireApiData({'message': 'Server Error'}),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.message,
            'message',
            'Server Error',
          ),
        ),
      );
    });
  });
}
