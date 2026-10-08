import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/downloads/download_gate.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/library/library_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _DownloadView {
  home,
  all,
  downloading,
  settings,
  storage,
  smart,
  episodes,
  options,
  bulk,
  history,
  location,
  offline,
}

const _inventory =
    <({String id, String title, String state, _DownloadView view})>[
      (
        id: 'downloads-1',
        title: 'Downloads',
        state: 'Storage overview',
        view: _DownloadView.home,
      ),
      (
        id: 'downloads-2',
        title: 'All Downloads',
        state: 'Episodes and podcasts',
        view: _DownloadView.all,
      ),
      (
        id: 'downloads-3',
        title: 'Downloading',
        state: '3 active · 2 queued',
        view: _DownloadView.downloading,
      ),
      (
        id: 'downloads-4',
        title: 'Download Settings',
        state: 'Quality and automation',
        view: _DownloadView.settings,
      ),
      (
        id: 'downloads-5',
        title: 'Storage Management',
        state: 'Cleanup',
        view: _DownloadView.storage,
      ),
      (
        id: 'downloads-6',
        title: 'Smart Downloads',
        state: 'Enabled · 5 GB',
        view: _DownloadView.smart,
      ),
      (
        id: 'downloads-7',
        title: 'Downloaded Episodes',
        state: 'Newest first',
        view: _DownloadView.episodes,
      ),
      (
        id: 'downloads-8',
        title: 'Episode Options',
        state: 'Ep. 124',
        view: _DownloadView.options,
      ),
      (
        id: 'downloads-9',
        title: 'Bulk Actions',
        state: '3 selected',
        view: _DownloadView.bulk,
      ),
      (
        id: 'downloads-10',
        title: 'Download History',
        state: 'Completed',
        view: _DownloadView.history,
      ),
      (
        id: 'downloads-11',
        title: 'Download Location',
        state: 'Internal storage',
        view: _DownloadView.location,
      ),
      (
        id: 'downloads-12',
        title: 'Offline Mode',
        state: 'No connection',
        view: _DownloadView.offline,
      ),
    ];

final List<PelevoScreenSpec> downloadScreens = List.unmodifiable(
  _inventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Downloads & Storage',
      title: item.title,
      state: item.state,
      builder: (_) => _DownloadScreen(view: item.view, title: item.title),
    ),
  ),
);

class _DownloadScreen extends ConsumerStatefulWidget {
  const _DownloadScreen({required this.view, required this.title});

  final _DownloadView view;
  final String title;

