import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

const wifiDownloadBlocked = ApiFailure(
  code: 'WIFI_REQUIRED',
  message:
      'Downloads are set to Wi-Fi only. Connect to Wi-Fi, or turn that setting off in Library Settings.',
);

Future<bool> deviceIsOnWifi() async {
  if (kIsWeb) return false;
  try {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  } on Object {
    return false;
  }
}

const _downloadDeclined = ApiFailure(
  code: 'CANCELLED',
  message: 'Request cancelled.',
);

/// Asks before using mobile data when Wi-Fi-only downloads are turned on.
Future<bool> confirmDownloadOnMobileData(BuildContext context) async {
  final choice = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: context.pelevo.surface,
          title: const Text('Download on mobile data?'),
          content: const Text(
            'Downloads are set to Wi-Fi only, and this device is using mobile data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Download',
                style: TextStyle(color: PelevoColors.green),
              ),
            ),
          ],
        ),
  );
  return choice ?? false;
}

Future<void> ensureWifiAllowsDownload(
  WidgetRef ref, {
  Future<bool> Function()? confirmCellular,
}) async {
  // downloadSettingsProvider is autoDispose. Reading it from a button with no
  // listener disposes the provider immediately and cancels the request, so
  // Authorize Download returned without a message or a file.
  final token = CancelToken();
  final DownloadSettings settings;
  try {
    settings = await ref.read(libraryRepositoryProvider).downloadSettings(token);
  } catch (error) {
    if (!token.isCancelled) token.cancel();
    rethrow;
  }
  if (!settings.wifiOnly) return;
  if (await deviceIsOnWifi()) return;
  if (confirmCellular != null) {
    if (await confirmCellular()) return;
    throw _downloadDeclined;
  }
  throw wifiDownloadBlocked;
}

void refreshAuthorizedDownloads(WidgetRef ref) {
  ref.invalidate(libraryDownloadsProvider);
}

/// Downloads new episodes from followed shows when the listener turned auto
/// download on and the current network is allowed.
Future<int> syncAutoDownloads(WidgetRef ref) async {
  final token = CancelToken();
  var saved = 0;
  try {
    final settings = await ref.read(libraryRepositoryProvider).downloadSettings(token);
    if (!settings.autoDownloadNew) return 0;
    if (settings.wifiOnly && !await deviceIsOnWifi()) return 0;
    final candidates = await ref
        .read(libraryRepositoryProvider)
        .newEpisodeDownloads(token);
    final files = ref.read(downloadFileServiceProvider);
    final catalog = ref.read(catalogRepositoryProvider);
    for (final item in candidates) {
      if (await files.isDownloaded(item.episodeId)) continue;
      try {
        final url = await catalog.authorizeDownload(item.episodeId);
        await files.downloadEpisode(episodeId: item.episodeId, url: url);
        saved++;
      } on ApiFailure catch (error) {
        if (error.code == 'DOWNLOAD_LIMIT' || error.code == 'WIFI_REQUIRED') {
          break;
        }
        rethrow;
      }
    }
    return saved;
  } finally {
    token.cancel();
  }
}
