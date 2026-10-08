import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

const _invalidSync = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Device sync details could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidSync;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidSync;
  return value as String?;
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw _invalidSync;
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidSync;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _listBody(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidSync;
  }
  return _maps(body['data']);
}

class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.trustState,
    this.lastSeenAt,
    this.lastActiveAt,
    this.revokedAt,
    this.createdAt,
  });

  factory SyncDevice.parse(Map<String, dynamic> data) {
    final lastSeen = _optionalText(data, 'last_seen_at');
    final lastActive = _optionalText(data, 'last_active_at');
    final revoked = _optionalText(data, 'revoked_at');
    final created = _optionalText(data, 'created_at');
    if (lastSeen != null && DateTime.tryParse(lastSeen) == null) throw _invalidSync;
    if (lastActive != null && DateTime.tryParse(lastActive) == null) {
      throw _invalidSync;
    }
    if (revoked != null && DateTime.tryParse(revoked) == null) throw _invalidSync;
    if (created != null && DateTime.tryParse(created) == null) throw _invalidSync;
    return SyncDevice(
      id: _text(data, 'id'),
      name: _optionalText(data, 'name') ?? 'Device',
      platform: _optionalText(data, 'platform') ?? 'unknown',
      trustState: _optionalText(data, 'trust_state') ?? 'paired',
      lastSeenAt: lastSeen,
      lastActiveAt: lastActive,
      revokedAt: revoked,
      createdAt: created,
    );
  }

  final String id, name, platform, trustState;
  final String? lastSeenAt, lastActiveAt, revokedAt, createdAt;

  bool get active => revokedAt == null && trustState != 'revoked';

  String get subtitle {
    final seen = lastSeenAt ?? lastActiveAt;
    return [platform, if (seen != null) seen].join(' · ');
  }
}

class PairingCode {
  const PairingCode(this.code, this.expiresIn);

  factory PairingCode.parse(Map<String, dynamic> data) =>
      PairingCode(_text(data, 'code'), _count(data['expires_in']));

  final String code;
  final int expiresIn;
}

class SyncChange {
  const SyncChange({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.operation,
    required this.version,
  });

  factory SyncChange.parse(Map<String, dynamic> data) => SyncChange(
    id: _text(data, 'id'),
    resourceType: _text(data, 'resource_type'),
    resourceId: _text(data, 'resource_id'),
    operation: _text(data, 'operation'),
    version: _count(data['version']),
  );

  final String id, resourceType, resourceId, operation;
  final int version;
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.createdAt,
    required this.state,
    required this.resourceType,
  });

  factory SyncConflict.parse(Map<String, dynamic> data) {
    final created = _text(data, 'created_at');
    if (DateTime.tryParse(created) == null) throw _invalidSync;
    return SyncConflict(
      id: _text(data, 'id'),
      createdAt: created,
      state: _text(data, 'state'),
      resourceType: _text(data, 'resource_type'),
    );
  }

  final String id, createdAt, state, resourceType;
}

class AccountBackup {
  const AccountBackup(this.id, this.state, this.sizeBytes);

  factory AccountBackup.parse(Map<String, dynamic> data) => AccountBackup(
    _text(data, 'id'),
    _text(data, 'state'),
    _count(data['size_bytes']),
  );

  final String id, state;
  final int sizeBytes;
}

class DeviceSyncRepository {
  DeviceSyncRepository(this._dio);
  final Dio _dio;

  Future<List<SyncDevice>> devices(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>('/devices', cancelToken: token)).data,
      ).map(SyncDevice.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PairingCode> pairingCode() async {
    try {
      return PairingCode.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>('/devices/pairing-code')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> pair({
    required String code,
    required String deviceIdentifier,
    required String name,
    required String platform,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/devices/pair',
          data: {
            'code': code,
            'device_identifier': deviceIdentifier,
            'name': name,
            'platform': platform,
          },
        )).data,
      );
      if (data['paired'] != true) throw _invalidSync;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> revoke(String deviceId) async {
    try {
      final data = requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/devices/$deviceId')).data,
      );
      if (data['revoked'] != true) throw _invalidSync;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> signOutAll() async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>('/devices/sign-out-all')).data,
      );
      if (data['signed_out'] != true) throw _invalidSync;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<SyncChange>> pull(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>('/sync/pull', cancelToken: token)).data,
      ).map(SyncChange.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<SyncConflict>> conflicts(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/sync/conflicts',
          cancelToken: token,
        )).data,
      ).map(SyncConflict.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> resolveConflict(
    String id, {
    required String resolution,
    List<dynamic>? payload,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.put<Map<String, dynamic>>(
          '/sync/conflicts/$id',
          data: {
            'resolution': resolution,
            if (resolution == 'client') 'payload': payload ?? const <dynamic>[],
          },
        )).data,
      );
      if (data['resolved'] != true) throw _invalidSync;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<AccountBackup> createBackup() async {
    try {
      return AccountBackup.parse(
        requireApiData((await _dio.post<Map<String, dynamic>>('/backups')).data),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> restoreBackup(String backupId) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/backups/$backupId/restore',
        )).data,
      );
      if (data['restored'] != true) throw _invalidSync;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

class SelectedDeviceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedDeviceIdProvider =
    NotifierProvider<SelectedDeviceIdNotifier, String?>(SelectedDeviceIdNotifier.new);

class LatestBackupNotifier extends Notifier<AccountBackup?> {
  @override
  AccountBackup? build() => null;
  void select(AccountBackup? backup) => state = backup;
}

final latestBackupProvider =
    NotifierProvider<LatestBackupNotifier, AccountBackup?>(
      LatestBackupNotifier.new,
    );

class SyncNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final syncNoticeProvider =
    NotifierProvider<SyncNoticeNotifier, String?>(SyncNoticeNotifier.new);

final deviceSyncRepositoryProvider = Provider(
  (ref) => DeviceSyncRepository(ref.watch(dioProvider)),
);

final syncDevicesProvider = FutureProvider.autoDispose<List<SyncDevice>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(deviceSyncRepositoryProvider).devices(token);
}, retry: (count, error) => null);

final syncPullProvider = FutureProvider.autoDispose<List<SyncChange>>((ref) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(deviceSyncRepositoryProvider).pull(token);
}, retry: (count, error) => null);

final syncConflictsProvider = FutureProvider.autoDispose<List<SyncConflict>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(deviceSyncRepositoryProvider).conflicts(token);
}, retry: (count, error) => null);
