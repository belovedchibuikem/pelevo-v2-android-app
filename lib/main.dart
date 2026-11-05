import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/core/deep_links/pelevo_deep_links.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/gifts/gift_service.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/firebase_push.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:pelevo/features/notifications/local_notifications.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/reels/reel_ad_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> _guarded(Future<void> Function() work, {Duration? timeout}) async {
  try {
    final future = work();
    if (timeout == null) {
      await future;
    } else {
      await future.timeout(timeout);
    }
  } on Object {
    // Startup must reach runApp even when optional plugins hang.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    FirebaseMessaging.onBackgroundMessage(
      pelevoFirebaseMessagingBackgroundHandler,
    );
  } on Object {
    // Tests / hosts without Firebase config continue without remote push.
  }
  // Never block the first frame on Play Integrity / App Attest. A hung
  // attestation (missing Play App Signing SHA-256 in Firebase, Integrity API
  // not linked, or Play Services delay) otherwise freezes the native splash.
  unawaited(() async {
    try {
      await FirebaseAppCheck.instance
          .activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider:
                kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
          )
          .timeout(const Duration(seconds: 8));
    } on Object {
      // App Check is optional; FCM and the rest of the app still proceed.
    }
  }());

  const sentryDsn = String.fromEnvironment('PELEVO_SENTRY_DSN');
  Future<void> startApp() async {
    // Hive / Keystore are hardened inside initialize(); still bound the wait so
    // Play never sees a frozen native splash (reported as crash-on-open).
    final services = await AppServices.initialize().timeout(
      const Duration(seconds: 20),
      onTimeout: AppServices.initializeDegraded,
    );
    await PodcastCreatorService.instance.initialize(services.preferences);
    // Prefs only — Play Billing catalog loads in the background.
    await GiftWalletService.instance.initialize(services.preferences);
    await CommentService.instance.initialize(services.preferences);
    await _guarded(
      () => initPelevoAudioHandler(),
      timeout: const Duration(seconds: 8),
    );
    await _guarded(
      () => initPelevoCast(),
      timeout: const Duration(seconds: 5),
    );
    await _guarded(
      () => PelevoLocalNotifications.initialize(),
      timeout: const Duration(seconds: 5),
    );
    await _guarded(
      () => PelevoNotificationRouter.listenForOpens(),
      timeout: const Duration(seconds: 5),
    );
    await _guarded(
      () => PelevoDeepLinks.bind(),
      timeout: const Duration(seconds: 5),
    );
    unawaited(
      _guarded(
        () async {
          await ReelAds.initialize();
        },
        timeout: const Duration(seconds: 30),
      ),
    );
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(services.preferences),
          settingsBoxProvider.overrideWithValue(services.settings),
          packageInfoProvider.overrideWithValue(services.packageInfo),
          authSessionStoreProvider.overrideWithValue(services.authStore),
          initialAuthSessionProvider.overrideWithValue(services.initialSession),
          installationIdProvider.overrideWithValue(services.installationId),
          onboardingProgressStoreProvider.overrideWithValue(
            SharedPreferencesOnboardingProgressStore(services.preferences),
          ),
          homeFeedCacheProvider.overrideWithValue(
            HiveHomeFeedCache(services.settings),
          ),
        ],
        child: const PelevoApp(),
      ),
    );
  }

  if (sentryDsn.isEmpty) {
    await startApp();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.environment = kReleaseMode ? 'release' : 'debug';
    options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
  }, appRunner: startApp);
}
