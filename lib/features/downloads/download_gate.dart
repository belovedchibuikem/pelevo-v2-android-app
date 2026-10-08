import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
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

Future<void> ensureWifiAllowsDownload(WidgetRef ref) async {
  final settings = await ref.read(downloadSettingsProvider.future);
  if (!settings.wifiOnly) return;
  if (await deviceIsOnWifi()) return;
  throw wifiDownloadBlocked;
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
