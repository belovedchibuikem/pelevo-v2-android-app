import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'support/catalog_harness.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/earn/earn_screens.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('catalog contains every supplied design state', () {
    if (const bool.fromEnvironment('PELEVO_EXPORT_INVENTORY')) {
      stdout.writeln(
        'PELEVO_INVENTORY:${jsonEncode([
          for (final screen in pelevoScreens) {'id': screen.id, 'section': screen.section, 'title': screen.title},
        ])}',
      );
    }
    expect(pelevoScreens, hasLength(350));
    expect(pelevoScreens.map((screen) => screen.id).toSet(), hasLength(350));
    final screenIds = pelevoScreens.map((screen) => screen.id).toSet();
    expect(screenIds.contains('creator-tax-information'), isFalse);
    expect(screenIds.contains('creator-payout-currency'), isFalse);
    expect(screenIds.contains('creator-payout-schedule'), isFalse);
  });

  test('every literal screen route targets a registered screen', () {
    final registered = pelevoScreens.map((screen) => screen.id).toSet();
    final referenced = <String>{};
    final routePattern = RegExp(r'''/screen/([^'"\s)]+)''');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in routePattern.allMatches(entity.readAsStringSync())) {
        referenced.add(match.group(1)!);
      }
    }

    final literalRoutes =
        referenced
            .where((id) => !id.contains(r'$') && !id.startsWith(':'))
            .toSet();
    expect(literalRoutes.difference(registered), isEmpty);
  });

  test('interactive callbacks are not empty', () {
    final emptyCallback = RegExp(
      r'(onPressed|onTap|onChanged|onDateChanged):\s*'
      r'(\(\)\s*\{\s*\}|\(_\)\s*\{\s*\})',
      multiLine: true,
    );
    final inactive = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (emptyCallback.hasMatch(entity.readAsStringSync())) {
        inactive.add(entity.path);
      }
    }

    expect(inactive, isEmpty);
  });

  testWidgets('onboarding starts at splash and advances', (tester) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    expect(find.text('Podcasts\nBuilt Around You'), findsOneWidget);

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Listen In\nYour Language'), findsOneWidget);

    for (final expected in [
      'AI Powered\nDiscovery',
      'Your World,\nYour Networks',
      'What do you love\nlistening to?',
    ]) {
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'authentication validates inputs and advances after API success',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const CatalogHarness());
      await tester.pumpAndSettle();
      pelevoRouter.go('/screen/auth-create-account');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your full name'),
        'Test Listener',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your email'),
        'listener@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'letters, numbers, _ or - (no @)'),
        'listener',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Create a password'),
        'Correct-Horse-9!',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm your password'),
        'Correct-Horse-9!',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final createButton = find.widgetWithText(FilledButton, 'Create Account');
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
      tester.widget<FilledButton>(createButton).onPressed!.call();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('listener@example.com'), findsWidgets);

      pelevoRouter.go('/screen/auth-sign-in');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Enter a valid email and password'), findsOneWidget);

      pelevoRouter.go('/screen/auth-forgot-password');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your email address'),
        'listener@example.com',
      );
      await tester.ensureVisible(find.text('Send Reset Code'));
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter new password'),
        'New-Password-9!',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new password'),
        'New-Password-9!',
      );
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Password updated'), findsOneWidget);
    },
  );

  testWidgets(
    'permission education allows skipping OS prompts and completing setup',
    (tester) async {
      await tester.pumpWidget(const CatalogHarness());
      pelevoRouter.go('/screen/permissions-intro');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Stay in the loop'), findsOneWidget);

      for (final actionAndTitle in [
        ('Not Now', 'Voice Search'),
        ('Not Now', 'Downloads'),
        ('Not Now', 'Background Playback'),
        ('Not Now', 'Connect Devices'),
        ('Not Now', "You're all set!"),
      ]) {
        await tester.ensureVisible(find.text(actionAndTitle.$1));
        await tester.tap(find.text(actionAndTitle.$1));
        await tester.pumpAndSettle();
        expect(find.text(actionAndTitle.$2), findsOneWidget);
      }

      await tester.tap(find.text('Finish Setup'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Continue Listening'), findsOneWidget);
    },
  );

  testWidgets('Home actions open notifications and bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/home-feed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Earn'), findsWidgets);
    expect(find.text('Reels'), findsWidgets);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Test listener'), findsOneWidget);

    pelevoRouter.go('/screen/home-feed');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);

    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsWidgets);
  });

  testWidgets('Search links typing, voice, filters, and content results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/search');
    await tester.pumpAndSettle();

    expect(find.text('Popular Searches'), findsOneWidget);
    await tester.tap(find.byTooltip('Voice search'));
    await tester.pumpAndSettle();
    expect(find.text('Listening...'), findsOneWidget);
    expect(find.text('Search for “mindset motivation”'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    pelevoRouter.go('/screen/search-filters');
    await tester.pumpAndSettle();
    expect(find.text('Narrow your results'), findsOneWidget);

    await tester.ensureVisible(find.text('Show results'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();
    expect(find.text('Podcasts'), findsWidgets);
  });

  testWidgets('Browse links categories, collection detail, and filters', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/browse');
    await tester.pumpAndSettle();

    expect(find.text('Featured Collections'), findsOneWidget);
    await tester.tap(find.text('See All').first);
    await tester.pumpAndSettle();
    expect(find.text('Explore every topic'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Music Collections'), findsWidgets);

    pelevoRouter.go('/screen/browse-search');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search browse catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Filter Collections'), findsOneWidget);
  });

  testWidgets('Podcast details links episodes, player, queue, and share', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/podcast-details');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('Play Latest'), findsOneWidget);

    await tester.ensureVisible(find.text('Play Latest'));
    await tester.tap(find.text('Play Latest'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsOneWidget);

    pelevoRouter.go('/screen/podcast-episodes');
    await tester.pumpAndSettle();
    expect(find.text('All Episodes'), findsOneWidget);

    pelevoRouter.go('/screen/podcast-notifications');
    await tester.pumpAndSettle();
    expect(find.text('Play Next'), findsOneWidget);

    pelevoRouter.go('/screen/podcast-details');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share'));
    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('Share Card'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('Episode details links play, queue, share, and options', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/episode-details');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Play Episode'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    await tester.ensureVisible(find.text('more'));
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    expect(find.text('In this episode:'), findsOneWidget);

    pelevoRouter.go('/screen/episode-details');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add to Queue'));
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();
    expect(find.text('Added to queue'), findsOneWidget);
    expect(find.text('Play Episode'), findsOneWidget);

    pelevoRouter.go('/screen/episode-details');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share'));
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('Share Card'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);

    pelevoRouter.go('/screen/episode-unavailable');
    await tester.pumpAndSettle();
    expect(find.text('Go to Show'), findsOneWidget);
  });

  testWidgets('Player experience links chapters, queue, share, and options', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/player-now-playing');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('PLAYING FROM'), findsOneWidget);
    expect(find.text('Ep. 124 - The Shift Life'), findsWidgets);

    await tester.ensureVisible(find.text('Chapters'));
    await tester.tap(find.text('Chapters'));
    await tester.pumpAndSettle();
    expect(find.text('Introduction'), findsOneWidget);

    pelevoRouter.go('/screen/player-now-playing');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Comments'));
    await tester.tap(find.text('Comments'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Comments ·'), findsOneWidget);
    await tester.tap(find.byTooltip('Close comments'));
    await tester.pumpAndSettle();

    pelevoRouter.go('/screen/player-now-playing');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Queue'));
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(find.text('Up Next'), findsOneWidget);

    pelevoRouter.go('/screen/player-video');
    await tester.pumpAndSettle();
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('Share Card'), findsOneWidget);

    pelevoRouter.go('/screen/player-offline');
    await tester.pumpAndSettle();
    expect(find.text('Mark as Played'), findsOneWidget);
  });

  testWidgets('Queue links edit, clear, options, and history', (tester) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/queue-up-next');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Up Next · 1 Episode'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Queue'), findsOneWidget);

    pelevoRouter.go('/screen/queue-clear-confirm');
    await tester.pumpAndSettle();
    expect(find.text('Clear Your Queue?'), findsOneWidget);

    pelevoRouter.go('/screen/queue-empty');
    await tester.pumpAndSettle();
    expect(find.text('Your queue is empty'), findsOneWidget);
    expect(find.text('Browse Podcasts'), findsOneWidget);

    pelevoRouter.go('/screen/queue-sync');
    await tester.pumpAndSettle();
    expect(find.text('Shuffle Queue'), findsOneWidget);

    pelevoRouter.go('/screen/queue-history');
    await tester.pumpAndSettle();
    expect(find.text('Clear History'), findsOneWidget);
  });

  testWidgets('Podcast stats links overview metrics and detail screens', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/stats-overview');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('2 min'), findsWidgets);
    expect(find.text('Continue Listening'), findsOneWidget);

    await tester.ensureVisible(find.text('Longest Streak'));
    await tester.tap(find.text('Longest Streak'));
    await tester.pumpAndSettle();
    expect(find.text('Current Streak — Keep it up!'), findsOneWidget);

    pelevoRouter.go('/screen/stats-overview');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Episodes Played'));
    await tester.tap(find.text('Episodes Played'));
    await tester.pumpAndSettle();
    expect(find.text('By Status'), findsOneWidget);

    pelevoRouter.go('/screen/stats-share');
    await tester.pumpAndSettle();
    expect(find.text('Share Comparison'), findsOneWidget);
  });

  testWidgets('AI Hub keeps Ask Pelevo, lineup, and recommender', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    pelevoRouter.go('/screen/ai-hub');
    await tester.pumpAndSettle();

    expect(find.text('Ask Pelevo'), findsOneWidget);
    expect(find.text('Your Podcast Lineup'), findsOneWidget);
    expect(find.text('AI Podcast Recommender'), findsOneWidget);
    expect(find.text('Smart Summary'), findsNothing);
    expect(find.text('Chapters Generator'), findsNothing);
    expect(find.text('Highlights Finder'), findsNothing);
    expect(find.text('Ask AI'), findsNothing);

    await tester.ensureVisible(find.text('AI Podcast Recommender'));
    await tester.tap(find.text('AI Podcast Recommender'));
    await tester.pumpAndSettle();
    expect(find.text('Generate Recommendations'), findsOneWidget);

    pelevoRouter.go('/screen/ai-hub');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Pelevo'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested Questions'), findsOneWidget);

    await tester.tap(find.text('Something thoughtful about growth'));
    await tester.pumpAndSettle();
    expect(find.text('Ask another question'), findsOneWidget);
  });

  testWidgets('Library links playlists, downloads, and AI Hub', (tester) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/library-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Playlists'), findsOneWidget);
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('Mindset & Growth'), findsOneWidget);

    await tester.tap(find.text('Mindset & Growth'));
    await tester.pumpAndSettle();
    expect(find.text('Play All'), findsOneWidget);

    pelevoRouter.go('/screen/library-1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI Hub'));
    await tester.tap(find.text('AI Hub'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Pelevo'), findsOneWidget);
  });

  testWidgets('Notifications links settings, details, and selection', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness(signedIn: true));
    pelevoRouter.go('/screen/notifications-1');
    await tester.pumpAndSettle();

    expect(find.text('Server notification navigation'), findsOneWidget);
    await tester.tap(find.byTooltip('Notification settings'));
    await tester.pumpAndSettle();
    expect(find.text('Push Notifications'), findsOneWidget);

    await tester.ensureVisible(find.text('Notification Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Save Preferences'), findsOneWidget);

    pelevoRouter.go('/screen/notifications-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Server notification navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Stored message navigation'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    pelevoRouter.go('/screen/notifications-1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Select'));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as Read'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Downloads links settings, storage, episodes, and actions', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/downloads-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('1\nFiles'), findsOneWidget);
    await tester.tap(find.byTooltip('Download settings'));
    await tester.pumpAndSettle();
    expect(find.text('Download Over Wi-Fi Only'), findsOneWidget);

    await tester.ensureVisible(find.text('Download Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Location'));
    await tester.pumpAndSettle();
    expect(find.text('Internal Storage'), findsOneWidget);
    expect(find.text('Change Location'), findsOneWidget);

    pelevoRouter.go('/screen/downloads-2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ep. 124 - The Shift Life'));
    await tester.pumpAndSettle();
    expect(find.text('Play Episode'), findsOneWidget);
    expect(find.text('Remove Download'), findsOneWidget);

    pelevoRouter.go('/screen/downloads-7');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Select Multiple'));
    await tester.tap(find.text('Select Multiple'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Downloads'), findsOneWidget);
  });

  testWidgets('Device sync links devices, pairing, settings, and dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/device-sync-basic-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('Sync is Active'), findsOneWidget);
    await tester.ensureVisible(find.text('Manage Devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Devices'));
    await tester.pumpAndSettle();
    expect(find.text('iPhone 15 Pro'), findsOneWidget);

    await tester.tap(find.byTooltip('Add device'));
    await tester.pumpAndSettle();
    expect(find.text('Connect a new device'), findsOneWidget);
    await tester.tap(find.text('Scan QR Code'));
    await tester.pumpAndSettle();
    expect(find.text('Pair a device'), findsWidgets);

    pelevoRouter.go('/screen/sync-dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Account sync'), findsWidgets);
    await tester.tap(find.text('Manage Devices').first);
    await tester.pumpAndSettle();
    expect(find.text('Connected devices'), findsWidgets);
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    expect(find.text('5 connected devices'), findsNothing);

    await tester.ensureVisible(find.text('Add New Device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add New Device'));
    await tester.pumpAndSettle();
    expect(find.text('Connection choices'), findsWidgets);
  });

  testWidgets('Premium links plans, account, payment, and subscription', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    pelevoRouter.go('/screen/premium-intro');
    await tester.pumpAndSettle();

    expect(find.text('Pelevo Plus'), findsWidgets);
    await tester.ensureVisible(find.text('Explore Plans'));
    await tester.tap(find.text('Explore Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Pelevo Plus Monthly'), findsOneWidget);

    await tester.ensureVisible(find.text('Try 1 Month Free'));
    await tester.tap(find.text('Try 1 Month Free'));
    await tester.pumpAndSettle();
    expect(find.text('Compare Plans'), findsWidgets);

    await tester.ensureVisible(find.text('Choose Your Plan'));
    await tester.tap(find.text('Choose Your Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Securely'), findsOneWidget);

    await tester.tap(find.text('Pay Securely'));
    await tester.pumpAndSettle();
    expect(find.text('You’re All Set!'), findsOneWidget);

    pelevoRouter.go('/screen/premium-subscription');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Billing History'));
    await tester.tap(find.text('Billing History'));
    await tester.pumpAndSettle();
    expect(find.text('Download Invoice'), findsOneWidget);
  });

  testWidgets('Lock screen alerts link previews, settings, and history', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/lock-settings');
    await tester.pumpAndSettle();

    expect(find.text('Enable Lock Screen Notifications'), findsOneWidget);
    await tester.ensureVisible(find.text('Notification Preview'));
    await tester.tap(find.text('Notification Preview'));
    await tester.pumpAndSettle();
    expect(find.text('New Episode Out Now!'), findsOneWidget);

    pelevoRouter.go('/screen/lock-history');
    await tester.pumpAndSettle();
    expect(find.text('Server notification navigation'), findsOneWidget);
    expect(find.text('Download Complete'), findsNothing);

    pelevoRouter.go('/screen/lock-download-complete');
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Ready offline'), findsNothing);

    await tester.tap(find.text('Notification Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Notification Types'), findsOneWidget);
  });

  testWidgets('Share cards link content, templates, editor, and sharing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/share-card-home');
    await tester.pumpAndSettle();

    expect(find.text('Create New Card'), findsOneWidget);
    await tester.ensureVisible(find.text('Create New Card'));
    await tester.tap(find.text('Create New Card'));
    await tester.pumpAndSettle();
    expect(find.text('Ep. 124 - The Shift Life'), findsOneWidget);

    await tester.tap(find.text('Ep. 124 - The Shift Life'));
    await tester.pumpAndSettle();
    expect(find.text('QR Code'), findsOneWidget);
    await tester.ensureVisible(find.text('QR Code'));
    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();
    expect(find.text('Use Template'), findsOneWidget);

    await tester.tap(find.text('Use Template'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Card'));
    await tester.tap(find.text('Save Card'));
    await tester.pumpAndSettle();
    expect(find.text('Share Card'), findsOneWidget);

    await tester.ensureVisible(find.text('Share Card'));
    await tester.tap(find.text('Share Card'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Save to Gallery'), findsOneWidget);
  });

  testWidgets('Home modules link discover, charts, playlists, and content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/home-feed');
    await tester.pumpAndSettle();

    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Made For You'), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2400),
      2400,
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore by Topic'), findsWidgets);
    expect(find.text('Shorts You Might Like'), findsNothing);

    pelevoRouter.go('/screen/home-discover');
    await tester.pumpAndSettle();
    expect(find.text('Editors Picks'), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);

    pelevoRouter.go('/screen/home-charts');
    await tester.pumpAndSettle();
    expect(find.text('Ranked Show'), findsOneWidget);
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Lagos Mix'), findsOneWidget);
    expect(find.text('AfroBeats Now'), findsNothing);

    pelevoRouter.go('/screen/home-playlists');
    await tester.pumpAndSettle();
    expect(find.text('Your Playlists'), findsOneWidget);
    expect(find.text('Morning desk'), findsOneWidget);
    expect(find.text('The Midday Show'), findsNothing);
  });

  testWidgets('Home See All opens a matching section screen', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/home-feed');
    await tester.pumpAndSettle();

    await tester.tap(find.text('See All').first);
    await tester.pumpAndSettle();
    expect(find.text('Pick up where you left off'), findsOneWidget);

    pelevoRouter.go('/screen/home-feed');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Made For You'));
    await tester.tap(find.text('See All').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Personalized episode picks'), findsOneWidget);

    pelevoRouter.go('/screen/home-quick-listen');
    await tester.pumpAndSettle();
    expect(find.text('Short episodes that fit your time'), findsOneWidget);

    pelevoRouter.go('/screen/home-because-you-listened');
    await tester.pumpAndSettle();
    expect(find.text('More from topics you already enjoy'), findsOneWidget);

    pelevoRouter.go('/screen/home-trending');
    await tester.pumpAndSettle();
    expect(find.text('What listeners are playing now'), findsOneWidget);

    pelevoRouter.go('/screen/home-following-new');
    await tester.pumpAndSettle();
    expect(find.text('Fresh episodes from your subscriptions'), findsOneWidget);

    pelevoRouter.go('/screen/home-african-voices');
    await tester.pumpAndSettle();
    expect(find.text('Shows published across the continent'), findsOneWidget);

    pelevoRouter.go('/screen/home-try-new');
    await tester.pumpAndSettle();
    expect(find.text('Topics outside your listening history'), findsOneWidget);

    pelevoRouter.go('/screen/home-topics');
    await tester.pumpAndSettle();
    expect(find.text('Browse the Pelevo catalog'), findsOneWidget);

    pelevoRouter.go('/screen/browse-categories');
    await tester.pumpAndSettle();
    expect(find.text('Explore every topic'), findsOneWidget);
  });

  testWidgets('Profile, settings, reels, and earn flows navigate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(PodcastCreatorService.instance.resetForTesting);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();
    expect(find.text('Test listener'), findsOneWidget);
    expect(find.text('Earn Wallet'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & Account'), findsOneWidget);
    expect(find.text('Dark Mode'), findsNothing);
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Sleep Timer'), findsOneWidget);

    await tester.ensureVisible(find.text('Connected Accounts'));
    await tester.tap(find.text('Connected Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsWidgets);
    expect(find.text('adesola@gmail.com'), findsNothing);

    PodcastCreatorService.instance.claim();
    pelevoRouter.go('/screen/reels');
    await tester.pumpAndSettle();
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Ada Creator'), findsWidgets);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Following reel caption.'), findsOneWidget);

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(find.text('Trending reel caption.'), findsOneWidget);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Reel'));
    await tester.pumpAndSettle();
    expect(find.text('Record'), findsOneWidget);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Record Reel'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);

    pelevoRouter.go('/screen/reels-upload');
    await tester.pumpAndSettle();
    expect(find.text('Upload Reel'), findsOneWidget);
    expect(find.text('Choose Video'), findsOneWidget);

    pelevoRouter.go('/screen/reels-drafts');
    await tester.pumpAndSettle();
    expect(find.text('No drafts yet'), findsOneWidget);

    pelevoRouter.go('/screen/earn');
    await tester.pumpAndSettle();
    expect(find.text('Reward Rules'), findsOneWidget);
    expect(find.text('Monetized Podcasts'), findsOneWidget);
    expect(find.text('The Mindset'), findsWidgets);

    await tester.ensureVisible(find.text('See All').first);
    await tester.tap(find.text('See All').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('podcast'), findsWidgets);
    expect(find.text('The Honest Bunch'), findsWidgets);
    expect(find.text('Ep. 123 - Soft Life Talk'), findsOneWidget);
    expect(find.text('Train Your Mind Daily'), findsWidgets);

    pelevoRouter.go('/screen/earn');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Train Your Mind Daily'));
    await tester.tap(find.text('Train Your Mind Daily'));
    await tester.pumpAndSettle();
    expect(find.text('Earn Playback'), findsOneWidget);
    expect(
      find.textContaining('isolated from the general podcast player'),
      findsOneWidget,
    );
    expect(find.text('Play to Earn'), findsOneWidget);
    expect(find.textContaining('Pause and play only'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    EarnPlaybackSession.instance.stop();
  });

  testWidgets('Profile destinations and withdrawal gateways navigate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Podcasts & creators you follow'));
    await tester.tap(find.text('Podcasts & creators you follow'));
    await tester.pumpAndSettle();
    expect(find.text('Discover more creators'), findsOneWidget);

    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('FAQs, support & feedback'));
    await tester.tap(find.text('FAQs, support & feedback'));
    await tester.pumpAndSettle();
    expect(find.text('How do earnings work?'), findsOneWidget);

    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invite friends & earn rewards'));
    await tester.tap(find.text('Invite friends & earn rewards'));
    await tester.pumpAndSettle();
    expect(find.text('PELEVOTEST1'), findsOneWidget);

    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('App version & information'));
    await tester.tap(find.text('App version & information'));
    await tester.pumpAndSettle();
    expect(find.text('About Pelevo'), findsOneWidget);

    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();
    expect(find.text('Upgrade to Pelevo Plus'), findsOneWidget);
    expect(find.text('Earn Wallet'), findsOneWidget);
    expect(find.text('Claim Your Podcast'), findsOneWidget);
    expect(find.text('Monetization'), findsNothing);

    pelevoRouter.go('/screen/reels-monetization-eligible');
    await tester.pumpAndSettle();
    expect(find.text("You're Eligible!"), findsOneWidget);
    await tester.tap(find.text('Opt In Now →'));
    await tester.pumpAndSettle();
    expect(find.text("You're Monetized!"), findsOneWidget);
    expect(find.textContaining('automatically'), findsWidgets);

    pelevoRouter.go('/screen/earn-wallet');
    await tester.pumpAndSettle();
    expect(find.textContaining('You request payout'), findsOneWidget);
    await tester.tap(find.text('Request Payout'));
    await tester.pumpAndSettle();
    expect(find.text('Payout Gateways'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('Bank Transfer (Local Banks)'), findsOneWidget);
    expect(find.text('Paystack'), findsNothing);

    final paypalTile = find.widgetWithText(ListTile, 'PayPal');
    await tester.ensureVisible(paypalTile);
    await tester.tap(
      find.descendant(of: paypalTile, matching: find.text('Set up')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set up PayPal'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'earn@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'earn@example.com');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify & Link PayPal'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw Earnings'), findsOneWidget);
    // Let success snackbars clear so they don't block the Continue CTA.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Withdrawal Amount'), findsOneWidget);
    await tester.tap(find.text('Review Withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Review & Confirm'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Withdrawal queued'), findsOneWidget);
  });

  testWidgets('Creator audience and management workflows are registered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/creator-audience');
    await tester.pumpAndSettle();
    expect(find.text('Audience Growth'), findsOneWidget);
    expect(find.text('Listener Demographics'), findsOneWidget);
    expect(find.text('Top Locations'), findsOneWidget);

    pelevoRouter.go('/screen/creator-new-episode');
    await tester.pumpAndSettle();
    expect(find.text('Upload episode audio'), findsOneWidget);
    expect(find.text('Publish Episode'), findsOneWidget);

    pelevoRouter.go('/screen/creator-go-live');
    await tester.pumpAndSettle();
    expect(find.text('Start a live conversation'), findsOneWidget);
    expect(find.text('Go Live Now'), findsOneWidget);
  });

  testWidgets('reel creation requires a claimed podcast', (tester) async {
    PodcastCreatorService.instance.resetForTesting();
    addTearDown(PodcastCreatorService.instance.resetForTesting);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));

    pelevoRouter.go('/screen/reels');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Create Reel'), findsOneWidget);

    await tester.tap(find.byTooltip('Create Reel'));
    await tester.pumpAndSettle();
    expect(find.text('Creator access required'), findsOneWidget);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Creator access required'), findsNothing);

    PodcastCreatorService.instance.claim();
    await tester.tap(find.byTooltip('Create Reel'));
    await tester.pumpAndSettle();
    expect(find.text('Create Reel'), findsWidgets);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('claim success updates creator state after the build frame', (
    tester,
  ) async {
    PodcastCreatorService.instance.resetForTesting();
    addTearDown(PodcastCreatorService.instance.resetForTesting);
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/profile');
    await tester.pumpAndSettle();

    pelevoRouter.push('/screen/claim-success');
    await tester.pumpAndSettle();

    expect(find.text('You’re verified!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gift flow links insufficient balance to the coin store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/reels');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gift').first);
    await tester.pumpAndSettle();
    expect(find.text('Support Ada Creator'), findsOneWidget);
    expect(find.text('Buy Coins'), findsOneWidget);

    await tester.tap(find.text('Champion'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not enough coins'), findsOneWidget);

    await tester.tap(find.text('Buy Coins').first);
    await tester.pumpAndSettle();
    expect(find.text('Choose a coin pack'), findsOneWidget);
    expect(find.text('500 coins'), findsOneWidget);
  });

  testWidgets('reels and episodes share a comment and reply thread', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CommentService.instance.resetForTesting();
    addTearDown(CommentService.instance.resetForTesting);

    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/reels');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Comments').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Comments ·'), findsOneWidget);
    expect(find.text('This reel is worth saving.'), findsOneWidget);
    expect(
      find.text('This hit hard. Saving this for morning motivation.'),
      findsNothing,
    );

    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Replying to'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'This reel is gold.');
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
    expect(find.text('This reel is gold.'), findsOneWidget);

    pelevoRouter.go('/screen/episode-comments');
    await tester.pumpAndSettle();
    expect(find.text('Episode Comments'), findsOneWidget);
    expect(find.text('Listener Ada'), findsWidgets);
    expect(find.text('This episode is worth a second listen.'), findsOneWidget);
    expect(
      find.text('This episode landed at the right time. Saving it for later.'),
      findsNothing,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'Listening again tonight.',
    );
    await tester.tap(find.byTooltip('Send comment').last);
    await tester.pumpAndSettle();
    expect(find.text('Listening again tonight.'), findsOneWidget);
  });

  testWidgets('reel linked episode opens and can be changed', (tester) async {
    await tester.pumpWidget(const CatalogHarness());
    await tester.pump(const Duration(milliseconds: 2300));
    pelevoRouter.go('/screen/reels');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen Now'));
    await tester.pumpAndSettle();
    expect(find.text('Play Episode'), findsOneWidget);
  });
}