  @override
  ConsumerState<_DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<_DownloadScreen> {
  int _nav = 3;
  int _allFilter = 0;
  int _historyFilter = 1;
  final int _quality = 0;
  int _location = 0;
  bool _paused = false;
  bool _smart = true;
  bool _newestFirst = true;
  bool _busy = false;

  bool get _preview => ref.read(catalogPreviewProvider);

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryDownloadsProvider);
    ref.watch(downloadSettingsProvider);
    ref.watch(storageUsageProvider);
    ref.watch(selectedDownloadIdsProvider);
    return PelevoPage(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            widget.view == _DownloadView.home
                ? PelevoBackButton(fallback: '/screen/library-5')
                : IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.pelevoBack(fallback: _backRoute),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        title: Text(
          widget.view == _DownloadView.bulk
              ? '${ref.watch(selectedDownloadIdsProvider).length} selected'
              : widget.title,
        ),
        actions: [
          if (widget.view == _DownloadView.home)
            IconButton(
              tooltip: 'Download settings',
              onPressed: () => context.go('/screen/downloads-4'),
              icon: const Icon(Icons.settings_outlined),
            ),
          if (widget.view == _DownloadView.downloading)
            TextButton(
              onPressed: () => setState(() => _paused = !_paused),
              child: Text(_paused ? 'Resume All' : 'Pause All'),
            ),
          if (widget.view == _DownloadView.bulk)
            TextButton(
              onPressed: () => context.go('/screen/downloads-7'),
              child: const Text('Cancel'),
            ),
        ],
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      ),
      child: switch (widget.view) {
        _DownloadView.home => _home(context),
        _DownloadView.all => _all(context),
        _DownloadView.downloading => _downloading(context),
        _DownloadView.settings => _settings(context),
        _DownloadView.storage => _storage(context),
        _DownloadView.smart => _smartDownloads(context),
        _DownloadView.episodes => _downloadedEpisodes(context),
        _DownloadView.options => _options(context),
        _DownloadView.bulk => _bulk(context),
        _DownloadView.history => _history(context),
        _DownloadView.location => _downloadLocation(context),
        _DownloadView.offline => _offline(context),
      },
    );
  }

  String get _backRoute => switch (widget.view) {
    _DownloadView.smart ||
    _DownloadView.settings ||
    _DownloadView.storage ||
    _DownloadView.all ||
    _DownloadView.downloading ||
    _DownloadView.history ||
    _DownloadView.offline => '/screen/downloads-1',
    _DownloadView.location => '/screen/downloads-4',
    _DownloadView.options || _DownloadView.bulk => '/screen/downloads-7',
    _DownloadView.episodes => '/screen/downloads-2',
    _DownloadView.home => '/screen/home-feed',
  };

  List<LibraryDownload> get _downloads =>
      ref.watch(libraryDownloadsProvider).asData?.value ?? const [];

  LibraryDownload? get _selectedDownload {
    final id = ref.watch(selectedDownloadIdProvider);
    for (final item in _downloads) {
      if (item.downloadId == id) return item;
    }
    return _downloads.isEmpty ? null : _downloads.first;
  }

  Widget _status({required Object? error, required VoidCallback retry}) {
    if (error != null) return CatalogStatusBody(error: error, retry: retry);
    return const CatalogStatusBody();
  }

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

  void _openOptions(LibraryDownload item) {
    ref.read(selectedDownloadIdProvider.notifier).select(item.downloadId);
    openCatalogEpisode(
      context,
      episodeId: item.episodeId,
      showId: item.showId,
    );
    context.go('/screen/downloads-8');
  }

  void _openDetails(LibraryDownload item) {
    openCatalogEpisodeDetails(
      context,
      episodeId: item.episodeId,
      showId: item.showId,
    );
  }

  void _play(LibraryDownload item) {
    playCatalogEpisode(
      context,
      episodeId: item.episodeId,
      showId: item.showId,
    );
  }

  Widget _home(BuildContext context) {
    final downloads = ref.watch(libraryDownloadsProvider);
    final storage = ref.watch(storageUsageProvider);
    if (downloads.isLoading || storage.isLoading) return const CatalogStatusBody();
    if (downloads.hasError) {
      return _status(
        error: downloads.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    if (storage.hasError) {
      return _status(
        error: storage.error,
        retry: () => ref.invalidate(storageUsageProvider),
      );
    }
    final items = downloads.requireValue;
    final usage = storage.requireValue;
    final count = usage.offlineItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StorageChart(
          used: count.toDouble(),
          total: count == 0 ? 1 : count.toDouble(),
          centerLabel: '$count\nFiles',
          semanticsLabel: '$count authorized files',
          items: [
            ('Authorized files', '$count', PelevoColors.green),
          ],
        ),
        PelevoButton(
          label: 'Smart Downloads',
          color: PelevoColors.green,
          icon: Icons.auto_awesome_rounded,
          onPressed: () => context.go('/screen/downloads-6'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Download Settings',
          color: PelevoColors.surfaceHigh,
          icon: Icons.settings_outlined,
          onPressed: () => context.go('/screen/downloads-4'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.go('/screen/downloads-5'),
          icon: const Icon(Icons.storage_rounded),
          label: const Text('Manage Storage'),
        ),
        const UtilitySection('Recent Downloads'),
        if (items.isEmpty)
          const Text(
            'No authorized downloads yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          _downloadRow(
            items.first,
            trailing: IconButton(
              tooltip: 'Play ${items.first.title}',
              onPressed: () => _play(items.first),
              icon: const Icon(Icons.play_circle_fill_rounded),
            ),
            onTap: () => _openDetails(items.first),
          ),
        TextButton(
          onPressed: () => context.go('/screen/downloads-2'),
          child: const Text('View All Downloads'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/screen/downloads-10'),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Download History'),
        ),
      ],
    );
  }

  Widget _all(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return _status(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final items = async.requireValue;
    final shows = <String, List<LibraryDownload>>{};
    for (final item in items) {
      final key = item.showTitle ?? '';
      shows.putIfAbsent(key, () => []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(
          const ['All', 'Episodes', 'Podcasts', 'More'],
          _allFilter,
          (value) => setState(() => _allFilter = value),
        ),
        const UtilitySection('Downloaded Episodes'),
        if (_allFilter != 2)
          if (items.isEmpty)
            const Text(
              'No authorized downloads yet.',
              style: TextStyle(color: PelevoColors.textMuted),
            )
          else
            for (final item in items) _downloadRow(item, onTap: () => _openOptions(item)),
        if (_allFilter != 1) ...[
          const UtilitySection('Downloaded Podcasts'),
          if (shows.isEmpty)
            const Text(
              'No downloaded shows yet.',
              style: TextStyle(color: PelevoColors.textMuted),
            )
          else
            for (final entry in shows.entries)
              _podcastRow(
                entry.key.isEmpty ? 'Show' : entry.key,
                '${entry.value.length} episodes',
                entry.value.first.artworkUrl,
                () => _openOptions(entry.value.first),
              ),
        ],
        const SizedBox(height: PelevoSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/screen/downloads-3'),
          icon: const Icon(Icons.downloading_rounded),
          label: const Text('View Active Downloads'),
        ),
      ],
    );
  }

  Widget _downloading(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _paused ? 'Downloads paused' : 'No in-progress downloads are reported.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'The server authorizes files. Transfer progress is not reported.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const UtilitySection('Queued'),
      const Text(
        'No queued downloads are reported.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
    ],
  );

  Widget _settings(BuildContext context) {
    final async = ref.watch(downloadSettingsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return _status(
        error: async.error,
        retry: () => ref.invalidate(downloadSettingsProvider),
      );
    }
    final settings = async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const UtilitySection('Download Quality'),
        for (var i = 0; i < 3; i++)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: i,
            groupValue: _quality,
            activeColor: PelevoColors.green,
            title: Text(
              const [
                'High (Best Quality)',
                'Medium (Balanced)',
                'Low (Data Saver)',
              ][i],
            ),
            subtitle: const Text('Episodes save the published audio file.'),
            onChanged: (_) => context.showPelevoMessage(
              'Episodes save the published audio file.',
            ),
          ),
        const UtilitySection('Download Preferences'),
        _switchTile(
          'Download Over Wi-Fi Only',
          'Save mobile data',
          Icons.wifi_rounded,
          settings.wifiOnly,
          _busy
              ? null
              : (value) => _run(() async {
                await ref.read(libraryRepositoryProvider).saveDownloadSettings(
                  settings,
                  wifiOnly: value,
                );
                ref.invalidate(downloadSettingsProvider);
              }),
        ),
        _switchTile(
          'Auto Download New Episodes',
          'New episodes from shows you follow.',
          Icons.download_for_offline_outlined,
          settings.autoDownloadNew,
          _busy
              ? null
              : (value) => _run(() async {
                await ref.read(libraryRepositoryProvider).saveDownloadSettings(
                  settings,
                  autoDownloadNew: value,
                );
                ref.invalidate(downloadSettingsProvider);
                if (value) await syncAutoDownloads(ref);
              }),
        ),
        _switchTile(
          'Delete Played Episodes',
          'Automatically remove completed episodes',
          Icons.delete_sweep_outlined,
          settings.autoDeleteCompleted,
          _busy
              ? null
              : (value) => _run(() async {
                await ref.read(libraryRepositoryProvider).saveDownloadSettings(
                  settings,
                  autoDeleteCompleted: value,
                );
                ref.invalidate(downloadSettingsProvider);
              }),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined, color: PelevoColors.green),
          title: const Text('Download Location'),
          subtitle: const Text('Internal Storage'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/downloads-11'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.airplanemode_active_rounded,
            color: PelevoColors.green,
          ),
          title: const Text('Offline Mode'),
          subtitle: const Text('Manage listening without a connection'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/downloads-12'),
        ),
      ],
    );
  }

  Widget _storage(BuildContext context) {
    final storage = ref.watch(storageUsageProvider);
    final settings = ref.watch(downloadSettingsProvider);
    if (storage.isLoading || settings.isLoading) return const CatalogStatusBody();
    if (storage.hasError) {
      return _status(
        error: storage.error,
        retry: () => ref.invalidate(storageUsageProvider),
      );
    }
    if (settings.hasError) {
      return _status(
        error: settings.error,
        retry: () => ref.invalidate(downloadSettingsProvider),
      );
    }
    final usage = storage.requireValue;
    final limit = settings.requireValue.maxStorageMb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const UtilitySection('Storage Used'),
        StorageChart(
          used: usage.offlineItems.toDouble(),
          total: usage.offlineItems == 0 ? 1 : usage.offlineItems.toDouble(),
          donut: false,
          centerLabel: '${usage.offlineItems} files',
          semanticsLabel: '${usage.offlineItems} authorized files',
          items: [
            ('Authorized files', '${usage.offlineItems}', PelevoColors.green),
            ('Limit', '$limit MB', PelevoColors.textDim),
          ],
        ),
        const UtilitySection('Smart Cleaning'),
        _actionRow(
          Icons.check_circle_outline_rounded,
          'Remove Completed',
          null,
          () => context.go('/screen/downloads-9'),
        ),
        _actionRow(
          Icons.history_rounded,
          'Old Episodes (30+ days)',
          'Age is not reported.',
          () => context.go('/screen/downloads-7'),
        ),
        const UtilitySection('Manual Cleanup'),
        _actionRow(
          Icons.delete_sweep_outlined,
          'Clear authorizations',
          '${usage.offlineItems} files',
          _busy
              ? () {}
              : () => _run(() async {
                await ref.read(libraryRepositoryProvider).clearStorageCache();
                ref.invalidate(libraryDownloadsProvider);
                ref.invalidate(storageUsageProvider);
              }),
        ),
      ],
    );
  }

  Widget _smartDownloads(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_smart ? 'Smart Downloads On' : 'Smart Downloads Off'),
        value: _smart,
        activeColor: PelevoColors.green,
        onChanged: (value) {
          if (!_preview) {
            context.showPelevoMessage('Smart Downloads are not offered.');
            return;
          }
          setState(() => _smart = value);
        },
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PelevoColors.green.withValues(alpha: .14),
          border: Border.all(color: PelevoColors.green),
        ),
        child: const Icon(
          Icons.download_rounded,
          size: 54,
          color: PelevoColors.text,
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        _smart ? 'Smart Downloads On' : 'Smart Downloads Off',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Automatic habit-based downloads are not stored on the server.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
    ],
  );

  Widget _downloadedEpisodes(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return _status(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final items = List<LibraryDownload>.from(async.requireValue);
    final ordered = _newestFirst ? items : items.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sort_rounded, color: PelevoColors.green),
            const SizedBox(width: PelevoSpacing.sm),
            const Expanded(child: Text('Sort by')),
            TextButton(
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
              child: Text(_newestFirst ? 'Newest First' : 'Oldest First'),
            ),
          ],
        ),
        if (ordered.isEmpty)
          const Text(
            'No authorized downloads yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in ordered)
            _downloadRow(
              item,
              trailing: const Icon(Icons.more_vert_rounded),
              onTap: () => _openOptions(item),
            ),
        const SizedBox(height: PelevoSpacing.md),
        Center(
          child: Text(
            '${ordered.length} episodes',
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            ref.read(selectedDownloadIdsProvider.notifier).replace(
              ordered.map((item) => item.downloadId),
            );
            context.go('/screen/downloads-9');
          },
          icon: const Icon(Icons.checklist_rounded),
          label: const Text('Select Multiple'),
        ),
      ],
    );
  }

  Widget _options(BuildContext context) {
    final item = _selectedDownload;
    if (ref.watch(libraryDownloadsProvider).isLoading) {
      return const CatalogStatusBody();
    }
    if (ref.watch(libraryDownloadsProvider).hasError) {
      return _status(
        error: ref.watch(libraryDownloadsProvider).error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item == null)
          const Text(
            'Select a download first.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          _downloadRow(
            item,
            trailing: const Icon(Icons.play_circle_fill_rounded),
            onTap: () => _play(item),
          ),
        const UtilitySection('Actions'),
        _actionRow(
          Icons.play_arrow_rounded,
          'Play Episode',
          null,
          item == null ? () {} : () => _play(item),
        ),
        _actionRow(
          Icons.delete_outline_rounded,
          'Remove Download',
          null,
          item == null || _busy
              ? () {}
              : () => _run(() async {
                await ref.read(libraryRepositoryProvider).deleteDownload(item.downloadId);
                ref.invalidate(libraryDownloadsProvider);
                ref.invalidate(storageUsageProvider);
                if (!context.mounted) return;
                context.go('/screen/downloads-7');
              }),
          color: PelevoColors.red,
        ),
        _actionRow(
          Icons.queue_music_rounded,
          'Add to Queue',
          null,
          () => context.go('/screen/queue-up-next'),
        ),
        _actionRow(
          Icons.playlist_add_rounded,
          'Add to Playlist',
          null,
          () => context.go('/screen/library-2'),
        ),
        _actionRow(
          Icons.share_outlined,
          'Share Episode',
          null,
          () => context.go('/screen/episode-share'),
        ),
        _actionRow(
          Icons.info_outline_rounded,
          'Episode Details',
          null,
          item == null
              ? () {}
              : () {
                openCatalogEpisode(context, episodeId: item.episodeId);
                context.go('/screen/episode-details');
              },
        ),
        const SizedBox(height: PelevoSpacing.md),
        PelevoButton(
          label: 'Cancel',
          color: PelevoColors.surfaceHigh,
          onPressed: () => context.go('/screen/downloads-7'),
        ),
      ],
    );
  }

  Widget _bulk(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return _status(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final items = async.requireValue;
    final selected = ref.watch(selectedDownloadIdsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected.contains(item.downloadId),
            activeColor: PelevoColors.green,
            secondary: CatalogArtwork(
              url: item.artworkUrl,
              width: 44,
              height: 44,
              assetPath: 'assets/library/ep_124.png',
            ),
            title: Text(item.title),
            subtitle: Text(item.showTitle ?? ''),
            onChanged: (_) =>
                ref.read(selectedDownloadIdsProvider.notifier).toggle(item.downloadId),
          ),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          'Total · ${selected.length} files',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          children: [
            Expanded(
              child: PelevoButton(
                label: 'Delete',
                color: PelevoColors.red,
                onPressed: selected.isEmpty || _busy ? null : () => _removeSelected(),
              ),
            ),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: PelevoButton(
                label: 'Remove Downloads',
                color: PelevoColors.green,
                onPressed: selected.isEmpty || _busy ? null : () => _removeSelected(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _removeSelected() async {
    final ids = List<String>.from(ref.read(selectedDownloadIdsProvider));
    await _run(() async {
      for (final id in ids) {
        await ref.read(libraryRepositoryProvider).deleteDownload(id);
      }
      ref.invalidate(libraryDownloadsProvider);
      ref.invalidate(storageUsageProvider);
      if (!context.mounted) return;
      context.go('/screen/downloads-7');
    });
  }

  Widget _history(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return _status(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final items = async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(
          const ['All', 'Completed', 'Failed'],
          _historyFilter,
          (value) => setState(() => _historyFilter = value),
        ),
        const UtilitySection('Authorized'),
        if (_historyFilter == 2)
          const Text(
            'Failed transfers are not reported.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else if (items.isEmpty)
          const Text(
            'No authorized downloads yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in items)
            _historyRow(item),
      ],
    );
  }

  Widget _downloadLocation(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < 3; i++)
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: i,
          groupValue: _location,
          activeColor: PelevoColors.green,
          title: Text(
            const ['Internal Storage', 'SD Card', 'Custom Folder'][i],
          ),
          subtitle: Text(
            i == 0
                ? 'This device'
                : 'Not offered by the server.',
          ),
          onChanged: (value) {
            if (value != 0 && !_preview) {
              context.showPelevoMessage('Download location cannot be changed.');
              return;
            }
            setState(() => _location = value!);
          },
        ),
      const UtilitySection('Capacity'),
      const Text(
        'Device free space is not reported.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      PelevoButton(
        label: 'Change Location',
        color: PelevoColors.green,
        onPressed: () {
          context.showPelevoMessage('Download location cannot be changed.');
          context.go('/screen/downloads-4');
        },
      ),
    ],
  );

  Widget _offline(BuildContext context) {
    final count = ref.watch(storageUsageProvider).asData?.value.offlineItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PelevoColors.green.withValues(alpha: .12),
            border: Border.all(color: PelevoColors.green),
          ),
          child: const Icon(
            Icons.airplanemode_active_rounded,
            size: 56,
            color: PelevoColors.green,
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text(
          'You’re Offline',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          count == null
              ? 'No internet connection. Enjoy your downloaded content.'
              : 'No internet connection. $count authorized files are listed.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xxl),
        PelevoButton(
          label: 'Go to Downloads',
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/downloads-2'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Retry Connection',
          icon: Icons.refresh_rounded,
          color: PelevoColors.surfaceHigh,
          onPressed: () {
            ref.invalidate(libraryDownloadsProvider);
            ref.invalidate(storageUsageProvider);
          },
        ),
      ],
    );
  }

  Widget _tabs(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: PelevoSpacing.xs),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              selectedColor: PelevoColors.green,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );

  Widget _downloadRow(
    LibraryDownload item, {
    required VoidCallback onTap,
    Widget? trailing,
  }) => Card(
    color: PelevoColors.surface,
    margin: const EdgeInsets.only(bottom: PelevoSpacing.xs),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: PelevoSpacing.sm),
      minLeadingWidth: 52,
      leading: CatalogArtwork(
        url: item.artworkUrl,
        width: 48,
        height: 48,
        assetPath: 'assets/library/ep_124.png',
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(item.showTitle ?? ''),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  Widget _podcastRow(
    String title,
    String subtitle,
    String? artworkUrl,
    VoidCallback onTap,
  ) => Card(
    color: PelevoColors.surface,
    margin: const EdgeInsets.only(bottom: PelevoSpacing.xs),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: PelevoSpacing.sm),
      minLeadingWidth: 52,
      leading: CatalogArtwork(
        url: artworkUrl,
        width: 48,
        height: 48,
        assetPath: 'assets/library/ep_124.png',
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  Widget _actionRow(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap, {
    Color color = PelevoColors.green,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Widget _switchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: PelevoColors.green, size: 22),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    activeColor: PelevoColors.green,
    onChanged: onChanged,
  );

  Widget _historyRow(LibraryDownload item) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const SizedBox(
      width: 40,
      height: 40,
      child: Icon(Icons.check_circle_rounded, color: PelevoColors.green),
    ),
    title: Text(item.title),
    subtitle: Text(
      [
        item.showTitle,
        if (item.authorizedUntil != null) 'Authorized',
      ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
    ),
    onTap: () => _openOptions(item),
  );
}
