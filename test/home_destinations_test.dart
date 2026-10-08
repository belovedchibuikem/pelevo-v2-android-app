import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/home/home_screens.dart';
import 'support/home_fixture.dart';

void main() {
  testWidgets('discover keeps section chrome after a failed load can retry', (
    tester,
  ) async {
    var allowSuccess = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDiscoverProvider.overrideWith((ref) async {
            if (!allowSuccess) {
              throw const ApiFailure(
                code: 'NETWORK',
                message: 'Home content could not be loaded. Please try again.',
              );
            }
            return HomeDiscoverPage.fromApi(homeDiscoverFixture());
          }),
        ],
        child: MaterialApp(
          theme: PelevoTheme.dark,
          home: const DiscoverScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Home content could not be loaded. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Editors Picks'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    allowSuccess = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Editors Picks'), findsOneWidget);
    expect(find.text('Voices desk'), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Fresh episode'), findsWidgets);
  });

  testWidgets('charts music tab stays empty when the catalog has no titles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeChartsProvider.overrideWith(
            (ref) async => HomeChartsPage.fromApi({
              'podcasts': const [],
              'music': const [],
              'audiobooks': const [],
            }),
          ),
        ],
        child: MaterialApp(
          theme: PelevoTheme.dark,
          home: const ChartsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('AfroBeats Now'), findsNothing);
    expect(
      find.text('No titles are ranked in this catalog yet.'),
      findsOneWidget,
    );
  });
}
