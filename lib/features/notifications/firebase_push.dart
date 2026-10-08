import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/local_notifications.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:pelevo/features/notifications/push_token_repository.dart';

int _messageNotificationId(RemoteMessage message) =>
    (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) &
    0x7fffffff;

Map<String, dynamic> _messageData(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);
  final type = message.data['type'];
  if (type is! String || type.isEmpty) {
    data['type'] = 'new_episode';
  }
  return data;
}

@pragma('vm:entry-point')
Future<void> pelevoFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
  if (message.notification != null) {
    return;
  }
  final data = _messageData(message);
  final title = data['title']?.toString();
  final body = data['body']?.toString();
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }
  await PelevoLocalNotifications.initialize();
  await PelevoLocalNotifications.showAlert(
    id: _messageNotificationId(message),
    title: title == null || title.isEmpty ? 'Pelevo' : title,
    body: body ?? '',
    payload: PelevoNotificationRouter.encodePayload(data),
  );
}

class PelevoFirebasePush {
  PelevoFirebasePush(this._ref);
  final Ref _ref;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  String? _lastToken;
  String? _registeredUserId;
  var _started = false;

  Future<String> bootstrap() async {
    if (kIsWeb) {
      return 'Web push is not configured.';
    }
    try {
      await Firebase.initializeApp();
    } on Object catch (error) {
      return 'Firebase could not start: $error';
    }

    final messaging = FirebaseMessaging.instance;
    if (_started) {
      return _syncToken(messaging);
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final denied = settings.authorizationStatus == AuthorizationStatus.denied;

    await PelevoLocalNotifications.initialize();
    await PelevoLocalNotifications.requestPermission();
    await PelevoNotificationRouter.listenForOpens();
    await messaging.setAutoInitEnabled(true);

    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.getAPNSToken();
    }

    await _foreground?.cancel();
    _foreground = FirebaseMessaging.onMessage.listen((message) async {
      final data = _messageData(message);
      final notification = message.notification;
      final title = notification?.title ?? data['title']?.toString();
      final body = notification?.body ?? data['body']?.toString();
      if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
        return;
      }
      await PelevoLocalNotifications.showAlert(
        id: _messageNotificationId(message),
        title: title == null || title.isEmpty ? 'Pelevo' : title,
        body: body ?? '',
        payload: PelevoNotificationRouter.encodePayload(data),
      );
    });

    await _tokenRefresh?.cancel();
    _tokenRefresh = messaging.onTokenRefresh.listen(_registerToken);
    _started = true;
    final synced = await _syncToken(messaging);
    return denied
        ? 'Notification permission is off in system settings. $synced'
        : synced;
  }

  Future<String> _syncToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return 'Firebase started, but no FCM token was issued yet.';
      }
      await _registerToken(token);
      return _lastToken == token
          ? 'Firebase push enabled and device token registered.'
          : 'Firebase started. Sign in to register this device for episode alerts.';
    } on Object catch (error) {
      debugPrint('Pelevo FCM token sync failed: $error');
      return 'Firebase started, but this device could not obtain a push token.';
    }
  }

  Future<void> _registerToken(String token) async {
    final session = _ref.read(authSessionProvider);
    if (session.userId == null) {
      _lastToken = null;
      _registeredUserId = null;
      return;
    }
    if (_lastToken == token && _registeredUserId == session.userId) return;
    try {
      await _ref.read(pushTokenRepositoryProvider).register(
        provider: 'fcm',
        token: token,
      );
      _lastToken = token;
      _registeredUserId = session.userId;
    } on ApiFailure catch (error) {
      debugPrint('Pelevo FCM token register failed: ${error.code} ${error.message}');
    } on Object catch (error) {
      debugPrint('Pelevo FCM token register failed: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
  }
}

final pelevoFirebasePushProvider = Provider((ref) {
  final push = PelevoFirebasePush(ref);
  ref.onDispose(push.dispose);
  return push;
});
