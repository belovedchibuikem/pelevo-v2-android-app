import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/ai/ai_data.dart';
import 'package:pelevo/features/ai/ai_hub_screens.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'support/ai_fixture.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';

void main() {
  Future<ProviderContainer> mount(
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
        for (final spec in aiHubScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/library-1',
          builder: (_, _) => const Scaffold(body: Text('Library')),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/screen/podcast-details',
          builder: (_, _) => const Scaffold(body: Text('Podcast')),
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
        selectedEpisodeIdProvider.overrideWith(CatalogHarnessEpisodeId.new),
        selectedShowIdProvider.overrideWith(CatalogHarnessShowId.new),
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
    return container;
  }

  testWidgets(
    'summary generate waits for a queued job and keeps Topics Covered',
    (tester) async {
      await mount(
        tester,
        location: '/screen/ai-summary',
        adapter: ApiAdapter((request) {
          if (request.path == '/episodes/$catalogEpisodeId') {
            return jsonResponse(catalogEpisodeFixture(detailed: true));
          }
          if (request.path == '/ai/jobs' && request.method == 'POST') {
            return jsonResponse(aiJobFixture(), status: 202);
          }
          if (request.path == '/ai/jobs/$aiJobId') {
            return jsonResponse(
              aiJobFixture(
                state: 'completed',
                outputText: 'Queued jobs return text when complete.',
              ),
            );
          }
          throw StateError('${request.method} ${request.path}');
        }),
      );
      await tester.tap(find.widgetWithText(PelevoButton, 'Generate Summary'));
      await tester.pumpAndSettle();
      expect(find.text('Topics Covered'), findsOneWidget);
      expect(
        find.text('Queued jobs return text when complete.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Honesty is the first real shift'),
        findsNothing,
      );
    },
  );

  testWidgets('recommendations bind server reasons instead of match percents', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/ai-generating',
      adapter: ApiAdapter((request) {
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        if (request.path == '/home/recommendations') {
          return jsonResponse(aiRecommendationsFixture());
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('From your listening history'), findsOneWidget);
    expect(find.text('88% Match'), findsNothing);
    expect(find.text('Tea with Tay'), findsNothing);
  });

  testWidgets('ask result keeps the question and does not invent an answer', (
    tester,
  ) async {
    final container = await mount(
      tester,
      location: '/screen/ai-ask',
      adapter: ApiAdapter((request) {
        if (request.path == '/episodes/$catalogEpisodeId') {
          return jsonResponse(catalogEpisodeFixture(detailed: true));
        }
        if (request.path == '/ai/ask' && request.method == 'POST') {
          return jsonResponse(aiAskFixture());
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    container
        .read(selectedAiQuestionProvider.notifier)
        .set('Something thoughtful about growth');
    await tester.tap(find.text('Something thoughtful about growth'));
    await tester.pumpAndSettle();
    expect(find.text('Ask another question'), findsOneWidget);
    expect(
      find.textContaining('These picks use that request and your history.'),
      findsOneWidget,
    );
    expect(find.text('Ask AI is not offered as a job type.'), findsNothing);
  });
}
