import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/player/pelevo_mini_player.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

class _NowPlayingEpisode extends NowPlayingEpisodeNotifier {
  @override
  CatalogEpisode? build() => _episode;
}

const _episode = CatalogEpisode(
  id: 'ep-1',
  showId: 'show-1',
  title: 'Hold to Close Episode',
  showTitle: 'Hold Show',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() => ProviderContainer(
    overrides: [
      nowPlayingEpisodeProvider.overrideWith(_NowPlayingEpisode.new),
      catalogEpisodeByIdProvider.overrideWith((ref, id) async => _episode),
      pelevoMediaItemProvider.overrideWith((ref) => Stream.value(null)),
      pelevoIsPlayingProvider.overrideWith((ref) => Stream.value(false)),
    ],
  );

  Future<void> mount(
    WidgetTester tester, {
    required ProviderContainer providers,
    required String label,
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PelevoPage(
            bottomNavigationBar: SizedBox(
              height: 56,
              child: ColoredBox(
                color: PelevoColors.background,
                child: Center(child: Text(label)),
              ),
            ),
            child: Text('$label body'),
          ),
        ),
        GoRoute(
          path: '/screen/player-now-playing',
          builder: (_, _) => const Scaffold(body: Text('Full player')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp.router(
          theme: PelevoTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('long-press reveals close and dismisses mini-player on every screen', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await mount(tester, providers: providers, label: 'Home');

    expect(find.byType(PelevoMiniPlayer), findsOneWidget);
    expect(find.text('Hold to Close Episode'), findsOneWidget);
    expect(find.text('Close'), findsNothing);

    await tester.longPress(find.text('Hold to Close Episode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Hold to Close Episode'), findsNothing);
    expect(providers.read(miniPlayerDismissedProvider), isTrue);

    await mount(tester, providers: providers, label: 'Search');
    expect(find.text('Search body'), findsOneWidget);
    expect(find.text('Hold to Close Episode'), findsNothing);
  });

  testWidgets('swipe left holds the close option on the mini-player', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await mount(tester, providers: providers, label: 'Library');

    expect(find.text('Close'), findsNothing);
    await tester.drag(find.text('Hold to Close Episode'), const Offset(-80, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Close'), findsOneWidget);
  });
}
