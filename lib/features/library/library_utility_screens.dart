import 'package:pelevo/features/device_sync/device_sync_basic_screens.dart';
import 'package:pelevo/features/downloads/download_screens.dart';
import 'package:pelevo/features/library/library_screens.dart';
import 'package:pelevo/features/notifications/notification_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

/// The 48 Library, Notifications, Downloads & Storage, and Device & Sync
/// showcase states, ordered as they appear on their four design boards.
final List<PelevoScreenSpec> libraryUtilityScreens = [
  ...libraryScreens,
  ...notificationScreens,
  ...downloadScreens,
  ...deviceSyncBasicScreens,
];
