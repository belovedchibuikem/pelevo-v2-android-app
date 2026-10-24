import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/device_sync/device_sync_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/library/library_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

List<PelevoScreenSpec> get deviceSyncBasicScreens => [
  for (var i = 0; i < _titles.length; i++)
    PelevoScreenSpec(
      id: 'device-sync-basic-${i + 1}',
      section: 'Device & Sync',
      title: _titles[i],
      state: _states[i],
      builder: (_) => DeviceSyncBasicScreen(index: i),
    ),
];

const _titles = [
  'Device & Sync Home',
  'My Devices',
  'Add New Device',
  'Sync Settings',
  'Syncing Now',
  'Sync Completed',
  'Offline Listening',
  'Storage & Data',
  'Download Limits',
  'Sync Conflicts',
  'Device Session',
  'Advanced Sync',
];

const _states = [
  'Account in sync',
  'Four logged-in devices',
  'Connection choices',
  'All content enabled',
  '75% progress',
  'Success',
  'Offline',
  '3.2 GB used',
  '5 GB · High Quality',
  'Two conflicts',
  'MacBook Pro',
  'Backup and danger zone',
];

class DeviceSyncBasicScreen extends ConsumerStatefulWidget {
  const DeviceSyncBasicScreen({required this.index, super.key});
  final int index;

  @override
  ConsumerState<DeviceSyncBasicScreen> createState() =>
      _DeviceSyncBasicScreenState();
}

class _DeviceSyncBasicScreenState extends ConsumerState<DeviceSyncBasicScreen> {
  double? _limitMb;
  int _quality = 0;
  bool _busy = false;
  PairingCode? _pairing;
  AccountBackup? _backup;
  String? _resolution;

