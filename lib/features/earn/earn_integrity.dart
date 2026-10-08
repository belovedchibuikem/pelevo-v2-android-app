import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Mints an Earn integrity token for heartbeat evidence.
///
/// Uses `PELEVO_EARN_INTEGRITY_SECRET` when it is compiled in. Otherwise uses
/// the local API secret so heartbeats can be verified and coins can be awarded.
class EarnIntegrity {
  static const _hmacSecret = String.fromEnvironment(
    'PELEVO_EARN_INTEGRITY_SECRET',
  );

  /// Matches the default local API `EARN_INTEGRITY_TOKEN` for debug/staging.
  static const _debugSecret = 'pelevo-dev-earn-integrity';

  static String get _effectiveSecret {
    if (_hmacSecret.isNotEmpty) return _hmacSecret;
    if (kDebugMode) return _debugSecret;
    return '';
  }

  static Future<String> token({
    required String deviceId,
    required String sessionId,
    required int sequence,
    required String nonce,
    required int position,
    required int elapsedSeconds,
    required int mediaDurationSeconds,
  }) async {
    final secret =
        _effectiveSecret.isNotEmpty ? _effectiveSecret : _debugSecret;
    final material = utf8.encode(
      '$deviceId|$sessionId|$sequence|$nonce|$position|$elapsedSeconds|$mediaDurationSeconds',
    );
    final digest = Hmac(sha256, utf8.encode(secret)).convert(material);
    return 'v2.${digest.toString()}';
  }
}
