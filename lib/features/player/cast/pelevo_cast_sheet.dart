import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/player/airplay/pelevo_airplay_button.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_permissions.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

Future<void> showPelevoCastSheet(
  BuildContext context,
  WidgetRef ref,
  CatalogEpisode episode,
) async {
  final controller = ref.read(pelevoCastControllerProvider);
  try {
    await controller.refreshDevices();
  } catch (error) {
    if (!context.mounted) return;
    final failure = catalogFailure(error);
    if (failure.code == 'CAST_PERMISSION') {
      await _showCastPermissionDialog(context);
      return;
    }
    context.showPelevoMessage(failure.message);
    return;
  }
  if (!context.mounted) return;

  final snapshot =
      ref.read(pelevoCastSnapshotProvider).asData?.value ?? controller.snapshot;
  if (!snapshot.supported) {
    context.showPelevoMessage(
      'Cast works in the Android and iOS apps when a Chromecast or Cast speaker is on the same Wi‑Fi.',
    );
    return;
  }

  await showPelevoSheet<void>(
    context: context,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(pelevoCastSnapshotProvider);
          final cast = async.asData?.value ?? controller.snapshot;
          final showAirPlay = pelevoAirPlayAvailable;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Play on a speaker',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  cast.connected
                      ? 'Connected to ${cast.deviceName ?? 'Cast device'}'
                      : showAirPlay
                      ? 'Choose AirPlay, or a Chromecast on the same Wi‑Fi.'
                      : 'Choose a Chromecast or Cast-enabled speaker on your Wi‑Fi.',
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
                if (showAirPlay) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.airplay_rounded),
                    title: const Text('AirPlay'),
                    subtitle: const Text(
                      'HomePod, Apple TV, and AirPlay speakers',
                    ),
                    trailing: const PelevoAirPlayRoutePicker(size: 32),
                  ),
                ],
                const SizedBox(height: 12),
                if (cast.connected) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.cast_connected_rounded,
                      color: PelevoColors.green,
                    ),
                    title: Text(cast.deviceName ?? 'Cast device'),
                    subtitle: Text(
                      cast.playing ? 'Playing on speaker' : 'Connected',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await controller.disconnect();
                          if (!context.mounted) return;
                          context.showPelevoMessage('Stopped casting');
                        } catch (error) {
                          if (!context.mounted) return;
                          context.showPelevoMessage(
                            catalogFailure(error).message,
                          );
                        }
                      },
                      child: const Text('Disconnect'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Chromecast',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (!cast.ready || cast.discovering && cast.devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cast.permissionDenied)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nearby-device access is needed to find Chromecast speakers.',
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  )
                else if (cast.devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      cast.statusMessage ??
                          'No Cast devices found. Power on your speaker and stay on the same Wi‑Fi.',
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  )
                else
                  for (final device in cast.devices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cast_rounded),
                      title: Text(device.name),
                      subtitle: Text(device.model ?? 'Cast device'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await controller.castEpisode(device, episode);
                          if (!context.mounted) return;
                          context.showPelevoMessage(
                            'Casting to ${device.name}',
                          );
                          context.go('/screen/player-device');
                        } catch (error) {
                          if (!context.mounted) return;
                          context.showPelevoMessage(
                            catalogFailure(error).message,
                          );
                        }
                      },
                    ),
                const SizedBox(height: 8),
                PelevoButton(
                  label: 'Refresh',
                  outlined: true,
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    try {
                      await controller.refreshDevices();
                    } catch (error) {
                      if (!context.mounted) return;
                      final failure = catalogFailure(error);
                      if (failure.code == 'CAST_PERMISSION') {
                        await _showCastPermissionDialog(context);
                        return;
                      }
                      context.showPelevoMessage(failure.message);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _showCastPermissionDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Find nearby speakers'),
          content: const Text(
            'Pelevo uses Nearby devices on Android 13+ (or Location on older Android) only to discover Chromecast speakers on your Wi‑Fi. Nothing is stored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await openCastPermissionSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
  );
}
