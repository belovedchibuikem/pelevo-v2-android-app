import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

void main() {
  test('maps upload send timeouts to a timeout message', () {
    final failure = apiFailureFromDio(
      DioException(
        requestOptions: RequestOptions(
          path: '/uploads/01h/content',
          baseUrl: 'https://pelevo.com/api/v1',
        ),
        type: DioExceptionType.sendTimeout,
      ),
    );
    expect(failure.code, 'TIMEOUT');
    expect(failure.message, contains('timed out'));
  });

  test('maps 413 responses to a file-too-large message', () {
    final failure = apiFailureFromDio(
      DioException(
        requestOptions: RequestOptions(path: '/uploads/01h/content'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/uploads/01h/content'),
          statusCode: 413,
          data: '<html>413 Request Entity Too Large</html>',
        ),
      ),
    );
    expect(failure.code, 'TOO_LARGE');
    expect(failure.message, contains('too large'));
  });

  test('maps Cloudflare 524 HTML to an unavailable message', () {
    final failure = apiFailureFromDio(
      DioException(
        requestOptions: RequestOptions(path: '/uploads/01h/content'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/uploads/01h/content'),
          statusCode: 524,
          data: '<html>timeout</html>',
        ),
      ),
    );
    expect(failure.code, 'UNAVAILABLE');
    expect(failure.message, contains('busy'));
  });
}
