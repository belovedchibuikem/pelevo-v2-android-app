import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'support/api_adapter.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<void> mount(WidgetTester tester, ApiAdapter adapter) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/screen/profile-connected',
      routes: [
        GoRoute(
          path: '/screen/profile-connected',
          builder: (_, _) => const ProfileConnectedAccountsScreen(),
        ),
        GoRoute(
          path: '/screen/settings-account',
          builder: (_, _) => const Scaffold(body: Text('Settings')),
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
              accessToken: 'test-access',
              refreshToken: 'test-refresh',
              deviceId: 'test-device',
              user: {'id': 'test-user', 'name': 'Test user'},
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: PelevoTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty server list does not invent a Google email', (
    tester,
  ) async {
    var posted = false;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'POST') {
          posted = true;
          fail('Connect must not post a provider token');
        }
        return jsonResponse(
          <Map<String, dynamic>>[],
          meta: {'user_id': 'test-user'},
        );
      }),
    );
    expect(find.text('adesola@gmail.com'), findsNothing);
    expect(find.text('Not connected'), findsNWidgets(3));
    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Google linking is not available in this build'),
      findsOneWidget,
    );
    expect(posted, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Facebook'),
          matching: find.byType(Card),
        ),
        matching: find.text('Connect'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Facebook is not offered by the connected-accounts API'),
      findsOneWidget,
    );
  });

  testWidgets('linked Google uses the server email and disconnects on confirm', (
    tester,
  ) async {
    var accounts = [connectedAccountFixture()];
    var deleted = false;
    await mount(
      tester,
      ApiAdapter((request) {
        if (request.method == 'POST') {
          fail('Manage must not invent a new link');
        }
        if (request.method == 'DELETE') {
          expect(request.path, '/me/connected-accounts/acct-google');
          deleted = true;
          accounts = [];
          return jsonResponse({'disconnected': true});
        }
        return jsonResponse(accounts, meta: {'user_id': 'test-user'});
      }),
    );
    expect(find.text('google@example.invalid'), findsOneWidget);
    expect(find.text('adesola@gmail.com'), findsNothing);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Google?'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('Google disconnected'), findsOneWidget);
    expect(find.text('google@example.invalid'), findsNothing);
    expect(find.text('Not connected'), findsNWidgets(3));
  });

  testWidgets('failed load retries without a seeded account', (tester) async {
    var failed = true;
    await mount(
      tester,
      ApiAdapter((request) {
        if (failed) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(
          [connectedAccountFixture()],
          meta: {'user_id': 'test-user'},
        );
      }),
    );
    expect(find.text('google@example.invalid'), findsNothing);
    failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('google@example.invalid'), findsOneWidget);
  });
}
