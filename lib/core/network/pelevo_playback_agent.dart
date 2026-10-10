import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Installs the IAB User-Agent on Android's ExoPlayer / Media3 HTTP stack.
///
/// just_audio only calls [DefaultHttpDataSource.Factory.setUserAgent] when the
/// source headers include User-Agent. This bridge sets that factory agent
/// directly so outbound .mp3 requests do not fall back to `just_audio`.
class PelevoPlaybackAgent {
  PelevoPlaybackAgent._();

  static const _channel = MethodChannel('pelevo/exo_user_agent');

  static Future<void> install(String userAgent) async {
    if (kIsWeb || userAgent.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('setUserAgent', {
        'userAgent': userAgent,
      });
    } on MissingPluginException {
      // iOS, desktop, and unit tests have no ExoPlayer bridge.
    } on PlatformException {
      // Source headers still identify Pelevo if the native bridge is absent.
    }
  }
}
