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
    await Hive.initFlutter();
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final authStore = AuthSessionStore(secureStorage);
    final installationId = await authStore.installationId();
    final values = await Future.wait<Object>([
      SharedPreferences.getInstance(),
      Hive.openBox<dynamic>('pelevo_settings'),
      PackageInfo.fromPlatform(),
      authStore.read(),
    ]);
    final preferences = values[0] as SharedPreferences;
    final settings = values[1] as Box<dynamic>;
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
    final packageInfo = values[2] as PackageInfo;
    await PelevoUserAgent.resolve(version: packageInfo.version);
    return AppServices(
      preferences: preferences,
      settings: settings,
      packageInfo: packageInfo,
      authStore: authStore,
      initialSession: values[3] as AuthSession,
      installationId: installationId,
    );
  }
}
