import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/device_sync/device_sync_basic_screens.dart';
import 'package:pelevo/features/device_sync/device_sync_expanded_screens.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/device_sync_fixture.dart';
import 'support/library_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
  }) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in deviceSyncBasicScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        for (final spec in deviceSyncExpandedScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/permissions-intro',
          builder: (_, _) => const Scaffold(body: Text('Permissions')),
        ),
        GoRoute(
          path: '/screen/library-12',
          builder: (_, _) => const Scaffold(body: Text('Library settings')),
        ),
        GoRoute(
          path: '/screen/downloads-2',
          builder: (_, _) => const Scaffold(body: Text('Downloads')),
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

  ApiAdapter _adapter() => ApiAdapter((request) {
    if (request.path == '/me') return jsonResponse(profileFixture());
    if (request.path == '/devices') return jsonResponse([syncDeviceFixture()]);
    if (request.path == '/library') {
      return jsonResponse(libraryOverviewFixture());
    }
    if (request.path == '/storage') return jsonResponse(storageUsageFixture());
    if (request.path == '/downloads') {
      return jsonResponse([libraryDownloadFixture()]);
    }
    if (request.path == '/downloads/settings') {
      return jsonResponse(downloadSettingsFixture());
    }
    if (request.path == '/sync/pull') return jsonResponse([syncChangeFixture()]);
    if (request.path == '/sync/conflicts') {
      return jsonResponse([syncConflictFixture()]);
    }
    if (request.path == '/devices/pairing-code') {
      return jsonResponse(pairingCodeFixture(), status: 201);
    }
    if (request.path == '/devices/pair') {
      return jsonResponse({'paired': true}, status: 201);
    }
    if (request.path == '/devices/sign-out-all') {
      return jsonResponse({'signed_out': true});
    }
    if (RegExp(r'^/devices/[^/]+$').hasMatch(request.path) &&
        request.method == 'DELETE') {
      return jsonResponse({'revoked': true});
    }
    if (RegExp(r'^/sync/conflicts/[^/]+$').hasMatch(request.path) &&
        request.method == 'PUT') {
      return jsonResponse({'resolved': true});
    }
    if (request.path == '/backups' && request.method == 'POST') {
      return jsonResponse({
        'id': 'backup-1',
        'state': 'ready',
        'size_bytes': 12,
      }, status: 201);
    }
    if (RegExp(r'^/backups/[^/]+/restore$').hasMatch(request.path)) {
      return jsonResponse({'restored': true});
    }
    if (request.path == '/storage/cache' && request.method == 'DELETE') {
      return jsonResponse({'cleared': true});
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('home binds profile and keeps Sync is Active', (tester) async {
    await mount(
      tester,
      location: '/screen/device-sync-basic-1',
      adapter: _adapter(),
    );
    expect(find.text('Sync is Active'), findsOneWidget);
    expect(find.text('Test listener'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('1,248'), findsNothing);
  });

  testWidgets('my devices lists the server name', (tester) async {
    await mount(
      tester,
      location: '/screen/device-sync-basic-2',
      adapter: _adapter(),
    );
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
  });

  testWidgets('add device posts a pairing code', (tester) async {
    var posted = false;
    await mount(
      tester,
      location: '/screen/device-sync-basic-3',
      adapter: ApiAdapter((request) {
        if (request.path == '/me') return jsonResponse(profileFixture());
        if (request.path == '/devices') {
          return jsonResponse([syncDeviceFixture()]);
        }
        if (request.path == '/library') {
          return jsonResponse(libraryOverviewFixture());
        }
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture());
        }
        if (request.path == '/downloads/settings') {
          return jsonResponse(downloadSettingsFixture());
        }
        if (request.path == '/sync/pull') {
          return jsonResponse([syncChangeFixture()]);
        }
        if (request.path == '/sync/conflicts') {
          return jsonResponse([syncConflictFixture()]);
        }
        if (request.path == '/devices/pairing-code') {
          posted = true;
          return jsonResponse(
            pairingCodeFixture(code: 'QWER5678'),
            status: 201,
          );
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.tap(find.text('Get pairing code'));
    await tester.pumpAndSettle();
    expect(posted, isTrue);
    expect(find.text('QWER5678'), findsOneWidget);
  });

  testWidgets('expanded dashboard uses live device count without fake GB', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/sync-dashboard',
      adapter: _adapter(),
    );
    expect(find.text('1 registered'), findsOneWidget);
    expect(find.text('3.2 GB used'), findsNothing);
    expect(find.text('5 devices connected'), findsNothing);
    expect(find.text('Manage Devices'), findsWidgets);
  });

  testWidgets('expanded conflicts list server rows without inventing times', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/sync-conflicts',
      adapter: _adapter(),
    );
    expect(find.textContaining('playlist'), findsWidgets);
    expect(find.text('32:18 listened · Updated now'), findsNothing);
  });

  testWidgets('pairing screen posts pair and opens connected success', (
    tester,
  ) async {
    var paired = false;
    await mount(
      tester,
      location: '/screen/pairing-code',
      adapter: ApiAdapter((request) {
        if (request.path == '/devices') {
          return jsonResponse([syncDeviceFixture()]);
        }
        if (request.path == '/sync/pull') {
          return jsonResponse([syncChangeFixture()]);
        }
        if (request.path == '/sync/conflicts') {
          return jsonResponse([syncConflictFixture()]);
        }
        if (request.path == '/storage') {
          return jsonResponse(storageUsageFixture());
        }
        if (request.path == '/devices/pairing-code') {
          return jsonResponse(pairingCodeFixture(code: 'ABCD1234'), status: 201);
        }
        if (request.path == '/devices/pair') {
          paired = true;
          final data = Map<String, dynamic>.from(request.data as Map);
          expect(data['code'], 'ABCD1234');
          expect(data['device_identifier'], 'test-device');
          return jsonResponse({'paired': true}, status: 201);
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    await tester.enterText(find.byType(TextField), 'ABCD1234');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PelevoButton, 'Connect Device'));
    await tester.pumpAndSettle();
    expect(paired, isTrue);
    expect(find.text('Enter the full 8-character pairing code.'), findsNothing);
    expect(find.text('Successfully paired'), findsNothing);
  });
}
