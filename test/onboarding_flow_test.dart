import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/onboarding/entry_flow_screens.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:pelevo/features/permissions/permission_screens.dart';
import 'support/api_adapter.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    required ApiAdapter adapter,
    required OnboardingProgressStore store,
    AuthSession session = const AuthSession(),
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/interests',
      routes: [
        GoRoute(
          path: '/interests',
          builder: (_, _) => const InterestsScreen(),
        ),
        GoRoute(
          path: '/screen/auth-sign-in',
          builder: (_, _) => const Scaffold(body: Text('Welcome back')),
        ),
        GoRoute(
          path: '/screen/permissions-intro',
          builder: (_, _) => const PermissionIntroScreen(),
        ),
        GoRoute(
          path: '/screen/home-feed',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        onboardingProgressStoreProvider.overrideWithValue(store),
        initialAuthSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: PelevoTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  const signedIn = AuthSession(
    accessToken: 'test',
    refreshToken: 'refresh',
    deviceId: 'device',
    user: {'id': 'test-user', 'name': 'Listener'},
  );

  testWidgets(
    'unsigned Get Started stores the draft and opens sign in',
    (tester) async {
      final store = MemoryOnboardingProgressStore();
      await mount(
        tester,
        adapter: ApiAdapter((request) => jsonResponse({})),
        store: store,
      );

      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(await store.hasSeenIntroduction(), isTrue);
      final draft = await store.readDraft();
      expect(draft?.interests, containsAll(['News', 'Culture', 'Technology']));
      expect(draft?.locale, 'en');
    },
  );

  testWidgets(
    'authenticated failure keeps the draft on the existing interests screen',
    (tester) async {
      final store = MemoryOnboardingProgressStore();
      await mount(
        tester,
        adapter: ApiAdapter(
          (request) => throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          ),
        ),
        store: store,
        session: signedIn,
      );

      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('What do you love\nlistening to?'), findsOneWidget);
      expect(
        find.textContaining('You appear to be offline'),
        findsOneWidget,
      );
      expect(await store.readDraft(), isNotNull);
      expect(find.text('Get Started'), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated success clears the draft and continues setup',
    (tester) async {
      final store = MemoryOnboardingProgressStore();
      await mount(
        tester,
        adapter: ApiAdapter((request) {
          expect(request.path, '/me/onboarding');
          return jsonResponse({
            'user_id': 'test-user',
            'onboarded': true,
            'interests': ['News', 'Culture', 'Technology'],
            'locale': 'en',
          });
        }),
        store: store,
        session: signedIn,
      );

      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text("Let's get you set up"), findsOneWidget);
      expect(await store.readDraft(), isNull);
    },
  );
}
