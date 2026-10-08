import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import '../support/api_adapter.dart';
import '../support/profile_fixture.dart';

void main() {
  late Dio dio;
  late ProfileRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
    repository = ProfileRepository(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'profile is parsed from the server including nullable details',
    () async {
      dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.path, '/me');
        return jsonResponse({...profileFixture(), 'profile': null});
      });
      final user = await repository.fetch();
      expect(user.name, 'Test listener');
      expect(user.following, 4);
      expect(user.bio, isNull);
      expect(user.avatarUrl, isNull);
    },
  );

  test('missing identity or counts are rejected instead of invented', () {
    for (final payload in [
      {...profileFixture(), 'id': null},
      {...profileFixture(), 'stats': {}},
      {...profileFixture(), 'unread_notifications': -1},
    ]) {
      expect(() => UserProfile.fromApi(payload), throwsA(isA<ApiFailure>()));
    }
  });

  test(
    'profile edit sends validated fields and uses the confirmed response',
    () async {
      dio.httpClientAdapter = ApiAdapter((request) {
        expect(request.method, 'PATCH');
        expect(request.data, {
          'name': 'Server name',
          'handle': null,
          'bio': 'Saved bio',
        });
        return jsonResponse({
          'user': {...profileFixture(), 'name': 'Server name', 'handle': null},
          'profile': {'bio': 'Saved bio'},
        });
      });
      final updated = await repository.update(
        UserProfile.fromApi(profileFixture()),
        name: ' Server name ',
        handle: '',
        bio: 'Saved bio',
      );
      expect(updated.name, 'Server name');
      expect(updated.bio, 'Saved bio');
      expect(updated.following, 4);
      expect(updated.handle, isNull);
    },
  );

  test(
    'a response for another user cannot replace the current profile',
    () async {
      dio.httpClientAdapter = ApiAdapter(
        (request) => jsonResponse({
          'user': profileFixture(id: 'other-user'),
          'profile': {},
        }),
      );
      await expectLater(
        repository.update(
          UserProfile.fromApi(profileFixture()),
          name: 'Name',
          handle: '',
          bio: '',
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test('validation field errors are retained for the form', () async {
    dio.httpClientAdapter = ApiAdapter(
      (request) => ResponseBody.fromString(
        jsonEncode({
          'ok': false,
          'error': {
            'code': 'VALIDATION',
            'message': 'Please check your details.',
            'fields': {
              'handle': ['This username is already taken.'],
            },
          },
        }),
        422,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    try {
      await repository.update(
        UserProfile.fromApi(profileFixture()),
        name: 'Name',
        handle: 'taken',
        bio: '',
      );
      fail('Update should fail');
    } on DioException catch (error) {
      expect(
        profileFailure(error).fields['handle'],
        'This username is already taken.',
      );
    }
  });

  test(
    'wallet coins preserve integer precision and reject other currencies',
    () {
      expect(
        EarnBalance.fromApi({
          'unit': 'ECN',
          'balance': '9223372036854775807',
        }).coins.toString(),
        '9223372036854775807',
      );
      for (final payload in [
        {'unit': 'NGN', 'balance': 10},
        {'unit': 'ECN', 'balance': 1.5},
        {'unit': 'ECN', 'balance': -1},
        {'unit': 'ECN'},
      ]) {
        expect(() => EarnBalance.fromApi(payload), throwsA(isA<ApiFailure>()));
      }
    },
  );

  test(
    'oversized or empty photo is rejected before a network request',
    () async {
      var requests = 0;
      dio.httpClientAdapter = ApiAdapter((request) {
        requests++;
        return jsonResponse({});
      });
      await expectLater(
        repository.uploadAvatar([], 'photo.jpg'),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        repository.uploadAvatar(
          List.filled(5 * 1024 * 1024 + 1, 0),
          'photo.jpg',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(requests, 0);
    },
  );
}
