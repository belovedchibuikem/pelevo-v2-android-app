import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/onboarding/onboarding_data.dart';
import '../support/api_adapter.dart';

void main() {
  late Dio dio;
  late OnboardingRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
    repository = OnboardingRepository(dio);
  });

  tearDown(() => dio.close(force: true));

  test('submit sends catalog interests and locale', () async {
    dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.method, 'PUT');
      expect(request.path, '/me/onboarding');
      expect(request.data, {
        'interests': ['Technology', 'True Crime'],
        'locale': 'yo',
      });
      return jsonResponse({
        'user_id': 'test-user',
        'onboarded': true,
        'interests': ['technology', 'true crime'],
        'locale': 'yo',
      });
    });

    final result = await repository.submit(
      const OnboardingDraft(
        interests: ['Technology', 'True Crime'],
        locale: 'yo',
      ),
    );
    expect(result.userId, 'test-user');
    expect(result.interests, ['Technology', 'True Crime']);
    expect(result.locale, 'yo');
  });

  test('malformed or foreign onboarding responses are rejected', () {
    expect(
      () => OnboardingResult.fromApi({
        'user_id': 'test-user',
        'onboarded': false,
        'interests': ['News'],
        'locale': 'en',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => OnboardingResult.fromApi({
        'user_id': 'test-user',
        'onboarded': true,
        'interests': ['Invented'],
        'locale': 'en',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => OnboardingResult.fromApi({
        'user_id': '',
        'onboarded': true,
        'interests': ['News'],
        'locale': 'en',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });
}
