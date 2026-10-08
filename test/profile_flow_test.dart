import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/profile/profile_screens.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'support/api_adapter.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<GoRouter> mount(
    WidgetTester tester,
    ApiAdapter adapter, {
    String route = '/screen/profile-edit',
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: '/screen/profile-edit',
          builder: (_, _) => const ProfileEditScreen(),
        ),
        GoRoute(
          path: '/screen/profile',
          builder: (_, _) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/screen/profile-personal',
          builder: (_, _) => const ProfilePersonalInfoScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: PelevoTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'profile displays returned identity and balance without seed values',
    (tester) async {
      await mount(
        tester,
        ApiAdapter(
          (request) =>
              request.path == '/earn/wallet'
                  ? jsonResponse({'unit': 'ECN', 'balance': 87})
                  : jsonResponse(profileFixture(name: 'Returned API name')),
        ),
        route: '/screen/profile',
      );
      expect(find.text('Returned API name'), findsOneWidget);
      expect(find.text('87 ECN'), findsOneWidget);
      expect(find.text('Adesola Adeyemi'), findsNothing);
      expect(find.text('₦24,560.00'), findsNothing);
    },
  );

  testWidgets('failed profile loads show retry without a fabricated identity', (
    tester,
  ) async {
    var requests = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        requests++;
        return requests == 1
            ? jsonResponse(null, status: 503)
            : jsonResponse(profileFixture());
      }),
      route: '/screen/profile-edit',
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Test listener'), findsOneWidget);
  });

  testWidgets(
    'save is single-flight and navigation waits for server confirmation',
    (tester) async {
      var writes = 0;
      var data = profileFixture();
      final pending = Completer<ResponseBody>();
      final router = await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'PATCH') {
            writes++;
            return pending.future;
          }
          if (request.path == '/earn/wallet') {
            return jsonResponse({'unit': 'ECN', 'balance': 0});
          }
          return jsonResponse(data);
        }),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Changed name');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(writes, 1);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/screen/profile-edit',
      );
      expect(find.text('Profile updated'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      data = profileFixture(name: 'Changed name');
      pending.complete(
        jsonResponse({'user': data, 'profile': data['profile']}),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/screen/profile');
      expect(find.text('Changed name'), findsOneWidget);
    },
  );

  testWidgets('server validation preserves edits and does not report success', (
    tester,
  ) async {
    final router = await mount(
      tester,
      ApiAdapter(
        (request) =>
            request.method == 'PATCH'
                ? ResponseBody.fromString(
                  jsonEncode({
                    'ok': false,
                    'error': {
                      'code': 'VALIDATION',
                      'message': 'Check the username.',
                      'fields': {
                        'handle': ['Username is taken.'],
                      },
                    },
                  }),
                  422,
                  headers: {
                    Headers.contentTypeHeader: [Headers.jsonContentType],
                  },
                )
                : jsonResponse(profileFixture()),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'taken');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/screen/profile-edit',
    );
    expect(find.text('Username is taken.'), findsOneWidget);
    expect(find.text('taken'), findsOneWidget);
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets(
    'personal information uses the account response and nullable fields',
    (tester) async {
      await mount(
        tester,
        ApiAdapter((request) => jsonResponse(profileFixture())),
        route: '/screen/profile-personal',
      );
      expect(find.text('Test listener'), findsOneWidget);
      expect(find.text('listener@example.invalid'), findsOneWidget);
      expect(find.text('NG'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('+234 801 234 5678'), findsNothing);
    },
  );

  testWidgets('leaving edited fields asks before discarding them', (
    tester,
  ) async {
    final router = await mount(
      tester,
      ApiAdapter((request) => jsonResponse(profileFixture())),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved name');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/screen/profile-edit',
    );
    expect(find.text('Unsaved name'), findsOneWidget);
  });
}
