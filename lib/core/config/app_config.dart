import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

class AppConfig {
  const AppConfig({
    required this.version,
    required this.tabs,
    required this.flags,
    required this.money,
    required this.limits,
  });

  factory AppConfig.fromApi(Map<String, dynamic> json) {
    final version = json['version'];
    final tabs = json['tabs'];
    final flags = json['flags'];
    final money = json['money'];
    final limits = json['limits'];
    if (version is! num ||
        tabs is! List ||
        flags is! Map ||
        money is! Map ||
        limits is! Map) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Pelevo configuration could not be verified.',
      );
    }

    final parsedTabs = tabs
        .whereType<String>()
        .where((tab) => tab.isNotEmpty)
        .toList(growable: false);
    final parsedFlags = <String, bool>{};
    for (final entry in flags.entries) {
      if (entry.key is! String || entry.value is! bool) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Pelevo feature configuration could not be verified.',
        );
      }
      parsedFlags[entry.key as String] = entry.value as bool;
    }
    if (parsedTabs.length != tabs.length) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Pelevo navigation configuration could not be verified.',
      );
    }

    return AppConfig(
      version: version.toInt(),
      tabs: List.unmodifiable(parsedTabs),
      flags: Map.unmodifiable(parsedFlags),
      money: Map.unmodifiable(Map<String, dynamic>.from(money)),
      limits: Map.unmodifiable(Map<String, dynamic>.from(limits)),
    );
  }

  final int version;
  final List<String> tabs;
  final Map<String, bool> flags;
  final Map<String, dynamic> money;
  final Map<String, dynamic> limits;

  bool enabled(String flag, {bool fallback = false}) => flags[flag] ?? fallback;
}

class AppConfigRepository {
  const AppConfigRepository(this._dio);

  final Dio _dio;

  Future<AppConfig> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/config');
    return AppConfig.fromApi(requireApiData(response.data));
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(ref.watch(dioProvider)),
);

class AppConfigController extends AsyncNotifier<AppConfig?> {
  @override
  Future<AppConfig?> build() async => null;

  Future<bool> refresh() async {
    state = const AsyncLoading();
    try {
      final config = await ref.read(appConfigRepositoryProvider).fetch();
      if (!ref.mounted) return false;
      state = AsyncData(config);
      return true;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) return false;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final appConfigProvider =
    AsyncNotifierProvider<AppConfigController, AppConfig?>(
      AppConfigController.new,
    );
