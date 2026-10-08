import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:pelevo/core/network/api_environment.dart';

void main() {
  test('development defaults to the Android emulator local API', () {
    expect(ApiEnvironment.baseUrl, 'http://10.0.2.2:8000/api/v1');
  });

  test('desktop development connects to localhost', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ApiEnvironment.baseUrl, 'http://localhost:8000/api/v1');
  });

  test('development supports an explicitly configured local backend', () {
    expect(
      ApiEnvironment.validate('http://10.0.2.2:8000/api/v1/', release: false),
      'http://10.0.2.2:8000/api/v1',
    );
  });

  test('production base URL is accepted for release builds', () {
    expect(
      ApiEnvironment.validate(ApiEnvironment.productionBaseUrl, release: true),
      'https://pelevo.com/api/v1',
    );
  });

  test('release refuses HTTP and malformed API addresses', () {
    for (final url in [
      'http://example.invalid/api/v1',
      'https://example.invalid',
      'https://user:secret@example.invalid/api/v1',
      'https://example.invalid/api/v1?token=secret',
      'https://example.invalid/api/v1#fragment',
      '/api/v1',
    ]) {
      expect(
        () => ApiEnvironment.validate(url, release: true),
        throwsStateError,
        reason: url,
      );
    }
  });
}