  @override
  Widget build(BuildContext context) {
    ref.watch(syncDevicesProvider);
    ref.watch(syncPullProvider);
    ref.watch(syncConflictsProvider);
    ref.watch(profileProvider);
    ref.watch(libraryOverviewProvider);
    ref.watch(storageUsageProvider);
    ref.watch(downloadSettingsProvider);
    return PelevoPage(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            widget.index == 0 || widget.index == 4
                ? null
                : IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go(_backRoute),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        title: Text(_titles[widget.index]),
        actions: [
          if (widget.index == 0)
            IconButton(
              tooltip: 'Sync settings',
              onPressed: () => context.go('/screen/device-sync-basic-4'),
              icon: const Icon(Icons.settings_outlined),
            ),
          if (widget.index == 1)
            IconButton(
              tooltip: 'Add device',
              onPressed: () => context.go('/screen/device-sync-basic-3'),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _content(context),
      ),
    );
  }

  String get _backRoute => switch (widget.index) {
    2 || 10 => '/screen/device-sync-basic-2',
    8 => '/screen/device-sync-basic-8',
    9 => '/screen/device-sync-basic-4',
    _ => '/screen/device-sync-basic-1',
  };

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final message = catalogFailure(error).message;
      if (!context.mounted) return;
      context.showPelevoMessage(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData _platformIcon(String platform) {
    final value = platform.toLowerCase();
    if (value.contains('ios') || value.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    }
    if (value.contains('mac')) return Icons.laptop_mac_rounded;
    if (value.contains('android')) return Icons.phone_android_rounded;
    if (value.contains('ipad') || value.contains('tablet')) {
      return Icons.tablet_mac_rounded;
    }
    if (value.contains('web') || value.contains('windows')) {
      return Icons.desktop_windows_rounded;
    }
    return Icons.devices_rounded;
  }

  List<Widget> _content(BuildContext context) {
    switch (widget.index) {
      case 0:
        return _home(context);
      case 1:
        return _devices(context);
      case 2:
        return _addDevice(context);
      case 3:
        return _syncSettings(context);
      case 4:
        return _syncing(context);
      case 5:
        return _completed(context);
      case 6:
        return _offline(context);
      case 7:
        return _storage(context);
      case 8:
        return _limits(context);
      case 9:
        return _conflicts(context);
      case 10:
        return _session(context);
      default:
        return _advanced(context);
    }
  }

  List<Widget> _home(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final devices = ref.watch(syncDevicesProvider);
    final overview = ref.watch(libraryOverviewProvider);
    if (profile.isLoading || devices.isLoading || overview.isLoading) {
      return const [CatalogStatusBody()];
    }
    if (profile.hasError) {
      return [
        CatalogStatusBody(
          error: profile.error,
          retry: () => ref.invalidate(profileProvider),
        ),
      ];
    }
    if (devices.hasError) {
      return [
        CatalogStatusBody(
          error: devices.error,
          retry: () => ref.invalidate(syncDevicesProvider),
        ),
      ];
    }
    if (overview.hasError) {
      return [
        CatalogStatusBody(
          error: overview.error,
          retry: () => ref.invalidate(libraryOverviewProvider),
        ),
      ];
    }
    final user = profile.requireValue;
    final list = devices.requireValue;
    final library = overview.requireValue;
    final lastSeen = list
        .map((item) => item.lastSeenAt ?? item.lastActiveAt)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .fold<String?>(null, (latest, value) => latest == null || value.compareTo(latest) > 0 ? value : latest);
    return [
      CircleAvatar(
        radius: 38,
        backgroundImage:
            user.avatarUrl == null ? const AssetImage('assets/podcast/guest_tolu.png') : null,
        child:
            user.avatarUrl == null
                ? null
                : CatalogArtwork(url: user.avatarUrl, width: 76, height: 76),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        user.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(user.email, textAlign: TextAlign.center),
      const UtilityHero(
        icon: Icons.cloud_done_rounded,
        title: 'Sync is Active',
        body: 'Registered devices can pull account changes.',
      ),
      UtilityRow(
        title: 'Last Synced',
        subtitle: lastSeen ?? 'Not reported',
        icon: Icons.sync_rounded,
        trailing: const Icon(Icons.refresh_rounded),
        onTap: () => context.go('/screen/device-sync-basic-5'),
      ),
      const UtilitySection('Sync Overview'),
      UtilityRow(
        title: 'Playlists',
        subtitle: '${library.playlists.length}',
        icon: Icons.playlist_play_rounded,
        trailing: const Icon(Icons.check_circle_rounded, color: PelevoColors.green),
      ),
      UtilityRow(
        title: 'Downloads',
        subtitle: '${library.downloadsCount}',
        icon: Icons.download_done_rounded,
        trailing: const Icon(Icons.check_circle_rounded, color: PelevoColors.green),
      ),
      PelevoButton(
        label: 'Manage Devices',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/device-sync-basic-2'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      OutlinedButton.icon(
        onPressed: () => context.go('/screen/sync-dashboard'),
        icon: const Icon(Icons.dashboard_customize_outlined),
        label: const Text('Advanced Sync Dashboard'),
      ),
      UtilityRow(
        title: 'App Permissions',
        subtitle: 'Notifications, mic, storage, devices',
        icon: Icons.security_rounded,
        color: PelevoColors.green,
        onTap: () => context.go('/screen/permissions-intro'),
      ),
      UtilityRow(
        title: 'Library Settings',
        icon: Icons.settings_outlined,
        onTap: () => context.go('/screen/library-12'),
      ),
      UtilityRow(
        title: 'Storage & Data',
        icon: Icons.storage_rounded,
        onTap: () => context.go('/screen/device-sync-basic-8'),
      ),
      UtilityRow(
        title: 'Offline Listening',
        icon: Icons.airplanemode_active_rounded,
        onTap: () => context.go('/screen/device-sync-basic-7'),
      ),
    ];
  }

  List<Widget> _devices(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const [CatalogStatusBody()];
    if (async.hasError) {
      return [
        CatalogStatusBody(
          error: async.error,
          retry: () => ref.invalidate(syncDevicesProvider),
        ),
      ];
    }
    final list = async.requireValue;
    final active = list.where((item) => item.active).toList(growable: false);
    return [
      const UtilitySection('This Device'),
      if (active.isEmpty)
        Text(
          'No registered devices yet.',
          style: TextStyle(color: context.pelevo.textMuted),
        )
      else
        _deviceRow(active.first, true),
      const UtilitySection('Other Devices'),
      if (active.length <= 1)
        Text(
          'No other devices.',
          style: TextStyle(color: context.pelevo.textMuted),
        )
      else
        for (final item in active.skip(1)) _deviceRow(item, item.active),
      Center(child: Text('Logged in on ${active.length} devices')),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Add New Device',
        icon: Icons.add_rounded,
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/device-sync-basic-3'),
      ),
    ];
  }

  List<Widget> _addDevice(BuildContext context) => [
    const UtilityHero(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Connect a new device',
      body: 'Scan the QR code on your other device to connect.',
    ),
    const SizedBox(height: PelevoSpacing.xl),
    PelevoButton(
      label: 'Scan QR Code',
      icon: Icons.qr_code_scanner_rounded,
      color: PelevoColors.green,
      onPressed: () => context.go('/screen/scan-qr-device'),
    ),
    const SizedBox(height: PelevoSpacing.sm),
    PelevoButton(
      label: 'Enter Code Manually',
      outlined: true,
      color: PelevoColors.green,
      foregroundColor: PelevoColors.green,
      onPressed: () => context.go('/screen/pairing-code'),
    ),
    const SizedBox(height: PelevoSpacing.md),
    PelevoButton(
      label: 'Get pairing code',
      color: context.pelevo.surfaceHigh,
      onPressed: _busy
          ? null
          : () => _run(() async {
            final code = await ref.read(deviceSyncRepositoryProvider).pairingCode();
            if (!mounted) return;
            setState(() => _pairing = code);
          }),
    ),
    if (_pairing != null) ...[
      const SizedBox(height: PelevoSpacing.md),
      Text(
        _pairing!.code,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(
        'Expires in ${_pairing!.expiresIn} seconds',
        textAlign: TextAlign.center,
      ),
    ],
    const SizedBox(height: PelevoSpacing.md),
    const Text(
      'Make sure you’re signed in on the other device.',
      textAlign: TextAlign.center,
    ),
  ];

  List<Widget> _syncSettings(BuildContext context) => [
    const UtilitySection('Sync Options'),
    const ToggleRow(
      title: 'Sync Listening Progress',
      subtitle: 'Not stored as a per-type server flag',
      icon: Icons.play_circle_outline_rounded,
    ),
    const ToggleRow(
      title: 'Sync Playlists',
      subtitle: 'Not stored as a per-type server flag',
      icon: Icons.playlist_play_rounded,
    ),
    const ToggleRow(
      title: 'Sync Liked Episodes',
      subtitle: 'Not stored as a per-type server flag',
      icon: Icons.favorite_outline_rounded,
    ),
    const ToggleRow(
      title: 'Sync Downloads',
      subtitle: 'Not stored as a per-type server flag',
      icon: Icons.download_outlined,
    ),
    const ToggleRow(
      title: 'Sync History',
      subtitle: 'Not stored as a per-type server flag',
      icon: Icons.history_rounded,
    ),
    const UtilitySection('Sync Preferences'),
    const ToggleRow(
      title: 'Sync Over Wi‑Fi Only',
      subtitle: 'Download Wi-Fi is a separate setting',
      icon: Icons.wifi_rounded,
    ),
    const ToggleRow(
      title: 'Auto Sync',
      subtitle: 'Background sync is not a server flag',
      icon: Icons.sync_rounded,
    ),
    UtilityRow(
      title: 'Sync Quality (Downloads)',
      subtitle: 'Limit is stored as max_storage_mb',
      icon: Icons.high_quality_rounded,
      onTap: () => context.go('/screen/device-sync-basic-9'),
    ),
    UtilityRow(
      title: 'Advanced Sync Settings',
      icon: Icons.tune_rounded,
      onTap: () => context.go('/screen/auto-sync-preferences'),
    ),
    UtilityRow(
      title: 'Resolve Sync Conflicts',
      icon: Icons.warning_amber_rounded,
      onTap: () => context.go('/screen/device-sync-basic-10'),
    ),
    UtilityRow(
      title: 'Backup & Advanced Sync',
      icon: Icons.backup_outlined,
      onTap: () => context.go('/screen/device-sync-basic-12'),
    ),
  ];

  List<Widget> _syncing(BuildContext context) {
    final pull = ref.watch(syncPullProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    return [
      const UtilityHero(
        icon: Icons.cloud_sync_rounded,
        title: 'Syncing Your Data',
        body: 'Please don’t close the app.',
      ),
      const UtilitySection('Overall Progress'),
      Text(
        pull.isLoading || conflicts.isLoading
            ? 'Reading account changes…'
            : 'Transfer percent is not reported.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      if (pull.hasError)
        CatalogStatusBody(
          error: pull.error,
          retry: () => ref.invalidate(syncPullProvider),
        ),
      if (conflicts.hasError)
        CatalogStatusBody(
          error: conflicts.error,
          retry: () => ref.invalidate(syncConflictsProvider),
        ),
      UtilityRow(
        title: 'Changes',
        subtitle: '${pull.asData?.value.length ?? 0}',
        icon: Icons.sync_rounded,
      ),
      UtilityRow(
        title: 'Open conflicts',
        subtitle: '${conflicts.asData?.value.length ?? 0}',
        icon: Icons.warning_amber_rounded,
      ),
      PelevoButton(
        label: 'Finish Sync',
        color: PelevoColors.green,
        onPressed: _busy
            ? null
            : () => _run(() async {
              await ref.read(syncPullProvider.future);
              await ref.read(syncConflictsProvider.future);
              if (!context.mounted) return;
              context.go('/screen/device-sync-basic-6');
            }),
      ),
    ];
  }

  List<Widget> _completed(BuildContext context) {
    final pull = ref.watch(syncPullProvider).asData?.value ?? const [];
    final devices = ref.watch(syncDevicesProvider).asData?.value ?? const [];
    return [
      const UtilityHero(
        icon: Icons.check_rounded,
        title: 'You’re All Set!',
        body: 'Account change pull finished.',
      ),
      const UtilitySection('Sync Summary'),
      UtilityRow(
        title: 'Items Updated',
        subtitle: '${pull.length}',
        icon: Icons.check_circle_outline_rounded,
      ),
      UtilityRow(
        title: 'Devices Updated',
        subtitle: '${devices.where((item) => item.active).length}',
        icon: Icons.check_circle_outline_rounded,
      ),
      PelevoButton(
        label: 'Done',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/device-sync-basic-1'),
      ),
    ];
  }

  List<Widget> _offline(BuildContext context) {
    final usage = ref.watch(storageUsageProvider);
    final count = usage.asData?.value.offlineItems;
    return [
      const UtilityHero(
        icon: Icons.airplanemode_active_rounded,
        title: 'You’re Offline',
        body:
            'No internet connection detected. You can still listen to your downloads.',
      ),
      const UtilitySection('Offline Mode'),
      UtilityRow(
        title: 'Downloads Available',
        subtitle: count == null ? 'Loading' : '$count episodes',
        icon: Icons.download_done_rounded,
      ),
      PelevoButton(
        label: 'View Downloads',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/downloads-2'),
      ),
    ];
  }

  List<Widget> _storage(BuildContext context) {
    final usage = ref.watch(storageUsageProvider);
    if (usage.isLoading) return const [CatalogStatusBody()];
    if (usage.hasError) {
      return [
        CatalogStatusBody(
          error: usage.error,
          retry: () => ref.invalidate(storageUsageProvider),
        ),
      ];
    }
    final data = usage.requireValue;
    return [
      StorageChart(
        used: data.offlineItems.toDouble(),
        total: data.offlineItems == 0 ? 1 : data.offlineItems.toDouble(),
        donut: false,
        centerLabel: '${data.offlineItems} files',
        semanticsLabel: '${data.offlineItems} authorized files',
        items: [
          ('Authorized files', '${data.offlineItems}', PelevoColors.green),
          ('Backup bytes', '${data.backupBytes} B', PelevoColors.yellow),
        ],
      ),
      const UtilitySection('Data Management'),
      UtilityRow(
        title: 'Clear Cache',
        subtitle: '${data.offlineItems} authorizations',
        icon: Icons.cleaning_services_outlined,
        onTap: _busy
            ? () {}
            : () => _run(() async {
              await ref.read(libraryRepositoryProvider).clearStorageCache();
              ref.invalidate(storageUsageProvider);
              ref.invalidate(libraryDownloadsProvider);
            }),
      ),
      UtilityRow(
        title: 'Delete Old Downloads',
        icon: Icons.auto_delete_outlined,
        onTap: () => context.go('/screen/downloads-7'),
      ),
      UtilityRow(
        title: 'Manage Downloads',
        icon: Icons.download_for_offline_outlined,
        onTap: () => context.go('/screen/downloads-5'),
      ),
      UtilityRow(
        title: 'Storage Settings',
        icon: Icons.settings_outlined,
        onTap: () => context.go('/screen/storage-cache'),
      ),
    ];
  }

  List<Widget> _limits(BuildContext context) {
    final async = ref.watch(downloadSettingsProvider);
    if (async.isLoading) return const [CatalogStatusBody()];
    if (async.hasError) {
      return [
        CatalogStatusBody(
          error: async.error,
          retry: () => ref.invalidate(downloadSettingsProvider),
        ),
      ];
    }
    final settings = async.requireValue;
    final value =
        ((_limitMb ?? settings.maxStorageMb.toDouble()).clamp(128.0, 65536.0))
            .toDouble();
    return [
      const UtilitySection('Storage Limit'),
      Text(
        '${value.round()} MB',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      Slider(
        value: value,
        min: 128,
        max: 65536,
        divisions: 64,
        label: '${value.round()} MB',
        onChanged: (next) => setState(() => _limitMb = next),
      ),
      const Text(
        'When the stored limit is reached, cleanup still waits for an authorization delete.',
      ),
      const UtilitySection('Download Quality'),
      RadioListTile<int>(
        value: 0,
        groupValue: _quality,
        title: const Text('High Quality'),
        subtitle: const Text('Quality is not stored on the server.'),
        activeColor: PelevoColors.green,
        onChanged: (next) => setState(() => _quality = next!),
      ),
      RadioListTile<int>(
        value: 1,
        groupValue: _quality,
        title: const Text('Medium Quality'),
        subtitle: const Text('Quality is not stored on the server.'),
        activeColor: PelevoColors.green,
        onChanged: (next) => setState(() => _quality = next!),
      ),
      RadioListTile<int>(
        value: 2,
        groupValue: _quality,
        title: const Text('Low Quality'),
        subtitle: const Text('Quality is not stored on the server.'),
        activeColor: PelevoColors.green,
        onChanged: (next) => setState(() => _quality = next!),
      ),
      PelevoButton(
        label: 'Save Changes',
        color: PelevoColors.green,
        onPressed: _busy
            ? null
            : () => _run(() async {
              await ref.read(libraryRepositoryProvider).saveDownloadSettings(
                settings,
                maxStorageMb: value.round(),
              );
              ref.invalidate(downloadSettingsProvider);
              if (!context.mounted) return;
              context.go('/screen/device-sync-basic-4');
            }),
      ),
    ];
  }

  List<Widget> _conflicts(BuildContext context) {
    final async = ref.watch(syncConflictsProvider);
    if (async.isLoading) return const [CatalogStatusBody()];
    if (async.hasError) {
      return [
        CatalogStatusBody(
          error: async.error,
          retry: () => ref.invalidate(syncConflictsProvider),
        ),
      ];
    }
    final items = async.requireValue;
    return [
      const UtilityHero(
        icon: Icons.warning_amber_rounded,
        title: 'We found some conflicts',
        body: 'Choose which data you want to keep.',
        color: PelevoColors.yellow,
      ),
      if (items.isEmpty)
        Text(
          'No open conflicts.',
          style: TextStyle(color: context.pelevo.textMuted),
        )
      else
        for (final item in items) ...[
          UtilityRow(
            title: item.resourceType,
            subtitle: item.createdAt,
            icon: Icons.sync_problem_rounded,
          ),
          RadioListTile<String>(
            value: '${item.id}:server',
            groupValue: _resolution,
            title: const Text('Keep server'),
            onChanged: (value) => setState(() => _resolution = value),
          ),
          RadioListTile<String>(
            value: '${item.id}:client',
            groupValue: _resolution,
            title: const Text('Keep this device'),
            onChanged: (value) => setState(() => _resolution = value),
          ),
        ],
      PelevoButton(
        label: 'Resolve All',
        color: PelevoColors.green,
        onPressed: items.isEmpty || _busy
            ? null
            : () => _run(() async {
              for (final item in items) {
                final selected = _resolution == '${item.id}:client' ? 'client' : 'server';
                await ref.read(deviceSyncRepositoryProvider).resolveConflict(
                  item.id,
                  resolution: selected,
                );
              }
              ref.invalidate(syncConflictsProvider);
            }),
      ),
    ];
  }

  List<Widget> _session(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const [CatalogStatusBody()];
    if (async.hasError) {
      return [
        CatalogStatusBody(
          error: async.error,
          retry: () => ref.invalidate(syncDevicesProvider),
        ),
      ];
    }
    final list = async.requireValue;
    final selectedId = ref.watch(selectedDeviceIdProvider);
    SyncDevice? device;
    for (final item in list) {
      if (item.id == selectedId) device = item;
    }
    device ??= list.isEmpty ? null : list.first;
    if (device == null) {
      return [
        Text(
          'Select a device first.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
      ];
    }
    final current = device;
    return [
      UtilityHero(
        icon: _platformIcon(current.platform),
        title: current.name,
        body: current.subtitle,
        color: PelevoColors.blue,
      ),
      const UtilitySection('Sync Status'),
      UtilityRow(
        title: 'Trust',
        subtitle: current.trustState,
        icon: Icons.check_circle_rounded,
        trailing: Icon(
          Icons.circle,
          size: 10,
          color: current.active ? PelevoColors.green : context.pelevo.textDim,
        ),
      ),
      PelevoButton(
        label: 'Sign Out of Device',
        onPressed: _busy
            ? null
            : () => _run(() async {
              await ref.read(deviceSyncRepositoryProvider).revoke(current.id);
              ref.invalidate(syncDevicesProvider);
              if (!context.mounted) return;
              context.go('/screen/device-sync-basic-2');
            }),
      ),
    ];
  }

  List<Widget> _advanced(BuildContext context) {
    final profile = ref.watch(profileProvider).asData?.value;
    return [
      const UtilitySection('Backup & Restore'),
      UtilityRow(
        title: 'Create Backup',
        subtitle: _backup == null ? 'Backup your data' : '${_backup!.state} · ${_backup!.sizeBytes} B',
        icon: Icons.backup_outlined,
        onTap: _busy
            ? () {}
            : () => _run(() async {
              final backup = await ref.read(deviceSyncRepositoryProvider).createBackup();
              if (!mounted) return;
              setState(() => _backup = backup);
            }),
      ),
      UtilityRow(
        title: 'Restore from Backup',
        subtitle: 'Restore your data',
        icon: Icons.restore_rounded,
        onTap: () => context.go('/screen/restore-backup'),
      ),
      const UtilitySection('Account Sync Info'),
      UtilityRow(
        title: 'Account',
        subtitle: profile?.email ?? 'Loading',
        icon: Icons.account_circle_outlined,
      ),
      UtilityRow(
        title: 'Data Encrypted',
        subtitle: 'On',
        icon: Icons.lock_outline_rounded,
        onTap: () => context.go('/screen/encryption-security'),
      ),
      const UtilitySection('Danger Zone'),
      UtilityRow(
        title: 'Sign out all devices',
        subtitle: 'Revoke every registered device and session.',
        icon: Icons.delete_forever_rounded,
        color: PelevoColors.red,
        onTap: _busy
            ? () {}
            : () => _run(() async {
              await ref.read(deviceSyncRepositoryProvider).signOutAll();
              ref.invalidate(syncDevicesProvider);
            }),
      ),
    ];
  }

  Widget _deviceRow(SyncDevice device, bool online) => UtilityRow(
    title: device.name,
    subtitle: device.subtitle,
    icon: _platformIcon(device.platform),
    trailing: Icon(
      Icons.circle,
      size: 10,
      color: online ? PelevoColors.green : context.pelevo.textDim,
    ),
    onTap: () {
      ref.read(selectedDeviceIdProvider.notifier).select(device.id);
      context.go('/screen/device-sync-basic-11');
    },
  );
}
