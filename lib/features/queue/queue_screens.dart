import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/library/playlist_picker.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/queue/queue_reorder_list.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _QueueView {
  home,
  edit,
  reorder,
  remove,
  clearConfirm,
  empty,
  addSheet,
  playNextConfirm,
  options,
  autoDownload,
  shuffleOn,
  history,
}

const _queueInventory =
    <({String id, String title, String state, _QueueView view})>[
      (
        id: 'queue-up-next',
        title: 'Queue',
        state: 'Now playing + up next',
        view: _QueueView.home,
      ),
      (
        id: 'queue-multi-select',
        title: 'Edit Queue',
        state: 'Remove items',
        view: _QueueView.edit,
      ),
      (
        id: 'queue-reorder',
        title: 'Reorder Queue',
        state: 'Drag to reorder',
        view: _QueueView.reorder,
      ),
      (
        id: 'queue-remove',
        title: 'Edit Queue',
        state: 'Episode removed',
        view: _QueueView.remove,
      ),
      (
        id: 'queue-clear-confirm',
        title: 'Clear Queue',
        state: 'Confirmation',
        view: _QueueView.clearConfirm,
      ),
      (
        id: 'queue-empty',
        title: 'Queue',
        state: 'Empty',
        view: _QueueView.empty,
      ),
      (
        id: 'queue-filter',
        title: 'Add to Queue',
        state: 'Add options',
        view: _QueueView.addSheet,
      ),
      (
        id: 'queue-autoplay',
        title: 'Play Next',
        state: 'Confirmed',
        view: _QueueView.playNextConfirm,
      ),
      (
        id: 'queue-sync',
        title: 'Queue Options',
        state: 'Settings',
        view: _QueueView.options,
      ),
      (
        id: 'queue-downloads',
        title: 'Auto-Download',
        state: 'Enabled',
        view: _QueueView.autoDownload,
      ),
      (
        id: 'queue-smart',
        title: 'Shuffle On',
        state: 'Shuffle enabled',
        view: _QueueView.shuffleOn,
      ),
      (
        id: 'queue-history',
        title: 'Queue History',
        state: 'Played episodes',
        view: _QueueView.history,
      ),
    ];

final List<PelevoScreenSpec> queueScreens = List.unmodifiable(
  _queueInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Queue',
      title: item.title,
      state: item.state,
      builder: (_) => _QueueScreen(view: item.view, title: item.title),
    ),
  ),
);

class _QueueScreen extends ConsumerStatefulWidget {
  const _QueueScreen({required this.view, required this.title});

  final _QueueView view;
  final String title;

