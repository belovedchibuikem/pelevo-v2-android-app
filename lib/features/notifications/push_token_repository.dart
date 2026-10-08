import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

const _invalidPush = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Push token registration could not be completed.',
);

class PushTokenRepository {
  PushTokenRepository(this.dio);
  final Dio dio;

  Future<void> register({
    required String provider,
    required String token,
  }) async {
    final data = requireApiData(
      (await dio.post<Map<String, dynamic>>(
        '/me/push-tokens',
        data: {'provider': provider, 'token': token},
      )).data,
    );
    if (data['registered'] != true) throw _invalidPush;
  }

  Future<void> revoke({required String provider, required String token}) async {
    await dio.delete<Map<String, dynamic>>(
      '/me/push-tokens',
      data: {'provider': provider, 'token': token},
    );
  }
}

final pushTokenRepositoryProvider = Provider(
  (ref) => PushTokenRepository(ref.watch(dioProvider)),
);
