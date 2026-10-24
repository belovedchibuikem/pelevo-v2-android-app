import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/theme/pelevo_appearance.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a saved appearance selects light or dark', () async {
    SharedPreferences.setMockInitialValues({pelevoThemeModeKey: 'light'});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(pelevoThemeModeProvider), ThemeMode.light);
    await container
        .read(pelevoThemeModeProvider.notifier)
        .select(ThemeMode.dark);
    expect(container.read(pelevoThemeModeProvider), ThemeMode.dark);
    expect(preferences.getString(pelevoThemeModeKey), 'dark');
  });

  testWidgets('light theme paints the light page background', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PelevoTheme.light,
          home: const PelevoPage(
            scrollable: false,
            showMiniPlayer: false,
            child: Text('Light'),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      PelevoScheme.light.background,
    );
    expect(find.text('Light'), findsOneWidget);
  });

  testWidgets('dark theme keeps the dark page background', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PelevoTheme.dark,
          home: const PelevoPage(
            scrollable: false,
            showMiniPlayer: false,
            child: Text('Dark'),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      PelevoScheme.dark.background,
    );
  });
}
