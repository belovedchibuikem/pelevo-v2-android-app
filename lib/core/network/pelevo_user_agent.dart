import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// IAB-style User-Agent so podcast hosts can identify Pelevo playback and
/// downloads. Never impersonates Apple Podcasts, Spotify, or generic stacks
/// such as okhttp / CFNetwork / Mozilla alone.
///
/// Examples:
/// `Pelevo/2.1.0 (iPhone; iOS 17.5; en-US)`
/// `Pelevo/2.1.0 (Mobile; Android 14; en-US)`
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

  static String format({
    required String version,
    required String device,
    required String os,
    required String locale,
  }) {
    final appVersion = version.trim().isEmpty ? '1.0.0' : version.trim();
    return '$appName/$appVersion (${device.trim()}; ${os.trim()}; ${locale.trim()})';
  }

  static String formatForPlatform({
    required String version,
    TargetPlatform? platform,
    String? locale,
    String? osVersion,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final tag = locale ?? localeTag();
    switch (target) {
      case TargetPlatform.iOS:
        return format(
          version: version,
          device: 'iPhone',
          os: _os('iOS', osVersion),
          locale: tag,
        );
      case TargetPlatform.android:
        return format(
          version: version,
          device: 'Mobile',
          os: _os('Android', osVersion),
          locale: tag,
        );
      case TargetPlatform.macOS:
        return format(
          version: version,
          device: 'Mac',
          os: _os('macOS', osVersion),
          locale: tag,
        );
      case TargetPlatform.windows:
        return format(
          version: version,
          device: 'Desktop',
          os: _os('Windows', osVersion),
          locale: tag,
        );
      case TargetPlatform.linux:
        return format(
          version: version,
          device: 'Desktop',
          os: _os('Linux', osVersion),
          locale: tag,
        );
      case TargetPlatform.fuchsia:
        return format(
          version: version,
          device: 'Device',
          os: _os('Fuchsia', osVersion),
          locale: tag,
        );
    }
  }

  static String localeTag([Locale? locale]) {
    final value = locale ?? PlatformDispatcher.instance.locale;
    final country = value.countryCode;
    if (country == null || country.isEmpty) {
      return value.languageCode;
    }
    return '${value.languageCode}-$country';
  }

  static Future<String> resolve({required String version}) async {
    final tag = localeTag();
    try {
      if (kIsWeb) {
        _resolved = format(
          version: version,
          device: 'Web',
          os: 'Web',
          locale: tag,
        );
        return _resolved!;
      }
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await plugin.androidInfo;
          _resolved = format(
            version: version,
            device: 'Mobile',
            os: _os('Android', info.version.release),
            locale: tag,
          );
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          _resolved = format(
            version: version,
            device: _iosDeviceFamily(info.model),
            os: _os('iOS', info.systemVersion),
            locale: tag,
          );
        case TargetPlatform.macOS:
          final info = await plugin.macOsInfo;
          _resolved = format(
            version: version,
            device: 'Mac',
            os: _os('macOS', info.osRelease),
            locale: tag,
          );
        case TargetPlatform.windows:
          final info = await plugin.windowsInfo;
          _resolved = format(
            version: version,
            device: 'Desktop',
            os: _os('Windows', '${info.majorVersion}'),
            locale: tag,
          );
        case TargetPlatform.linux:
          final info = await plugin.linuxInfo;
          _resolved = format(
            version: version,
            device: 'Desktop',
            os: _os('Linux', info.versionId),
            locale: tag,
          );
        case TargetPlatform.fuchsia:
          _resolved = formatForPlatform(version: version, locale: tag);
      }
      return _resolved!;
    } on Object {
      _resolved = formatForPlatform(version: version, locale: tag);
      return _resolved!;
    }
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

  static String _iosDeviceFamily(String model) {
    final value = model.toLowerCase();
    if (value.contains('ipad')) return 'iPad';
    if (value.contains('ipod')) return 'iPod';
    return 'iPhone';
  }
}
