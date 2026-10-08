import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/preferences_data.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'package:pelevo/features/profile/profile_screens.dart';
import 'support/api_adapter.dart';
import 'support/preferences_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ApiAdapter adapter, {
    bool settings = false,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (_, _) =>
                  settings
                      ? const SettingsAccountScreen()
                      : const ProfileEmailPreferencesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          initialAuthSessionProvider.overrideWithValue(
            const AuthSession(
              accessToken: 'test',
              refreshToken: 'refresh',
              deviceId: 'device',
              user: {'id': 'test-user'},
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: PelevoTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('malformed preference values cannot become local defaults', () {
    expect(
      () => AccountPreferences.fromApi({
        ...preferencesFixture(),
        'email_product': 'true',
      }),
      throwsException,
    );
    expect(
      () => AccountPreferences.fromApi({
        ...preferencesFixture(),
        'audio_quality': 'invented',
      }),
      throwsException,
    );
    expect(
      () =>
          AccountPreferences.fromApi({...preferencesFixture(), 'version': -1}),
      throwsException,
    );
  });

  testWidgets(
    'email switches load the server values and save once after confirmation',
    (tester) async {
      var data = {...preferencesFixture(version: 3), 'email_product': true};
      final pending = Completer<ResponseBody>();
      var writes = 0;
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
            writes++;
            expect(request.data, {
              'version': 3,
              'email_product': true,
              'email_episodes': false,
              'email_marketing': true,
            });
            return pending.future;
          }
          return jsonResponse(data);
        }),
      );
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((tile) => tile.value),
        [true, false, false],
      );
      await tester.tap(find.text('Offers & promotions'));
      await tester.tap(find.text('Save Preferences'));
      await tester.pump();
      expect(find.text('Preferences saved'), findsNothing);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((tile) => tile.onChanged == null),
        isTrue,
      );
      data = {...data, 'version': 4, 'email_marketing': true};
      pending.complete(jsonResponse(data));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Preferences saved'), findsOneWidget);
    },
  );

  testWidgets(
    'conflict retains the draft and explicit reload reads current server preferences',
    (tester) async {
      var data = preferencesFixture(version: 2);
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
            data = {...preferencesFixture(version: 3), 'email_episodes': true};
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: request,
                statusCode: 409,
                data: {
                  'ok': false,
                  'error': {
                    'code': 'VERSION_CONFLICT',
                    'message': 'Preferences changed on another device.',
                  },
                },
              ),
            );
          }
          return jsonResponse(data);
        }),
      );
      await tester.tap(find.text('Offers & promotions'));
      await tester.tap(find.text('Save Preferences'));
      await tester.pumpAndSettle();
      expect(
        find.text('Preferences changed on another device.'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .last
            .value,
        isTrue,
      );
      expect(find.text('Preferences saved'), findsNothing);
      await tester.tap(find.text('Reload saved preferences'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((tile) => tile.value),
        [false, true, false],
      );
    },
  );

  testWidgets('failed initial load shows retry and no invented switches', (
    tester,
  ) async {
    var reads = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        if (++reads == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(preferencesFixture());
      }),
    );
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNWidgets(3));
  });

  testWidgets(
    'account quality reads persisted choice and data saver waits for server',
    (tester) async {
      var data = {...preferencesFixture(version: 5), 'audio_quality': 'low'};
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
            expect(request.data, {'data_saver': true, 'version': 5});
            data = {...data, 'version': 6, 'data_saver': true};
          }
          return jsonResponse(data);
        }),
        settings: true,
      );
      expect(find.text('Low'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    },
  );
}
