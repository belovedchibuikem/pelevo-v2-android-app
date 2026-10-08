import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/lock_screen/lock_screen_data.dart';
import '../support/api_adapter.dart';

void main() {
  test('lock rules parse rejects user_id and accepts bool fields', () {
    expect(
      () => NotificationLockRules.parse({
        'user_id': 'x',
        'show_title': true,
        'show_body': false,
        'sensitive_hidden': true,
      }),
      throwsA(isA<ApiFailure>()),
    );
    final rules = NotificationLockRules.parse({
      'show_title': true,
      'show_body': false,
      'sensitive_hidden': true,
    });
    expect(rules.privacyIndex, 1);
    expect(NotificationLockRules.fromPrivacyIndex(0).showTitle, isFalse);
    expect(NotificationLockRules.fromPrivacyIndex(2).sensitiveHidden, isFalse);
  });

  test('lock rules repository loads and saves presented privacy triad', () async {
    Map<String, dynamic>? body;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/notification-lock-rules' &&
          request.method == 'GET') {
        return jsonResponse({
          'show_title': true,
          'show_body': false,
          'sensitive_hidden': true,
        });
      }
      if (request.path == '/notification-lock-rules' &&
          request.method == 'PUT') {
        body =
            request.data is Map
                ? Map<String, dynamic>.from(request.data as Map)
                : null;
        return jsonResponse(body!);
      }
      return errorResponse(status: 404, code: 'NOT_FOUND', message: 'missing');
    });
    final repo = NotificationLockRulesRepository(dio);
    final loaded = await repo.load(CancelToken());
    expect(loaded.showBody, isFalse);
    final saved = await repo.save(
      const NotificationLockRules(
        showTitle: false,
        showBody: false,
        sensitiveHidden: true,
      ),
    );
    expect(body, {
      'show_title': false,
      'show_body': false,
      'sensitive_hidden': true,
    });
    expect(saved.showTitle, isFalse);
  });
}
