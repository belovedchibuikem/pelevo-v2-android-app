import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidInvite = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Invite data could not be verified. Please retry.',
);

class UserInvite {
  const UserInvite({
    required this.owner,
    this.code,
    this.expiresAt,
    this.redemptions = 0,
    this.maxRedemptions = 0,
  });

  factory UserInvite.fromApi(Map<String, dynamic> data, String owner) {
    if (data['user_id'] != owner) throw _invalidInvite;
    final code = data['code'];
    if (code != null && (code is! String || code.isEmpty)) {
      throw _invalidInvite;
    }
    final expires = data['expires_at'];
    if (expires != null && expires is! String) throw _invalidInvite;
    final until =
        expires == null ? null : DateTime.tryParse(expires as String);
    if (expires != null && until == null) throw _invalidInvite;
    final redemptions = data['redemptions'];
    final maxRedemptions = data['max_redemptions'];
    if (redemptions is! int ||
        redemptions < 0 ||
        maxRedemptions is! int ||
        maxRedemptions < 0) {
      throw _invalidInvite;
    }
    return UserInvite(
      owner: owner,
      code: code as String?,
      expiresAt: until,
      redemptions: redemptions,
      maxRedemptions: maxRedemptions,
    );
  }

  final String owner;
  final String? code;
  final DateTime? expiresAt;
  final int redemptions;
  final int maxRedemptions;

  String get shareLink =>
      code == null || code!.isEmpty ? '' : 'pelevo://invite/$code';
}

class InviteRepository {
  InviteRepository(this._dio);
  final Dio _dio;

  Future<UserInvite> current(String owner, CancelToken token) async {
    try {
      return UserInvite.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/me/invite',
            cancelToken: token,
          )).data,
        ),
        owner,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<UserInvite> create(
    String owner,
    CancelToken token, {
    bool rotate = false,
  }) async {
    try {
      return UserInvite.fromApi(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/me/invite',
            data: {if (rotate) 'rotate': true},
            cancelToken: token,
          )).data,
        ),
        owner,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final inviteRepositoryProvider = Provider(
  (ref) => InviteRepository(ref.watch(dioProvider)),
);

final userInviteProvider = FutureProvider.autoDispose<UserInvite>((ref) async {
  final owner = ref.watch(authSessionProvider.select((session) => session.userId));
  if (owner == null) throw _invalidInvite;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  final repository = ref.watch(inviteRepositoryProvider);
  final current = await repository.current(owner, token);
  if (current.code != null && current.code!.isNotEmpty) return current;
  return repository.create(owner, token);
}, retry: (count, error) => null);

ApiFailure inviteFailure(Object error) => profileFailure(error);
