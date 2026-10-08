import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/notification_screens.dart';
import 'package:pelevo/features/profile/account_feed.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'support/api_adapter.dart';
import 'support/account_feed_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ApiAdapter adapter, {
    String screen = 'notifications-1',
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/screen/$screen',
      routes: [
        GoRoute(
          path: '/screen/profile-following',
          builder: (_, _) => const ProfileFollowingScreen(),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode details')),
        ),
        for (final spec in notificationScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
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
    await tester.pumpAndSettle();
  }

  testWidgets(
    'inbox reads real counts and cursor pages without duplicate rows',
    (tester) async {
      await mount(
        tester,
        ApiAdapter((request) {
          expect(request.path, '/notifications');
          if (request.queryParameters['cursor'] == 'next-page') {
            return feedResponse([
              notificationFixture('one'),
              notificationFixture('two'),
            ], unread: 2);
          }
          return feedResponse(
            [notificationFixture('one')],
            cursor: 'next-page',
            unread: 2,
          );
        }),
      );
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(find.text('Server notification one'), findsOneWidget);
      expect(find.text('Ep. 124 - The Shift Life'), findsNothing);
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Server notification one'), findsOneWidget);
      expect(find.text('Server notification two'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
  );

  testWidgets('read waits for the receipt before showing the stored message', (
    tester,
  ) async {
    final pending = Completer<ResponseBody>();
    var read = false;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'PUT') {
          expect(request.path, '/notifications/one/read');
          return pending.future;
        }
        return feedResponse([
          notificationFixture('one', read: read),
        ], unread: read ? 0 : 1);
      }),
    );
    await tester.tap(find.text('Server notification one'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    read = true;
    pending.complete(jsonResponse({'read': true}));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Unread (0)'), findsOneWidget);
  });

  testWidgets('load failure shows retry without fabricating an empty inbox', (
    tester,
  ) async {
    var attempt = 0;
    await mount(
      tester,
      ApiAdapter((request) {
        if (++attempt == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return feedResponse([]);
      }),
    );
    expect(find.text('No notifications to show.'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications to show.'), findsOneWidget);
  });

  testWidgets(
    'following requires confirmation and retains rows after failed unfollow',
    (tester) async {
      var writes = 0;
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.method == 'DELETE') {
            writes++;
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
          return feedResponse([followedShowFixture('one')]);
        }),
        screen: 'profile-following',
      );
      expect(find.text('Server show one'), findsOneWidget);
      expect(find.text('Jay Shetty'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Following'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.text('Unfollow'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Server show one'), findsOneWidget);
      expect(find.text('Unfollowed Server show one'), findsNothing);
    },
  );

  testWidgets('selected notifications send only chosen server IDs', (
    tester,
  ) async {
    Set<String>? ids;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'POST') {
          expect(request.path, '/notifications/bulk');
          expect(request.data['action'], 'read');
          ids = Set<String>.from(request.data['ids']);
          return jsonResponse({'action': 'read', 'ids': ids!.toList()});
        }
        return feedResponse([
          notificationFixture('one'),
          notificationFixture('two'),
        ], unread: 2);
      }),
      screen: 'notifications-10',
    );
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((box) => box.value == false),
      isTrue,
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Mark as Read'));
    await tester.pumpAndSettle();
    expect(ids, {'one'});
  });

  testWidgets('clear confirmation sends a real request before navigating', (
    tester,
  ) async {
    var cleared = false;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.path == '/notifications/clear') {
          expect(request.data['confirmed'], true);
          cleared = true;
          return jsonResponse({'cleared': true, 'count': 1});
        }
        return feedResponse(cleared ? [] : [notificationFixture('one')]);
      }),
      screen: 'notifications-11',
    );
    expect(cleared, isFalse);
    await tester.ensureVisible(find.text('Clear All'));
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('No notifications to show.'), findsOneWidget);
  });

  testWidgets('new episode uses the stored alert instead of invented copy', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) {
        expect(request.queryParameters['view'], 'new_episode');
        return feedResponse([
          notificationFixture(
            'new-episode',
            type: 'new_episode',
            title: 'New episode from The Honest Bunch',
            body: 'A published episode is available.',
            data: {'episode_id': 'ep-1', 'show_id': 'show-1'},
          ),
        ]);
      }),
      screen: 'notifications-3',
    );
    expect(find.text('New episode from The Honest Bunch'), findsOneWidget);
    expect(find.text('Ep. 125 - Stay Motivated'), findsNothing);
    await tester.tap(find.text('Play Now'));
    await tester.pumpAndSettle();
    expect(find.text('Episode details'), findsOneWidget);
  });

  testWidgets('inbox episode alerts open the episode instead of a dialog', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'PUT') {
          expect(request.path, '/notifications/one/read');
          return jsonResponse({'read': true});
        }
        return feedResponse([
          notificationFixture(
            'one',
            type: 'new_episode',
            title: 'New episode from The Honest Bunch',
            body: 'A published episode is available.',
            data: {'episode_id': 'ep-1', 'show_id': 'show-1'},
          ),
        ], unread: 1);
      }),
    );
    await tester.tap(find.text('New episode from The Honest Bunch'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Episode details'), findsOneWidget);
  });

  testWidgets('promotions bind broadcast rows instead of invented offers', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) {
        expect(request.queryParameters['view'], 'broadcast');
        return feedResponse([
          notificationFixture(
            'broadcast',
            type: 'broadcast',
            title: 'Server broadcast navigation',
            body: 'Stored broadcast navigation',
          ),
        ]);
      }),
      screen: 'notifications-9',
    );
    expect(find.text('Server broadcast navigation'), findsOneWidget);
    expect(find.text('Premium Offer'), findsNothing);
    expect(find.text('Explore Now'), findsOneWidget);
  });

  test('malformed list records are rejected', () async {
    final dio =
        Dio()
          ..httpClientAdapter = ApiAdapter(
            (_) => feedResponse([
              {'id': 'bad'},
            ]),
          );
    addTearDown(dio.close);
    await expectLater(
      AccountFeedRepository(dio).page(AccountFeed.all),
      throwsException,
    );
  });
}
