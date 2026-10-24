import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/library/playlist_picker.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _PodcastView {
  overview,
  about,
  episodes,
  nowPlaying,
  episodeDetails,
  chapters,
  reviews,
  related,
  queue,
  share,
}

const _podcastInventory =
    <({String id, String title, String state, _PodcastView view})>[
      (
        id: 'podcast-details',
        title: 'The Honest Bunch',
        state: 'Podcast overview',
        view: _PodcastView.overview,
      ),
      (
        id: 'podcast-about',
        title: 'About Podcast',
        state: 'Expanded description',
        view: _PodcastView.about,
      ),
      (
        id: 'podcast-episodes',
        title: 'Episodes',
        state: 'Episode archive',
        view: _PodcastView.episodes,
      ),
      (
        id: 'podcast-following',
        title: 'Now Playing',
        state: 'Full player',
        view: _PodcastView.nowPlaying,
      ),
      (
        id: 'podcast-unavailable',
        title: 'Episode Details',
        state: 'In-depth episode information',
        view: _PodcastView.episodeDetails,
      ),
      (
        id: 'podcast-unfollowed',
        title: 'Chapters',
        state: 'Chapter list',
        view: _PodcastView.chapters,
      ),
      (
        id: 'podcast-reviews',
        title: 'Reviews & Ratings',
        state: 'Listener reviews',
        view: _PodcastView.reviews,
      ),
      (
        id: 'podcast-related',
        title: 'Similar Podcasts',
        state: 'Related podcasts',
        view: _PodcastView.related,
      ),
      (
        id: 'podcast-notifications',
        title: 'Add to Queue',
        state: 'Queue options',
        view: _PodcastView.queue,
      ),
      (
        id: 'podcast-loading',
        title: 'Share Podcast',
        state: 'Share options',
        view: _PodcastView.share,
      ),
    ];

final List<PelevoScreenSpec> podcastScreens = List.unmodifiable(
  _podcastInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Podcast Details',
      title: item.title,
      state: item.state,
      builder: (_) => _PodcastScreen(view: item.view, title: item.title),
    ),
  ),
);

class _PodcastScreen extends ConsumerStatefulWidget {
  const _PodcastScreen({required this.view, required this.title});

  final _PodcastView view;
  final String title;

