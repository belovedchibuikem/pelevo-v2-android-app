import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/notification_preferences.dart';
import 'support/api_adapter.dart';
import 'support/notification_preferences_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ApiAdapter adapter,
    NotificationPreferenceView view,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
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
        child: MaterialApp(
          theme: PelevoTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPreferencesContent(view: view),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('general settings use server values and wait for confirmation', (
    tester,
  ) async {
    var data = notificationPreferencesFixture(version: 3);
    final pending = Completer<ResponseBody>();
    var calls = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'PATCH') {
          calls++;
          expect(request.data['version'], 3);
          expect(request.data['push_enabled'], true);
          return pending.future;
        }
        return jsonResponse(data);
      }),
      NotificationPreferenceView.settings,
    );
    expect(
      tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .first
          .value,
      isFalse,
    );
    expect(
      find.textContaining('In-app messages respect saved preferences'),
      findsOneWidget,
    );
    await tester.tap(find.text('Push Notifications'));
    await tester.pump();
    expect(find.text('Notification preferences saved'), findsNothing);
    expect(
      tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .first
          .onChanged,
      isNull,
    );
    data = {...data, 'version': 4, 'push_enabled': true};
    pending.complete(jsonResponse(data));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Notification preferences saved'), findsOneWidget);
  });

  testWidgets(
    'filter conflict retains draft and reload replaces it with server state',
    (tester) async {
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
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
                    'message': 'Changed on another device.',
                  },
                },
              ),
            );
          }
          return jsonResponse(notificationPreferencesFixture());
        }),
        NotificationPreferenceView.filters,
      );
      await tester.tap(find.text('Promotions'));
      await tester.ensureVisible(find.text('Save Preferences'));
      await tester.tap(find.text('Save Preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Changed on another device.'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Promotions'),
            )
            .value,
        isTrue,
      );
      await tester.ensureVisible(find.text('Reload saved preferences'));
      await tester.tap(find.text('Reload saved preferences'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Promotions'),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'schedule submits actual server time days and selected categories',
    (tester) async {
      var data = notificationPreferencesFixture(version: 6);
      Map<String, dynamic>? payload;
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
            payload = Map<String, dynamic>.from(request.data);
            data = {...data, 'version': 7, 'options': payload!['options']};
          }
          return jsonResponse(data);
        }),
        NotificationPreferenceView.scheduled,
      );
      expect(find.text('09:15'), findsOneWidget);
      expect(find.text('Times use Africa/Lagos'), findsOneWidget);
      await tester.tap(find.text('Promotions'));
      await tester.ensureVisible(find.text('Save Schedule'));
      await tester.tap(find.text('Save Schedule'));
      await tester.pumpAndSettle();
      expect(payload!['options']['summary_days'], [1, 4]);
      expect(payload!['options']['summary_include'], [
        'mentions',
        'promotions',
      ]);
      expect(payload!['options']['summary_time'], '09:15');
    },
  );

  testWidgets('failed load shows retry without default switches', (
    tester,
  ) async {
    var tries = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        if (++tries == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(notificationPreferencesFixture());
      }),
      NotificationPreferenceView.settings,
    );
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Push Notifications'), findsOneWidget);
  });

  test('malformed wire values and schedule times are rejected', () {
    final data = notificationPreferencesFixture();
    expect(
      () => NotificationPreferences.parse({
        ...data,
        'delivery_status': 'all_enabled',
      }),
      throwsException,
    );
    expect(
      () => NotificationPreferences.parse({...data, 'push_enabled': 1}),
      throwsException,
    );
    expect(
      () => NotificationPreferences.parse({
        ...data,
        'options': {...data['options'], 'summary_time': '25:99'},
      }),
      throwsException,
    );
  });

  testWidgets('legacy API status does not claim in-app enforcement', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter(
        (request) => jsonResponse({
          ...notificationPreferencesFixture(),
          'delivery_status': 'preferences_only',
        }),
      ),
      NotificationPreferenceView.settings,
    );
    expect(
      find.textContaining('Delivery integration is still pending'),
      findsOneWidget,
    );
    expect(
      find.textContaining('In-app messages respect saved preferences'),
      findsNothing,
    );
  });
}
