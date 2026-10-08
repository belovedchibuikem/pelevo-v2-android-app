import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'support/api_adapter.dart';
import 'support/cms_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ApiAdapter adapter, {
    bool about = false,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (_, _) =>
                  about
                      ? const ProfileAboutScreen()
                      : const ProfileHelpScreen(),
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
              refreshToken: 'test-refresh',
              deviceId: 'test-device',
              user: {'id': 'test-user', 'name': 'Test listener'},
            ),
          ),
          packageInfoProvider.overrideWithValue(
            PackageInfo(
              appName: 'Pelevo',
              packageName: 'test.app',
              version: '7.8.9',
              buildNumber: '42',
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

  testWidgets('help renders server sections instead of fixed payout policies', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter(
        (request) => jsonResponse({
          ...cmsFixture('help'),
          'sections': [
            {'title': 'Server question', 'body': 'Server answer'},
          ],
        }),
      ),
    );
    expect(find.text('Server question'), findsOneWidget);
    expect(find.text('When can I withdraw?'), findsNothing);
    await tester.tap(find.text('Server question'));
    await tester.pumpAndSettle();
    expect(find.text('Server answer'), findsOneWidget);
  });

  testWidgets(
    'missing CMS keeps contact actions available and retry reloads content',
    (tester) async {
      var requests = 0;
      await mount(
        tester,
        ApiAdapter((request) {
          requests++;
          return requests == 1
              ? jsonResponse(null, status: 404)
              : jsonResponse(cmsFixture('help'));
        }),
      );
      expect(
        find.text('This content has not been published yet.'),
        findsOneWidget,
      );
      expect(find.text('Contact Support'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Content supplied by the API.'), findsOneWidget);
    },
  );

  testWidgets('contact form sends once and waits for the server receipt', (
    tester,
  ) async {
    final pending = Completer<ResponseBody>();
    var writes = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'POST') {
          writes++;
          return pending.future;
        }
        return jsonResponse(cmsFixture('help'));
      }),
    );
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Playback help');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'The audio stopped.',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(writes, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sending…'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('Support request received'), findsNothing);
    pending.complete(
      jsonResponse({'id': 'confirmed-ticket', 'state': 'open'}, status: 201),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Reference: confirmed-ticket'), findsOneWidget);
  });

  testWidgets(
    'uncertain submission retains the draft and retries with the same identifier',
    (tester) async {
      final keys = <String>[];
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'POST') {
            keys.add(request.data['client_request_id'] as String);
            if (keys.length == 1) {
              throw DioException(
                requestOptions: request,
                type: DioExceptionType.connectionTimeout,
              );
            }
            return jsonResponse({
              'id': 'confirmed-feedback',
              'state': 'new',
            }, status: 201);
          }
          return jsonResponse(cmsFixture('help'));
        }),
      );
      await tester.tap(find.text('Send Feedback'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'My suggestion');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('My suggestion'), findsOneWidget);
      expect(find.textContaining('Feedback received'), findsNothing);
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(keys.length, 2);
      expect(keys[1], keys[0]);
      expect(
        find.textContaining('Reference: confirmed-feedback'),
        findsOneWidget,
      );
    },
  );

  testWidgets('about uses runtime package metadata and published content', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) => jsonResponse(cmsFixture('about'))),
      about: true,
    );
    expect(find.text('7.8.9 (build 42)'), findsOneWidget);
    expect(find.text('Content supplied by the API.'), findsOneWidget);
    expect(find.text('support@pelevo.app'), findsNothing);
  });

  testWidgets('published legal documents resolve while signed out', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = ApiAdapter(
        (request) => jsonResponse(cmsFixture('terms')),
      );
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const PelevoApp(),
      ),
    );
    pelevoRouter.go('/legal/terms');
    await tester.pumpAndSettle();
    expect(
      pelevoRouter.routeInformationProvider.value.uri.path,
      '/legal/terms',
    );
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Content supplied by the API.'), findsOneWidget);
  });
}
