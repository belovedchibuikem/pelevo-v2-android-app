import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidConnected = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Connected accounts could not be verified. Please retry.',
);

const connectedAccountProviders = ['google', 'apple'];

class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.provider,
    required this.createdAt,
    this.email,
  });

  factory ConnectedAccount.parse(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['provider'] is! String ||
        !connectedAccountProviders.contains(data['provider']) ||
        data['created_at'] is! String) {
      throw _invalidConnected;
    }
    final created = DateTime.tryParse(data['created_at'] as String);
    if (created == null) throw _invalidConnected;
    final email = data['email'];
    if (email != null && (email is! String || email.isEmpty)) {
      throw _invalidConnected;
    }
    return ConnectedAccount(
      id: data['id'] as String,
      provider: data['provider'] as String,
      email: email as String?,
      createdAt: created,
    );
  }

  final String id;
  final String provider;
  final String? email;
  final DateTime createdAt;

  String get subtitle =>
      (email != null && email!.isNotEmpty) ? email! : 'Connected';
}

class ConnectedAccountsPage {
  const ConnectedAccountsPage(this.owner, this.accounts);
  final String owner;
  final List<ConnectedAccount> accounts;

  ConnectedAccount? forProvider(String provider) {
    for (final account in accounts) {
      if (account.provider == provider) return account;
    }
    return null;
  }
}

class ConnectedAccountsRepository {
  ConnectedAccountsRepository(this._dio);
  final Dio _dio;

  Future<ConnectedAccountsPage> list(String owner, CancelToken token) async {
    try {
      final body =
          (await _dio.get<Map<String, dynamic>>(
            '/me/connected-accounts',
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      final meta = body?['meta'];
      final rows = body?['data'];
      if (meta is! Map ||
          meta['user_id'] != owner ||
          rows is! List ||
          rows.any((row) => row is! Map<String, dynamic>)) {
        throw _invalidConnected;
      }
      final accounts =
          rows
              .map((row) => ConnectedAccount.parse(row as Map<String, dynamic>))
              .toList(growable: false);
      if (accounts.map((item) => item.id).toSet().length != accounts.length) {
        throw _invalidConnected;
      }
      return ConnectedAccountsPage(owner, accounts);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<ConnectedAccount> link({
    required String provider,
    required String token,
    CancelToken? cancelToken,
  }) async {
    try {
      return ConnectedAccount.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/me/connected-accounts',
            data: {'provider': provider, 'token': token},
            cancelToken: cancelToken,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> disconnect(String id, {CancelToken? token}) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>(
          '/me/connected-accounts/$id',
          cancelToken: token,
        )).data,
      );
      if (data['disconnected'] != true) throw _invalidConnected;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final connectedAccountsRepositoryProvider = Provider(
  (ref) => ConnectedAccountsRepository(ref.watch(dioProvider)),
);

final connectedAccountsProvider =
    FutureProvider.autoDispose<ConnectedAccountsPage>((ref) async {
      final owner = ref.watch(
        authSessionProvider.select((session) => session.userId),
      );
      if (owner == null) throw _invalidConnected;
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(connectedAccountsRepositoryProvider).list(owner, token);
    }, retry: (count, error) => null);

ApiFailure connectedAccountsFailure(Object error) => profileFailure(error);
