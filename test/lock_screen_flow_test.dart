import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/app.dart';
import 'support/catalog_harness.dart';

void main() {
  testWidgets('lock settings bind preferences and privacy without seeds', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));

    pelevoRouter.go('/screen/lock-settings');
    await tester.pumpAndSettle();
    expect(find.text('Enable Lock Screen Notifications'), findsOneWidget);
    expect(find.text('Not available yet'), findsWidgets);
    expect(find.textContaining('OS lock'), findsWidgets);

    await tester.ensureVisible(find.text('Privacy Options'));
    await tester.tap(find.text('Privacy Options'));
    await tester.pumpAndSettle();
    expect(find.text('Show Title Only'), findsOneWidget);
    await tester.tap(find.text('Save Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Notification Types'), findsOneWidget);
  });

  testWidgets('lock alerts and history use server lists', (tester) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));

    pelevoRouter.go('/screen/lock-new-episode');
    await tester.pumpAndSettle();
    expect(find.text('New Episode Out Now!'), findsOneWidget);
    expect(
      find.textContaining('New episode from The Honest Bunch'),
      findsOneWidget,
    );
    expect(find.text('Ep. 125 - The Mindset Shift'), findsNothing);

    pelevoRouter.go('/screen/lock-download-complete');
    await tester.pumpAndSettle();
    expect(find.textContaining('authorized on your account'), findsOneWidget);
    expect(find.textContaining('Ready to listen offline'), findsNothing);

    pelevoRouter.go('/screen/lock-history');
    await tester.pumpAndSettle();
    expect(find.text('Server notification navigation'), findsOneWidget);
    expect(find.text('Download Complete'), findsNothing);
  });
}
