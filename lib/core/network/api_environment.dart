import 'package:flutter/foundation.dart';

/// Deployment configuration only; this must never fall back to sample content.
abstract final class ApiEnvironment {
  static const developmentBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const productionBaseUrl = 'https://pelevo.com/api/v1';

  /// Public website origin used for share / App Link URLs (no `/api/v1`).
  static String get publicWebBase {
    const configured = String.fromEnvironment('PELEVO_PUBLIC_WEB_BASE');
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }
    final api = baseUrl;
    if (api.endsWith('/api/v1')) {
      return api.substring(0, api.length - '/api/v1'.length);
    }
    return 'https://pelevo.com';
  }

  static String get baseUrl {
    const configured = String.fromEnvironment('PELEVO_API_BASE_URL');
    if (configured.isNotEmpty) {
      return validate(configured, release: kReleaseMode);
    }
    if (kReleaseMode) {
      return validate(productionBaseUrl, release: true);
    }
    // Chrome/debug web usually tests against the live API; override with
    // --dart-define=PELEVO_API_BASE_URL=http://localhost:8000/api/v1 for local.
    if (kIsWeb) {
      return validate(productionBaseUrl, release: false);
    }
    final local =
        defaultTargetPlatform == TargetPlatform.android
            ? developmentBaseUrl
            : 'http://localhost:8000/api/v1';
    return validate(local, release: false);
  }

  static String validate(String value, {required bool release}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.replaceAll(RegExp(r'/+$'), '') != '/api/v1' ||
        (release && uri.scheme != 'https')) {
      throw StateError(
        'PELEVO_API_BASE_URL must be an absolute API URL ending in /api/v1. '
        'Release builds require HTTPS, without credentials, query or fragment.',
      );
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }
}
