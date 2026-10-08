import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'support/api_adapter.dart';
import 'support/comment_fixture.dart';
import 'support/home_fixture.dart';

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
        GoRoute(
          path: '/screen/episode-comments',
          builder: (_, _) => const CommentThreadPage(
            type: CommentTargetType.episode,
            title: 'Episode Comments',
          ),
        ),
        GoRoute(
          path: '/screen/episode-comments-empty',
          builder: (_, _) => const CommentThreadPage(
            type: CommentTargetType.episode,
            title: 'Episode Comments',
            subtitle: 'Be the first to start this conversation',
            emptyCatalog: true,
          ),
        ),
        GoRoute(
          path: '/screen/episode-comment-replies',
          builder: (_, _) => const CommentRepliesPage(),
        ),
        GoRoute(
          path: '/screen/reel-comments',
          builder: (_, _) => const CommentThreadPage(
            type: CommentTargetType.reel,
            title: 'Reel Comments',
          ),
        ),
        GoRoute(
          path: '/screen/comment-report',
          builder: (_, _) => const CommentReportScreen(),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode')),
        ),
        GoRoute(
          path: '/screen/reels',
          builder: (_, _) => const Scaffold(body: Text('Reels')),
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
        homeDiscoverProvider.overrideWith(
          (ref) async => HomeDiscoverPage.fromApi(homeDiscoverFixture()),
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

  ApiAdapter commentsAdapter() => ApiAdapter((request) {
    if (request.path == '/comments' && request.method == 'POST') {
      final data =
          request.data is Map
              ? Map<String, dynamic>.from(request.data as Map)
              : const <String, dynamic>{};
      return jsonResponse(
        commentFixture(
          id: 'posted-1',
          body: '${data['body'] ?? ''}',
          authorName: 'Test user',
          authorHandle: 'test_user',
          isMine: true,
          parentId: data['parent_id'] as String?,
        ),
        status: 201,
      );
    }
    if (request.path == '/reports') {
      return jsonResponse({'id': 'report-1', 'state': 'open'}, status: 201);
    }
    final type = '${request.queryParameters['commentable_type']}';
    return jsonResponse(
      type == 'reel' ? reelCommentsFixture() : episodeCommentsFixture(),
    );
  });

  testWidgets('episode comments bind server authors instead of kemi', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/episode-comments',
      adapter: commentsAdapter(),
    );
    expect(find.text('Listener Ada'), findsOneWidget);
    expect(find.text('This episode is worth a second listen.'), findsOneWidget);
    expect(find.text('Kemi'), findsNothing);
    await tester.enterText(
      find.byType(TextField).last,
      'Listening again tonight.',
    );
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(find.text('Listening again tonight.'), findsOneWidget);
  });

  testWidgets('empty catalog comment row does not invent a thread', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/episode-comments-empty',
      adapter: commentsAdapter(),
    );
    expect(find.text('Be the first to comment'), findsOneWidget);
    expect(find.text('Listener Ada'), findsNothing);
  });

  testWidgets('replies stay unavailable without a selected comment', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/episode-comment-replies',
      adapter: commentsAdapter(),
    );
    expect(find.text('This comment is no longer available.'), findsOneWidget);
  });

  testWidgets('report does not claim success without a selected comment', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/comment-report',
      adapter: commentsAdapter(),
    );
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();
    expect(find.text('No comment is selected to report.'), findsOneWidget);
    expect(find.text('Report submitted'), findsNothing);
  });
}
