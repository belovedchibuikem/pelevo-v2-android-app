import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

const audioQualityLabels = {
  'low': 'Low',
  'normal': 'Normal',
  'high': 'High',
  'very_high': 'Very High',
};

class AccountPreferences {
  AccountPreferences._(this.values);
  final Map<String, dynamic> values;
  int get version => values['version'] as int;
  String get userId => values['user_id'] as String;
  String get audioQuality => values['audio_quality'] as String;
  bool flag(String key) => values[key] as bool;

  factory AccountPreferences.fromApi(Map<String, dynamic> data) {
    const invalid = ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'Your preferences could not be read. Please retry.',
    );
    if (data['user_id'] is! String ||
        (data['user_id'] as String).isEmpty ||
        data['version'] is! int ||
        (data['version'] as int) < 0 ||
        !audioQualityLabels.containsKey(data['audio_quality'])) {
      throw invalid;
    }
    for (final key in [
      'explicit_content',
      'autoplay',
      'download_wifi_only',
      'data_saver',
      'email_product',
      'email_episodes',
      'email_marketing',
    ]) {
      if (data[key] is! bool) throw invalid;
    }
    return AccountPreferences._(Map.unmodifiable(data));
  }
}

class PreferencesRepository {
  PreferencesRepository(this.dio);
  final Dio dio;
  Future<AccountPreferences> load({CancelToken? cancelToken}) async =>
      AccountPreferences.fromApi(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/me/preferences',
            cancelToken: cancelToken,
          )).data,
        ),
      );
  Future<AccountPreferences> save(
    AccountPreferences previous,
    Map<String, dynamic> changes,
  ) async {
    final result = AccountPreferences.fromApi(
      requireApiData(
        (await dio.patch<Map<String, dynamic>>(
          '/me/preferences',
          data: {...changes, 'version': previous.version},
        )).data,
      ),
    );
    if (result.userId != previous.userId ||
        result.version != previous.version + 1) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'The save could not be confirmed. Reload your preferences.',
      );
    }
    return result;
  }
}

final preferencesRepositoryProvider = Provider(
  (ref) => PreferencesRepository(ref.watch(dioProvider)),
);
final preferencesProvider = FutureProvider.autoDispose<AccountPreferences>((
  ref,
) async {
  final owner = ref.watch(
    authSessionProvider.select((session) => session.userId),
  );
  if (owner == null) {
    throw const ApiFailure(
      code: 'UNAUTHENTICATED',
      message: 'Sign in to view your preferences.',
    );
  }
  final cancel = CancelToken();
  ref.onDispose(() => cancel.cancel());
  final result = await ref
      .read(preferencesRepositoryProvider)
      .load(cancelToken: cancel);
  if (result.userId != owner) {
    throw const ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'Your account preferences could not be verified.',
    );
  }
  return result;
}, retry: (count, error) => null);
