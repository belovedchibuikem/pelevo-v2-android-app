import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/downloads/download_screens.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/library_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in downloadScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/queue-up-next',
          builder: (_, _) => const Scaffold(body: Text('Queue')),
        ),
        GoRoute(
          path: '/screen/library-2',
          builder: (_, _) => const Scaffold(body: Text('Library')),
        ),
        GoRoute(
          path: '/screen/episode-share',
          builder: (_, _) => const Scaffold(body: Text('Share')),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        selectedShowIdProvider.overrideWith(CatalogHarnessShowId.new),
        selectedEpisodeIdProvider.overrideWith(CatalogHarnessEpisodeId.new),
        initialAuthSessionProvider.overrideWithValue(
          const AuthSession(
            accessToken: 'test-access',
            refreshToken: 'test-refresh',
            deviceId: 'test-device',
            user: {'id': 'test-user', 'name': 'Test user'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PelevoTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
  }

  testWidgets('home uses authorized file count instead of invented GB', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/downloads-1',
      adapter: ApiAdapter((request) {
        if (request.path == '/downloads') {
          return jsonResponse([libraryDownloadFixture()]);
        }
        if (request.path == '/downloads/settings') {
          return jsonResponse(downloadSettingsFixture());
        }
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture(offlineItems: 1));
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('1\nFiles'), findsOneWidget);
    expect(find.text('3.2 GB\nUsed'), findsNothing);
    expect(find.text('Ep. 124 - The Shift Life'), findsOneWidget);
  });

  testWidgets('wifi toggle waits for PATCH', (tester) async {
    var patched = false;
    await mount(
      tester,
      location: '/screen/downloads-4',
      adapter: ApiAdapter((request) {
        if (request.path == '/downloads') {
          return jsonResponse([libraryDownloadFixture()]);
        }
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture());
        }
        if (request.path == '/downloads/settings') {
          if (request.method == 'PATCH') {
            patched = true;
            return jsonResponse(
              downloadSettingsFixture(wifiOnly: false, version: 2),
            );
          }
          return jsonResponse(downloadSettingsFixture());
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.ensureVisible(find.text('Download Over Wi-Fi Only'));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(patched, isTrue);
  });

  testWidgets('remove download waits for DELETE', (tester) async {
    var deleted = false;
    await mount(
      tester,
      location: '/screen/downloads-8',
      adapter: ApiAdapter((request) {
        if (request.path == '/downloads') {
          return jsonResponse([libraryDownloadFixture()]);
        }
        if (request.path == '/downloads/settings') {
          return jsonResponse(downloadSettingsFixture());
        }
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture());
        }
        if (request.path == '/downloads/$libraryDownloadId' &&
            request.method == 'DELETE') {
          deleted = true;
          return jsonResponse({'deleted': true});
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.tap(find.text('Remove Download'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
