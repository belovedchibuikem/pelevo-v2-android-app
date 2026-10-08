import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/device_sync/device_sync_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _boardStates = <({String id, String title, String state, IconData icon})>[
  (
    id: 'sync-dashboard',
    title: 'Device & Sync',
    state: 'Account sync',
    icon: Icons.devices_rounded,
  ),
  (
    id: 'connected-devices',
    title: 'My Devices',
    state: 'Connected devices',
    icon: Icons.devices_other_rounded,
  ),
  (
    id: 'current-device-details',
    title: 'Device Details',
    state: 'Current device',
    icon: Icons.phone_android_rounded,
  ),
  (
    id: 'add-sync-device',
    title: 'Add New Device',
    state: 'Connection choices',
    icon: Icons.laptop_rounded,
  ),
  (
    id: 'scan-qr-device',
    title: 'Scan QR Code',
    state: 'Pair a device',
    icon: Icons.qr_code_scanner_rounded,
  ),
  (
    id: 'pairing-code',
    title: 'Enter Pairing Code',
    state: 'Manual pairing',
    icon: Icons.pin_outlined,
  ),
  (
    id: 'sync-status-overview',
    title: 'Sync Overview',
    state: 'Pull summary',
    icon: Icons.sync_alt_rounded,
  ),
  (
    id: 'syncing-data',
    title: 'Syncing Data',
    state: 'Sync in progress',
    icon: Icons.sync_rounded,
  ),
  (
    id: 'sync-completed',
    title: 'Sync Completed',
    state: 'Pull finished',
    icon: Icons.cloud_done_outlined,
  ),
  (
    id: 'sync-failed',
    title: 'Sync Failed',
    state: 'Sync interrupted',
    icon: Icons.sync_problem_rounded,
  ),
  (
    id: 'sync-conflicts',
    title: 'Sync Conflicts',
    state: 'Open conflicts',
    icon: Icons.merge_type_rounded,
  ),
  (
    id: 'merge-progress',
    title: 'Merging Progress',
    state: 'Resolving',
    icon: Icons.sync_rounded,
  ),
  (
    id: 'device-session',
    title: 'Device Session',
    state: 'Selected device',
    icon: Icons.laptop_mac_rounded,
  ),
  (
    id: 'remove-device',
    title: 'Remove Device?',
    state: 'Confirmation',
    icon: Icons.phonelink_erase_rounded,
  ),
  (
    id: 'sign-out-all-devices',
    title: 'Sign Out of All Devices',
    state: 'Confirmation',
    icon: Icons.logout_rounded,
  ),
  (
    id: 'offline-sync-queue',
    title: 'Offline Sync Queue',
    state: 'Account changes',
    icon: Icons.cloud_queue_rounded,
  ),
  (
    id: 'backup-restore',
    title: 'Backup & Restore',
    state: 'Cloud protection',
    icon: Icons.cloud_upload_outlined,
  ),
  (
    id: 'cloud-backup-settings',
    title: 'Cloud Backup',
    state: 'Backup settings',
    icon: Icons.settings_backup_restore_rounded,
  ),
  (
    id: 'restore-backup',
    title: 'Restore From Backup',
    state: 'Latest backup',
    icon: Icons.restore_rounded,
  ),
  (
    id: 'auto-sync-preferences',
    title: 'Auto Sync Preferences',
    state: 'Local preferences',
    icon: Icons.sync_rounded,
  ),
  (
    id: 'sync-wifi-only-setting',
    title: 'Sync Over Wi-Fi Only',
    state: 'Local preferences',
    icon: Icons.wifi_rounded,
  ),
  (
    id: 'cellular-data-sync',
    title: 'Cellular Data Sync',
    state: 'Local preferences',
    icon: Icons.signal_cellular_alt_rounded,
  ),
  (
    id: 'download-sync-settings',
    title: 'Download Sync Settings',
    state: 'Local preferences',
    icon: Icons.download_for_offline_outlined,
  ),
  (
    id: 'playlist-synchronization',
    title: 'Playlist Synchronization',
    state: 'Local preferences',
    icon: Icons.playlist_play_rounded,
  ),
  (
    id: 'library-synchronization',
    title: 'Library Sync',
    state: 'Local preferences',
    icon: Icons.library_books_outlined,
  ),
  (
    id: 'bookmark-synchronization',
    title: 'Bookmark Sync',
    state: 'Local preferences',
    icon: Icons.bookmark_outline_rounded,
  ),
  (
    id: 'favorites-synchronization',
    title: 'Favorites Sync',
    state: 'Local preferences',
    icon: Icons.favorite_outline_rounded,
  ),
  (
    id: 'listening-history-sync',
    title: 'Listening History Sync',
    state: 'Local preferences',
    icon: Icons.history_rounded,
  ),
  (
    id: 'download-history-sync',
    title: 'Download History Sync',
    state: 'Local preferences',
    icon: Icons.download_outlined,
  ),
  (
    id: 'recent-plays-sync',
    title: 'Recent Plays Sync',
    state: 'Local preferences',
    icon: Icons.replay_rounded,
  ),
  (
    id: 'storage-cache',
    title: 'Storage & Cache',
    state: 'Storage',
    icon: Icons.storage_rounded,
  ),
  (
    id: 'clear-cache',
    title: 'Clear Cache',
    state: 'Clear local cache',
    icon: Icons.cleaning_services_outlined,
  ),
  (
    id: 'reset-sync-data',
    title: 'Reset Sync Data',
    state: 'Danger zone',
    icon: Icons.delete_forever_rounded,
  ),
  (
    id: 'encryption-security',
    title: 'Encryption & Security',
    state: 'API limits',
    icon: Icons.lock_outline_rounded,
  ),
  (
    id: 'trusted-devices',
    title: 'Trusted Devices',
    state: 'Connected devices',
    icon: Icons.verified_user_outlined,
  ),
  (
    id: 'device-activity-log',
    title: 'Device Activity Log',
    state: 'Last seen',
    icon: Icons.timeline_rounded,
  ),
  (
    id: 'sync-notifications',
    title: 'Sync Notifications',
    state: 'Local preferences',
    icon: Icons.notifications_outlined,
  ),
  (
    id: 'sync-analytics',
    title: 'Sync Analytics',
    state: 'Pull summary',
    icon: Icons.insights_outlined,
  ),
  (
    id: 'device-limit',
    title: 'Device Limit Reached',
    state: 'Device count',
    icon: Icons.devices_other_rounded,
  ),
  (
    id: 'device-connected',
    title: 'Device Connected!',
    state: 'Pairing complete',
    icon: Icons.check_circle_outline_rounded,
  ),
];

