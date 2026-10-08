import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/browse/browse_screens.dart';
import 'support/account_feed_fixture.dart';
import 'support/api_adapter.dart';
import 'support/browse_fixture.dart';
import 'support/home_fixture.dart';
import 'support/search_fixture.dart';

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
        for (final spec in browseScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/search',
          builder: (_, _) => const Scaffold(body: Text('Search')),
        ),
        GoRoute(
          path: '/screen/podcast-details',
          builder: (_, _) => const Scaffold(body: Text('Podcast')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/library-2',
          builder: (_, _) => const Scaffold(body: Text('Library')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
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
    await tester.pumpAndSettle();
  }

  ApiAdapter adapter() => ApiAdapter((request) {
    if (request.path == '/browse' || request.path == '/browse/categories') {
      return jsonResponse(browseCategoriesFixture());
    }
    if (request.path == '/browse/music') {
      return jsonResponse(
        browseCategoryPageFixture(
          id: '2',
          name: 'Music',
          slug: 'music',
          shows: [browseShowFixture(id: 'show-music', title: 'Lagos Mix')],
        ),
      );
    }
    if (request.path.startsWith('/browse/')) {
      return jsonResponse(browseCategoryPageFixture());
    }
    if (request.path == '/home/discover') {
      return jsonResponse(homeDiscoverFixture());
    }
    if (request.path == '/home/charts') {
      return jsonResponse(homeChartsFixture());
    }
    if (request.path == '/search/recent') {
      return jsonResponse([recentSearchFixture()]);
    }
    if (request.path == '/me/following') {
      return jsonResponse([followedShowFixture('one')]);
    }
    if (RegExp(r'^/shows/[^/]+/follow$').hasMatch(request.path)) {
      return jsonResponse({'following': true});
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('browse home binds categories instead of Afrobeats', (
    tester,
  ) async {
    await mount(tester, location: '/screen/browse', adapter: adapter());
    expect(find.text('Featured Collections'), findsOneWidget);
    expect(find.text('Afrobeats Vibes'), findsNothing);
    expect(find.text('Technology'), findsWidgets);
    expect(find.text('Music'), findsWidgets);
    expect(find.text('Fresh episode'), findsWidgets);
  });

  testWidgets('music and following use server titles', (tester) async {
    await mount(tester, location: '/screen/browse-music', adapter: adapter());
    expect(find.text('Music Collections'), findsWidgets);
    expect(find.text('Lagos Mix'), findsWidgets);
    expect(find.text('Afrobeats Hits'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await mount(
      tester,
      location: '/screen/browse-following',
      adapter: adapter(),
    );
    expect(find.text('Server show one'), findsOneWidget);
    expect(find.text('Startup Stories'), findsNothing);
  });

  testWidgets('added chrome does not invent a collection name', (tester) async {
    await mount(tester, location: '/screen/browse-added', adapter: adapter());
    expect(find.text('Added to your library'), findsOneWidget);
    expect(find.textContaining('Startup Stories'), findsNothing);
  });

  testWidgets('collection detail shows back, tabs, and category hero', (
    tester,
  ) async {
    await mount(tester, location: '/screen/browse-detail', adapter: adapter());
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Technology'), findsWidgets);
    expect(find.textContaining('Curated collection'), findsOneWidget);
    expect(find.text('Owned Show'), findsOneWidget);
  });
}
