import 'package:dio/dio.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

/// Coordinates rotating credentials across concurrent requests. Network failures
/// retain the session; only a rejected refresh revokes it.
class SessionInterceptor extends Interceptor {
  SessionInterceptor({
    required this.dio,
    required this.readSession,
    required this.saveSession,
    required this.clearSession,
    this.installationId,
  });

  final Dio dio;
  final AuthSession Function() readSession;
  final Future<void> Function(AuthSession) saveSession;
  final Future<void> Function() clearSession;
  final String? installationId;
  Future<AuthSession>? _refreshing;

  bool _public(RequestOptions options) =>
      options.path.startsWith('/auth/') && options.path != '/auth/logout';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final base = Uri.parse(dio.options.baseUrl);
    if (options.uri.origin != base.origin ||
        !options.uri.path.startsWith(
          '${base.path.replaceFirst(RegExp(r'/$'), '')}/',
        )) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiFailure(
            code: 'INVALID_API_DESTINATION',
            message: 'This request cannot be sent to that destination.',
          ),
        ),
      );
      return;
    }
    final session = readSession();
    if (!_public(options) && session.authenticated) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      options.extra['sessionUser'] = session.userId;
    }
    final deviceHeader = installationId ?? session.deviceId;
    if (deviceHeader?.isNotEmpty == true) {
      options.headers['X-Device-Id'] = deviceHeader;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final session = readSession();
    if (err.response?.statusCode != 401 ||
        _public(request) ||
        request.extra['sessionRetry'] == true ||
        !session.authenticated ||
        request.extra['sessionUser'] != session.userId) {
      handler.next(err);
      return;
    }
    AuthSession renewed;
    try {
      if (request.headers['Authorization'] != 'Bearer ${session.accessToken}') {
        renewed = session;
      } else {
        renewed = await (_refreshing ??= _refresh(session));
      }
    } on DioException catch (refreshError) {
      handler.next(refreshError);
      return;
    } on Object catch (failure) {
      handler.next(DioException(requestOptions: request, error: failure));
      return;
    }
    if (readSession().refreshToken != renewed.refreshToken) {
      handler.next(err);
      return;
    }
    request.extra['sessionRetry'] = true;
    request.headers['Authorization'] = 'Bearer ${renewed.accessToken}';
    if (request.data is FormData) {
      request.data = (request.data as FormData).clone();
    }
    try {
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthSession> _refresh(AuthSession original) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {
          'refresh_token': original.refreshToken,
          'device_id': original.deviceId,
        },
      );
      final renewed = AuthSession.fromApi(requireApiData(asApiJsonMap(response.data)));
      if (readSession().refreshToken != original.refreshToken ||
          renewed.userId != original.userId) {
        throw const ApiFailure(
          code: 'SESSION_CHANGED',
          message: 'Please sign in again.',
        );
      }
      final preserved = _preserveCreatorAccess(original, renewed);
      await saveSession(preserved);
      return preserved;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 &&
          readSession().refreshToken == original.refreshToken) {
        await clearSession();
      }
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  AuthSession _preserveCreatorAccess(AuthSession original, AuthSession renewed) {
    final nextUser = Map<String, dynamic>.from(renewed.user ?? const {});
    if (nextUser['capabilities'] is Map) {
      return renewed;
    }
    final previous = original.user?['capabilities'];
    if (previous is! Map) {
      return renewed;
    }
    nextUser['capabilities'] = previous;
    return AuthSession(
      accessToken: renewed.accessToken,
      refreshToken: renewed.refreshToken,
      deviceId: renewed.deviceId,
      user: Map<String, dynamic>.unmodifiable(nextUser),
    );
  }
}
