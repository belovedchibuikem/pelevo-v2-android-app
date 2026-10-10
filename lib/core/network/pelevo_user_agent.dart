import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// IAB-style User-Agent so podcast hosts can identify Pelevo playback and
/// downloads. Never impersonates Apple Podcasts, Spotify, or generic stacks
/// such as okhttp / CFNetwork / Mozilla / just_audio / ExoPlayer alone.
///
/// Podcast measurement reads this header on the media file request itself
/// (the .mp3), not on API calls. Android uses the Linux family token hosts
/// expect:
/// `Pelevo/1.0.0 (Linux; Android 14; SM-S911U)`
/// `Pelevo/1.0.0 (iPhone; iOS 17.5; iPhone15,2)`
class PelevoUserAgent {
  PelevoUserAgent._();

  static const appName = 'Pelevo';
  static const headerName = 'User-Agent';

  static String? _resolved;

  static String get current => _resolved ?? formatForPlatform(version: '1.0.0');

  static String resolvedOrFormat({required String version}) =>
      _resolved ?? formatForPlatform(version: version);

  @visibleForTesting
  static void setResolved(String? value) => _resolved = value;

  /// `Pelevo/1.0.0 (Linux; Android 14; SM-S911U)`
  static String format({
    required String version,
    required String system,
    required String os,
    required String device,
  }) {
    final appVersion = version.trim().isEmpty ? '1.0.0' : version.trim();
    return '$appName/$appVersion (${_field(system, 'Device')}; ${_field(os, 'OS')}; ${_field(device, 'Device')})';
  }

  static String formatForPlatform({
    required String version,
    TargetPlatform? platform,
    String? osVersion,
    String? deviceModel,
    String? system,
  }) {
    final target = platform ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.iOS:
        final family = system ?? 'iPhone';
        return format(
          version: version,
          system: family,
          os: _os('iOS', osVersion),
          device: deviceModel ?? family,
        );
      case TargetPlatform.android:
        return format(
          version: version,
          system: 'Linux',
          os: _os('Android', osVersion),
          device: deviceModel ?? 'Android',
        );
      case TargetPlatform.macOS:
        return format(
          version: version,
          system: 'Mac',
          os: _os('macOS', osVersion),
          device: deviceModel ?? 'Mac',
        );
      case TargetPlatform.windows:
        return format(
          version: version,
          system: 'Windows',
          os: _os('Windows', osVersion),
          device: deviceModel ?? 'Desktop',
        );
      case TargetPlatform.linux:
        return format(
          version: version,
          system: 'Linux',
          os: _os('Linux', osVersion),
          device: deviceModel ?? 'Desktop',
        );
      case TargetPlatform.fuchsia:
        return format(
          version: version,
          system: 'Device',
          os: _os('Fuchsia', osVersion),
          device: deviceModel ?? 'Device',
        );
    }
  }

  static Future<String> resolve({required String version}) async {
    try {
      if (kIsWeb) {
        _resolved = format(
          version: version,
          system: 'Web',
          os: 'Web',
          device: 'Web',
        );
        return _resolved!;
      }
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await plugin.androidInfo;
          _resolved = format(
            version: version,
            system: 'Linux',
            os: _os('Android', info.version.release),
            device: info.model,
          );
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          final family = _iosDeviceFamily(info.model);
          _resolved = format(
            version: version,
            system: family,
            os: _os('iOS', info.systemVersion),
            device: info.utsname.machine,
          );
        case TargetPlatform.macOS:
          final info = await plugin.macOsInfo;
          _resolved = format(
            version: version,
            system: 'Mac',
            os: _os('macOS', info.osRelease),
            device: 'Mac',
          );
        case TargetPlatform.windows:
          final info = await plugin.windowsInfo;
          _resolved = format(
            version: version,
            system: 'Windows',
            os: _os('Windows', '${info.majorVersion}'),
            device: 'Desktop',
          );
        case TargetPlatform.linux:
          final info = await plugin.linuxInfo;
          _resolved = format(
            version: version,
            system: 'Linux',
            os: _os('Linux', info.versionId),
            device: 'Desktop',
          );
        case TargetPlatform.fuchsia:
          _resolved = formatForPlatform(version: version);
      }
      return _resolved!;
    } on Object {
      _resolved = formatForPlatform(version: version);
      return _resolved!;
    }
  }

  /// Headers for a remote media URL. Local files and web playback omit them:
  /// browsers will not let script set User-Agent, and a file URI is not HTTP.
  static Map<String, String>? mediaRequestHeaders({
    required String userAgent,
    required Uri uri,
    Map<String, String>? headers,
    bool isWeb = false,
  }) {
    if (isWeb) return headers;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'file' || scheme == 'asset' || scheme == 'content') {
      return headers;
    }
    return {...?headers, headerName: userAgent};
  }

  /// Always identify Pelevo on remote media. Auth stays first-party only.
  static Map<String, String>? playbackHeaders({
    required String userAgent,
    required String audioUri,
    required bool isLocal,
    bool isWeb = false,
    String? accessToken,
    String? deviceId,
  }) {
    if (isLocal || isWeb) return null;
    final headers = <String, String>{headerName: userAgent};
    if (!_isFirstPartyHost(audioUri)) return headers;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      headers['X-Device-Id'] = deviceId;
    }
    return headers;
  }

  static bool _isFirstPartyHost(String audioUri) {
    final host = Uri.tryParse(audioUri)?.host.toLowerCase() ?? '';
    return host.isEmpty ||
        host.endsWith('pelevo.com') ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host.endsWith('.local');
  }

  static String _os(String name, String? version) {
    final value = version?.trim() ?? '';
    return value.isEmpty ? name : '$name $value';
  }

  static String _field(String? value, String fallback) {
    final cleaned =
        (value ?? '')
            .replaceAll(RegExp(r'[\r\n;()]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String _iosDeviceFamily(String model) {
    final value = model.toLowerCase();
    if (value.contains('ipad')) return 'iPad';
    if (value.contains('ipod')) return 'iPod';
    return 'iPhone';
  }
}
