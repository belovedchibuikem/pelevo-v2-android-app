import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

/// Strips @ / spaces and lowercases a public handle for registration.
String? normalizeHandle(String? value) {
  if (value == null) return null;
  final normalized =
      value.trim().replaceFirst(RegExp(r'^@+'), '').replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

class AuthSession {
  const AuthSession({
    this.accessToken,
    this.refreshToken,
    this.deviceId,
    this.user,
  });

  factory AuthSession.fromApi(Map<String, dynamic> data) {
    final rawUser = data['user'];
    final user =
        rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    if (data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        data['refresh_token'] is! String ||
        (data['refresh_token'] as String).isEmpty ||
        data['device_id'] == null ||
        '${data['device_id']}'.isEmpty ||
        user == null ||
        user['id'] == null ||
        '${user['id']}'.isEmpty ||
        user['name'] is! String) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Unable to verify the sign-in response. Please try again.',
      );
    }
    return AuthSession(
      accessToken: data['access_token'] as String?,
      refreshToken: data['refresh_token'] as String?,
      deviceId: '${data['device_id']}',
      user: Map<String, dynamic>.unmodifiable(user),
    );
  }

  final String? accessToken;
  final String? refreshToken;
  final String? deviceId;
  final Map<String, dynamic>? user;

  String? get userId => user?['id']?.toString();
  bool get authenticated =>
      accessToken?.isNotEmpty == true &&
      refreshToken?.isNotEmpty == true &&
      deviceId?.isNotEmpty == true &&
      userId != null;
  String get displayName => '${user?['name'] ?? 'Listener'}';
  bool get creatorAccess {
    final capabilities = user?['capabilities'];
    return capabilities is Map && capabilities['creator_access'] == true;
  }

  AuthSession withUser(Map<String, dynamic> nextUser) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    deviceId: deviceId,
    user: Map<String, dynamic>.unmodifiable(nextUser),
  );
}

class AuthSessionStore {
  const AuthSessionStore(this._storage);
  final FlutterSecureStorage _storage;

  static const _access = 'pelevo.access_token';
  static const _refresh = 'pelevo.refresh_token';
  static const _device = 'pelevo.device_id';
  static const _session = 'pelevo.session.v1';

  Future<String> installationId() async {
    const key = 'pelevo.installation_id';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) return existing;
    // A session created without its installation identity cannot be safely
    // replayed as a different device. Reauthenticate once after this upgrade.
    await clear();
    final random = Random.secure();
    final id =
        List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await _storage.write(key: key, value: id);
    return id;
  }

  Future<AuthSession> read() async {
    final raw = await _storage.read(key: _session);
    if (raw == null) return const AuthSession();
    try {
      return AuthSession.fromApi(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return const AuthSession();
    }
  }

  Future<void> write(AuthSession session) async {
    await _storage.write(
      key: _session,
      value: jsonEncode({
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'device_id': session.deviceId,
        'user': session.user,
      }),
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _access),
      _storage.delete(key: _refresh),
      _storage.delete(key: _device),
      _storage.delete(key: _session),
    ]);
  }
}

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => throw StateError('AuthSessionStore has not been initialized'),
);

final initialAuthSessionProvider = Provider<AuthSession>(
  (ref) => const AuthSession(),
);

class AuthSessionNotifier extends Notifier<AuthSession> {
  @override
  AuthSession build() => ref.watch(initialAuthSessionProvider);

  Future<void> save(AuthSession session) async {
    await ref.read(authSessionStoreProvider).write(session);
    if (!ref.mounted) return;
    state = session;
  }

  Future<void> clear() async {
    state = const AuthSession();
    await ref.read(authSessionStoreProvider).clear();
  }

  Future<bool> bootstrap() async {
    if (!state.authenticated) return false;
    try {
      final response = await ref
          .read(dioProvider)
          .get<Map<String, dynamic>>('/me');
      final data = requireApiData(response.data);
      await save(state.withUser(data));
      return true;
    } on DioException {
      // A transport or service outage must not sign out a listener whose
      // locally stored session is still valid. A rejected refresh is cleared
      // by SessionInterceptor before this branch runs.
      return state.authenticated;
    } on ApiFailure {
      // A successful response with an invalid identity envelope is not safe to
      // use as an authenticated startup result.
      await clear();
      return false;
    } on Object {
      return state.authenticated;
    }
  }
}

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSession>(
  AuthSessionNotifier.new,
);

