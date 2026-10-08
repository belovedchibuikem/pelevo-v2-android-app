import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/share_cards/share_card_export.dart';
import 'package:pelevo/features/share_cards/share_card_screens.dart';
import 'support/api_adapter.dart';
import 'support/catalog_fixture.dart';
import 'support/cms_fixture.dart';
import 'support/fake_share_card_exporter.dart';
import 'support/share_card_fixture.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    required String location,
    required ApiAdapter adapter,
    FakeShareCardExporter? exporter,
  }) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData' ||
              call.method == 'Clipboard.getData') {
            return null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final spec in shareCardScreens)
          GoRoute(
            path: '/screen/${spec.id}',
            builder: (context, _) => spec.builder(context),
          ),
        GoRoute(
          path: '/screen/home-feed',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/screen/episode-details',
          builder: (_, _) => const Scaffold(body: Text('Episode')),
        ),
        GoRoute(
          path: '/screen/podcast-details',
          builder: (_, _) => const Scaffold(body: Text('Podcast')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => dio.close(force: true));
    final fakeExporter = exporter ?? FakeShareCardExporter();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        shareCardExporterProvider.overrideWithValue(fakeExporter),
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
    return container;
  }

  ApiAdapter shareAdapter() => ApiAdapter((request) {
    if (request.path == '/episodes/$catalogEpisodeId') {
      return jsonResponse(catalogEpisodeFixture(detailed: true));
    }
    if (request.path == '/shows/$catalogShowId/episodes') {
      return jsonResponse(catalogEpisodesFixture(), meta: {'has_more': false});
    }
    if (request.path == '/stats/me') {
      return jsonResponse(catalogStatsFixture());
    }
    if (request.path == '/share-card-templates') {
      return jsonResponse([shareCardTemplateFixture()]);
    }
    if (request.path == '/share-cards') {
      if (request.method == 'POST') {
        final data =
            request.data is Map
                ? Map<String, dynamic>.from(request.data as Map)
                : const <String, dynamic>{};
        expect(data['template_id'], shareCardTemplateId);
        expect(data['subject_type'], 'episode');
        expect(data['subject_id'], catalogEpisodeId);
        return jsonResponse(shareCardFixture(), status: 201);
      }
      return jsonResponse([shareCardFixture()]);
    }
    if (RegExp(r'^/share-cards/[^/]+$').hasMatch(request.path)) {
      return jsonResponse(
        shareCardDetailFixture(id: request.path.split('/').last),
      );
    }
    if (request.path == '/cms/guidelines') {
      return jsonResponse(cmsFixture('guidelines'));
    }
    throw StateError('${request.method} ${request.path}');
  });

  testWidgets('home create uses catalog episode titles and posts a card', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/share-card-home',
      adapter: shareAdapter(),
    );
    expect(find.text('Create New Card'), findsOneWidget);
    expect(find.text('The Mindset Shift'), findsNothing);
    await tester.tap(find.text('Create New Card'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);

    await tester.tap(find.text('Ep. 124 - The Shift Life').first);
    await tester.pumpAndSettle();
    expect(find.text('QR Code'), findsOneWidget);
    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PelevoButton, 'Save Card'));
    await tester.pumpAndSettle();
    expect(find.text('Share Card'), findsOneWidget);

    await tester.tap(find.widgetWithText(PelevoButton, 'Share Card'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Copy Link'));
    await tester.pumpAndSettle();
    expect(find.text('Share link copied'), findsWidgets);
    expect(find.text('Opening WhatsApp'), findsNothing);
  });

  testWidgets('export shares a captured PNG', (tester) async {
    final exporter = FakeShareCardExporter();
    await mount(
      tester,
      location: '/screen/share-card-export',
      adapter: shareAdapter(),
      exporter: exporter,
    );
    final button = tester.widget<PelevoButton>(
      find.widgetWithText(PelevoButton, 'Export'),
    );
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(exporter.captureCount, 1);
    expect(exporter.shareImageCount, 1);
  });

  testWidgets('share options capture and open the system share sheet', (
    tester,
  ) async {
    final exporter = FakeShareCardExporter();
    await mount(
      tester,
      location: '/screen/share-card-share-options',
      adapter: shareAdapter(),
      exporter: exporter,
    );
    final inkWell = tester.widget<InkWell>(
      find.byKey(const ValueKey('share-app-WhatsApp')),
    );
    inkWell.onTap!();
    await tester.pumpAndSettle();
    expect(exporter.captureCount, 1);
    expect(exporter.shareImageCount, 1);
    expect(find.text('Opening WhatsApp'), findsNothing);
  });

  testWidgets('download writes gallery through the exporter', (tester) async {
    final exporter = FakeShareCardExporter();
    await mount(
      tester,
      location: '/screen/share-card-download',
      adapter: shareAdapter(),
      exporter: exporter,
    );
    await tester.tap(find.widgetWithText(PelevoButton, 'Download'));
    await tester.pumpAndSettle();
    expect(exporter.captureCount, 1);
    expect(exporter.galleryCount, 1);
    expect(find.text('Saved Successfully!'), findsOneWidget);
    expect(
      find.text('Saving an image to your gallery is not offered.'),
      findsNothing,
    );
  });

  testWidgets('guidelines load published CMS content without local tips', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/share-card-guidelines',
      adapter: shareAdapter(),
    );
    expect(find.text('Use high contrast colors for clarity.'), findsOneWidget);
    expect(find.text('Keep text short'), findsOneWidget);
    expect(find.text('Keep captions brief and impactful.'), findsOneWidget);
    expect(find.text('Add your personal touch with branding'), findsNothing);
  });

  testWidgets('analytics counts real events and does not invent totals', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/screen/share-card-analytics',
      adapter: shareAdapter(),
    );
    expect(find.text('128'), findsNothing);
    expect(find.text('64'), findsNothing);
    expect(find.text('The Mindset Shift'), findsNothing);
    expect(find.text('Total Shares'), findsOneWidget);
  });
}