  @override
  ConsumerState<_PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends ConsumerState<_PodcastScreen> {
  bool _playing = true;
  bool _busy = false;
  double _progress = 0;
  int _episodeFilter = 0;
  int _reviewFilter = 0;
  int _queueChoice = 1;
  int _nav = 0;
  final _reviewBody = TextEditingController();
  final _episodeSearch = TextEditingController();
  final _episodeSearchFocus = FocusNode();
  int _reviewRating = 5;
  Timer? _syncPoll;
  Timer? _episodeSearchDebounce;
  var _focusEpisodeSearch = false;

  bool get _needsEpisode => const {
    _PodcastView.nowPlaying,
    _PodcastView.episodeDetails,
    _PodcastView.chapters,
    _PodcastView.queue,
  }.contains(widget.view);

  @override
  void initState() {
    super.initState();
    _episodeSearch.text = '';
  }

  @override
  void dispose() {
    _syncPoll?.cancel();
    _episodeSearchDebounce?.cancel();
    _reviewBody.dispose();
    _episodeSearch.dispose();
    _episodeSearchFocus.dispose();
    super.dispose();
  }

  void _openEpisodeSearch() {
    setState(() => _focusEpisodeSearch = true);
    context.go('/screen/podcast-episodes');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _episodeSearchFocus.requestFocus();
    });
  }

  void _onEpisodeSearchChanged(String value) {
    _episodeSearchDebounce?.cancel();
    _episodeSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(catalogEpisodeQueryProvider.notifier).setQuery(value);
    });
  }

  void _watchEpisodeSync(CatalogShow show) {
    if (!show.episodesSyncing) {
      _syncPoll?.cancel();
      _syncPoll = null;
      return;
    }
    // Quiet background poll — refresh keeps prior AsyncValue so the page
    // stays visible while RSS / Podcast Index hydration finishes.
    _syncPoll ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(catalogShowProvider);
      ref.read(catalogEpisodesProvider.notifier).refreshFirstPage();
    });
  }

  Future<void> _refreshEpisodes(CatalogShow show) async {
    setState(() => _busy = true);
    try {
      await ref.read(catalogRepositoryProvider).refreshShow(show.id);
      if (!mounted) return;
      ref.invalidate(catalogShowProvider);
      await ref.read(catalogEpisodesProvider.notifier).refreshFirstPage();
      _watchEpisodeSync(show.copyWith(episodesSyncing: true));
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
      ref.invalidate(catalogShowProvider);
      await ref.read(catalogEpisodesProvider.notifier).refreshFirstPage();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNav = {
      _PodcastView.overview,
      _PodcastView.about,
      _PodcastView.episodes,
      _PodcastView.related,
      _PodcastView.reviews,
    }.contains(widget.view);
    final showId = ref.watch(selectedShowIdProvider);
    final showAsync = ref.watch(catalogShowProvider);
    final title =
        showAsync.asData?.value.title ??
        ((showId == null || showId.isEmpty) ? 'Podcast' : widget.title);

    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (widget.view == _PodcastView.overview) {
              context.pelevoBack();
            } else {
              context.pelevoBack(fallback: '/screen/podcast-details');
            }
          },
          icon: Icon(
            widget.view == _PodcastView.nowPlaying
                ? Icons.keyboard_arrow_down_rounded
                : Icons.arrow_back_rounded,
          ),
        ),
        title: Text(
          widget.view == _PodcastView.nowPlaying ||
                  widget.view == _PodcastView.overview
              ? title
              : widget.title,
        ),
        actions: [
          if (widget.view == _PodcastView.overview) ...[
            IconButton(
              tooltip: 'Search episodes',
              onPressed: _openEpisodeSearch,
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'More options',
              onPressed: () => _showActions(context),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
          if (widget.view == _PodcastView.nowPlaying)
            IconButton(
              tooltip: 'Open queue',
              onPressed: () => context.go('/screen/queue-up-next'),
              icon: const Icon(Icons.queue_music_rounded),
            ),
        ],
      ),
      bottomNavigationBar:
          showNav
              ? PelevoBottomNavigation(
                index: _nav,
                onDestinationSelected: (value) {
                  setState(() => _nav = value);
                  context.openPelevoTab(value);
                },
              )
              : null,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final showId = ref.watch(selectedShowIdProvider);
    if (showId == null || showId.isEmpty) {
      return CatalogStatusBody(
        error: missingCatalogShow,
        retry: () => context.go('/screen/search'),
      );
    }
    final showAsync = ref.watch(catalogShowProvider);
    if (showAsync.isLoading && !showAsync.hasValue) {
      return const CatalogStatusBody();
    }
    if (showAsync.hasError && !showAsync.hasValue) {
      return CatalogStatusBody(
        error: showAsync.error,
        retry: () => ref.invalidate(catalogShowProvider),
      );
    }
    final show = showAsync.requireValue;
    _watchEpisodeSync(show);
    if (_needsEpisode) return _episodeBound(context, show);
    return switch (widget.view) {
      _PodcastView.overview => _overview(context, show),
      _PodcastView.about => _about(context, show),
      _PodcastView.episodes => _episodesList(context, show),
      _PodcastView.reviews => _reviews(context, show),
      _PodcastView.related => _related(context, show),
      _PodcastView.share => _sharePodcast(context, show),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _episodeBound(BuildContext context, CatalogShow show) {
    final episodeId = ref.watch(selectedEpisodeIdProvider);
    final episodesAsync = ref.watch(catalogEpisodesProvider);
    if (episodeId == null || episodeId.isEmpty) {
      if (episodesAsync.isLoading && !episodesAsync.hasValue) {
        return const CatalogStatusBody();
      }
      if (episodesAsync.hasError && !episodesAsync.hasValue) {
        return CatalogStatusBody(
          error: episodesAsync.error,
          retry: () => ref.invalidate(catalogEpisodesProvider),
        );
      }
      final episodes = episodesAsync.asData?.value.items ?? const <CatalogEpisode>[];
      if (episodes.isEmpty) {
        return CatalogStatusBody(
          error: missingCatalogEpisode,
          retry: () => context.go('/screen/podcast-episodes'),
        );
      }
      final episode = episodes.first.overlayLivePlayback(
        nowPlaying: ref.watch(nowPlayingEpisodeProvider),
      );
      return switch (widget.view) {
        _PodcastView.nowPlaying => _nowPlaying(context, show, episode),
        _PodcastView.episodeDetails => _episodeDetail(context, show, episode),
        _PodcastView.chapters => _chapters(context, episode),
        _PodcastView.queue => _addToQueue(context, episode),
        _ => const SizedBox.shrink(),
      };
    }
    final episodeAsync = ref.watch(catalogEpisodeProvider);
    if (episodeAsync.isLoading && !episodeAsync.hasValue) {
      return const CatalogStatusBody();
    }
    if (episodeAsync.hasError && !episodeAsync.hasValue) {
      return CatalogStatusBody(
        error: episodeAsync.error,
        retry: () => ref.invalidate(catalogEpisodeProvider),
      );
    }
    final episode = episodeAsync.requireValue.overlayLivePlayback(
      nowPlaying: ref.watch(nowPlayingEpisodeProvider),
      listed: ref.watch(catalogEpisodesProvider).asData?.value.items ?? const [],
    );
    return switch (widget.view) {
      _PodcastView.nowPlaying => _nowPlaying(context, show, episode),
      _PodcastView.episodeDetails => _episodeDetail(context, show, episode),
      _PodcastView.chapters => _chapters(context, episode),
      _PodcastView.queue => _addToQueue(context, episode),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _overview(BuildContext context, CatalogShow show) {
    final episodesAsync = ref.watch(catalogEpisodesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(show, 116),
            const SizedBox(width: PelevoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: PelevoSpacing.xxs),
                  Text(
                    show.categoryLabel,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  const SizedBox(height: PelevoSpacing.xs),
                  InkWell(
                    onTap: () => context.go('/screen/podcast-reviews'),
                    child: Text(
                      show.ratingLine,
                      style: const TextStyle(color: PelevoColors.yellow),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        InkWell(
          onTap: () => context.go('/screen/podcast-about'),
          child: Text(
            show.description == null || show.description!.isEmpty
                ? 'No description is available.'
                : show.description!,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: PelevoButton(
                label: 'Play Latest',
                color: PelevoColors.green,
                icon: Icons.play_arrow_rounded,
                onPressed: _busy ? null : () => _playLatest(show),
              ),
            ),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: PelevoButton(
                label: show.following ? 'Following' : 'Follow',
                outlined: true,
                color: PelevoColors.green,
                icon:
                    show.following
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                onPressed: _busy ? null : () => _toggleFollow(show),
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _quickAction(
              Icons.star_border_rounded,
              'Rate',
              () => context.go('/screen/podcast-reviews'),
            ),
            _quickAction(
              Icons.ios_share_rounded,
              'Share',
              () => context.go('/screen/podcast-loading'),
            ),
            _quickAction(
              Icons.download_outlined,
              'Download',
              () => context.go('/screen/downloads-1'),
            ),
            _quickAction(
              Icons.more_horiz_rounded,
              'More',
              () => _showActions(context),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoSectionHeader(
          title: 'Episodes',
          onSeeAll: () => context.go('/screen/podcast-episodes'),
        ),
        if (episodesAsync.isLoading && !episodesAsync.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: PelevoSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (episodesAsync.hasError && !episodesAsync.hasValue)
          CatalogStatusBody(
            error: episodesAsync.error,
            retry: () => ref.invalidate(catalogEpisodesProvider),
          )
        else if ((episodesAsync.asData?.value.items ?? const <CatalogEpisode>[])
            .isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                show.emptyEpisodesMessage,
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              if (show.episodesSyncing) ...[
                const SizedBox(height: PelevoSpacing.sm),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: PelevoSpacing.sm),
              TextButton(
                onPressed: _busy ? null : () => _refreshEpisodes(show),
                child: Text(
                  show.episodesSyncing
                      ? 'Check again'
                      : 'Refresh from podcast feed',
                ),
              ),
            ],
          )
        else
          ..._episodeTiles(
            context,
            show,
            (episodesAsync.asData?.value.items ?? const <CatalogEpisode>[])
                .take(4)
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _about(BuildContext context, CatalogShow show) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'About the Podcast',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        show.description == null || show.description!.isEmpty
            ? 'No description is available.'
            : show.description!,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: PelevoSpacing.xs),
      if (show.categories.isEmpty)
        Text(
          'No categories are listed.',
          style: TextStyle(color: context.pelevo.textMuted),
        )
      else
        Wrap(
          spacing: PelevoSpacing.xs,
          children: [
            for (final category in show.categories)
              Chip(label: Text(category.name)),
          ],
        ),
      const SizedBox(height: PelevoSpacing.lg),
      const Text('Host', style: TextStyle(fontWeight: FontWeight.w700)),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipOval(child: _cover(show, 48)),
        title: Text(show.host),
        subtitle: const Text('Host'),
        onTap: () => context.go('/screen/podcast-related'),
      ),
      const SizedBox(height: PelevoSpacing.md),
      Row(
        children: [
          Expanded(
            child: _StatCard(label: 'Episodes', value: '${show.episodesCount}'),
          ),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Followers',
              value: '${show.followerCount}',
            ),
          ),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Rating',
              value:
                  show.ratingAverage == null || show.ratingAverage!.isEmpty
                      ? '—'
                      : '${show.ratingAverage}★',
            ),
          ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'See similar podcasts',
        outlined: true,
        onPressed: () => context.go('/screen/podcast-related'),
      ),
    ],
  );

  Widget _episodesList(BuildContext context, CatalogShow show) {
    final episodesAsync = ref.watch(catalogEpisodesProvider);
    final query = ref.watch(catalogEpisodeQueryProvider);
    final page = episodesAsync.asData?.value;
    final episodes = page?.items ?? const <CatalogEpisode>[];
    if (_episodeSearch.text != query && !_episodeSearchFocus.hasFocus) {
      _episodeSearch.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    if (_focusEpisodeSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _episodeSearchFocus.requestFocus();
        setState(() => _focusEpisodeSearch = false);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _episodeSearch,
          focusNode: _episodeSearchFocus,
          textInputAction: TextInputAction.search,
          onChanged: _onEpisodeSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search episodes in this podcast',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                query.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _episodeSearchDebounce?.cancel();
                        _episodeSearch.clear();
                        ref.read(catalogEpisodeQueryProvider.notifier).clear();
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                (0, 'All Episodes'),
                (1, 'Popular'),
                (2, 'Oldest'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _episodeFilter == entry.$1,
                    selectedColor: PelevoColors.green,
                    onSelected: (_) => setState(() => _episodeFilter = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (show.episodesSyncing && episodes.isNotEmpty) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: PelevoSpacing.sm),
          Text(
            'Syncing more episodes in the background…',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
        ],
        if (episodesAsync.isLoading && !episodesAsync.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: PelevoSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (episodesAsync.hasError && !episodesAsync.hasValue)
          CatalogStatusBody(
            error: episodesAsync.error,
            retry: () => ref.invalidate(catalogEpisodesProvider),
          )
        else if (episodes.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                query.isEmpty
                    ? show.emptyEpisodesMessage
                    : 'No episodes match “$query”.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              if (show.episodesSyncing && query.isEmpty) ...[
                const SizedBox(height: PelevoSpacing.sm),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (query.isEmpty)
                TextButton(
                  onPressed: _busy ? null : () => _refreshEpisodes(show),
                  child: Text(
                    show.episodesSyncing
                        ? 'Check again'
                        : 'Refresh from podcast feed',
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    _episodeSearchDebounce?.cancel();
                    _episodeSearch.clear();
                    ref.read(catalogEpisodeQueryProvider.notifier).clear();
                  },
                  child: const Text('Clear search'),
                ),
            ],
          )
        else ...[
          ..._episodeTiles(
            context,
            show,
            _filteredEpisodes(episodes),
            showMenu: true,
          ),
          if (page?.hasMore == true) ...[
            const SizedBox(height: PelevoSpacing.md),
            if (page?.loadingMore == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: PelevoSpacing.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              PelevoButton(
                label: 'Load more episodes',
                outlined: true,
                onPressed:
                    () => ref.read(catalogEpisodesProvider.notifier).loadMore(),
              ),
          ],
        ],
      ],
    );
  }

  List<CatalogEpisode> _filteredEpisodes(List<CatalogEpisode> episodes) {
    if (_episodeFilter == 2) return episodes.reversed.toList(growable: false);
    return episodes;
  }

  Widget _nowPlaying(
    BuildContext context,
    CatalogShow show,
    CatalogEpisode episode,
  ) {
    final duration = episode.durationSeconds ?? 0;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.md),
        CatalogArtwork(
          url: episode.artworkUrl ?? show.artworkUrl,
          width: double.infinity,
          height: 280,
          radius: PelevoRadii.large,
          assetPath: 'assets/podcast/now_playing.png',
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text(
          episode.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          show.title,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Slider(
          value: _progress.clamp(0, 1),
          activeColor: PelevoColors.green,
          onChanged: (value) => setState(() => _progress = value),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatCatalogClock((_progress * duration).round()),
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            Text(
              duration == 0 ? '—' : formatCatalogClock(duration),
              style: TextStyle(color: context.pelevo.textMuted),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => context.go('/screen/episode-playing'),
              child: const Text('1x'),
            ),
            IconButton(
              tooltip: 'Rewind 10 seconds',
              onPressed:
                  () => setState(() => _progress = (_progress - .05).clamp(0, 1)),
              icon: const Icon(Icons.replay_10_rounded, size: 32),
            ),
            CircleAvatar(
              radius: 34,
              backgroundColor: PelevoColors.red,
              child: IconButton(
                tooltip: _playing ? 'Pause' : 'Play',
                onPressed: _busy ? null : () => _toggleSession(episode, show),
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Forward 10 seconds',
              onPressed:
                  () => setState(() => _progress = (_progress + .05).clamp(0, 1)),
              icon: const Icon(Icons.forward_10_rounded, size: 32),
            ),
            IconButton(
              tooltip: 'Sleep timer',
              onPressed: () => context.go('/screen/episode-sleep-timer'),
              icon: const Icon(Icons.bedtime_outlined),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _quickAction(
              Icons.ios_share_rounded,
              'Share',
              () => context.go('/screen/podcast-loading'),
            ),
            _quickAction(
              Icons.download_outlined,
              'Download',
              () => context.go('/screen/downloads-1'),
            ),
            _quickAction(
              Icons.bookmark_border_rounded,
              'Save',
              () => context.showPelevoMessage(
                'Saving this episode is not available yet.',
              ),
            ),
            _quickAction(
              Icons.queue_music_rounded,
              'Queue',
              () => context.go('/screen/podcast-notifications'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _episodeDetail(
    BuildContext context,
    CatalogShow show,
    CatalogEpisode episode,
  ) {
    final chaptersAsync = ref.watch(catalogChaptersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CatalogArtwork(
              url: episode.artworkUrl ?? show.artworkUrl,
              width: 84,
              height: 84,
              assetPath: 'assets/podcast/episode_detail.png',
            ),
            const SizedBox(width: PelevoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.subtitle.isEmpty ? show.title : episode.subtitle,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          episode.description == null || episode.description!.isEmpty
              ? 'No description is available.'
              : episode.description!,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: _episodePlayLabel(episode),
          color: PelevoColors.green,
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            playCatalogEpisode(
              context,
              episodeId: episode.id,
              showId: show.id,
              positionSeconds:
                  episode.completed ? null : episode.positionSeconds,
              restart: episode.completed,
            );
          },
        ),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _quickAction(
              Icons.download_outlined,
              'Download',
              () => context.go('/screen/downloads-1'),
            ),
            _quickAction(
              Icons.ios_share_rounded,
              'Share',
              () => context.go('/screen/podcast-loading'),
            ),
            _quickAction(
              Icons.playlist_add_rounded,
              'Add to Queue',
              _busy ? () {} : () => _queueShowEpisode(context),
            ),
            _quickAction(
              Icons.more_horiz_rounded,
              'More',
              () => _showActions(context),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoSectionHeader(
          title: 'Chapters',
          onSeeAll: () => context.go('/screen/podcast-unfollowed'),
        ),
        if (chaptersAsync.isLoading)
          const CatalogStatusBody()
        else if (chaptersAsync.hasError)
          CatalogStatusBody(
            error: chaptersAsync.error,
            retry: () => ref.invalidate(catalogChaptersProvider),
          )
        else if (chaptersAsync.requireValue.isEmpty)
          Text(
            'No chapters are available.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final chapter in chaptersAsync.requireValue.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                chapter.timestamp,
                style: const TextStyle(
                  color: PelevoColors.yellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
              title: Text(chapter.title),
              trailing: const Icon(Icons.play_circle_fill_rounded),
              onTap: () {
                playCatalogEpisode(
                  context,
                  episodeId: episode.id,
                  showId: show.id,
                );
              },
            ),
      ],
    );
  }

  Widget _chapters(BuildContext context, CatalogEpisode episode) {
    final chaptersAsync = ref.watch(catalogChaptersProvider);
    if (chaptersAsync.isLoading) return const CatalogStatusBody();
    if (chaptersAsync.hasError) {
      return CatalogStatusBody(
        error: chaptersAsync.error,
        retry: () => ref.invalidate(catalogChaptersProvider),
      );
    }
    final chapters = chaptersAsync.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chapters', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: PelevoSpacing.md),
        if (chapters.isEmpty)
          Text(
            'No chapters are available.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final chapter in chapters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 54,
                child: Text(
                  chapter.timestamp,
                  style: const TextStyle(
                    color: PelevoColors.yellow,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(chapter.title),
              trailing: const Icon(Icons.play_circle_fill_rounded),
              onTap: () {
                playCatalogEpisode(
                  context,
                  episodeId: episode.id,
                  showId: episode.showId,
                );
              },
            ),
      ],
    );
  }

  Widget _reviews(BuildContext context, CatalogShow show) {
    final reviewsAsync = ref.watch(catalogReviewsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              show.ratingAverage == null || show.ratingAverage!.isEmpty
                  ? '—'
                  : show.ratingAverage!,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '★★★★★',
                    style: TextStyle(color: PelevoColors.yellow),
                  ),
                  Text(
                    '${show.ratingCount} ratings',
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (reviewsAsync.hasValue)
          for (final entry in catalogRatingBars(
            reviewsAsync.requireValue,
          ).asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 18, child: Text('${5 - entry.key}')),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: PelevoColors.green,
                      backgroundColor: context.pelevo.surfaceHigh,
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Write a Review',
          outlined: true,
          color: PelevoColors.green,
          onPressed: _busy ? null : () => _writeReview(context, show),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                (0, 'Most Recent'),
                (1, 'Most Helpful'),
                (2, 'Most Positive'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _reviewFilter == entry.$1,
                    selectedColor: PelevoColors.green,
                    onSelected: (_) => setState(() => _reviewFilter = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
        if (reviewsAsync.isLoading)
          const CatalogStatusBody()
        else if (reviewsAsync.hasError)
          CatalogStatusBody(
            error: reviewsAsync.error,
            retry: () => ref.invalidate(catalogReviewsProvider),
          )
        else if (reviewsAsync.requireValue.isEmpty)
          Text(
            'No reviews are published yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final review in sortedCatalogReviews(
            reviewsAsync.requireValue,
            _reviewFilter,
          ))
            Card(
              color: context.pelevo.surface,
              margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: ListTile(
                title: Text(
                  '★' * review.rating,
                  style: const TextStyle(color: PelevoColors.yellow),
                ),
                subtitle: Text(
                  '${review.reviewerName} · ${review.createdAt.toIso8601String().split('T').first}\n${review.body ?? ''}',
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }

  Widget _related(BuildContext context, CatalogShow show) {
    final relatedAsync = ref.watch(catalogRelatedProvider);
    if (relatedAsync.isLoading) return const CatalogStatusBody();
    if (relatedAsync.hasError) {
      return CatalogStatusBody(
        error: relatedAsync.error,
        retry: () => ref.invalidate(catalogRelatedProvider),
      );
    }
    final related = relatedAsync.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Similar Podcasts',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (related.isEmpty)
          Text(
            'No related shows are published yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in related)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 58,
                height: 58,
                assetPath: 'assets/podcast/similar_tea.png',
              ),
              title: Text(item.title),
              subtitle: Text(item.author ?? 'Podcast'),
              trailing: OutlinedButton(
                onPressed: _busy ? null : () => _followRelated(item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PelevoColors.green,
                  side: const BorderSide(color: PelevoColors.green, width: 1.5),
                ),
                child: const Text('Follow'),
              ),
              onTap: () {
                openCatalogShow(context, item.id);
                context.push('/screen/podcast-details');
              },
            ),
      ],
    );
  }

  Widget _addToQueue(BuildContext context, CatalogEpisode episode) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final option in const [
        (0, 'Play Next', 'Play this episode next'),
        (1, 'Add to Queue', 'Add this episode to your queue'),
        (2, 'Add to Playlist', 'Save this episode to a playlist'),
      ])
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: option.$1,
          groupValue: _queueChoice,
          activeColor: PelevoColors.green,
          title: Text(option.$2),
          subtitle: Text(option.$3),
          onChanged: (value) => setState(() => _queueChoice = value ?? 1),
        ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Confirm',
        color: PelevoColors.green,
        onPressed: _busy ? null : () => _confirmQueue(episode),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.pelevoBack(fallback: '/screen/podcast-details'),
      ),
    ],
  );

  Widget _sharePodcast(BuildContext context, CatalogShow show) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        color: context.pelevo.surface,
        child: ListTile(
          leading: _cover(show, 56),
          title: Text(show.title),
          subtitle: Text(show.categoryLabel),
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _shareAction(
            context,
            'Copy Link',
            Icons.link_rounded,
            () => _copyShowLink(show),
          ),
          _shareAction(
            context,
            'WhatsApp',
            Icons.chat_rounded,
            () => context.go('/screen/share-card-preview'),
          ),
          _shareAction(
            context,
            'Instagram',
            Icons.camera_alt_outlined,
            () => context.go('/screen/share-card-preview'),
          ),
          _shareAction(
            context,
            'Twitter',
            Icons.alternate_email_rounded,
            () => context.go('/screen/share-card-preview'),
          ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Share via...'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/share-card-preview'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('More Options'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/share-card-home'),
      ),
    ],
  );

  Widget _cover(CatalogShow show, double size) => CatalogArtwork(
    url: show.artworkUrl,
    width: size,
    height: size,
    assetPath: 'assets/podcast/honest_bunch_cover.png',
  );

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.all(PelevoSpacing.xs),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: context.pelevo.surfaceHigh,
                child: Icon(icon, color: context.pelevo.text),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _shareAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
      child: Column(
        children: [
          IconButton.filledTonal(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  List<Widget> _episodeTiles(
    BuildContext context,
    CatalogShow show,
    List<CatalogEpisode> episodes, {
    bool showMenu = false,
  }) {
    final nowPlayingId = ref.watch(nowPlayingEpisodeIdProvider);
    final isPlaying = ref.watch(pelevoIsPlayingProvider).asData?.value ?? false;
    final currentId = nowPlayingId;
    final listening = isPlaying && currentId != null && currentId.isNotEmpty;
    final nowPlaying = ref.watch(nowPlayingEpisodeProvider);
    final visible = [
      for (final episode in episodes)
        episode.overlayLivePlayback(nowPlaying: nowPlaying),
    ];

    return [
      for (final episode in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
          child: Material(
            color:
                currentId == episode.id
                    ? PelevoColors.green.withValues(alpha: .08)
                    : Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap:
                      () => openCatalogEpisodeDetails(
                        context,
                        episodeId: episode.id,
                        showId: show.id,
                      ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EpisodeListArtwork(
                        url: episode.artworkUrl ?? show.artworkUrl,
                        isCurrent: currentId == episode.id && listening,
                        completed:
                            episode.completed &&
                            !(currentId == episode.id && listening),
                      ),
                      const SizedBox(width: PelevoSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    currentId == episode.id
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                height: 1.25,
                                color:
                                    currentId == episode.id && listening
                                        ? PelevoColors.green
                                        : episode.completed
                                        ? context.pelevo.textMuted
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _episodeListSubtitle(
                                show,
                                episode,
                                currentId == episode.id,
                                listening,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    currentId == episode.id && listening
                                        ? PelevoColors.green
                                        : context.pelevo.textMuted,
                                fontWeight:
                                    currentId == episode.id
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip:
                          currentId == episode.id && listening
                              ? 'Now playing ${episode.title}'
                              : episode.completed
                              ? 'Play ${episode.title} again'
                              : currentId == episode.id
                              ? 'Resume ${episode.title}'
                              : episode.positionSeconds > 0
                              ? 'Continue ${episode.title}'
                              : 'Play ${episode.title}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        playCatalogEpisode(
                          context,
                          episodeId: episode.id,
                          showId: show.id,
                          positionSeconds:
                              episode.completed
                                  ? null
                                  : episode.positionSeconds,
                          restart: episode.completed,
                        );
                      },
                      icon: Icon(
                        currentId == episode.id && listening
                            ? Icons.equalizer_rounded
                            : episode.completed
                            ? Icons.replay_rounded
                            : episode.positionSeconds > 0
                            ? Icons.play_circle_outline_rounded
                            : Icons.play_circle_fill_rounded,
                        color:
                            currentId == episode.id && listening
                                ? PelevoColors.green
                                : null,
                      ),
                    ),
                    GestureDetector(
                      onLongPress:
                          _busy
                              ? null
                              : () => enqueueCatalogEpisode(
                                context,
                                episodeId: episode.id,
                                playNext: true,
                              ),
                      child: IconButton(
                        tooltip:
                            'Add ${episode.title} to queue. Long-press to play next.',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            _busy
                                ? null
                                : () => enqueueCatalogEpisode(
                                  context,
                                  episodeId: episode.id,
                                ),
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                    ),
                    if (showMenu)
                      IconButton(
                        tooltip: 'Episode options',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            () =>
                                _episodeQuickActions(context, show, episode),
                        icon: const Icon(Icons.more_vert_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  String _episodeListSubtitle(
    CatalogShow show,
    CatalogEpisode episode,
    bool isCurrent,
    bool listening,
  ) {
    final meta = episode.subtitle.isEmpty ? show.title : episode.subtitle;
    if (isCurrent && listening) {
      return 'Now playing · $meta';
    }
    if (episode.completed) return 'Completed · $meta';
    if (isCurrent) return 'Paused · $meta';
    if (episode.positionSeconds > 0) return 'Continue · $meta';
    return meta;
  }

  String _episodePlayLabel(CatalogEpisode episode) {
    if (episode.completed) return 'Play Again';
    if (episode.positionSeconds > 0) return 'Continue';
    return 'Play Episode';
  }

  Future<void> _playLatest(CatalogShow show) async {
    final episodes = ref.read(catalogEpisodesProvider).asData?.value.items;
    if (episodes == null || episodes.isEmpty) {
      context.showPelevoMessage(
        show.episodesSyncing
            ? 'Episodes are still syncing. Try again in a moment.'
            : 'No episodes are published yet.',
      );
      return;
    }
    playCatalogEpisode(
      context,
      episodeId: episodes.first.id,
      showId: show.id,
    );
  }

  Future<void> _toggleFollow(CatalogShow show) async {
    setState(() => _busy = true);
    try {
      final next = !show.following;
      await ref
          .read(catalogRepositoryProvider)
          .follow(show.id, following: next);
      ref.invalidate(catalogShowProvider);
      ref.invalidate(libraryShowsProvider);
      ref.invalidate(libraryOverviewProvider);
      await ref.read(catalogEpisodesProvider.notifier).refreshFirstPage();
      if (!mounted) return;
      if (next) {
        _watchEpisodeSync(show.copyWith(episodesSyncing: true));
      }
      context.showPelevoMessage(
        next ? '${show.title} followed' : '${show.title} unfollowed',
      );
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _followRelated(CatalogRelatedShow show) async {
    setState(() => _busy = true);
    try {
      await ref.read(catalogRepositoryProvider).follow(show.id, following: true);
      ref.invalidate(catalogRelatedProvider);
      ref.invalidate(libraryShowsProvider);
      ref.invalidate(libraryOverviewProvider);
      if (!mounted) return;
      context.showPelevoMessage('${show.title} followed');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSession(CatalogEpisode episode, CatalogShow show) async {
    setState(() => _busy = true);
    try {
      final session = await ref.read(catalogPlayerSessionProvider.future);
      final next = await ref
          .read(catalogRepositoryProvider)
          .savePlayerSession(
            episodeId: episode.id,
            playing: !session.playing,
            playbackRate: session.playbackRate,
            version: session.version,
          );
      ref.invalidate(catalogPlayerSessionProvider);
      if (!mounted) return;
      setState(() => _playing = next.playing);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmQueue(CatalogEpisode episode) async {
    setState(() => _busy = true);
    try {
      if (_queueChoice == 2) {
        await pickPlaylistForEpisode(
          context: context,
          ref: ref,
          episodeId: episode.id,
        );
        return;
      }
      await ref
          .read(catalogRepositoryProvider)
          .enqueueEpisode(episode.id, playNext: _queueChoice == 0);
      ref.invalidate(catalogQueueProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        _queueChoice == 0 ? 'Will play next' : 'Added to queue',
      );
      context.pelevoBack(fallback: '/screen/podcast-details');
    } catch (error) {
      if (!mounted) return;
      final failure = catalogFailure(error);
      if (failure.code != 'CANCELLED') {
        context.showPelevoMessage(failure.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queueShowEpisode(
    BuildContext context, {
    bool playNext = false,
  }) async {
    final items =
        ref.read(catalogEpisodesProvider).asData?.value.items ??
        const <CatalogEpisode>[];
    final selectedId = ref.read(selectedEpisodeIdProvider);
    final match = items.where((item) => item.id == selectedId);
    final episodeId =
        (match.isNotEmpty ? match.first.id : null) ??
        (items.isNotEmpty ? items.first.id : null);
    if (episodeId == null) {
      if (context.mounted) {
        context.showPelevoMessage('No episodes to add yet.');
      }
      return;
    }
    await enqueueCatalogEpisode(
      context,
      episodeId: episodeId,
      playNext: playNext,
    );
  }

  Future<void> _episodeQuickActions(
    BuildContext context,
    CatalogShow show,
    CatalogEpisode episode,
  ) {
    return showPelevoSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Add to queue'),
            onTap: () {
              Navigator.pop(sheetContext);
              enqueueCatalogEpisode(context, episodeId: episode.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: const Text('Play next'),
            onTap: () {
              Navigator.pop(sheetContext);
              enqueueCatalogEpisode(
                context,
                episodeId: episode.id,
                playNext: true,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Episode details'),
            onTap: () {
              Navigator.pop(sheetContext);
              openCatalogEpisodeDetails(
                context,
                episodeId: episode.id,
                showId: show.id,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _copyShowLink(CatalogShow show) async {
    await Clipboard.setData(
      ClipboardData(text: catalogShareShowLink(show.id)),
    );
    if (!mounted) return;
    context.showPelevoMessage('Link copied');
  }

  Future<void> _showActions(BuildContext context) {
    final show = ref.read(catalogShowProvider).asData?.value;
    if (show == null) return Future.value();
    return showPelevoSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About podcast'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/screen/podcast-about');
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share podcast'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/screen/podcast-loading');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add latest episode to queue'),
              onTap: () {
                Navigator.pop(sheetContext);
                _queueShowEpisode(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.podcasts_rounded),
              title: const Text('Similar podcasts'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/screen/podcast-related');
              },
            ),
          ],
        ),
    );
  }

  Future<void> _writeReview(BuildContext context, CatalogShow show) =>
      showDialog<void>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                final ratingLabel =
                    '$_reviewRating star${_reviewRating == 1 ? '' : 's'}';
                return AlertDialog(
                  title: Text('Rate ${show.title}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var rating = 1; rating <= 5; rating++)
                            IconButton(
                              tooltip: '$rating star${rating == 1 ? '' : 's'}',
                              onPressed:
                                  () => setDialogState(
                                    () => _reviewRating = rating,
                                  ),
                              icon: Icon(
                                rating <= _reviewRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: PelevoColors.yellow,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                          color: PelevoColors.yellow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      TextField(
                        controller: _reviewBody,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Share what you think',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(catalogRepositoryProvider)
                              .review(
                                show.id,
                                rating: _reviewRating,
                                body: _reviewBody.text.trim(),
                              );
                          _reviewBody.clear();
                          ref.invalidate(catalogReviewsProvider);
                          ref.invalidate(catalogShowProvider);
                          if (!context.mounted) return;
                          context.showPelevoMessage('Review published');
                        } catch (error) {
                          if (!context.mounted) return;
                          context.showPelevoMessage(
                            catalogFailure(error).message,
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                );
              },
            ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
    ),
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _EpisodeListArtwork extends StatelessWidget {
  const _EpisodeListArtwork({
    required this.url,
    required this.isCurrent,
    required this.completed,
  });

  final String? url;
  final bool isCurrent;
  final bool completed;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CatalogArtwork(
        url: url,
        width: 54,
        height: 54,
        assetPath: 'assets/podcast/episode_124.png',
      ),
      if (isCurrent)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.equalizer_rounded,
              color: PelevoColors.green,
            ),
          ),
        )
      else if (completed)
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: PelevoColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.check, size: 11, color: Colors.white),
          ),
        ),
    ],
  );
}
