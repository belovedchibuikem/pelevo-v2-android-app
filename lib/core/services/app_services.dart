import 'package:dio/dio.dart';
import 'package:pelevo/core/network/api_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';
import 'package:pelevo/core/network/session_interceptor.dart';

final packageInfoProvider = Provider<PackageInfo>(
  (ref) => throw StateError('PackageInfo has not been initialized'),
);
final installationIdProvider = Provider<String>(
  (ref) => throw StateError('Installation identity has not been initialized'),
);

final pelevoUserAgentProvider = Provider<String>((ref) {
  final package = ref.watch(packageInfoProvider);
  return PelevoUserAgent.resolvedOrFormat(version: package.version);
});

final dioProvider = Provider<Dio>((ref) {
  final package = ref.watch(packageInfoProvider);
  final userAgent = ref.watch(pelevoUserAgentProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEnvironment.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent': userAgent,
        'X-API-Version': '1',
        'X-App-Version': package.version,
        'X-App-Build': package.buildNumber,
        'X-Platform': defaultTargetPlatform.name,
      },
    ),
  );
  dio.interceptors.add(
    SessionInterceptor(
      dio: dio,
      installationId: ref.read(installationIdProvider),
      readSession: () => ref.read(authSessionProvider),
      saveSession:
          (session) => ref.read(authSessionProvider.notifier).save(session),
      clearSession: () => ref.read(authSessionProvider.notifier).clear(),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final authTokenProvider = Provider<String?>(
  (ref) => ref.watch(authSessionProvider).accessToken,
);
final userDisplayNameProvider = Provider<String>(
  (ref) => ref.watch(authSessionProvider).displayName,
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences has not been initialized'),
);

final settingsBoxProvider = Provider<Box<dynamic>>(
  (ref) => throw StateError('Hive has not been initialized'),
);

class AppServices {
  const AppServices({
    required this.preferences,
    required this.settings,
    required this.packageInfo,
    required this.authStore,
    required this.initialSession,
    required this.installationId,
  });

  final SharedPreferences preferences;
  final Box<dynamic> settings;
  final PackageInfo packageInfo;
  final AuthSessionStore authStore;
  final AuthSession initialSession;
  final String installationId;

  static Future<AppServices> initialize() async {
    await Hive.initFlutter().timeout(const Duration(seconds: 5));
    // flutter_secure_storage 11+: Android uses Keystore AES-GCM by default
    // (encryptedSharedPreferences was removed — it deadlocked / crashed on
    // some Play review devices under storage 9.x).
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
    );
    final authStore = AuthSessionStore(secureStorage);
    final preferences = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 5),
    );
    final settings = await Hive.openBox<dynamic>('pelevo_settings').timeout(
      const Duration(seconds: 5),
    );
    final packageInfo = await PackageInfo.fromPlatform().timeout(
      const Duration(seconds: 5),
    );
    // Secure storage can hang or throw on broken Keystore; never block launch.
    final installationId = await authStore.installationId().timeout(
      const Duration(seconds: 5),
      onTimeout: () => 'launch-fallback',
    );
    final initialSession = await authStore.read().timeout(
      const Duration(seconds: 5),
      onTimeout: () => const AuthSession(),
    );
    // Prototype authority is not eligible for migration into server state.
    if ((preferences.getInt('pelevo_storage_version') ?? 0) < 1) {
      for (final key in const [
        'pelevo_access_token',
        'pelevo_coin_balance',
        'podcast_creator_claimed',
        'pelevo_user_comments',
      ]) {
        await preferences.remove(key);
      }
      await settings.delete('home_feed_v2');
      await preferences.setInt('pelevo_storage_version', 1);
    }
    await PelevoUserAgent.resolve(version: packageInfo.version);
    return AppServices(
      preferences: preferences,
      settings: settings,
      packageInfo: packageInfo,
      authStore: authStore,
      initialSession: initialSession,
      installationId: installationId,
    );
  }

  /// Last-resort cold start when Hive/Keystore hang past the outer timeout.
  static Future<AppServices> initializeDegraded() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 3));
    } on Object {
      // Continue; openBox below may still succeed if init already ran.
    }
    Box<dynamic> settings;
    try {
      settings = await Hive.openBox<dynamic>('pelevo_settings').timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      settings = await Hive.openBox<dynamic>('pelevo_settings_degraded');
    }
    final packageInfo = await PackageInfo.fromPlatform();
    const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
    final authStore = AuthSessionStore(secureStorage);
    return AppServices(
      preferences: preferences,
      settings: settings,
      packageInfo: packageInfo,
      authStore: authStore,
      initialSession: const AuthSession(),
      installationId: 'launch-degraded',
    );
  }
}
