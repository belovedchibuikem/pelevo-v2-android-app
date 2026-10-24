import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/config/app_config.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/onboarding/onboarding_data.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('startup destination', () {
    test('authenticated listeners resume at home', () {
      expect(
        startupDestination(
          hadStoredSession: true,
          authenticated: true,
          introductionSeen: true,
        ),
        '/screen/home-feed',
      );
    });

    test('first launch starts the existing introduction', () {
      expect(
        startupDestination(
          hadStoredSession: false,
          authenticated: false,
          introductionSeen: false,
        ),
        '/screen/onboarding-personalized',
      );
    });

    test('returning signed-out listeners go directly to sign in', () {
      expect(
        startupDestination(
          hadStoredSession: false,
          authenticated: false,
          introductionSeen: true,
        ),
        '/screen/auth-sign-in',
      );
    });

    test('a new account is sent to podcast and language choices', () {
      expect(sessionNeedsOnboarding({'onboarded': false}), isTrue);
      expect(
        sessionNeedsOnboarding({'onboarded_at': null, 'name': 'Ada'}),
        isTrue,
      );
      expect(
        postAuthDestination(
          onboardingApplied: false,
          needsOnboarding: true,
          permissionsComplete: false,
        ),
        '/screen/onboarding-interests',
      );
    });

    test('saved choices continue into permissions before home', () {
      expect(sessionNeedsOnboarding({'onboarded': true}), isFalse);
      expect(
        sessionNeedsOnboarding({'onboarded_at': '2026-10-24T00:00:00Z'}),
        isFalse,
      );
      expect(sessionNeedsOnboarding({'name': 'Listener'}), isFalse);
      expect(
        postAuthDestination(
          onboardingApplied: true,
          needsOnboarding: false,
          permissionsComplete: false,
        ),
        '/screen/permissions-intro',
      );
      expect(
        postAuthDestination(
          onboardingApplied: true,
          needsOnboarding: false,
          permissionsComplete: true,
          preferredPath: '/screen/home-feed',
        ),
        '/screen/home-feed',
      );
    });

    test('a rejected stored session goes to sign in', () {
      expect(
        startupDestination(
          hadStoredSession: true,
          authenticated: false,
          introductionSeen: false,
        ),
        '/screen/auth-sign-in',
      );
    });
  });

  test('onboarding introduction completion persists', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOnboardingProgressStore(preferences);

    expect(await store.hasSeenIntroduction(), isFalse);
    await store.markIntroductionSeen();
    expect(await store.hasSeenIntroduction(), isTrue);
  });

  test('onboarding draft and permissions completion persist', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOnboardingProgressStore(preferences);
    const draft = OnboardingDraft(
      interests: ['News', 'Culture'],
      locale: 'ha',
    );

    expect(await store.readDraft(), isNull);
    expect(await store.hasCompletedPermissions(), isFalse);
    await store.saveDraft(draft);
    await store.markPermissionsComplete();
    final restored = await store.readDraft();
    expect(restored?.interests, ['News', 'Culture']);
    expect(restored?.locale, 'ha');
    expect(await store.hasCompletedPermissions(), isTrue);
    await store.clearDraft();
    expect(await store.readDraft(), isNull);
  });

  group('app configuration', () {
    test('parses the authoritative bootstrap contract', () {
      final config = AppConfig.fromApi({
        'version': 3,
        'tabs': ['home', 'search', 'library', 'earn', 'reels'],
        'flags': {'earn_enabled': true, 'ai_hub': false},
        'money': {'earn_min_withdraw_coins': 1250},
        'limits': {'comment_chars': 400},
      });

      expect(config.version, 3);
      expect(config.enabled('earn_enabled'), isTrue);
      expect(config.enabled('ai_hub'), isFalse);
      expect(config.enabled('unknown'), isFalse);
      expect(config.money['earn_min_withdraw_coins'], 1250);
    });

    test('rejects malformed feature flags', () {
      expect(
        () => AppConfig.fromApi({
          'version': 3,
          'tabs': ['home'],
          'flags': {'earn_enabled': 'yes'},
          'money': <String, dynamic>{},
          'limits': <String, dynamic>{},
        }),
        throwsA(isA<ApiFailure>()),
      );
    });
  });
}
