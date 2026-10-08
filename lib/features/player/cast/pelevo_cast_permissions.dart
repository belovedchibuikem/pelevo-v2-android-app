import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permission Chromecast needs to discover nearby devices.
///
/// Android 13+ uses Nearby Wi‑Fi Devices. Older Android versions use location
/// because Wi‑Fi / mDNS scans are gated behind it. iOS prompts automatically
/// via [NSLocalNetworkUsageDescription] when Cast discovery starts.
Future<bool> ensureCastDiscoveryPermissions() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final permission =
        info.version.sdkInt >= 33
            ? Permission.nearbyWifiDevices
            : Permission.locationWhenInUse;
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
    final next = await permission.request();
    return next.isGranted || next.isLimited;
  } on Object {
    // Widget tests and hosts without the permission plugin still allow Cast init.
    return true;
  }
}

Future<void> openCastPermissionSettings() async {
  try {
    await openAppSettings();
  } on Object {
    // Settings may be unavailable in tests or on desktop.
  }
}