class AuthRepository {
  const AuthRepository(this._dio);
  final Dio _dio;

  Future<void> register({
    required String name,
    String? handle,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    final normalizedHandle = normalizeHandle(handle);
    final response = await _dio.post<dynamic>(
      '/auth/register',
      data: {
        'name': name.trim(),
        if (normalizedHandle != null) 'handle': normalizedHandle,
        'email': email.trim().toLowerCase(),
        'password': password,
        'password_confirmation': confirmation,
        'device_name': await _deviceName(),
      },
    );
    final data = requireApiData(asApiJsonMap(response.data));
    if (data['verification_required'] != true) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Unable to start email verification. Please try again.',
      );
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_name': await _deviceName(),
      },
    );
    return AuthSession.fromApi(requireApiData(asApiJsonMap(response.data)));
  }

  Future<void> forgotPassword(String email) async {
    final response = await _dio.post<dynamic>(
      '/auth/password/forgot',
      data: {'email': email.trim().toLowerCase()},
    );
    requireApiData(asApiJsonMap(response.data));
  }

  Future<void> logout() async {
    final response = await _dio.post<dynamic>('/auth/logout');
    requireApiData(asApiJsonMap(response.data));
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String confirmation,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/password/reset',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
    requireApiData(asApiJsonMap(response.data));
  }

  Future<void> sendCode(String email, {String purpose = 'login'}) async {
    final response = await _dio.post<dynamic>(
      '/auth/otp/send',
      data: {
        'email': email.trim().toLowerCase(),
        'purpose': purpose == 'email_verification' ? purpose : 'login',
      },
    );
    requireApiData(asApiJsonMap(response.data));
  }

  Future<AuthSession> verifyCode(
    String email,
    String code, {
    String purpose = 'login',
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/otp/verify',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code,
        'purpose': purpose == 'email_verification' ? purpose : 'login',
        'device_name': await _deviceName(),
      },
    );
    return AuthSession.fromApi(requireApiData(asApiJsonMap(response.data)));
  }

  Future<AuthSession> social({
    required String provider,
    required String token,
    String? nonce,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/social',
      data: {
        'provider': provider,
        'token': token,
        if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
        'device_name': await _deviceName(),
      },
    );
    return AuthSession.fromApi(requireApiData(asApiJsonMap(response.data)));
  }

  Future<String> _deviceName() async {
    // dart:io Platform throws on Flutter web; never touch it in browsers.
    if (kIsWeb) return 'Web browser';
    try {
      final info = DeviceInfoPlugin();
      final name = await switch (defaultTargetPlatform) {
        TargetPlatform.android => info.androidInfo.then((value) => value.model),
        TargetPlatform.iOS =>
          info.iosInfo.then((value) => value.utsname.machine),
        _ => Future<String>.value('${defaultTargetPlatform.name} device'),
      }.timeout(const Duration(seconds: 2));
      final trimmed = name.trim();
      return trimmed.isEmpty ? '${defaultTargetPlatform.name} device' : trimmed;
    } on Object {
      return '${defaultTargetPlatform.name} device';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);

class AuthFormState {
  const AuthFormState({this.submitting = false, this.failure});
  final bool submitting;
  final ApiFailure? failure;
}

class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<bool> login(String email, String password) => _run(
    () => ref
        .read(authRepositoryProvider)
        .login(email: email, password: password),
  );

  Future<bool> register(
    String name,
    String email,
    String password,
    String confirmation, [
    String? handle,
  ]) => _guard(
    () => ref
        .read(authRepositoryProvider)
        .register(
          name: name,
          email: email,
          password: password,
          confirmation: confirmation,
          handle: handle,
        ),
  );

  Future<bool> verifyCode(
    String email,
    String code, {
    String purpose = 'login',
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .verifyCode(email, code, purpose: purpose),
  );

  Future<bool> social({
    required String provider,
    required String token,
    String? nonce,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .social(provider: provider, token: token, nonce: nonce),
  );

  Future<bool> _run(Future<AuthSession> Function() operation) => _guard(() async {
    final session = await operation();
    if (!ref.mounted) return;
    await ref.read(authSessionProvider.notifier).save(session);
  });

  Future<bool> _guard(Future<void> Function() operation) async {
    if (state.submitting) return false;
    state = const AuthFormState(submitting: true);
    try {
      await operation();
      if (!ref.mounted) return false;
      state = const AuthFormState();
      return true;
    } on DioException catch (error) {
      if (!ref.mounted) return false;
      final embedded = error.error;
      state = AuthFormState(
        failure:
            embedded is ApiFailure
                ? embedded
                : apiFailureFromDio(error),
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return false;
      state = AuthFormState(failure: failure);
    } on Object catch (error) {
      if (!ref.mounted) return false;
      final detail = error.toString();
      state = AuthFormState(
        failure: ApiFailure(
          code: 'UNEXPECTED',
          message:
              detail.contains('SecureStorage') ||
                      detail.contains('flutter_secure_storage')
                  ? 'Could not save your session on this device. Check device security settings and try again.'
                  : kDebugMode
                  ? 'Something went wrong: $detail'
                  : 'Something went wrong. Please try again.',
        ),
      );
    }
    return false;
  }
}

ApiFailure apiFailureFromDio(DioException error) {
  if (error.type == DioExceptionType.cancel || CancelToken.isCancel(error)) {
    return const ApiFailure(
      code: 'CANCELLED',
      message: 'Request cancelled.',
    );
  }
  final nested = error.error;
  if (nested is ApiFailure) {
    return nested;
  }
  final body = asApiJsonMap(error.response?.data);
  if (body != null) {
    try {
      requireApiData(body);
    } on ApiFailure catch (failure) {
      return ApiFailure(
        code: failure.code,
        message: failure.message,
        fields: failure.fields,
        requestId: failure.requestId,
        statusCode: error.response?.statusCode,
      );
    }
  }
  final status = error.response?.statusCode;
  final host = error.requestOptions.uri.host;
  final path = error.requestOptions.uri.path;
  final uploading =
      path.contains('/uploads') ||
      path.endsWith('/reels') ||
      path.contains('/reels/');
  if (error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return ApiFailure(
      code: 'TIMEOUT',
      message:
          uploading
              ? 'The video upload timed out. Try a shorter clip or a stronger connection, then try again.'
              : 'Pelevo took too long to respond. Please try again.',
      statusCode: status,
    );
  }
  if (status == 413) {
    return const ApiFailure(
      code: 'TOO_LARGE',
      message:
          'That video is too large to upload. Try a shorter or more compressed clip.',
      statusCode: 413,
    );
  }
  if (status == 403) {
    return const ApiFailure(
      code: 'FORBIDDEN',
      message:
          'Pelevo blocked this request. Try again on mobile data or another network.',
      statusCode: 403,
    );
  }
  if (status == 502 ||
      status == 503 ||
      status == 504 ||
      status == 520 ||
      status == 521 ||
      status == 522 ||
      status == 523 ||
      status == 524) {
    return ApiFailure(
      code: 'UNAVAILABLE',
      message: 'Pelevo is busy. Please try again in a moment.',
      statusCode: status,
    );
  }
  final offline =
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      _looksLikeTransportFailure(error);
  if (offline) {
    return ApiFailure(
      code: 'OFFLINE',
      message:
          kDebugMode && host.isNotEmpty
              ? 'Could not reach Pelevo at $host. Is the API running, or set PELEVO_API_BASE_URL?'
              : host.isNotEmpty
              ? 'Could not reach Pelevo at $host. Check your connection and try again.'
              : 'You appear to be offline. Check your connection and try again.',
      statusCode: status,
    );
  }
  if (status != null) {
    return ApiFailure(
      code: 'BAD_RESPONSE',
      message:
          'Pelevo returned an unexpected response ($status). Please try again.',
      statusCode: status,
    );
  }
  return const ApiFailure(
    code: 'NETWORK_ERROR',
    message: 'We could not reach Pelevo. Please try again.',
  );
}

bool _looksLikeTransportFailure(DioException error) {
  final cause = '${error.error ?? ''} ${error.message ?? ''}'.toLowerCase();
  return cause.contains('socket') ||
      cause.contains('handshake') ||
      cause.contains('certificate') ||
      cause.contains('connection closed') ||
      cause.contains('connection reset') ||
      cause.contains('failed host lookup') ||
      cause.contains('network is unreachable') ||
      cause.contains('timed out');
}

final authFormProvider =
    NotifierProvider.autoDispose<AuthFormController, AuthFormState>(
      AuthFormController.new,
    );
