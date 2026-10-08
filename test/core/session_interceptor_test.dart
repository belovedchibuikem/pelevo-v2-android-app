import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/session_interceptor.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import '../support/api_adapter.dart';

Map<String, dynamic> sessionData(String token, {String user = 'listener-a'}) =>
    {
      'access_token': token,
      'refresh_token': 'refresh-$token',
      'device_id': 'device-a',
      'user': {'id': user, 'name': 'Test listener'},
    };

void main() {
  late Dio dio;
  late AuthSession session;
  late int saves;
  late int clears;

  setUp(() {
    session = AuthSession.fromApi(sessionData('expired'));
    saves = 0;
    clears = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    dio.interceptors.add(
      SessionInterceptor(
        dio: dio,
        readSession: () => session,
        saveSession: (value) async {
          saves++;
          session = value;
        },
        clearSession: () async {
          clears++;
          session = const AuthSession();
        },
      ),
    );
  });
  tearDown(() => dio.close(force: true));

  test('session credentials cannot be sent to another origin', () async {
    var requests = 0;
    dio.httpClientAdapter = ApiAdapter((request) {
      requests++;
      return jsonResponse({});
    });
    await expectLater(
      dio.get<dynamic>('https://external.invalid/api/v1/me'),
      throwsA(isA<DioException>()),
    );
    expect(requests, 0);
  });

  test(
    'concurrent 401 responses rotate once and replay with committed credentials',
    () async {
      var refreshes = 0;
      dio.httpClientAdapter = ApiAdapter((request) async {
        if (request.path == '/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(sessionData('fresh'));
        }
        return request.headers['Authorization'] == 'Bearer fresh'
            ? jsonResponse({'path': request.path})
            : jsonResponse(null, status: 401);
      });
      final responses = await Future.wait([
        dio.get<dynamic>('/me'),
        dio.get<dynamic>('/home/feed'),
      ]);
      expect(responses.map((r) => r.statusCode), [200, 200]);
      expect(refreshes, 1);
      expect(saves, 1);
      expect(clears, 0);
    },
  );

  test('transient refresh failure preserves the session for retry', () async {
    dio.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/auth/refresh') {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return jsonResponse(null, status: 401);
    });
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(session.authenticated, isTrue);
    expect(clears, 0);
  });

  test(
    'an expired photo upload is replayed with a fresh multipart body',
    () async {
      var uploads = 0;
      dio.httpClientAdapter = ApiAdapter((request) {
        if (request.path == '/auth/refresh') {
          return jsonResponse(sessionData('fresh'));
        }
        uploads++;
        return request.headers['Authorization'] == 'Bearer fresh'
            ? jsonResponse({'avatar_url': '/storage/avatars/photo.jpg'})
            : jsonResponse(null, status: 401);
      });
      final response = await dio.post<dynamic>(
        '/me/avatar',
        data: FormData.fromMap({
          'avatar': MultipartFile.fromBytes([1, 2, 3], filename: 'photo.jpg'),
        }),
      );
      expect(response.statusCode, 200);
      expect(uploads, 2);
      expect(saves, 1);
    },
  );

  test(
    'a replayed endpoint failure does not erase newly rotated credentials',
    () async {
      dio.httpClientAdapter = ApiAdapter((request) {
        if (request.path == '/auth/refresh') {
          return jsonResponse(sessionData('fresh'));
        }
        return jsonResponse(
          null,
          status: request.extra['sessionRetry'] == true ? 503 : 401,
        );
      });
      await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
      expect(session.accessToken, 'fresh');
      expect(clears, 0);
    },
  );

  test('refresh without capabilities keeps previously granted creator access', () async {
    session = AuthSession.fromApi({
      ...sessionData('expired'),
      'user': {
        'id': 'listener-a',
        'name': 'Test listener',
        'capabilities': {'creator_access': true},
      },
    });
    dio.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/auth/refresh') {
        return jsonResponse(sessionData('fresh'));
      }
      return request.headers['Authorization'] == 'Bearer fresh'
          ? jsonResponse({'ok': true})
          : jsonResponse(null, status: 401);
    });
    await dio.get<dynamic>('/me');
    expect(session.accessToken, 'fresh');
    expect(session.creatorAccess, isTrue);
  });

  test('rejected refresh clears the revoked session', () async {
    dio.httpClientAdapter = ApiAdapter(
      (request) => jsonResponse(null, status: 401),
    );
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(session.authenticated, isFalse);
    expect(clears, 1);
  });

  test(
    'invalid login does not refresh an unrelated existing session',
    () async {
      var requests = 0;
      dio.httpClientAdapter = ApiAdapter((request) {
        requests++;
        return jsonResponse(null, status: 401);
      });
      await expectLater(
        dio.post<dynamic>('/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(requests, 1);
      expect(clears, 0);
    },
  );

  test(
    'logout while refresh is in flight cannot restore the old session',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      dio.httpClientAdapter = ApiAdapter((request) async {
        if (request.path == '/auth/refresh') {
          started.complete();
          await finish.future;
          return jsonResponse(sessionData('fresh'));
        }
        return jsonResponse(null, status: 401);
      });
      final request = expectLater(
        dio.get<dynamic>('/me'),
        throwsA(isA<DioException>()),
      );
      await started.future;
      session = const AuthSession();
      finish.complete();
      await request;
      expect(saves, 0);
      expect(session.authenticated, isFalse);
    },
  );
}
