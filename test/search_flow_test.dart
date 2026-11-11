import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/search/search_screens.dart';
import 'support/api_adapter.dart';
import 'support/home_fixture.dart';
import 'support/search_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in searchScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/browse',
          builder: (_, _) => const Scaffold(body: Text('Browse')),
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
          path: '/screen/reels',
          builder: (_, _) => const Scaffold(body: Text('Reels')),
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
    if (request.path == '/home/charts') {
      return jsonResponse(homeChartsFixture());
    }
    if (request.path == '/search/recent') {
      if (request.method == 'DELETE') {
        return jsonResponse({'cleared': true});
      }
      return jsonResponse([recentSearchFixture()]);
    }
    if (request.path == '/search/voice') {
      return jsonResponse(
        searchPageFixture(query: '${request.data['transcript']}'),
      );
    }
    if (request.path == '/search') {
      final query = '${request.queryParameters['q']}';
      if (query.contains('unknown')) {
        return jsonResponse(
          searchPageFixture(
            query: query,
            shows: const [],
            episodes: const [],
            playlists: const [],
          ),
        );
      }
      return jsonResponse(searchPageFixture(query: query));
    }
    if (request.path == '/directory/search') {
      return jsonResponse({
        'query': '${request.queryParameters['q'] ?? ''}',
        'candidates': const <Map<String, dynamic>>[],
      });
    }
    if (RegExp(r'^/shows/[^/]+/follow$').hasMatch(request.path)) {
      return jsonResponse({'following': true});
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('landing uses recent and charts instead of seeded names', (
    tester,
  ) async {
    await mount(tester, location: '/screen/search', adapter: adapter());
    expect(find.text('Popular Searches'), findsOneWidget);
    expect(find.text('The Honest Bunch'), findsNothing);
    expect(find.text('Technology'), findsWidgets);
    expect(find.text('Ranked Show'), findsOneWidget);
  });

  testWidgets('results bind server shows and keep people empty', (tester) async {
    await mount(tester, location: '/screen/search', adapter: adapter());
    await tester.enterText(find.byType(TextField), 'Owned');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Owned Show'), findsWidgets);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Owned Show'), findsWidgets);
    expect(find.text('Fresh episode'), findsOneWidget);
    expect(find.text('The Mindset Mentor'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'People'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'People'));
    await tester.pumpAndSettle();
    expect(find.text('People search is not available yet.'), findsOneWidget);
    expect(find.text('Rob Dial'), findsNothing);
  });

  testWidgets('empty query and voice stay honest', (tester) async {
    await mount(tester, location: '/screen/search', adapter: adapter());
    await tester.enterText(find.byType(TextField), 'unknown topic');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No matches for “unknown topic”'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voice search'));
    await tester.pumpAndSettle();
    expect(find.text('Listening...'), findsOneWidget);
    expect(find.text('Search for “mindset motivation”'), findsNothing);
    expect(
      find.text(
        'Voice capture is not available in this build. Type a search instead.',
      ),
      findsOneWidget,
    );
  });
}
