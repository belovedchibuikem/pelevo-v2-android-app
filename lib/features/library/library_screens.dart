import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:pelevo/features/downloads/download_gate.dart';
import 'package:pelevo/features/library/collection_picker.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reels_screens.dart';
import 'package:pelevo/features/share/pelevo_share_chooser.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _LibraryView {
  home,
  playlists,
  playlistDetails,
  saved,
  savedReels,
  downloads,
  shows,
  liked,
  recent,
  collections,
  createCollection,
  collectionDetails,
  settings,
}

const _libraryInventory =
    <({String id, String title, String state, _LibraryView view})>[
      (
        id: 'library-1',
        title: 'Library',
        state: 'Home overview',
        view: _LibraryView.home,
      ),
      (
        id: 'library-2',
        title: 'Playlists',
        state: 'All playlists',
        view: _LibraryView.playlists,
      ),
      (
        id: 'library-3',
        title: 'Playlist Details',
        state: 'Mindset & Growth',
        view: _LibraryView.playlistDetails,
      ),
      (
        id: 'library-4',
        title: 'Saved Episodes',
        state: 'Bookmarked',
        view: _LibraryView.saved,
      ),
      (
        id: 'library-13',
        title: 'Saved Reels',
        state: 'Bookmarked reels',
        view: _LibraryView.savedReels,
      ),
      (
        id: 'library-5',
        title: 'Downloads',
        state: 'This device',
        view: _LibraryView.downloads,
      ),
      (
        id: 'library-6',
        title: 'Your Shows',
        state: 'Followed shows',
        view: _LibraryView.shows,
      ),
      (
        id: 'library-7',
        title: 'Liked Episodes',
        state: 'Favorites',
        view: _LibraryView.liked,
      ),
      (
        id: 'library-8',
        title: 'Recently Played',
        state: 'Listening progress',
        view: _LibraryView.recent,
      ),
      (
        id: 'library-9',
        title: 'Collections',
        state: 'Collection grid',
        view: _LibraryView.collections,
      ),
      (
        id: 'library-10',
        title: 'Create Collection',
        state: 'New collection',
        view: _LibraryView.createCollection,
      ),
      (
        id: 'library-11',
        title: 'Collection Details',
        state: 'Sunday Reset',
        view: _LibraryView.collectionDetails,
      ),
      (
        id: 'library-12',
        title: 'Library Settings',
        state: 'Preferences',
        view: _LibraryView.settings,
      ),
    ];

final List<PelevoScreenSpec> libraryScreens = List.unmodifiable(
  _libraryInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Library',
      title: item.title,
      state: item.state,
      builder: (_) => _LibraryScreen(view: item.view, title: item.title),
    ),
  ),
);

class _LibraryScreen extends ConsumerStatefulWidget {
  const _LibraryScreen({required this.view, required this.title});

  final _LibraryView view;
  final String title;

