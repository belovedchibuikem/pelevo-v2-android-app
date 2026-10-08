import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/notification_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/library_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String screen,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/screen/$screen',
      routes: [
        for (final spec in notificationScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/library-5',
          builder: (_, _) => const Scaffold(body: Text('Downloads')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/episode-share',
          builder: (_, _) => const Scaffold(body: Text('Share')),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
  }

  testWidgets('download complete uses an authorized row', (tester) async {
    await mount(
      tester,
      screen: 'notifications-4',
      adapter: ApiAdapter((request) {
        expect(request.path, '/downloads');
        return jsonResponse([libraryDownloadFixture()]);
      }),
    );
    expect(find.text('Ep. 124 - The Shift Life is authorized on your account.'), findsOneWidget);
    expect(find.textContaining('ready for offline listening'), findsNothing);
  });

  testWidgets('daily reminder uses streak and recents', (tester) async {
    await mount(
      tester,
      screen: 'notifications-5',
      adapter: ApiAdapter((request) {
        if (request.path == '/stats/me') {
          return jsonResponse(catalogStatsFixture());
        }
        if (request.path == '/library/recent') {
          return jsonResponse([catalogRecentEpisodeFixture()]);
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.textContaining('3-day streak'), findsOneWidget);
    expect(find.text('Ep. 123 - Keep Going'), findsOneWidget);
    expect(find.textContaining('7-day streak'), findsNothing);
  });
}