final List<PelevoScreenSpec> deviceSyncExpandedScreens = List.unmodifiable(
  List.generate(_boardStates.length, (index) {
    final board = _boardStates[index];
    return PelevoScreenSpec(
      id: board.id,
      section: 'Device & Sync',
      title: board.title,
      state: board.state,
      builder: (_) => _DeviceSyncScreen(config: board),
    );
  }),
);

class _DeviceSyncScreen extends ConsumerStatefulWidget {
  const _DeviceSyncScreen({required this.config});

  final ({String id, String title, String state, IconData icon}) config;

  @override
  ConsumerState<_DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends ConsumerState<_DeviceSyncScreen> {
  bool _busy = false;
  bool _pullStarted = false;
  bool _mergeStarted = false;
  bool _pairingStarted = false;
  PairingCode? _pairing;
  String? _resolution;
  final _codeController = TextEditingController();

  bool _autoSync = true;
  bool _wifiOnly = true;
  bool _cellular = false;
  bool _downloadSync = false;
  bool _playlistSync = true;
  bool _librarySync = true;
  bool _bookmarkSync = true;
  bool _favoritesSync = true;
  bool _listeningSync = true;
  bool _downloadHistorySync = false;
  bool _recentPlaysSync = true;
  bool _notifyConflicts = true;
  bool _notifyFailures = true;
  bool _notifyCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = widget.config.id;
      if (id == 'scan-qr-device') {
        _ensurePairingCode();
      } else if (id == 'syncing-data') {
        _runPull(navigate: true);
      } else if (id == 'merge-progress') {
        _finishMerge();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _indeterminateBusy {
    final id = widget.config.id;
    return id == 'syncing-data' || id == 'merge-progress' || _busy;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final message = catalogFailure(error).message;
      ref.read(syncNoticeProvider.notifier).set(message);
      if (!mounted) return;
      context.showPelevoMessage(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensurePairingCode({bool force = false}) async {
    if (_busy) return;
    if (!force && (_pairingStarted || _pairing != null)) return;
    _pairingStarted = true;
    await _run(() async {
      final code = await ref.read(deviceSyncRepositoryProvider).pairingCode();
      if (!mounted) return;
      setState(() => _pairing = code);
    });
  }

  Future<void> _runPull({required bool navigate}) async {
    if (_pullStarted && navigate) return;
    if (navigate) _pullStarted = true;
    setState(() => _busy = true);
    try {
      ref.invalidate(syncPullProvider);
      await ref.read(syncPullProvider.future);
      ref.read(syncNoticeProvider.notifier).set(null);
      if (!mounted || !navigate) return;
      context.go('/screen/sync-completed');
    } catch (error) {
      final message = catalogFailure(error).message;
      ref.read(syncNoticeProvider.notifier).set(message);
      if (!mounted || !navigate) return;
      context.go('/screen/sync-failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishMerge() async {
    if (_mergeStarted) return;
    _mergeStarted = true;
    setState(() => _busy = true);
    try {
      ref.invalidate(syncConflictsProvider);
      await ref.read(syncConflictsProvider.future);
      if (!mounted) return;
      context.go('/screen/sync-completed');
    } catch (error) {
      final message = catalogFailure(error).message;
      ref.read(syncNoticeProvider.notifier).set(message);
      if (!mounted) return;
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

  String _pairPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  String _pairDeviceName() {
    if (kIsWeb) return 'Web browser';
    return '${defaultTargetPlatform.name} device';
  }

  SyncDevice? _resolveDevice(List<SyncDevice> list) {
    final selectedId = ref.watch(selectedDeviceIdProvider);
    final sessionDeviceId = ref.watch(authSessionProvider).deviceId;
    for (final item in list) {
      if (selectedId != null && item.id == selectedId) return item;
    }
    if (sessionDeviceId != null && sessionDeviceId.isNotEmpty) {
      for (final item in list) {
        if (item.id == sessionDeviceId) return item;
      }
    }
    final active = list.where((item) => item.active);
    return active.isEmpty ? null : active.first;
  }

  int _pullCountFor(String resourceType) {
    final pull = ref.watch(syncPullProvider).asData?.value ?? const [];
    return pull.where((item) => item.resourceType == resourceType).length;
  }

  String _backRoute(String id) {
    if (id == 'scan-qr-device' || id == 'pairing-code') {
      return '/screen/add-sync-device';
    }
    if (id == 'remove-device') return '/screen/device-session';
    if (id == 'cloud-backup-settings' || id == 'restore-backup') {
      return '/screen/backup-restore';
    }
    if (id == 'clear-cache') return '/screen/storage-cache';
    if (id == 'sync-conflicts' || id == 'merge-progress') {
      return '/screen/sync-status-overview';
    }
    if (id == 'device-connected') return '/screen/connected-devices';
    if (id == 'sync-completed' || id == 'sync-failed') {
      return '/screen/sync-status-overview';
    }
    return '/screen/sync-dashboard';
  }

  Future<void> _openPrimary() async {
    final id = widget.config.id;
    switch (id) {
      case 'sync-dashboard':
        context.go('/screen/connected-devices');
      case 'connected-devices':
      case 'trusted-devices':
      case 'device-limit':
        context.go('/screen/add-sync-device');
      case 'current-device-details':
        context.go('/screen/sync-status-overview');
      case 'add-sync-device':
        context.go('/screen/scan-qr-device');
      case 'scan-qr-device':
        context.go('/screen/pairing-code');
      case 'pairing-code':
        await _pairWithCode();
      case 'sync-status-overview':
      case 'offline-sync-queue':
        context.go('/screen/syncing-data');
      case 'syncing-data':
        await _runPull(navigate: true);
      case 'sync-completed':
      case 'device-connected':
        context.go('/screen/connected-devices');
      case 'sync-failed':
        await _run(() async {
          ref.invalidate(syncPullProvider);
          await ref.read(syncPullProvider.future);
          if (!mounted) return;
          context.go('/screen/sync-completed');
        });
      case 'sync-conflicts':
        await _resolveConflicts();
      case 'merge-progress':
        await _finishMerge();
      case 'device-session':
        context.go('/screen/remove-device');
      case 'remove-device':
        await _revokeSelected();
      case 'sign-out-all-devices':
        await _signOutAll();
      case 'backup-restore':
        await _createBackup();
      case 'cloud-backup-settings':
        context.showPelevoMessage(
          'Backup schedule is not a server setting. Local choices are not saved remotely.',
        );
      case 'restore-backup':
        await _restoreLatest();
      case 'storage-cache':
        context.go('/screen/clear-cache');
      case 'clear-cache':
      case 'reset-sync-data':
        await _clearCache(resetCopy: id == 'reset-sync-data');
      case 'encryption-security':
        context.showPelevoMessage(
          'Encryption controls are not exposed by the mobile API.',
        );
      case 'device-activity-log':
      case 'sync-analytics':
        context.go('/screen/connected-devices');
      case 'sync-notifications':
      case 'auto-sync-preferences':
      case 'sync-wifi-only-setting':
      case 'cellular-data-sync':
      case 'download-sync-settings':
      case 'playlist-synchronization':
      case 'library-synchronization':
      case 'bookmark-synchronization':
      case 'favorites-synchronization':
      case 'listening-history-sync':
      case 'download-history-sync':
      case 'recent-plays-sync':
        context.showPelevoMessage(
          'These are local preferences and are not stored as server sync flags.',
        );
      default:
        context.go('/screen/sync-dashboard');
    }
  }

  Future<void> _pairWithCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 8) {
      context.showPelevoMessage('Enter the full 8-character pairing code.');
      return;
    }
    final deviceId = ref.read(authSessionProvider).deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      context.showPelevoMessage('This session has no device identifier yet.');
      return;
    }
    await _run(() async {
      await ref.read(deviceSyncRepositoryProvider).pair(
        code: code,
        deviceIdentifier: deviceId,
        name: _pairDeviceName(),
        platform: _pairPlatform(),
      );
      ref.invalidate(syncDevicesProvider);
      if (!mounted) return;
      context.go('/screen/device-connected');
    });
  }

  Future<void> _resolveConflicts() async {
    final items = ref.read(syncConflictsProvider).asData?.value ?? const [];
    if (items.isEmpty) {
      context.go('/screen/merge-progress');
      return;
    }
    await _run(() async {
      for (final item in items) {
        final selected =
            _resolution == '${item.id}:client' ? 'client' : 'server';
        await ref.read(deviceSyncRepositoryProvider).resolveConflict(
          item.id,
          resolution: selected,
        );
      }
      ref.invalidate(syncConflictsProvider);
      if (!mounted) return;
      context.go('/screen/merge-progress');
    });
  }

  Future<void> _revokeSelected() async {
    final selectedId = ref.read(selectedDeviceIdProvider);
    if (selectedId == null || selectedId.isEmpty) {
      context.showPelevoMessage('Select a device first.');
      return;
    }
    await _run(() async {
      await ref.read(deviceSyncRepositoryProvider).revoke(selectedId);
      ref.read(selectedDeviceIdProvider.notifier).select(null);
      ref.invalidate(syncDevicesProvider);
      if (!mounted) return;
      context.go('/screen/connected-devices');
    });
  }

  Future<void> _signOutAll() async {
    await _run(() async {
      await ref.read(deviceSyncRepositoryProvider).signOutAll();
      ref.read(selectedDeviceIdProvider.notifier).select(null);
      ref.invalidate(syncDevicesProvider);
      if (!mounted) return;
      context.go('/screen/connected-devices');
    });
  }

  Future<void> _createBackup() async {
    await _run(() async {
      final backup = await ref.read(deviceSyncRepositoryProvider).createBackup();
      ref.read(latestBackupProvider.notifier).select(backup);
      if (!mounted) return;
      context.go('/screen/cloud-backup-settings');
    });
  }

  Future<void> _restoreLatest() async {
    final backup = ref.read(latestBackupProvider);
    if (backup == null) {
      context.showPelevoMessage('Create a backup first.');
      return;
    }
    await _run(() async {
      await ref.read(deviceSyncRepositoryProvider).restoreBackup(backup.id);
      if (!mounted) return;
      context.showPelevoMessage('Restore requested for backup ${backup.id}.');
    });
  }

  Future<void> _clearCache({required bool resetCopy}) async {
    await _run(() async {
      await ref.read(libraryRepositoryProvider).clearStorageCache();
      ref.invalidate(storageUsageProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        resetCopy
            ? 'Local storage cache cleared. A full account sync wipe is not offered.'
            : 'Local storage cache cleared.',
      );
      if (!resetCopy) context.go('/screen/storage-cache');
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return PelevoPage(
      appBar: AppBar(
        leading:
            config.id == 'sync-dashboard'
                ? null
                : IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go(_backRoute(config.id)),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        automaticallyImplyLeading: false,
        title: Text(config.title),
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(config: config, busy: _indeterminateBusy),
          const SizedBox(height: PelevoSpacing.xl),
          Text(config.state, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.xs),
          Text(
            _description(config.id),
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          if (config.id == 'syncing-data' || config.id == 'merge-progress') ...[
            const LinearProgressIndicator(
              minHeight: 8,
              color: PelevoColors.green,
              backgroundColor: PelevoColors.border,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Text(
              config.id == 'syncing-data'
                  ? 'Pulling account changes…'
                  : 'Resolving conflicts…',
            ),
          ] else
            _body(context),
          const SizedBox(height: PelevoSpacing.xl),
          PelevoButton(
            label: _primaryAction(config.id),
            icon: config.icon,
            onPressed: _busy ? null : _openPrimary,
          ),
          if (config.id != 'syncing-data' && config.id != 'merge-progress') ...[
            const SizedBox(height: PelevoSpacing.sm),
            PelevoButton(
              label: 'Review sync activity',
              outlined: true,
              onPressed: () => context.go('/screen/device-activity-log'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (widget.config.id) {
      case 'sync-dashboard':
        return _dashboard(context);
      case 'connected-devices':
      case 'trusted-devices':
        return _deviceList(context);
      case 'current-device-details':
      case 'device-session':
      case 'remove-device':
        return _deviceDetails(context);
      case 'add-sync-device':
        return _addDevice(context);
      case 'scan-qr-device':
        return _scanQr(context);
      case 'pairing-code':
        return _pairingCode(context);
      case 'sync-status-overview':
        return _syncOverview(context);
      case 'sync-completed':
        return _syncCompleted(context);
      case 'sync-failed':
        return _syncFailed(context);
      case 'sync-conflicts':
        return _conflicts(context);
      case 'sign-out-all-devices':
        return const Text(
          'This revokes every registered device and session for the account.',
          style: TextStyle(color: PelevoColors.textMuted),
        );
      case 'offline-sync-queue':
        return _offlineQueue(context);
      case 'backup-restore':
        return _backupRestore(context);
      case 'cloud-backup-settings':
        return _cloudBackupSettings(context);
      case 'restore-backup':
        return _restoreBackup(context);
      case 'auto-sync-preferences':
        return _prefSwitch(
          title: 'Auto sync',
          value: _autoSync,
          onChanged: (value) => setState(() => _autoSync = value),
        );
      case 'sync-wifi-only-setting':
        return _prefSwitch(
          title: 'Sync over Wi‑Fi only',
          value: _wifiOnly,
          onChanged: (value) => setState(() => _wifiOnly = value),
        );
      case 'cellular-data-sync':
        return _prefSwitch(
          title: 'Allow cellular sync',
          value: _cellular,
          onChanged: (value) => setState(() => _cellular = value),
        );
      case 'download-sync-settings':
        return _prefSwitch(
          title: 'Sync download metadata',
          value: _downloadSync,
          onChanged: (value) => setState(() => _downloadSync = value),
          resourceType: 'download',
        );
      case 'playlist-synchronization':
        return _prefSwitch(
          title: 'Sync playlists',
          value: _playlistSync,
          onChanged: (value) => setState(() => _playlistSync = value),
          resourceType: 'playlist',
        );
      case 'library-synchronization':
        return _prefSwitch(
          title: 'Sync library',
          value: _librarySync,
          onChanged: (value) => setState(() => _librarySync = value),
          resourceType: 'library',
        );
      case 'bookmark-synchronization':
        return _prefSwitch(
          title: 'Sync bookmarks',
          value: _bookmarkSync,
          onChanged: (value) => setState(() => _bookmarkSync = value),
          resourceType: 'bookmark',
        );
      case 'favorites-synchronization':
        return _prefSwitch(
          title: 'Sync favorites',
          value: _favoritesSync,
          onChanged: (value) => setState(() => _favoritesSync = value),
          resourceType: 'favorite',
        );
      case 'listening-history-sync':
        return _prefSwitch(
          title: 'Sync listening history',
          value: _listeningSync,
          onChanged: (value) => setState(() => _listeningSync = value),
          resourceType: 'listening_history',
        );
      case 'download-history-sync':
        return _prefSwitch(
          title: 'Sync download history',
          value: _downloadHistorySync,
          onChanged: (value) => setState(() => _downloadHistorySync = value),
          resourceType: 'download',
        );
      case 'recent-plays-sync':
        return _prefSwitch(
          title: 'Sync recent plays',
          value: _recentPlaysSync,
          onChanged: (value) => setState(() => _recentPlaysSync = value),
          resourceType: 'recent_play',
        );
      case 'storage-cache':
      case 'clear-cache':
        return _storage(context);
      case 'reset-sync-data':
        return const Text(
          'This clears the local storage cache only. A full account sync wipe is not offered by the mobile API.',
          style: TextStyle(color: PelevoColors.textMuted),
        );
      case 'encryption-security':
        return const Text(
          'Encryption controls are not exposed by the mobile API. Transport security follows the signed-in session.',
          style: TextStyle(color: PelevoColors.textMuted),
        );
      case 'device-activity-log':
        return _activityLog(context);
      case 'sync-notifications':
        return Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conflict alerts'),
              subtitle: const Text(
                'Local preference only — not a server notification setting.',
              ),
              value: _notifyConflicts,
              onChanged: (value) => setState(() => _notifyConflicts = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync failure alerts'),
              subtitle: const Text(
                'Local preference only — not a server notification setting.',
              ),
              value: _notifyFailures,
              onChanged: (value) => setState(() => _notifyFailures = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync completed alerts'),
              subtitle: const Text(
                'Local preference only — not a server notification setting.',
              ),
              value: _notifyCompleted,
              onChanged: (value) => setState(() => _notifyCompleted = value),
            ),
          ],
        );
      case 'sync-analytics':
        return _analytics(context);
      case 'device-limit':
        return _deviceLimit(context);
      case 'device-connected':
        return const Text(
          'This device was paired with the account. Continue to review connected devices.',
          style: TextStyle(color: PelevoColors.textMuted),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _dashboard(BuildContext context) {
    final devices = ref.watch(syncDevicesProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    final storage = ref.watch(storageUsageProvider);
    final backup = ref.watch(latestBackupProvider);
    if (devices.isLoading || conflicts.isLoading || storage.isLoading) {
      return const CatalogStatusBody();
    }
    if (devices.hasError) {
      return CatalogStatusBody(
        error: devices.error,
        retry: () => ref.invalidate(syncDevicesProvider),
      );
    }
    if (conflicts.hasError) {
      return CatalogStatusBody(
        error: conflicts.error,
        retry: () => ref.invalidate(syncConflictsProvider),
      );
    }
    if (storage.hasError) {
      return CatalogStatusBody(
        error: storage.error,
        retry: () => ref.invalidate(storageUsageProvider),
      );
    }
    final deviceCount = devices.requireValue.length;
    final conflictCount = conflicts.requireValue.length;
    final usage = storage.requireValue;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.devices_other_rounded, color: PelevoColors.green),
          ),
          title: const Text('Manage Devices'),
          subtitle: Text('$deviceCount registered'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/connected-devices'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.sync_rounded, color: PelevoColors.green),
          ),
          title: const Text('Sync Settings'),
          subtitle: Text(
            conflictCount == 0
                ? 'No open conflicts'
                : '$conflictCount open conflicts',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/auto-sync-preferences'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.backup_outlined, color: PelevoColors.green),
          ),
          title: const Text('Backup & Restore'),
          subtitle: Text(
            backup == null
                ? 'No backup created yet'
                : '${backup.state} · ${backup.sizeBytes} B',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/backup-restore'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.storage_rounded, color: PelevoColors.green),
          ),
          title: const Text('Storage & Cache'),
          subtitle: Text(
            '${usage.backupBytes} B backup · ${usage.offlineItems} offline items',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/storage-cache'),
        ),
      ],
    );
  }

  Widget _deviceList(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncDevicesProvider),
      );
    }
    final list = async.requireValue;
    if (list.isEmpty) {
      return const Text(
        'No registered devices yet.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return Column(
      children: [
        for (final device in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                _platformIcon(device.platform),
                color: PelevoColors.green,
              ),
            ),
            title: Text(device.name),
            subtitle: Text(device.subtitle),
            trailing: Icon(
              Icons.circle,
              size: 10,
              color:
                  device.active ? PelevoColors.green : PelevoColors.textDim,
            ),
            onTap: () {
              ref.read(selectedDeviceIdProvider.notifier).select(device.id);
              context.go('/screen/device-session');
            },
          ),
      ],
    );
  }

  Widget _deviceDetails(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncDevicesProvider),
      );
    }
    final device = _resolveDevice(async.requireValue);
    if (device == null) {
      return const Text(
        'No device is available to show.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    final confirming = widget.config.id == 'remove-device';
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              _platformIcon(device.platform),
              color: PelevoColors.green,
            ),
          ),
          title: Text(device.name),
          subtitle: Text(device.subtitle),
          trailing: Text(device.trustState),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          subtitle: Text(device.active ? 'Yes' : 'Revoked'),
        ),
        if (confirming)
          const Text(
            'Removing this device revokes its registered session.',
            style: TextStyle(color: PelevoColors.textMuted),
          ),
      ],
    );
  }

  Widget _addDevice(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.qr_code_scanner_rounded, color: PelevoColors.green),
        title: const Text('Show pairing QR'),
        subtitle: const Text('Generate a code another device can enter'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/scan-qr-device'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.pin_outlined, color: PelevoColors.green),
        title: const Text('Enter pairing code'),
        subtitle: const Text('Connect this device with an 8-character code'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/pairing-code'),
      ),
    ],
  );

  Widget _scanQr(BuildContext context) {
    final code = _pairing?.code;
    return Column(
      children: [
        if (code == null)
          _busy
              ? const CatalogStatusBody()
              : const Text(
                'No pairing code yet. Generate one to show a QR.',
                style: TextStyle(color: PelevoColors.textMuted),
              )
        else ...[
          Center(
            child: Semantics(
              image: true,
              label: 'Pairing code QR',
              child: ColoredBox(
                color: Colors.white,
                child: QrImageView(
                  data: code,
                  size: 190,
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: PelevoSpacing.md),
          Text(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            'Expires in ${_pairing!.expiresIn} seconds',
            textAlign: TextAlign.center,
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
        ],
        const SizedBox(height: PelevoSpacing.md),
        const Text(
          'Camera auto-pair is not offered. Share this code with the other device, then enter a code on this device if needed.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        TextButton(
          onPressed: _busy ? null : () => _ensurePairingCode(force: true),
          child: const Text('Generate new code'),
        ),
      ],
    );
  }

  Widget _pairingCode(BuildContext context) => Column(
    children: [
      TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        maxLength: 8,
        decoration: const InputDecoration(
          labelText: '8-character pairing code',
          hintText: 'ABCD1234',
        ),
      ),
      const Text(
        'Connect calls the pairing API with this session’s device identifier.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
    ],
  );

  Widget _syncOverview(BuildContext context) {
    final pull = ref.watch(syncPullProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    final devices = ref.watch(syncDevicesProvider);
    if (pull.isLoading || conflicts.isLoading || devices.isLoading) {
      return const CatalogStatusBody();
    }
    Object? error;
    VoidCallback? retry;
    if (pull.hasError) {
      error = pull.error;
      retry = () => ref.invalidate(syncPullProvider);
    } else if (conflicts.hasError) {
      error = conflicts.error;
      retry = () => ref.invalidate(syncConflictsProvider);
    } else if (devices.hasError) {
      error = devices.error;
      retry = () => ref.invalidate(syncDevicesProvider);
    }
    if (error != null) return CatalogStatusBody(error: error, retry: retry);
    final active =
        devices.requireValue.where((item) => item.active).length;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Account changes'),
          subtitle: Text('${pull.requireValue.length}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open conflicts'),
          subtitle: Text('${conflicts.requireValue.length}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active devices'),
          subtitle: Text('$active'),
        ),
      ],
    );
  }

  Widget _syncCompleted(BuildContext context) {
    final pull = ref.watch(syncPullProvider).asData?.value ?? const [];
    final devices = ref.watch(syncDevicesProvider).asData?.value ?? const [];
    final active = devices.where((item) => item.active).length;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Changes pulled'),
          subtitle: Text('${pull.length}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active devices'),
          subtitle: Text('$active'),
        ),
      ],
    );
  }

  Widget _syncFailed(BuildContext context) {
    final notice = ref.watch(syncNoticeProvider);
    return Text(
      notice?.isNotEmpty == true
          ? notice!
          : 'Sync could not finish. Retry to pull account changes again.',
      style: const TextStyle(color: PelevoColors.textMuted),
    );
  }

  Widget _conflicts(BuildContext context) {
    final async = ref.watch(syncConflictsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncConflictsProvider),
      );
    }
    final items = async.requireValue;
    if (items.isEmpty) {
      return const Text(
        'No open conflicts.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return Column(
      children: [
        for (final item in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.resourceType),
            subtitle: Text('${item.state} · ${item.createdAt}'),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep server'),
            value: '${item.id}:server',
            groupValue: _resolution ?? '${item.id}:server',
            onChanged: (value) => setState(() => _resolution = value),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep client'),
            value: '${item.id}:client',
            groupValue: _resolution ?? '${item.id}:server',
            onChanged: (value) => setState(() => _resolution = value),
          ),
        ],
      ],
    );
  }

  Widget _offlineQueue(BuildContext context) {
    final async = ref.watch(syncPullProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncPullProvider),
      );
    }
    final items = async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A separate local offline queue API is not offered. These are account changes from sync pull awaiting apply.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (items.isEmpty)
          const Text(
            'No account changes awaiting apply.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${item.resourceType} · ${item.operation}'),
              subtitle: Text(item.resourceId),
              trailing: Text('v${item.version}'),
            ),
      ],
    );
  }

  Widget _backupRestore(BuildContext context) {
    final backup = ref.watch(latestBackupProvider);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Latest backup'),
          subtitle: Text(
            backup == null
                ? 'None created in this session yet'
                : '${backup.id} · ${backup.state} · ${backup.sizeBytes} B',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Restore from backup'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/restore-backup'),
        ),
      ],
    );
  }

  Widget _cloudBackupSettings(BuildContext context) {
    final backup = ref.watch(latestBackupProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backup schedule is not a server setting.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Last backup'),
          subtitle: Text(
            backup == null
                ? 'No backup yet'
                : '${backup.id} · ${backup.state} · ${backup.sizeBytes} B',
          ),
        ),
      ],
    );
  }

  Widget _restoreBackup(BuildContext context) {
    final backup = ref.watch(latestBackupProvider);
    if (backup == null) {
      return const Text(
        'Create a backup first. A remote backup list is not offered here.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(backup.id),
      subtitle: Text('${backup.state} · ${backup.sizeBytes} B'),
    );
  }

  Widget _prefSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? resourceType,
  }) {
    final count =
        resourceType == null ? null : _pullCountFor(resourceType);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        count == null
            ? 'Local preference only — not a server sync flag.'
            : 'Local preference only — not a server sync flag. Pull changes for this type: $count.',
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _storage(BuildContext context) {
    final async = ref.watch(storageUsageProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(storageUsageProvider),
      );
    }
    final usage = async.requireValue;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Backup bytes'),
          subtitle: Text('${usage.backupBytes} B'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offline items'),
          subtitle: Text('${usage.offlineItems}'),
        ),
      ],
    );
  }

  Widget _activityLog(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncDevicesProvider),
      );
    }
    final list = async.requireValue;
    if (list.isEmpty) {
      return const Text(
        'No devices to show activity for.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Only last_seen_at / last_active_at from registered devices are shown. Invented activity events are not available.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.md),
        for (final device in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _platformIcon(device.platform),
              color: PelevoColors.green,
            ),
            title: Text(device.name),
            subtitle: Text(
              [
                if (device.lastSeenAt != null) 'Seen ${device.lastSeenAt}',
                if (device.lastActiveAt != null) 'Active ${device.lastActiveAt}',
                if (device.lastSeenAt == null && device.lastActiveAt == null)
                  'No timestamps reported',
              ].join(' · '),
            ),
          ),
      ],
    );
  }

  Widget _analytics(BuildContext context) {
    final devices = ref.watch(syncDevicesProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    final pull = ref.watch(syncPullProvider);
    if (devices.isLoading || conflicts.isLoading || pull.isLoading) {
      return const CatalogStatusBody();
    }
    Object? error;
    VoidCallback? retry;
    if (devices.hasError) {
      error = devices.error;
      retry = () => ref.invalidate(syncDevicesProvider);
    } else if (conflicts.hasError) {
      error = conflicts.error;
      retry = () => ref.invalidate(syncConflictsProvider);
    } else if (pull.hasError) {
      error = pull.error;
      retry = () => ref.invalidate(syncPullProvider);
    }
    if (error != null) return CatalogStatusBody(error: error, retry: retry);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Registered devices'),
          subtitle: Text('${devices.requireValue.length}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open conflicts'),
          subtitle: Text('${conflicts.requireValue.length}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pull changes'),
          subtitle: Text('${pull.requireValue.length}'),
        ),
      ],
    );
  }

  Widget _deviceLimit(BuildContext context) {
    final async = ref.watch(syncDevicesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(syncDevicesProvider),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Current devices'),
          subtitle: Text('${async.requireValue.length}'),
        ),
        const Text(
          'A maximum device limit is not reported by the API.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.config, required this.busy});

  final ({String id, String title, String state, IconData icon}) config;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final error =
        config.id.contains('failed') ||
        config.id == 'sync-failed' ||
        config.id == 'reset-sync-data';
    final success =
        config.id.contains('completed') ||
        config.id == 'device-connected' ||
        config.id == 'sync-completed';
    final color =
        error
            ? PelevoColors.red
            : success
            ? PelevoColors.green
            : PelevoColors.blue;
    return Semantics(
      container: true,
      label: '${config.title}, ${config.state}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PelevoSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: PelevoRadii.card,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .14),
              ),
              child: Icon(config.icon, size: 30, color: color),
            ),
            const SizedBox(width: PelevoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(config.state, style: TextStyle(color: color)),
                  if (busy)
                    const Text(
                      'In progress',
                      style: TextStyle(color: PelevoColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _description(String id) {
  return switch (id) {
    'scan-qr-device' =>
      'Generate a pairing code for another device. Camera scanning is not offered.',
    'pairing-code' =>
      'Enter an 8-character code to register this device with the account.',
    'syncing-data' || 'merge-progress' =>
      'Keep Pelevo open until the request finishes. Progress percent is not reported.',
    'sync-conflicts' =>
      'Choose whether each conflict keeps the server or client version.',
    'offline-sync-queue' =>
      'Account changes from sync pull. A separate offline queue endpoint is not available.',
    'backup-restore' || 'cloud-backup-settings' || 'restore-backup' =>
      'Create or restore account backups through the mobile API.',
    'storage-cache' || 'clear-cache' || 'reset-sync-data' =>
      'Storage figures come from backup bytes and offline item counts only.',
    'encryption-security' =>
      'Encryption controls are not exposed by the mobile API.',
    'device-activity-log' =>
      'Timestamps reported by registered devices — no invented activity feed.',
    'sync-analytics' =>
      'Counts from devices, conflicts, and pull changes. Success rate is not invented.',
    'device-limit' =>
      'Shows the current registered device count. Maximum is not reported.',
    'device-connected' =>
      'Shown after a successful pairing API call.',
    _ when id.contains('synchronization') ||
            id.contains('sync-settings') ||
            id.contains('preferences') ||
            id.contains('wifi') ||
            id.contains('cellular') ||
            id.contains('notifications') =>
      'These controls are local preferences and are not stored as server sync flags.',
    _ =>
      'Manage registered devices and pull account changes across your Pelevo session.',
  };
}

String _primaryAction(String id) {
  return switch (id) {
    'sync-dashboard' => 'Manage Devices',
    'connected-devices' || 'trusted-devices' || 'device-limit' =>
      'Add New Device',
    'current-device-details' => 'View Sync Status',
    'add-sync-device' => 'Scan QR Code',
    'scan-qr-device' => 'Enter Code Manually',
    'pairing-code' => 'Connect Device',
    'sync-status-overview' || 'offline-sync-queue' => 'Sync Now',
    'syncing-data' => 'Continue',
    'sync-completed' || 'device-connected' => 'Continue',
    'sync-failed' => 'Retry Now',
    'sync-conflicts' => 'Resolve',
    'merge-progress' => 'Finish',
    'device-session' => 'Sign Out',
    'remove-device' => 'Remove',
    'sign-out-all-devices' => 'Sign Out All',
    'backup-restore' => 'Create Backup',
    'cloud-backup-settings' || 'sync-notifications' => 'Save Settings',
    'restore-backup' => 'Restore Now',
    'storage-cache' => 'Manage Storage',
    'clear-cache' => 'Clear Cache',
    'reset-sync-data' => 'Reset Now',
    'encryption-security' => 'Learn More',
    'device-activity-log' || 'sync-analytics' => 'View Details',
    _ => 'Save Settings',
  };
}
