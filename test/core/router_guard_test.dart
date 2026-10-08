import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import '../support/api_adapter.dart';

void main() {
  testWidgets(
    'signed-out content links preserve their destination through sign-in',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: PelevoApp()));
      pelevoRouter.go('/screen/library-1');
      await tester.pumpAndSettle();
      final uri = pelevoRouter.routeInformationProvider.value.uri;
      expect(uri.path, '/screen/auth-sign-in');
      expect(uri.queryParameters['from'], '/screen/library-1');
    },
  );

  testWidgets('local prototype claim cannot grant publishing access', (
    tester,
  ) async {
    PodcastCreatorService.instance.claim();
    addTearDown(PodcastCreatorService.instance.resetForTesting);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = ApiAdapter((request) {
        if (request.path == '/me/onboarding') {
          return jsonResponse({'user_id': 'listener', 'completed': true});
        }
        return jsonResponse(<String, dynamic>{});
      });
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
              user: {
                'id': 'listener',
                'name': 'Listener',
                'capabilities': {'creator_access': false},
              },
            ),
          ),
        ],
        child: const PelevoApp(),
      ),
    );
    pelevoRouter.go('/screen/reels-upload');
    await tester.pump();
    expect(
      pelevoRouter.routeInformationProvider.value.uri.path,
      '/screen/claim-podcast',
    );
  });
}