  @override
  ConsumerState<_LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<_LibraryScreen> {
  int _nav = 2;
  int _homeTab = 0;
  int _playlistFilter = 0;
  int _savedFilter = 0;
  int _likedFilter = 0;
  int _downloadSource = 0;
  int _viewMode = 0;
  bool _shuffle = false;
  bool _busy = false;
  bool _autoSyncStarted = false;
  bool _collectionDraftApplied = false;
  bool _collectionPublic = false;
  final _search = TextEditingController();
  final _collectionName = TextEditingController();
  final _collectionDesc = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = GoRouterState.of(context).uri.queryParameters['id'];
    if (id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.view == _LibraryView.playlistDetails &&
          ref.read(selectedPlaylistIdProvider) != id) {
        ref.read(selectedPlaylistIdProvider.notifier).select(id);
      }
      if ((widget.view == _LibraryView.collectionDetails ||
              widget.view == _LibraryView.createCollection) &&
          ref.read(selectedCollectionIdProvider) != id) {
        ref.read(selectedCollectionIdProvider.notifier).select(id);
      }
    });
  }

  String get _backFallback => switch (widget.view) {
    _LibraryView.playlistDetails => '/screen/library-2',
    _LibraryView.createCollection ||
    _LibraryView.collectionDetails => '/screen/library-9',
    _ => '/screen/library-1',
  };

  @override
  void dispose() {
    _search.dispose();
    _collectionName.dispose();
    _collectionDesc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHome = widget.view == _LibraryView.home;
    final editingCollectionId =
        widget.view == _LibraryView.createCollection
            ? GoRouterState.of(context).uri.queryParameters['id']
            : null;
    if (editingCollectionId != null && editingCollectionId.isNotEmpty) {
      final current = ref.watch(libraryCollectionProvider).asData?.value;
      if (!_collectionDraftApplied &&
          current != null &&
          current.id == editingCollectionId) {
        _collectionDraftApplied = true;
        final name = current.name;
        final description = current.description ?? '';
        final isPublic = current.isPublic;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _collectionName.text = name;
          _collectionDesc.text = description;
          setState(() => _collectionPublic = isPublic);
        });
      }
    }
    return PelevoPage(
      appBar: AppBar(
        leading:
            isHome
                ? const Padding(
                  padding: EdgeInsets.only(left: PelevoSpacing.sm),
                  child: ProfileNavAvatar(),
                )
                : PelevoBackButton(fallback: _backFallback),
        title: Text(
          isHome
              ? 'Good morning, ${ref.watch(authSessionProvider).displayName}'
              : widget.view == _LibraryView.createCollection &&
                  (GoRouterState.of(context).uri.queryParameters['id'] ?? '')
                      .isNotEmpty
              ? 'Edit Collection'
              : widget.title,
        ),
        actions: [
          if (isHome) ...[
            IconButton(
              tooltip: 'AI Hub',
              onPressed: () => context.pelevoOpen('/screen/ai-hub'),
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
            ),
            IconButton(
              tooltip: 'Library settings',
              onPressed: () => context.pelevoOpen('/screen/library-12'),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.pelevoOpen('/screen/notifications-1'),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
          if (widget.view == _LibraryView.playlists)
            IconButton(
              tooltip: 'Create playlist',
              onPressed: () => _showPlaylistEditor(context),
              icon: const Icon(Icons.add_rounded),
            ),
          if (widget.view == _LibraryView.collections)
            IconButton(
              tooltip: 'Create collection',
              onPressed: () => context.pelevoOpen('/screen/library-10'),
              icon: const Icon(Icons.add_rounded),
            ),
          if (widget.view == _LibraryView.playlistDetails ||
              widget.view == _LibraryView.collectionDetails)
            IconButton(
              tooltip: 'More options',
              onPressed: () => _showPlaylistOptions(context),
              icon: const Icon(Icons.more_vert_rounded),
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
        _LibraryView.home => _home(context),
        _LibraryView.playlists => _playlists(context),
        _LibraryView.playlistDetails => _playlistDetails(context),
        _LibraryView.saved => _saved(context),
        _LibraryView.savedReels => _savedReels(context),
        _LibraryView.downloads => _downloads(context),
        _LibraryView.shows => _shows(context),
        _LibraryView.liked => _liked(context),
        _LibraryView.recent => _recent(context),
        _LibraryView.collections => _collections(context),
        _LibraryView.createCollection => _createCollection(context),
        _LibraryView.collectionDetails => _collectionDetails(context),
        _LibraryView.settings => _settings(context),
      },
    );
  }

  Widget _home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chipTab(
              'Overview',
              0,
              _homeTab,
              (v) => setState(() => _homeTab = v),
            ),
            const SizedBox(width: PelevoSpacing.xs),
            _chipTab('Followed', 1, _homeTab, (v) {
              setState(() => _homeTab = v);
              ref.invalidate(libraryShowsProvider);
            }),
            const SizedBox(width: PelevoSpacing.xs),
            _chipTab('History', 2, _homeTab, (v) {
              setState(() => _homeTab = v);
              ref.invalidate(libraryRecentProvider);
            }),
          ],
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      if (_homeTab == 0) ..._overviewMenu(context),
      if (_homeTab == 1) _shows(context),
      if (_homeTab == 2) _recent(context),
    ],
  );

  List<Widget> _overviewMenu(BuildContext context) {
    final overview = ref.watch(libraryOverviewProvider);
    if (overview.isLoading) return const [CatalogStatusBody()];
    if (overview.hasError) {
      return [
        CatalogStatusBody(
          error: overview.error,
          retry: () => ref.invalidate(libraryOverviewProvider),
        ),
      ];
    }
    final data = overview.requireValue;
    return [
      _menuRow(
        'Playlists',
        Icons.queue_music_rounded,
        PelevoColors.yellow,
        () {
          ref.invalidate(libraryPlaylistsProvider);
          context.pelevoOpen('/screen/library-2');
        },
        badge: '${data.playlists.length}',
      ),
      _menuRow(
        'Your Shows',
        Icons.podcasts_rounded,
        PelevoColors.orange,
        () {
          ref.invalidate(libraryShowsProvider);
          context.pelevoOpen('/screen/library-6');
        },
        badge: '${data.showsCount}',
      ),
      _menuRow(
        'Saved Episodes',
        Icons.bookmark_rounded,
        PelevoColors.green,
        () {
          ref.invalidate(librarySavedProvider);
          context.pelevoOpen('/screen/library-4');
        },
        badge: '${data.savedCount}',
      ),
      _menuRow(
        'Saved Reels',
        Icons.movie_creation_outlined,
        PelevoColors.purple,
        () {
          ref.invalidate(savedReelsProvider);
          context.pelevoOpen('/screen/library-13');
        },
        badge: '${data.savedReelsCount}',
      ),
      _menuRow(
        'Downloads',
        Icons.download_done_rounded,
        PelevoColors.blue,
        () {
          ref.invalidate(libraryDownloadsProvider);
          context.pelevoOpen('/screen/library-5');
        },
        badge: '${data.downloadsCount}',
      ),
      _menuRow(
        'Liked Episodes',
        Icons.favorite_rounded,
        PelevoColors.red,
        () {
          ref.invalidate(libraryLikedProvider);
          context.pelevoOpen('/screen/library-7');
        },
        badge: '${data.likedCount}',
      ),
      _menuRow(
        'Recently Played',
        Icons.history_rounded,
        context.pelevo.textMuted,
        () {
          ref.invalidate(libraryRecentProvider);
          context.pelevoOpen('/screen/library-8');
        },
        badge: '${data.recentCount}',
      ),
      _menuRow(
        'Collections',
        Icons.collections_bookmark_rounded,
        PelevoColors.green,
        () {
          ref.invalidate(libraryCollectionsProvider);
          context.pelevoOpen('/screen/library-9');
        },
        badge: '${data.collections.length}',
      ),
      const SizedBox(height: PelevoSpacing.md),
      Text('Tools', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: PelevoSpacing.sm),
      _menuRow(
        'AI Hub',
        Icons.auto_awesome,
        const Color(0xFF8B5CF6),
        () => context.pelevoOpen('/screen/ai-hub'),
        subtitle: 'Ask Pelevo, lineup, and recommendations',
      ),
      _menuRow(
        'Your Stats',
        Icons.insights_rounded,
        PelevoColors.green,
        () => context.pelevoOpen('/screen/stats-overview'),
        subtitle: 'Listening time and streaks',
      ),
      _menuRow(
        'Queue',
        Icons.playlist_play_rounded,
        PelevoColors.orange,
        () => context.pelevoOpen('/screen/queue-up-next'),
        subtitle: 'Up next and history',
      ),
      _menuRow(
        'App Permissions',
        Icons.security_rounded,
        PelevoColors.green,
        () => context.pelevoOpen('/screen/permissions-intro'),
        subtitle: 'Notifications, mic, storage, devices',
      ),
    ];
  }

  Widget _playlists(BuildContext context) {
    final mineAsync = ref.watch(libraryPlaylistsProvider);
    final othersAsync = ref.watch(libraryPublicPlaylistsProvider);
    if (mineAsync.isLoading && _playlistFilter != 2) {
      return const CatalogStatusBody();
    }
    if (othersAsync.isLoading && _playlistFilter == 2) {
      return const CatalogStatusBody();
    }
    if (mineAsync.hasError && _playlistFilter != 2) {
      return CatalogStatusBody(
        error: mineAsync.error,
        retry: () => ref.invalidate(libraryPlaylistsProvider),
      );
    }
    if (othersAsync.hasError && _playlistFilter == 2) {
      return CatalogStatusBody(
        error: othersAsync.error,
        retry: () => ref.invalidate(libraryPublicPlaylistsProvider),
      );
    }
    final mine = mineAsync.asData?.value ?? const <LibraryPlaylist>[];
    final others = othersAsync.asData?.value ?? const <LibraryPlaylist>[];
    final playlists = switch (_playlistFilter) {
      1 => mine,
      2 => others,
      _ => [...mine, ...others],
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                (0, 'All'),
                (1, 'By You'),
                (2, 'By Others'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _playlistFilter == entry.$1,
                    selectedColor: PelevoColors.green,
                    onSelected:
                        (_) => setState(() => _playlistFilter = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (playlists.isEmpty)
          Text(
            _playlistFilter == 2
                ? 'No public playlists from other listeners yet.'
                : 'No playlists yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in playlists)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 52,
                height: 52,
                assetPath: 'assets/library/playlist_mindset.png',
              ),
              title: Text(item.name),
              subtitle: Text(
                [
                  if (!item.isOwner && (item.ownerName ?? '').isNotEmpty)
                    item.ownerName!,
                  item.countLabel,
                  item.visibilityLabel,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ref.read(selectedPlaylistIdProvider.notifier).select(item.id);
                context.pelevoOpen(
                  '/screen/library-3?id=${Uri.encodeComponent(item.id)}',
                );
              },
            ),
      ],
    );
  }

  Widget _playlistDetails(BuildContext context) {
    final id = ref.watch(selectedPlaylistIdProvider);
    if (id == null || id.isEmpty) {
      return CatalogStatusBody(
        error: missingLibraryPlaylist,
        retry: () => context.pelevoBack(fallback: '/screen/library-2'),
      );
    }
    final async = ref.watch(libraryPlaylistProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryPlaylistProvider),
      );
    }
    final playlist = async.requireValue;
    final coverUrl =
        playlist.artworkUrl ??
        (playlist.items.isEmpty ? null : playlist.items.first.artworkUrl);
    final ownerLabel =
        playlist.isOwner
            ? ref.watch(authSessionProvider).displayName
            : playlist.ownerName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(playlist.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: PelevoSpacing.sm),
        if (ownerLabel != null && ownerLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: PelevoSpacing.xs),
            child: Row(
              children: [
                if (playlist.isOwner)
                  const ProfileNavAvatar(size: 22)
                else
                  Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: context.pelevo.textMuted,
                  ),
                const SizedBox(width: PelevoSpacing.xs),
                Flexible(
                  child: Text(
                    ownerLabel,
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          [playlist.countLabel, playlist.visibilityLabel].join(' · '),
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        if (playlist.description != null &&
            playlist.description!.isNotEmpty) ...[
          const SizedBox(height: PelevoSpacing.xs),
          Text(
            playlist.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.pelevo.textDim),
          ),
        ],
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            CatalogArtwork(
              url: coverUrl,
              width: 72,
              height: 72,
              radius: PelevoRadii.medium,
              assetPath: 'assets/library/cover_mindset.png',
            ),
            const SizedBox(width: PelevoSpacing.sm),
            IconButton(
              tooltip: 'Share playlist',
              onPressed: () => showPelevoShareChooser(
                context: context,
                ref: ref,
                title: playlist.name,
                subtitle: playlist.description,
                artworkUrl: coverUrl,
                link: catalogSharePlaylistLink(playlist.id),
                subjectType: 'playlist',
                subjectId: playlist.id,
                assetPath: 'assets/library/cover_mindset.png',
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            if (playlist.isOwner)
              IconButton(
                tooltip: 'Edit playlist',
                onPressed:
                    () => _showPlaylistEditor(context, editing: playlist),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            const Spacer(),
            Material(
              color: PelevoColors.green,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Play All',
                onPressed:
                    () => _playPlaylist(context, playlist, shuffle: false),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        Wrap(
          spacing: PelevoSpacing.xs,
          runSpacing: PelevoSpacing.xs,
          children: [
            _playlistPill(
              icon: Icons.play_arrow_rounded,
              label: 'Play All',
              filled: true,
              onPressed: () => _playPlaylist(context, playlist, shuffle: false),
            ),
            _playlistPill(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              selected: _shuffle,
              onPressed: () => _playPlaylist(context, playlist, shuffle: true),
            ),
            if (playlist.isOwner)
              _playlistPill(
                icon: Icons.add_rounded,
                label: 'Add',
                onPressed: () => context.pelevoOpen('/screen/search'),
              ),
            if (playlist.isOwner)
              _playlistPill(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onPressed:
                    () => _showPlaylistEditor(context, editing: playlist),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (playlist.items.isEmpty)
          Text(
            'No episodes are in this playlist yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else if (playlist.isOwner)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: playlist.items.length,
            onReorder: (oldIndex, newIndex) {
              unawaited(
                _reorderPlaylistItems(context, playlist, oldIndex, newIndex),
              );
            },
            itemBuilder: (context, index) {
              final item = playlist.items[index];
              return Material(
                key: ValueKey(item.id),
                color: Colors.transparent,
                child: _playlistEpisodeTile(
                  context,
                  playlist,
                  item,
                  playFromHere: true,
                  reorderIndex: index,
                ),
              );
            },
          )
        else
          for (final item in playlist.items)
            _playlistEpisodeTile(context, playlist, item, playFromHere: true),
      ],
    );
  }

  Widget _playlistPill({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
    bool selected = false,
  }) {
    final background =
        filled
            ? PelevoColors.green
            : selected
            ? PelevoColors.green.withValues(alpha: 0.22)
            : context.pelevo.surfaceHigh;
    final foreground = filled ? Colors.white : context.pelevo.text;
    return ActionChip(
      onPressed: onPressed,
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      backgroundColor: background,
      side: BorderSide(
        color: filled || selected ? PelevoColors.green : context.pelevo.border,
      ),
      shape: const StadiumBorder(),
    );
  }

  Widget _playlistEpisodeTile(
    BuildContext context,
    LibraryPlaylist playlist,
    LibraryEpisode item, {
    required bool playFromHere,
    int? reorderIndex,
  }) {
    final duration =
        item.durationSeconds == null
            ? null
            : formatCatalogDuration(item.durationSeconds!);
    final manage = playlist.isOwner && reorderIndex != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              openCatalogEpisode(
                context,
                episodeId: item.id,
                showId: item.showId,
              );
              context.pelevoOpen('/screen/episode-details');
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogArtwork(
                  url: item.artworkUrl,
                  width: 56,
                  height: 56,
                  radius: PelevoRadii.small,
                  assetPath: 'assets/library/ep_124.png',
                ),
                const SizedBox(width: PelevoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if ((item.showTitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.showTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.pelevo.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (duration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          duration,
                          style: TextStyle(color: context.pelevo.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PelevoSpacing.xs),
          Row(
            children: [
              if (manage) ...[
                IconButton(
                  tooltip: 'Remove from playlist',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _busy
                          ? null
                          : () =>
                              _removePlaylistEpisode(context, playlist, item),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: PelevoSpacing.xs),
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Play',
                onPressed: () {
                  if (!playFromHere) {
                    playCatalogEpisode(
                      context,
                      episodeId: item.id,
                      showId: item.showId,
                    );
                    return;
                  }
                  final start = playlist.items.indexWhere(
                    (episode) => episode.id == item.id,
                  );
                  final rest =
                      start < 0
                          ? playlist.items
                          : playlist.items.sublist(start);
                  _playPlaylistEpisodes(context, rest, shuffle: false);
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _playPlaylist(
    BuildContext context,
    LibraryPlaylist playlist, {
    required bool shuffle,
  }) {
    if (playlist.items.isEmpty) {
      context.showPelevoMessage('This playlist has no episodes yet.');
      return;
    }
    setState(() => _shuffle = shuffle);
    _playPlaylistEpisodes(context, playlist.items, shuffle: shuffle);
  }

  void _playPlaylistEpisodes(
    BuildContext context,
    List<LibraryEpisode> items, {
    required bool shuffle,
  }) {
    playCatalogEpisodeQueue(
      context,
      episodeIds: [for (final item in items) item.id],
      showIds: {for (final item in items) item.id: item.showId},
      shuffle: shuffle,
    );
  }

  Future<void> _reorderPlaylistItems(
    BuildContext context,
    LibraryPlaylist playlist,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = [for (final item in playlist.items) item.id];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .reorderPlaylistItems(
            playlistId: playlist.id,
            episodeIds: ids,
            version: playlist.version,
          );
      ref.invalidate(libraryPlaylistProvider);
      ref.invalidate(libraryPlaylistsProvider);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePlaylistEpisode(
    BuildContext context,
    LibraryPlaylist playlist,
    LibraryEpisode item,
  ) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .removePlaylistItem(
            playlistId: playlist.id,
            episodeId: item.id,
            version: playlist.version,
          );
      ref.invalidate(libraryPlaylistProvider);
      ref.invalidate(libraryPlaylistsProvider);
      ref.invalidate(libraryOverviewProvider);
      if (context.mounted) {
        context.showPelevoMessage('Removed from playlist');
      }
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _saved(BuildContext context) {
    final async = ref.watch(librarySavedProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(librarySavedProvider),
      );
    }
    var episodes = async.requireValue;
    if (_savedFilter == 1) {
      final downloads = ref.watch(libraryDownloadsProvider).asData?.value ?? [];
      final ids = {for (final item in downloads) item.episodeId};
      episodes = [
        for (final item in episodes)
          if (ids.contains(item.id)) item,
      ];
    } else if (_savedFilter == 2) {
      episodes = [
        for (final item in episodes)
          if (item.completed != true) item,
      ];
    }
    return _episodeBrowser(
      context,
      hint: 'Search saved episodes',
      filters: const ['All', 'Downloaded', 'Unplayed'],
      selected: _savedFilter,
      onFilter: (v) => setState(() => _savedFilter = v),
      episodes: episodes,
    );
  }

  Widget _savedReels(BuildContext context) {
    final async = ref.watch(savedReelsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(savedReelsProvider),
      );
    }
    final reels = async.requireValue;
    if (reels.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No saved reels yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
          Text(
            'Tap the bookmark on a reel to keep it here.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.go('/screen/reels'),
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Watch Reels'),
          ),
        ],
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openSavedReels(context),
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: const Text('Play all'),
          ),
        ),
        for (final reel in reels)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CatalogArtwork(
              url: reel.imageUrl,
              width: 48,
              height: 48,
              assetPath: 'assets/library/ep_124.png',
            ),
            title: Text(
              reel.captionText.isEmpty ? reel.creatorName : reel.captionText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(reel.creatorName),
            trailing: const Icon(Icons.play_circle_fill_rounded),
            onTap: () => openSavedReels(context, reelId: reel.id),
          ),
      ],
    );
  }

  Widget _liked(BuildContext context) {
    final async = ref.watch(libraryLikedProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryLikedProvider),
      );
    }
    var episodes = [...async.requireValue];
    if (_likedFilter == 2) episodes = episodes.reversed.toList();
    return _episodeBrowser(
      context,
      hint: 'Search liked episodes',
      filters: const ['All', 'Newest', 'Oldest'],
      selected: _likedFilter,
      onFilter: (v) => setState(() => _likedFilter = v),
      episodes: episodes,
    );
  }

  Widget _downloads(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final downloads =
        _downloadSource == 1 ? const <LibraryDownload>[] : async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _chipTab(
              'This Device',
              0,
              _downloadSource,
              (v) => setState(() => _downloadSource = v),
            ),
            const SizedBox(width: PelevoSpacing.xs),
            _chipTab(
              'SD Card',
              1,
              _downloadSource,
              (v) => setState(() => _downloadSource = v),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Downloading', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          'No in-progress downloads are reported.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Downloaded', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (_downloadSource == 1)
          Text(
            'SD card downloads are not available.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else if (downloads.isEmpty)
          Text(
            'No authorized downloads yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in downloads)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 48,
                height: 48,
                assetPath: 'assets/library/ep_124.png',
              ),
              title: Text(item.title),
              subtitle: Text(
                [
                      item.showTitle,
                      if (item.authorizedUntil != null)
                        'Authorized until offline expiry',
                    ]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
              ),
              trailing: const Icon(
                Icons.check_circle_rounded,
                color: PelevoColors.green,
              ),
              onTap: () {
                openCatalogEpisode(
                  context,
                  episodeId: item.episodeId,
                  showId: item.showId,
                );
                context.pelevoOpen('/screen/episode-details');
              },
            ),
        const SizedBox(height: PelevoSpacing.md),
        Center(
          child: Text(
            'On-device file size is not reported.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => context.pelevoOpen('/screen/downloads-1'),
          child: const Text('Open Downloads Manager'),
        ),
      ],
    );
  }

  Widget _shows(BuildContext context) {
    final async = ref.watch(libraryShowsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryShowsProvider),
      );
    }
    final shows = async.requireValue;
    if (shows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No followed shows yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
          Text(
            'Follow shows from Search or Browse, then open them here to listen to episodes.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.pelevoOpen('/screen/browse'),
            icon: const Icon(Icons.explore_rounded),
            label: const Text('Browse podcasts'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${shows.length} followed',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        for (final item in shows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CatalogArtwork(
              url: item.artworkUrl,
              width: 52,
              height: 52,
              assetPath: 'assets/library/show_honest.png',
            ),
            title: Text(item.title),
            subtitle: Text(
              item.author?.isNotEmpty == true
                  ? item.author!
                  : 'Tap to open episodes',
            ),
            trailing: Icon(
              item.notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.chevron_right_rounded,
              color: PelevoColors.green,
            ),
            onTap: () {
              openCatalogShow(context, item.id);
              context.push('/screen/podcast-details');
            },
          ),
      ],
    );
  }

  Widget _recent(BuildContext context) {
    final async = ref.watch(libraryRecentProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryRecentProvider),
      );
    }
    final episodes = async.requireValue;
    if (episodes.isEmpty) {
      return Text(
        'No recently played episodes yet.',
        style: TextStyle(color: context.pelevo.textMuted),
      );
    }
    return Column(
      children: [
        for (final item in episodes)
          Card(
            color: context.pelevo.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: InkWell(
              onTap: () {
                openCatalogEpisode(
                  context,
                  episodeId: item.id,
                  showId: item.showId,
                );
                context.pelevoOpen('/screen/episode-details');
              },
              child: Padding(
                padding: const EdgeInsets.all(PelevoSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CatalogArtwork(
                          url: item.artworkUrl,
                          width: 48,
                          height: 48,
                          assetPath: 'assets/library/ep_124.png',
                        ),
                        const SizedBox(width: PelevoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title),
                              Text(
                                '${item.showTitle ?? ''} · ${(item.progress * 100).round()}%',
                                style: TextStyle(
                                  color: context.pelevo.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Resume',
                          onPressed: () {
                            playCatalogEpisode(
                              context,
                              episodeId: item.id,
                              showId: item.showId,
                            );
                          },
                          icon: const Icon(Icons.play_circle_fill_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 5,
                        color: PelevoColors.green,
                        backgroundColor: context.pelevo.surfaceHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _collections(BuildContext context) {
    final async = ref.watch(libraryCollectionsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryCollectionsProvider),
      );
    }
    final collections = async.requireValue;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.pelevoOpen('/screen/library-10'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create'),
          ),
        ),
        if (collections.isEmpty)
          Text(
            'No collections yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: PelevoSpacing.sm,
            mainAxisSpacing: PelevoSpacing.sm,
            childAspectRatio: .9,
            children: [
              for (final item in collections)
                InkWell(
                  onTap: () {
                    ref
                        .read(selectedCollectionIdProvider.notifier)
                        .select(item.id);
                    context.pelevoOpen(
                      '/screen/library-11?id=${Uri.encodeComponent(item.id)}',
                    );
                  },
                  borderRadius: BorderRadius.circular(PelevoRadii.large),
                  child: Container(
                    padding: const EdgeInsets.all(PelevoSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.pelevo.surface,
                      borderRadius: BorderRadius.circular(PelevoRadii.large),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CatalogArtwork(
                            url: item.artworkUrl,
                            width: double.infinity,
                            height: double.infinity,
                            radius: PelevoRadii.medium,
                            assetPath: 'assets/library/cover_sunday.png',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty)
                          Text(
                            item.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.pelevo.textMuted),
                          ),
                        Text(
                          '${item.countLabel}${item.isPublic ? ' · Public' : ''}',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _createCollection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Collection Name',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: PelevoSpacing.xs),
      TextField(controller: _collectionName),
      const SizedBox(height: PelevoSpacing.lg),
      const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: PelevoSpacing.xs),
      TextField(controller: _collectionDesc, maxLines: 3),
      const SizedBox(height: PelevoSpacing.xs),
      Text(
        'Optional. Shown on the collection.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Public'),
        subtitle: Text(
          'Anyone with the link can open this collection.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        value: _collectionPublic,
        activeColor: PelevoColors.green,
        onChanged:
            _busy ? null : (value) => setState(() => _collectionPublic = value),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label:
            (GoRouterState.of(context).uri.queryParameters['id'] ?? '')
                    .isEmpty
                ? 'Create Collection'
                : 'Save Collection',
        color: PelevoColors.green,
        onPressed: _busy ? null : () => _createNamedCollection(context),
      ),
    ],
  );

  Widget _collectionDetails(BuildContext context) {
    final id = ref.watch(selectedCollectionIdProvider);
    if (id == null || id.isEmpty) {
      return CatalogStatusBody(
        error: missingLibraryCollection,
        retry: () => context.pelevoBack(fallback: '/screen/library-9'),
      );
    }
    final async = ref.watch(libraryCollectionProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryCollectionProvider),
      );
    }
    final collection = async.requireValue;
    final firstEpisode = collection.items.where(
      (item) => item.type == 'episode',
    );
    final firstShow = collection.items.where((item) => item.type == 'show');
    final owner = collection.isOwner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CatalogArtwork(
            url:
                collection.items.isEmpty
                    ? null
                    : collection.items.first.artworkUrl,
            width: 180,
            height: 180,
            radius: PelevoRadii.large,
            assetPath: 'assets/library/cover_sunday.png',
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          collection.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          collection.countLabel,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        if (collection.description != null &&
            collection.description!.isNotEmpty) ...[
          const SizedBox(height: PelevoSpacing.xs),
          Text(collection.description!),
        ],
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: PelevoButton(
                label: 'Play All',
                color: PelevoColors.green,
                icon: Icons.play_arrow_rounded,
                onPressed:
                    firstEpisode.isNotEmpty
                        ? () => _playCollection(context, collection)
                        : firstShow.isNotEmpty
                        ? () {
                          openCatalogShow(context, firstShow.first.id);
                          context.push('/screen/podcast-details');
                        }
                        : () => context.showPelevoMessage(
                          'This collection has no episodes yet.',
                        ),
              ),
            ),
            if (owner)
              IconButton(
                tooltip: 'Add',
                onPressed:
                    _busy
                        ? null
                        : () => _addLibraryItems(context, collection),
                icon: const Icon(Icons.add_rounded),
              ),
            if (owner)
              IconButton(
                tooltip: 'Edit',
                onPressed:
                    () => context.pelevoOpen(
                      '/screen/library-10?id=${Uri.encodeComponent(collection.id)}',
                    ),
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: 'Share',
              onPressed: () => showPelevoShareChooser(
                context: context,
                ref: ref,
                title: collection.name,
                subtitle: collection.description,
                artworkUrl: collection.items.isEmpty
                    ? collection.artworkUrl
                    : collection.items.first.artworkUrl,
                link: catalogShareCollectionLink(collection.id),
                subjectType: 'collection',
                subjectId: collection.id,
                assetPath: 'assets/library/cover_sunday.png',
                shareTitle: collection.name,
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (collection.items.isEmpty)
          Text(
            'No items are in this collection yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in collection.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 48,
                height: 48,
                assetPath: 'assets/library/ep_124.png',
              ),
              title: Text(item.title),
              subtitle: Text(item.subtitle ?? ''),
              trailing: PopupMenuButton<String>(
                tooltip: 'Item options',
                onSelected: (value) {
                  if (value == 'remove') {
                    if (!owner) return;
                    _removeCollectionItem(context, collection, item);
                    return;
                  }
                  if (item.type == 'episode') {
                    playCatalogEpisode(
                      context,
                      episodeId: item.id,
                      showId: item.showId,
                    );
                  } else {
                    openCatalogShow(context, item.id);
                    context.push('/screen/podcast-details');
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: item.type == 'episode' ? 'play' : 'open',
                        child: Text(item.type == 'episode' ? 'Play' : 'Open'),
                      ),
                      if (owner)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                    ],
              ),
              onTap: () {
                if (item.type == 'episode') {
                  openCatalogEpisode(
                    context,
                    episodeId: item.id,
                    showId: item.showId,
                  );
                  context.pelevoOpen('/screen/episode-details');
                } else {
                  openCatalogShow(context, item.id);
                  context.push('/screen/podcast-details');
                }
              },
            ),
      ],
    );
  }

  Widget _settings(BuildContext context) {
    final settings = ref.watch(librarySettingsProvider);
    final downloads = ref.watch(downloadSettingsProvider);
    if (settings.isLoading || downloads.isLoading) {
      return const CatalogStatusBody();
    }
    if (settings.hasError) {
      return CatalogStatusBody(
        error: settings.error,
        retry: () => ref.invalidate(librarySettingsProvider),
      );
    }
    if (downloads.hasError) {
      return CatalogStatusBody(
        error: downloads.error,
        retry: () => ref.invalidate(downloadSettingsProvider),
      );
    }
    final library = settings.requireValue;
    final download = downloads.requireValue;
    if (download.autoDownloadNew && !_autoSyncStarted) {
      _autoSyncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAutoDownloads(context);
      });
    }
    final sortLabels = const ['Recently added', 'Title', 'Recently played'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sort By'),
          subtitle: Text(sortLabels[library.sortIndex]),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : () => _cycleSort(context, library),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('View Mode'),
          subtitle: Text(const ['List', 'Grid'][_viewMode]),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => setState(() => _viewMode = (_viewMode + 1) % 2),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Auto Downloads', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto Download New Episodes'),
          subtitle: const Text(
            'New episodes from shows you follow, on Wi-Fi when that setting is on.',
          ),
          value: download.autoDownloadNew,
          activeColor: PelevoColors.green,
          onChanged:
              _busy
                  ? null
                  : (value) => _saveAutoDownload(context, download, value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download on Wi-Fi Only'),
          value: download.wifiOnly,
          activeColor: PelevoColors.green,
          onChanged:
              _busy ? null : (value) => _saveWifiOnly(context, download, value),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Storage', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download Quality'),
          subtitle: const Text('Episodes save the published audio file.'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Clear Downloaded Files'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : () => _clearDownloads(context),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Permissions', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.security_rounded,
            color: PelevoColors.green,
          ),
          title: const Text('App Permissions'),
          subtitle: const Text('Notifications, mic, storage, and more'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.pelevoOpen('/screen/permissions-intro'),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('About', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Version'),
          subtitle: Text(ref.watch(packageInfoProvider).version),
        ),
      ],
    );
  }

  Widget _episodeBrowser(
    BuildContext context, {
    required String hint,
    required List<String> filters,
    required int selected,
    required ValueChanged<int> onFilter,
    required List<LibraryEpisode> episodes,
  }) {
    final query = _search.text.trim().toLowerCase();
    final visible =
        query.isEmpty
            ? episodes
            : [
              for (final item in episodes)
                if (item.title.toLowerCase().contains(query)) item,
            ];
    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < filters.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                  child: ChoiceChip(
                    label: Text(filters[i]),
                    selected: selected == i,
                    selectedColor: PelevoColors.green,
                    onSelected: (_) => onFilter(i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (visible.isEmpty)
          Text(
            'No episodes match this list.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 48,
                height: 48,
                assetPath: 'assets/library/ep_124.png',
              ),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: IconButton(
                tooltip: 'Play',
                onPressed: () {
                  playCatalogEpisode(
                    context,
                    episodeId: item.id,
                    showId: item.showId,
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
              ),
              onTap: () {
                openCatalogEpisode(
                  context,
                  episodeId: item.id,
                  showId: item.showId,
                );
                context.pelevoOpen('/screen/episode-details');
              },
            ),
      ],
    );
  }

  Widget _menuRow(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? badge,
    String? subtitle,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .18),
      child: Icon(icon, color: color),
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.pelevo.surfaceHigh,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(badge),
          ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
    onTap: onTap,
  );

  Future<void> _playCollection(
    BuildContext context,
    LibraryCollection collection,
  ) async {
    final episodes =
        collection.items.where((item) => item.type == 'episode').toList();
    if (episodes.isEmpty) {
      context.showPelevoMessage('This collection has no episodes yet.');
      return;
    }
    final repo = ref.read(catalogRepositoryProvider);
    for (final item in episodes.skip(1)) {
      try {
        await repo.enqueueEpisode(item.id);
      } on Object {
        // The first episode still starts if a later one cannot be queued.
      }
    }
    if (!context.mounted) return;
    playCatalogEpisode(
      context,
      episodeId: episodes.first.id,
      showId: episodes.first.showId,
    );
  }

  Future<void> _addLibraryItems(
    BuildContext context,
    LibraryCollection collection,
  ) async {
    final changed = await showCollectionLibraryPicker(
      context: context,
      ref: ref,
      collection: collection,
    );
    if (!changed) return;
    ref.invalidate(libraryCollectionProvider);
    ref.invalidate(libraryCollectionsProvider);
    ref.invalidate(libraryOverviewProvider);
  }

  Future<void> _removeCollectionItem(
    BuildContext context,
    LibraryCollection collection,
    LibraryCollectionItem item,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(libraryRepositoryProvider).removeCollectionItem(
        id: collection.id,
        type: item.type,
        collectableId: item.id,
        version: collection.version,
      );
      ref.invalidate(libraryCollectionProvider);
      ref.invalidate(libraryCollectionsProvider);
      ref.invalidate(libraryOverviewProvider);
      if (context.mounted) context.showPelevoMessage('Removed from collection');
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createNamedCollection(BuildContext context) async {
    final name = _collectionName.text.trim();
    if (name.isEmpty) {
      context.showPelevoMessage('Enter a collection name.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final description = _collectionDesc.text.trim();
      final editingId = GoRouterState.of(context).uri.queryParameters['id'];
      final LibraryCollection saved;
      if (editingId != null && editingId.isNotEmpty) {
        final current = ref.read(libraryCollectionProvider).asData?.value;
        if (current == null || current.id != editingId) {
          if (context.mounted) {
            context.showPelevoMessage('Collection is still loading.');
          }
          return;
        }
        saved = await repo.updateCollection(
          id: editingId,
          name: name,
          description: description,
          isPublic: _collectionPublic,
          version: current.version,
        );
      } else {
        saved = await repo.createCollection(
          name,
          description: description,
          isPublic: _collectionPublic,
        );
      }
      ref.invalidate(libraryCollectionsProvider);
      ref.invalidate(libraryCollectionProvider);
      ref.invalidate(libraryOverviewProvider);
      ref.read(selectedCollectionIdProvider.notifier).select(saved.id);
      if (!context.mounted) return;
      context.showPelevoMessage(
        editingId == null || editingId.isEmpty
            ? 'Collection created'
            : 'Collection updated',
      );
      context.pelevoOpen(
        '/screen/library-11?id=${Uri.encodeComponent(saved.id)}',
      );
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cycleSort(BuildContext context, LibrarySettings current) async {
    const order = ['recent', 'title', 'oldest'];
    final next = order[(current.sortIndex + 1) % order.length];
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSettings(
            hideCompleted: current.hideCompleted,
            sort: next,
            version: current.version,
          );
      ref.invalidate(librarySettingsProvider);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAutoDownload(
    BuildContext context,
    DownloadSettings current,
    bool enabled,
  ) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveDownloadSettings(current, autoDownloadNew: enabled);
      ref.invalidate(downloadSettingsProvider);
      if (!context.mounted) return;
      if (enabled) {
        final saved = await _syncAutoDownloads(context);
        if (!context.mounted) return;
        context.showPelevoMessage(
          saved == 0
              ? 'Auto-download is on. New episodes will save when you are on an allowed network.'
              : 'Saved $saved new episode${saved == 1 ? '' : 's'}.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int> _syncAutoDownloads(BuildContext context) async {
    try {
      final saved = await syncAutoDownloads(ref);
      if (saved > 0) ref.invalidate(libraryDownloadsProvider);
      return saved;
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
      return 0;
    }
  }

  Future<void> _clearDownloads(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Clear downloaded files'),
            content: const Text(
              'This removes episodes saved on this device. You can download them again later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _busy = true);
    try {
      final removed = await ref.read(downloadFileServiceProvider).clearAll();
      if (!context.mounted) return;
      context.showPelevoMessage(
        removed == 0
            ? 'No downloaded files on this device.'
            : 'Removed $removed downloaded file${removed == 1 ? '' : 's'}.',
      );
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveWifiOnly(
    BuildContext context,
    DownloadSettings current,
    bool wifiOnly,
  ) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveDownloadSettings(current, wifiOnly: wifiOnly);
      ref.invalidate(downloadSettingsProvider);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPlaylistEditor(
    BuildContext context, {
    LibraryPlaylist? editing,
  }) async {
    final nameController = TextEditingController(text: editing?.name ?? '');
    var isPublic = editing?.isPublic ?? true;
    List<int>? artworkBytes;
    String? artworkName;
    var artworkUrl = editing?.artworkUrl;
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  editing == null ? 'Create playlist' : 'Edit playlist',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1400,
                              maxHeight: 1400,
                              imageQuality: 88,
                            );
                            if (photo == null) return;
                            if (await photo.length() > 5 * 1024 * 1024) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Choose a photo smaller than 5 MB.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            final bytes = await photo.readAsBytes();
                            setDialogState(() {
                              artworkBytes = bytes;
                              artworkName = photo.name;
                              artworkUrl = null;
                            });
                          } catch (_) {}
                        },
                        child: CatalogArtwork(
                          url: artworkUrl,
                          width: 96,
                          height: 96,
                          radius: PelevoRadii.medium,
                          assetPath: 'assets/library/cover_mindset.png',
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      TextButton(
                        onPressed: () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1400,
                              maxHeight: 1400,
                              imageQuality: 88,
                            );
                            if (photo == null) return;
                            final bytes = await photo.readAsBytes();
                            setDialogState(() {
                              artworkBytes = bytes;
                              artworkName = photo.name;
                            });
                          } catch (_) {}
                        },
                        child: Text(
                          artworkBytes == null
                              ? 'Upload cover art'
                              : 'Cover art selected',
                        ),
                      ),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Playlist name',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Public playlist'),
                        subtitle: const Text(
                          'Public playlists appear in search and By Others.',
                        ),
                        value: isPublic,
                        onChanged:
                            (value) => setDialogState(() => isPublic = value),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        () => Navigator.pop(
                          dialogContext,
                          nameController.text.trim().isNotEmpty,
                        ),
                    child: Text(editing == null ? 'Create' : 'Save'),
                  ),
                ],
              );
            },
          ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (saved != true || !context.mounted) return;
    setState(() => _busy = true);
    try {
      if (editing == null) {
        final created = await ref
            .read(libraryRepositoryProvider)
            .createPlaylist(name: name, isPublic: isPublic);
        if (artworkBytes != null && artworkName != null) {
          await ref
              .read(libraryRepositoryProvider)
              .uploadPlaylistArtwork(
                playlistId: created.id,
                bytes: artworkBytes!,
                filename: artworkName!,
              );
        }
        if (context.mounted) context.showPelevoMessage('Playlist created');
      } else {
        await ref
            .read(libraryRepositoryProvider)
            .updatePlaylist(
              editing,
              name: name,
              description: editing.description,
              isPublic: isPublic,
            );
        if (artworkBytes != null && artworkName != null) {
          await ref
              .read(libraryRepositoryProvider)
              .uploadPlaylistArtwork(
                playlistId: editing.id,
                bytes: artworkBytes!,
                filename: artworkName!,
              );
        }
        if (context.mounted) context.showPelevoMessage('Playlist updated');
        ref.invalidate(libraryPlaylistProvider);
      }
      ref.invalidate(libraryPlaylistsProvider);
      ref.invalidate(libraryPublicPlaylistsProvider);
      ref.invalidate(libraryOverviewProvider);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPlaylistOptions(BuildContext context) =>
      showPelevoSheet<void>(
        context: context,
        builder:
            (sheetContext) => Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(
                    widget.view == _LibraryView.collectionDetails
                        ? 'Edit collection'
                        : 'Edit playlist',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (widget.view == _LibraryView.collectionDetails) {
                      final collection =
                          ref.read(libraryCollectionProvider).asData?.value;
                      if (collection != null && !collection.isOwner) {
                        context.showPelevoMessage(
                          'Only the owner can edit this collection.',
                        );
                        return;
                      }
                      context.pelevoOpen(
                        collection == null
                            ? '/screen/library-10'
                            : '/screen/library-10?id=${Uri.encodeComponent(collection.id)}',
                      );
                      return;
                    }
                    final playlist =
                        ref.read(libraryPlaylistProvider).asData?.value;
                    if (playlist != null && !playlist.isOwner) {
                      context.showPelevoMessage(
                        'Only the owner can edit this playlist.',
                      );
                      return;
                    }
                    _showPlaylistEditor(context, editing: playlist);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text(
                    widget.view == _LibraryView.collectionDetails
                        ? 'Share collection'
                        : 'Share playlist',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (widget.view == _LibraryView.collectionDetails) {
                      final collection =
                          ref.read(libraryCollectionProvider).asData?.value;
                      if (collection == null) return;
                      showPelevoShareChooser(
                        context: context,
                        ref: ref,
                        title: collection.name,
                        subtitle: collection.description,
                        artworkUrl: collection.artworkUrl,
                        link: catalogShareCollectionLink(collection.id),
                        subjectType: 'collection',
                        subjectId: collection.id,
                        assetPath: 'assets/library/cover_sunday.png',
                      );
                      return;
                    }
                    final playlist =
                        ref.read(libraryPlaylistProvider).asData?.value;
                    if (playlist == null) return;
                    showPelevoShareChooser(
                      context: context,
                      ref: ref,
                      title: playlist.name,
                      subtitle: playlist.description,
                      artworkUrl: playlist.artworkUrl,
                      link: catalogSharePlaylistLink(playlist.id),
                      subjectType: 'playlist',
                      subjectId: playlist.id,
                      assetPath: 'assets/library/cover_mindset.png',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: PelevoColors.red,
                  ),
                  title: Text(
                    widget.view == _LibraryView.collectionDetails
                        ? 'Delete collection'
                        : 'Delete playlist',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (widget.view == _LibraryView.collectionDetails) {
                      final collection =
                          ref.read(libraryCollectionProvider).asData?.value;
                      if (collection != null && !collection.isOwner) {
                        context.showPelevoMessage(
                          'Only the owner can delete this collection.',
                        );
                        return;
                      }
                    }
                    _deleteCurrentLibraryItem(context);
                  },
                ),
              ],
            ),
      );

  Future<void> _deleteCurrentLibraryItem(BuildContext context) async {
    setState(() => _busy = true);
    try {
      if (widget.view == _LibraryView.collectionDetails) {
        final id = ref.read(selectedCollectionIdProvider);
        if (id == null || id.isEmpty) throw missingLibraryCollection;
        await ref.read(libraryRepositoryProvider).deleteCollection(id);
        ref.invalidate(libraryCollectionsProvider);
        ref.invalidate(libraryOverviewProvider);
        if (!context.mounted) return;
        context.showPelevoMessage('Collection deleted');
        context.pelevoBack(fallback: '/screen/library-9');
      } else {
        final playlist = ref.read(libraryPlaylistProvider).asData?.value;
        if (playlist != null && !playlist.isOwner) {
          if (context.mounted) {
            context.showPelevoMessage(
              'Only the owner can delete this playlist.',
            );
          }
          return;
        }
        final id = ref.read(selectedPlaylistIdProvider);
        if (id == null || id.isEmpty) throw missingLibraryPlaylist;
        await ref.read(libraryRepositoryProvider).deletePlaylist(id);
        ref.invalidate(libraryPlaylistsProvider);
        ref.invalidate(libraryPublicPlaylistsProvider);
        ref.invalidate(libraryOverviewProvider);
        if (!context.mounted) return;
        context.showPelevoMessage('Playlist deleted');
        context.pelevoBack(fallback: '/screen/library-2');
      }
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chipTab(
    String label,
    int value,
    int selected,
    ValueChanged<int> onSelected,
  ) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    selectedColor: PelevoColors.green,
    visualDensity: VisualDensity.compact,
    onSelected: (_) => onSelected(value),
  );
}
