import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void pelevoLocalNotificationBackgroundTap(NotificationResponse response) {
  PelevoNotificationRouter.openPayload(response.payload);
}

/// Local (and lock-visible) notifications + Android notification channels.
class PelevoLocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _alertsChannel = AndroidNotificationChannel(
    'pelevo_alerts',
    'Pelevo Alerts',
    description: 'Episode, download and live alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const _quietChannel = AndroidNotificationChannel(
    'pelevo_quiet',
    'Pelevo Quiet',
    description: 'Low-priority Pelevo alerts',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse:
          pelevoLocalNotificationBackgroundTap,
    );
    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_alertsChannel);
    await androidPlugin?.createNotificationChannel(_quietChannel);
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      PelevoNotificationRouter.openPayload(
        launch?.notificationResponse?.payload,
      );
    }
  }

  static void _onTap(NotificationResponse response) {
    PelevoNotificationRouter.openPayload(response.payload);
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  static Future<void> showAlert({
    required int id,
    required String title,
    required String body,
    bool quiet = false,
    bool playSound = true,
    bool vibrate = true,
    String? payload,
  }) async {
    if (!_ready) await initialize();
    final channel = quiet ? _quietChannel : _alertsChannel;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: quiet ? Importance.low : Importance.high,
          priority: quiet ? Priority.low : Priority.high,
          playSound: playSound && !quiet,
          enableVibration: vibrate && !quiet,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound && !quiet,
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> snooze({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    if (!_ready) await initialize();
    final when = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannel.id,
          _alertsChannel.name,
          channelDescription: _alertsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> openSystemNotificationSettings() async {
    await openAppSettings();
  }
}

final localNotificationsReadyProvider = FutureProvider<bool>((ref) async {
  await PelevoLocalNotifications.initialize();
  return true;
});
