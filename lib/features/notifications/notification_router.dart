import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Opens episode/show destinations from FCM, local notifications, and inbox taps.
abstract final class PelevoNotificationRouter {
  static String? _pending;
  static void Function(String location)? _go;
  static var _listening = false;

  static void bindGo(void Function(String location) go) {
    _go = go;
  }

  static String? consumePending() {
    final location = _pending;
    _pending = null;
    return location;
  }

  static Future<void> listenForOpens() async {
    if (_listening || kIsWeb) return;
    _listening = true;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        openMessage(initial);
      }
    } on Object {
      // Tests and hosts without Firebase continue without remote tap handling.
    }
    FirebaseMessaging.onMessageOpenedApp.listen(openMessage);
  }

  static void openMessage(RemoteMessage message) {
    openData(message.data);
  }

  static void openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        openData(Map<String, dynamic>.from(decoded));
        return;
      }
    } on Object {
      // Fall through to treating the payload as an episode id.
    }
    if (payload.length >= 8) {
      goTo('/episodes/$payload');
    }
  }

  static void openData(Map<String, dynamic> data) {
    final location = locationFor(data);
    if (location != null) goTo(location);
  }

  static String? locationFor(Map<String, dynamic> data) {
    if (_text(data['type']) == 'earn_award') {
      return '/screen/earn-wallet';
    }
    if (_text(data['type']) == 'claim_decision') {
      return '/screen/claim-status';
    }
    final episodeId = _text(data['episode_id']);
    final showId = _text(data['show_id']);
    final reelId = _text(data['reel_id']);
    if (episodeId != null) {
      return showId == null
          ? '/episodes/$episodeId'
          : '/episodes/$episodeId?showId=$showId';
    }
    if (reelId != null) {
      return '/reels/$reelId';
    }
    if (showId != null) {
      return '/shows/$showId';
    }
    return null;
  }

  static String encodePayload(Map<String, dynamic> data) {
    final payload = <String, String>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) continue;
      final text = '$value';
      if (text.isEmpty) continue;
      payload[entry.key] = text;
    }
    return jsonEncode(payload);
  }

  static void goTo(String location) {
    if (location.isEmpty) return;
    _pending = location;
    _go?.call(location);
  }

  @visibleForTesting
  static void reset() {
    _pending = null;
    _go = null;
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return '$value';
    return null;
  }
}