  @override
  ConsumerState<_QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<_QueueScreen> {
  bool _shuffle = false;
  bool _autoDownload = false;
  bool _removePlayed = true;
  bool _showPlayed = false;
  int _addChoice = 1;
  int _nav = 2;
  bool _busy = false;
  String? _playNextTitle;

  @override
  void initState() {
    super.initState();
    if (widget.view == _QueueView.autoDownload) _autoDownload = true;
    if (widget.view == _QueueView.shuffleOn) _shuffle = true;
  }

  bool get _preview => ref.read(catalogPreviewProvider);

  bool get _isSheet =>
      widget.view == _QueueView.addSheet || widget.view == _QueueView.options;

  bool get _showChrome =>
      !_isSheet && widget.view != _QueueView.playNextConfirm;

  _QueueView get _shown {
    if (ref.watch(catalogPreviewProvider)) return widget.view;
    switch (widget.view) {
      case _QueueView.clearConfirm:
      case _QueueView.addSheet:
      case _QueueView.playNextConfirm:
      case _QueueView.options:
      case _QueueView.autoDownload:
      case _QueueView.shuffleOn:
      case _QueueView.history:
      case _QueueView.empty:
        return widget.view;
      case _QueueView.home:
      case _QueueView.edit:
      case _QueueView.reorder:
      case _QueueView.remove:
        final queueAsync = ref.watch(catalogQueueProvider);
        if (queueAsync.isLoading || queueAsync.hasError) return widget.view;
        final queue = queueAsync.asData?.value;
        if (queue != null && queue.items.isEmpty) return _QueueView.empty;
        return widget.view;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final failure = catalogFailure(error);
      if (failure.code == 'CANCELLED') return;
      if (!mounted) return;
      context.showPelevoMessage(failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return PelevoPage(
      scrollable:
          shown != _QueueView.home && shown != _QueueView.reorder,
      padding:
          _isSheet || shown == _QueueView.playNextConfirm
              ? const EdgeInsets.fromLTRB(
                PelevoSpacing.page,
                PelevoSpacing.md,
                PelevoSpacing.page,
                PelevoSpacing.lg,
              )
              : const EdgeInsets.symmetric(horizontal: PelevoSpacing.page),
      appBar: _appBar(context, shown),
      bottomNavigationBar: _showChrome ? _bottomChrome(context, shown) : null,
      child: switch (shown) {
        _QueueView.home => _home(context),
        _QueueView.edit || _QueueView.remove => _edit(context),
        _QueueView.reorder => _reorder(context),
        _QueueView.clearConfirm => _clearConfirm(context),
        _QueueView.empty => _empty(context),
        _QueueView.addSheet => _addSheet(context),
        _QueueView.playNextConfirm => _playNextConfirm(context),
        _QueueView.options => _options(context),
        _QueueView.autoDownload => _autoDownloadOn(context),
        _QueueView.shuffleOn => _shuffleOn(context),
        _QueueView.history => _historyView(context),
      },
    );
  }

  PreferredSizeWidget? _appBar(BuildContext context, _QueueView shown) {
    if (_isSheet || shown == _QueueView.playNextConfirm) return null;

    final editing =
        shown == _QueueView.edit ||
        shown == _QueueView.remove ||
        shown == _QueueView.reorder ||
        shown == _QueueView.clearConfirm ||
        shown == _QueueView.history;

    return AppBar(
      leading: IconButton(
        tooltip: editing ? 'Close' : 'Back',
        onPressed: () {
          if (shown == _QueueView.home || shown == _QueueView.empty) {
            context.pelevoBack(fallback: '/screen/library-1');
          } else {
            context.pelevoBack(fallback: '/screen/queue-up-next');
          }
        },
        icon: Icon(editing ? Icons.close_rounded : Icons.arrow_back_rounded),
      ),
      title: Text(widget.title),
      actions: [
        if (shown == _QueueView.home) ...[
          IconButton(
            tooltip: 'Browse episodes to add',
            onPressed: () => context.pelevoOpen('/screen/browse'),
            icon: const Icon(Icons.add_rounded),
          ),
          TextButton(
            onPressed: () => context.go('/screen/queue-multi-select'),
            child: const Text(
              'Edit',
              style: TextStyle(color: PelevoColors.green),
            ),
          ),
          IconButton(
            tooltip: 'Queue options',
            onPressed: () => context.go('/screen/queue-sync'),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
        if (shown == _QueueView.edit ||
            shown == _QueueView.remove ||
            shown == _QueueView.reorder)
          TextButton(
            onPressed: () => context.go('/screen/queue-up-next'),
            child: const Text(
              'Done',
              style: TextStyle(color: PelevoColors.green),
            ),
          ),
      ],
    );
  }

  Widget _bottomChrome(BuildContext context, _QueueView shown) =>
      PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      );

  Widget _nowPlayingTile(BuildContext context, {bool compact = false}) {
    final session = ref.watch(catalogPlayerSessionProvider).asData?.value;
    final episodeId = session?.episodeId;
    final episodeAsync =
        episodeId == null || episodeId.isEmpty
            ? null
            : ref.watch(catalogEpisodeByIdProvider(episodeId));
    if (episodeAsync != null && episodeAsync.isLoading) {
      return const CatalogStatusBody();
    }
    if (episodeAsync != null && episodeAsync.hasError) {
      return CatalogStatusBody(
        error: episodeAsync.error,
        retry: () => ref.invalidate(catalogEpisodeByIdProvider(episodeId!)),
      );
    }
    final episode = episodeAsync?.asData?.value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: compact
          ? const Icon(Icons.remove_circle, color: PelevoColors.red)
          : CatalogArtwork(
            url: episode?.artworkUrl,
            width: 52,
            height: 52,
            assetPath: 'assets/queue/ep_124.png',
          ),
      title: Text(episode?.title ?? ''),
      subtitle: Text(
        compact
            ? [
              'Now Playing',
              if (episode?.showTitle != null) episode!.showTitle,
            ].join(' · ')
            : episode?.showTitle ?? '',
      ),
      trailing:
          compact
              ? CatalogArtwork(
                url: episode?.artworkUrl,
                width: 44,
                height: 44,
                assetPath: 'assets/queue/ep_124.png',
              )
              : const Icon(Icons.equalizer_rounded, color: PelevoColors.green),
      onTap: () => context.push('/screen/player-now-playing'),
    );
  }

  Widget _home(BuildContext context) {
    final count = ref.watch(catalogQueueProvider).asData?.value.items.length ?? 0;
    return QueueReorderList(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Now Playing', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.sm),
          _nowPlayingTile(context),
          const SizedBox(height: PelevoSpacing.lg),
          PelevoSectionHeader(
            title:
                'Up Next · $count Episode${count == 1 ? '' : 's'}',
          ),
          Padding(
            padding: EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: Text(
              'Hold and drag, or use the handle, to choose what plays next.',
              style: TextStyle(color: context.pelevo.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
      footer: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_rounded, color: PelevoColors.green),
        title: const Text('Queue History'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/queue-history'),
      ),
      onEpisodeTap: (item) {
        openCatalogEpisode(
          context,
          episodeId: item.episode.id,
          showId: item.episode.showId,
        );
        context.go('/screen/episode-details');
      },
    );
  }

  Widget _edit(BuildContext context) {
    final queueAsync = ref.watch(catalogQueueProvider);
    return Column(
      children: [
        _nowPlayingTile(context, compact: true),
        Divider(color: context.pelevo.border),
        if (queueAsync.isLoading)
          const CatalogStatusBody()
        else if (queueAsync.hasError)
          CatalogStatusBody(
            error: queueAsync.error,
            retry: () => ref.invalidate(catalogQueueProvider),
          )
        else
          for (final item in queueAsync.requireValue.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                tooltip: 'Remove ${item.episode.title}',
                onPressed:
                    _busy
                        ? null
                        : () => _run(() async {
                          await ref
                              .read(catalogRepositoryProvider)
                              .removeQueueItem(
                                item.queueItemId,
                                queueAsync.requireValue.version,
                              );
                          ref.invalidate(catalogQueueProvider);
                          if (!context.mounted) return;
                          if (_preview) {
                            context.go('/screen/queue-remove');
                          }
                        }),
                icon: const Icon(Icons.remove_circle, color: PelevoColors.red),
              ),
              title: Text(item.episode.title),
              subtitle: Text(item.episode.showTitle ?? ''),
              trailing: CatalogArtwork(
                url: item.episode.artworkUrl,
                width: 44,
                height: 44,
              ),
            ),
        const SizedBox(height: PelevoSpacing.xl),
        TextButton(
          onPressed: () => context.go('/screen/queue-clear-confirm'),
          child: const Text(
            'Clear Queue',
            style: TextStyle(
              color: PelevoColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reorder(BuildContext context) {
    return QueueReorderList(
      header: Padding(
        padding: EdgeInsets.only(bottom: PelevoSpacing.md),
        child: Text(
          'Drag episodes to set the order they will play.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
      ),
    );
  }

  Widget _clearConfirm(BuildContext context) {
    final queueAsync = ref.watch(catalogQueueProvider);
    final queue = queueAsync.asData?.value;
    return Column(
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      Image.asset(
        'assets/queue/clear_hero.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Clear Your Queue?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        'This will remove all upcoming episodes from your queue.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      if (queueAsync.hasError)
        CatalogStatusBody(
          error: queueAsync.error,
          retry: () => ref.invalidate(catalogQueueProvider),
        ),
      PelevoButton(
        label: 'Clear Queue',
        color: PelevoColors.red,
        onPressed:
            _busy || queue == null
                ? null
                : () => _run(() async {
                  await ref.read(catalogRepositoryProvider).clearQueue(queue.version);
                  ref.invalidate(catalogQueueProvider);
                  if (context.mounted) context.go('/screen/queue-empty');
                }),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        color: PelevoColors.yellow,
        onPressed: () => context.go('/screen/queue-up-next'),
      ),
    ],
    );
  }

  Widget _empty(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      Image.asset(
        'assets/queue/empty_hero.png',
        width: 140,
        height: 140,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Your queue is empty',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        'Add episodes to your queue to start listening.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      PelevoButton(
        label: 'Browse Podcasts',
        color: PelevoColors.green,
        onPressed: () => context.pelevoOpen('/screen/browse'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Go to Library',
        outlined: true,
        onPressed: () => context.go('/screen/library-1'),
      ),
    ],
  );

  Widget _addSheet(BuildContext context) {
    final episodeAsync = ref.watch(catalogEpisodeProvider);
    final episode = episodeAsync.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: context.pelevo.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (episodeAsync.isLoading)
          const CatalogStatusBody()
        else if (episodeAsync.hasError)
          CatalogStatusBody(
            error: episodeAsync.error,
            retry: () => ref.invalidate(catalogEpisodeProvider),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CatalogArtwork(
              url: episode?.artworkUrl,
              width: 52,
              height: 52,
            ),
            title: Text(episode?.title ?? ''),
            subtitle: Text(episode?.showTitle ?? ''),
          ),
        const SizedBox(height: PelevoSpacing.md),
        for (final option in const [
          (0, 'Play Next', 'Play this episode next'),
          (1, 'Add to Queue', 'Add this episode to the end of your queue'),
          (2, 'Add to Playlist', 'Add this episode to a playlist'),
        ])
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: option.$1,
            groupValue: _addChoice,
            activeColor: PelevoColors.green,
            title: Text(option.$2),
            subtitle: Text(option.$3),
            onChanged: (value) => setState(() => _addChoice = value ?? 1),
          ),
        const SizedBox(height: PelevoSpacing.md),
        PelevoButton(
          label: 'Confirm',
          color: PelevoColors.green,
          onPressed:
              _busy || episode == null
                  ? null
                  : () => _run(() async {
                    if (_addChoice == 2) {
                      await pickPlaylistForEpisode(
                        context: context,
                        ref: ref,
                        episodeId: episode.id,
                      );
                      return;
                    }
                    await ref
                        .read(catalogRepositoryProvider)
                        .enqueueEpisode(
                          episode.id,
                          playNext: _addChoice == 0,
                        );
                    ref.invalidate(catalogQueueProvider);
                    if (!context.mounted) return;
                    context.showPelevoMessage(
                      _addChoice == 0 ? 'Will play next' : 'Added to queue',
                    );
                    context.pelevoBack(fallback: '/screen/queue-up-next');
                  }),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Cancel',
          outlined: true,
          onPressed: () => context.pelevoBack(fallback: '/screen/queue-up-next'),
        ),
      ],
    );
  }

  Widget _playNextConfirm(BuildContext context) {
    final selected = ref.watch(catalogEpisodeProvider).asData?.value;
    final title = _playNextTitle ?? selected?.title;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        Image.asset(
          'assets/queue/play_next_hero.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text('Will play next', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          title == null || title.isEmpty
              ? 'The selected episode will play after the current episode finishes.'
              : '$title will play next. It will play after the current episode finishes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xxl),
        PelevoButton(
          label: 'View Queue',
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/queue-up-next'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Back to Player',
          outlined: true,
          onPressed: () => context.pelevoBack(
            fallback: '/screen/player-now-playing',
          ),
        ),
      ],
    );
  }

  Widget _options(BuildContext context) {
    final queue = ref.watch(catalogQueueProvider).asData?.value;
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: context.pelevo.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text('Queue Options', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.md),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Shuffle Queue'),
        value: _shuffle,
        activeColor: PelevoColors.green,
        onChanged:
            _busy
                ? null
                : (value) {
                  if (!value) {
                    setState(() => _shuffle = false);
                    return;
                  }
                  if (_preview) {
                    setState(() => _shuffle = true);
                    context.go('/screen/queue-smart');
                    return;
                  }
                  _run(() async {
                    if (queue == null) return;
                    final ids =
                        queue.items.map((item) => item.episode.id).toList()
                          ..shuffle();
                    await ref
                        .read(catalogRepositoryProvider)
                        .replaceQueue(ids, queue.version);
                    ref.invalidate(catalogQueueProvider);
                    if (!context.mounted) return;
                    setState(() => _shuffle = true);
                    context.go('/screen/queue-up-next');
                  });
                },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Auto-Download'),
        value: _autoDownload,
        activeColor: PelevoColors.green,
        onChanged: (value) {
          setState(() => _autoDownload = value);
          if (value) {
            context.go('/screen/downloads-1');
          }
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Remove Played'),
        value: _removePlayed,
        activeColor: PelevoColors.green,
        onChanged: (value) => setState(() => _removePlayed = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show Played Episodes'),
        value: _showPlayed,
        activeColor: PelevoColors.green,
        onChanged: (value) => setState(() => _showPlayed = value),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_rounded),
        title: const Text('Queue History'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/queue-history'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.delete_outline_rounded,
          color: PelevoColors.red,
        ),
        title: const Text('Clear Queue'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/queue-clear-confirm'),
      ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Close',
        outlined: true,
        onPressed: () => context.go('/screen/queue-up-next'),
      ),
    ],
    );
  }

  Widget _autoDownloadOn(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      Image.asset(
        'assets/queue/download_hero.png',
        width: 130,
        height: 130,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Auto-Download On',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        'Manage offline episodes from Downloads. Authorized files stay on this device.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      PelevoButton(
        label: 'Open Downloads',
        color: PelevoColors.green,
        icon: Icons.cloud_download_rounded,
        onPressed: () => context.go('/screen/downloads-1'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Download Settings',
        outlined: true,
        onPressed: () => context.go('/screen/downloads-4'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      TextButton(
        onPressed: () => context.go('/screen/queue-up-next'),
        child: const Text('Back to Queue'),
      ),
    ],
  );

  Widget _shuffleOn(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      Image.asset(
        'assets/queue/shuffle_hero.png',
        width: 130,
        height: 130,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text('Shuffle On', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        'Your queue will now play episodes in random order.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      PelevoButton(
        label: 'View Queue',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/queue-up-next'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Turn Off Shuffle',
        outlined: true,
        onPressed: () {
          setState(() => _shuffle = false);
          context.go('/screen/queue-sync');
        },
      ),
    ],
  );

  Widget _historyView(BuildContext context) {
    final recentAsync = ref.watch(catalogLibraryRecentProvider);
    return Column(
      children: [
        if (recentAsync.isLoading)
          const CatalogStatusBody()
        else if (recentAsync.hasError)
          CatalogStatusBody(
            error: recentAsync.error,
            retry: () => ref.invalidate(catalogLibraryRecentProvider),
          )
        else if (recentAsync.requireValue.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
            child: Text(
              'No recently played episodes yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted),
            ),
          )
        else
          for (final item in recentAsync.requireValue)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.episode.artworkUrl,
                width: 44,
                height: 44,
              ),
              title: Text(item.episode.title),
              subtitle: Text(item.subtitle),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Play ${item.episode.title}',
                onPressed: () {
                  playCatalogEpisode(
                    context,
                    episodeId: item.episode.id,
                    showId: item.episode.showId,
                    keepQueue: true,
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
              ),
              onTap: () {
                openCatalogEpisode(
                  context,
                  episodeId: item.episode.id,
                  showId: item.episode.showId,
                );
                context.go('/screen/episode-details');
              },
            ),
        const SizedBox(height: PelevoSpacing.xl),
        TextButton(
          onPressed:
              () => context.showPelevoMessage(
                'Clearing playback history is not offered yet.',
              ),
          child: const Text(
            'Clear History',
            style: TextStyle(
              color: PelevoColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
