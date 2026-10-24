import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:pelevo/features/downloads/download_gate.dart';
import 'package:pelevo/features/downloads/download_hero.dart';
import 'package:pelevo/features/library/playlist_picker.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';
import 'package:pelevo/features/player/playback_preferences.dart';
import 'package:pelevo/features/player/sleep_timer.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _EpisodeView {
  overview,
  about,
  chapters,
  transcript,
  reviews,
  notes,
  download,
  queue,
  share,
  options,
  sleepTimer,
  playbackSpeed,
}

const _episodeInventory =
    <({String id, String title, String state, _EpisodeView view})>[
      (
        id: 'episode-details',
        title: 'Ep. 124 - The Shift Life',
        state: 'Episode overview',
        view: _EpisodeView.overview,
      ),
      (
        id: 'episode-description',
        title: 'About This Episode',
        state: 'Expanded episode info',
        view: _EpisodeView.about,
      ),
      (
        id: 'episode-chapters',
        title: 'Chapters',
        state: 'Chapter list',
        view: _EpisodeView.chapters,
      ),
      (
        id: 'episode-transcript',
        title: 'Transcript',
        state: 'Synced transcript',
        view: _EpisodeView.transcript,
      ),
      (
        id: 'episode-transcript-search',
        title: 'Reviews & Ratings',
        state: 'Episode reviews',
        view: _EpisodeView.reviews,
      ),
      (
        id: 'episode-notes',
        title: 'Take Notes',
        state: 'Episode notes',
        view: _EpisodeView.notes,
      ),
      (
        id: 'episode-download',
        title: 'Downloads',
        state: 'Download quality',
        view: _EpisodeView.download,
      ),
      (
        id: 'episode-queued',
        title: 'Add to Queue',
        state: 'Queue options',
        view: _EpisodeView.queue,
      ),
      (
        id: 'episode-share',
        title: 'Share Episode',
        state: 'Share options',
        view: _EpisodeView.share,
      ),
      (
        id: 'episode-unavailable',
        title: 'Episode Options',
        state: 'More actions',
        view: _EpisodeView.options,
      ),
      (
        id: 'episode-sleep-timer',
        title: 'Sleep Timer',
        state: 'Timer options',
        view: _EpisodeView.sleepTimer,
      ),
      (
        id: 'episode-playing',
        title: 'Playback Speed',
        state: 'Speed options',
        view: _EpisodeView.playbackSpeed,
      ),
    ];

final List<PelevoScreenSpec> episodeScreens = List.unmodifiable(
  _episodeInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Episode Details',
      title: item.title,
      state: item.state,
      builder: (_) => _EpisodeScreen(view: item.view, title: item.title),
    ),
  ),
);

class _EpisodeScreen extends ConsumerStatefulWidget {
  const _EpisodeScreen({required this.view, required this.title});

  final _EpisodeView view;
  final String title;

  @override
  ConsumerState<_EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends ConsumerState<_EpisodeScreen> {
  bool _busy = false;
  int _nav = 1;
  int _queueChoice = 1;
  int _timerChoice = 1;
  int _reviewFilter = 0;
  double _speed = 1;
  String _quality = 'High (128 kbps)';
  double? _downloadProgress;
  bool? _alreadyDownloaded;
  final _transcriptQuery = TextEditingController();
  final _noteController = TextEditingController();
  final int _reviewRating = 5;
  final _reviewBody = TextEditingController();

  bool get _isSheet => const {
    _EpisodeView.queue,
    _EpisodeView.share,
    _EpisodeView.options,
    _EpisodeView.sleepTimer,
    _EpisodeView.playbackSpeed,
  }.contains(widget.view);

  bool get _showChrome => !_isSheet;

  @override
  void dispose() {
    _transcriptQuery.dispose();
    _noteController.dispose();
    _reviewBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(catalogEpisodeProvider).asData?.value;
    return PelevoPage(
      scrollable: true,
      padding:
          _isSheet
              ? const EdgeInsets.fromLTRB(
                PelevoSpacing.page,
                PelevoSpacing.md,
                PelevoSpacing.page,
                PelevoSpacing.lg,
              )
              : const EdgeInsets.symmetric(horizontal: PelevoSpacing.page),
      appBar:
          _isSheet
              ? null
              : AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    if (widget.view == _EpisodeView.overview) {
                      context.pelevoBack(fallback: '/screen/podcast-details');
                    } else {
                      context.pelevoBack(fallback: '/screen/episode-details');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(
                  widget.view == _EpisodeView.overview
                      ? (episode?.title ?? widget.title)
                      : widget.title,
                ),
                actions: [
                  if (widget.view == _EpisodeView.overview)
                    IconButton(
                      tooltip: 'Episode options',
                      onPressed:
                          () => context.go('/screen/episode-unavailable'),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  if (widget.view == _EpisodeView.download)
                    IconButton(
                      tooltip: 'Download settings',
                      onPressed: () => context.go('/screen/downloads-4'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                ],
              ),
      bottomNavigationBar: _showChrome ? _bottomChrome(context, episode) : null,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final episodeId = ref.watch(selectedEpisodeIdProvider);
    if (episodeId == null || episodeId.isEmpty) {
      return CatalogStatusBody(
        error: missingCatalogEpisode,
        retry: () => context.go('/screen/podcast-episodes'),
      );
    }
    final episodeAsync = ref.watch(catalogEpisodeProvider);
    if (episodeAsync.isLoading) return const CatalogStatusBody();
    if (episodeAsync.hasError) {
      return CatalogStatusBody(
        error: episodeAsync.error,
        retry: () => ref.invalidate(catalogEpisodeProvider),
      );
    }
    final episode = episodeAsync.requireValue.overlayLivePlayback(
      nowPlaying: ref.watch(nowPlayingEpisodeProvider),
    );
    if (ref.read(selectedShowIdProvider) != episode.showId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedShowIdProvider.notifier).select(episode.showId);
      });
    }
    return switch (widget.view) {
      _EpisodeView.overview => _overview(context, episode),
      _EpisodeView.about => _about(context, episode),
      _EpisodeView.chapters => _chaptersView(context, episode),
      _EpisodeView.transcript => _transcriptView(context),
      _EpisodeView.reviews => _reviewsView(context, episode),
      _EpisodeView.notes => _notesView(context, episode),
      _EpisodeView.download => _downloadView(context, episode),
      _EpisodeView.queue => _queueSheet(context, episode),
      _EpisodeView.share => _shareSheet(context, episode),
      _EpisodeView.options => _optionsSheet(context, episode),
      _EpisodeView.sleepTimer => _sleepSheet(context),
      _EpisodeView.playbackSpeed => _speedSheet(context, episode),
    };
  }

  Widget _bottomChrome(BuildContext context, CatalogEpisode? episode) =>
      PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      );

  Widget _overview(BuildContext context, CatalogEpisode episode) {
    final show = ref.watch(catalogShowProvider).asData?.value;
    final description = episode.description ?? '';
    final preview =
        description.length > 140
            ? '${description.substring(0, 140).trim()} '
            : description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: PelevoSpacing.sm),
        CatalogArtwork(
          url: episode.artworkUrl,
          width: 220,
          height: 220,
          radius: PelevoRadii.large,
          assetPath: 'assets/episode/episode_cover.png',
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          episode.showTitle ?? show?.title ?? '',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          episode.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                episode.subtitle.isEmpty ? 'Podcast' : '${episode.subtitle} · ',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.pelevo.textMuted),
              ),
            ),
            Icon(
              Icons.headphones_rounded,
              size: 14,
              color: context.pelevo.textMuted,
            ),
            Text(
              ' Podcast',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
          ],
        ),
        if (episode.completed) ...[
          const SizedBox(height: PelevoSpacing.xs),
          const Text(
            'Completed',
            style: TextStyle(
              color: PelevoColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: episode.completed
              ? 'Play Again'
              : episode.positionSeconds > 0
              ? 'Continue'
              : 'Play Episode',
          color: PelevoColors.green,
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            playCatalogEpisode(
              context,
              episodeId: episode.id,
              showId: episode.showId,
              positionSeconds:
                  episode.completed ? null : episode.positionSeconds,
              restart: episode.completed,
            );
          },
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                Icons.download_outlined,
                'Download',
                () => context.go('/screen/episode-download'),
              ),
            ),
            Expanded(
              child: _quickAction(
                Icons.playlist_add_rounded,
                'Add to Queue',
                _busy
                    ? () {}
                    : () => enqueueCatalogEpisode(
                      context,
                      episodeId: episode.id,
                    ),
              ),
            ),
            Expanded(
              child: _quickAction(
                Icons.ios_share_rounded,
                'Share',
                () => context.go('/screen/episode-share'),
              ),
            ),
            Expanded(
              child: _quickAction(
                Icons.more_horiz_rounded,
                'More',
                () => context.go('/screen/episode-unavailable'),
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Description',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              style: TextStyle(color: context.pelevo.textMuted, height: 1.4),
              children: [
                TextSpan(
                  text:
                      description.isEmpty
                          ? 'No description is available. '
                          : preview,
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => context.go('/screen/episode-description'),
                    child: const Text(
                      'more',
                      style: TextStyle(
                        color: PelevoColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        _linkTile(
          Icons.info_outline_rounded,
          'About this episode',
          'Summary, host, and categories',
          () => context.go('/screen/episode-description'),
        ),
        _linkTile(
          Icons.list_rounded,
          'Chapters',
          'Jump to a section',
          () => context.go('/screen/episode-chapters'),
        ),
        _linkTile(
          Icons.notes_rounded,
          'Transcript',
          'Read along while you listen',
          () => context.go('/screen/episode-transcript'),
        ),
        _linkTile(
          Icons.chat_bubble_outline_rounded,
          'Comments',
          'Community replies',
          () => context.go('/screen/episode-comments'),
        ),
        _linkTile(
          Icons.star_border_rounded,
          'Reviews & Ratings',
          show?.ratingLine ?? 'Show reviews',
          () => context.go('/screen/episode-transcript-search'),
        ),
        _linkTile(
          Icons.edit_note_rounded,
          'Notes',
          'Capture thoughts while you listen',
          () => context.go('/screen/episode-notes'),
        ),
        _linkTile(
          Icons.bedtime_outlined,
          'Sleep Timer',
          'Set a timer on this device',
          () => context.go('/screen/episode-sleep-timer'),
        ),
        _linkTile(
          Icons.speed_rounded,
          'Playback Speed',
          '${_speed.toStringAsFixed(_speed % 1 == 0 ? 1 : 2)}x',
          () => context.go('/screen/episode-playing'),
        ),
      ],
    );
  }

  Widget _about(BuildContext context, CatalogEpisode episode) {
    final show = ref.watch(catalogShowProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CatalogArtwork(
              url: episode.artworkUrl,
              width: 72,
              height: 72,
              assetPath: 'assets/episode/episode_thumb.png',
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
                    episode.showTitle ?? show?.title ?? '',
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.subtitle.isEmpty
                        ? 'Podcast'
                        : '${episode.subtitle} · Podcast',
                    style: TextStyle(
                      color: context.pelevo.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          episode.description == null || episode.description!.isEmpty
              ? 'No description is available.'
              : episode.description!,
          style: TextStyle(color: context.pelevo.textMuted, height: 1.45),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        const Text(
          'In this episode:',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          episode.description == null || episode.description!.isEmpty
              ? 'No additional episode outline is available.'
              : episode.description!,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Divider(color: context.pelevo.border),
        const SizedBox(height: PelevoSpacing.md),
        const Text('Host', style: TextStyle(fontWeight: FontWeight.w700)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CatalogArtwork(
            url: episode.artworkUrl ?? show?.artworkUrl,
            width: 48,
            height: 48,
            radius: 24,
            assetPath: 'assets/episode/host_avatar.png',
          ),
          title: Text(episode.showAuthor ?? show?.host ?? episode.showTitle ?? ''),
          subtitle: const Text('Podcast Host'),
          onTap: () {
            openCatalogShow(context, episode.showId);
            context.push('/screen/podcast-details');
          },
        ),
        const SizedBox(height: PelevoSpacing.sm),
        const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: PelevoSpacing.xs),
        if (show == null || show.categories.isEmpty)
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
      ],
    );
  }

  Widget _chaptersView(BuildContext context, CatalogEpisode episode) {
    final chaptersAsync = ref.watch(catalogChaptersProvider);
    if (chaptersAsync.isLoading) return const CatalogStatusBody();
    if (chaptersAsync.hasError) {
      return CatalogStatusBody(
        error: chaptersAsync.error,
        retry: () => ref.invalidate(catalogChaptersProvider),
      );
    }
    final chapters = chaptersAsync.requireValue;
    if (chapters.isEmpty) {
      return Text(
        'No chapters are available.',
        style: TextStyle(color: context.pelevo.textMuted),
      );
    }
    return Column(
      children: [
        for (final chapter in chapters)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              child: Text(
                chapter.timestamp,
                style: const TextStyle(
                  color: PelevoColors.yellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(chapter.title),
            trailing: IconButton(
              tooltip: 'Play ${chapter.title}',
              onPressed: () => playCatalogEpisode(
                context,
                episodeId: episode.id,
                showId: episode.showId,
              ),
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
            onTap: () => playCatalogEpisode(
              context,
              episodeId: episode.id,
              showId: episode.showId,
            ),
          ),
      ],
    );
  }

  Widget _transcriptView(BuildContext context) {
    final transcriptAsync = ref.watch(catalogTranscriptProvider);
    if (transcriptAsync.isLoading) return const CatalogStatusBody();
    if (transcriptAsync.hasError) {
      return CatalogStatusBody(
        error: transcriptAsync.error,
        retry: () => ref.invalidate(catalogTranscriptProvider),
      );
    }
    final content = transcriptAsync.requireValue;
    final query = _transcriptQuery.text.trim().toLowerCase();
    final visible =
        query.isEmpty || content.toLowerCase().contains(query) ? content : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _transcriptQuery,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search in transcript',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (content.isEmpty)
          Text(
            'No transcript is available.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else if (visible.isEmpty)
          Text(
            'No transcript lines match that search.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          Text(
            visible,
            style: TextStyle(color: context.pelevo.textMuted, height: 1.4),
          ),
      ],
    );
  }

  Widget _reviewsView(BuildContext context, CatalogEpisode episode) {
    final show = ref.watch(catalogShowProvider).asData?.value;
    final reviewsAsync = ref.watch(catalogReviewsProvider);
    final bars =
        reviewsAsync.hasValue
            ? catalogRatingBars(reviewsAsync.requireValue)
            : const [0.0, 0.0, 0.0, 0.0, 0.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(
                  show?.ratingAverage == null || show!.ratingAverage!.isEmpty
                      ? '—'
                      : show.ratingAverage!,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                Text(
                  'out of 5',
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '(${show?.ratingCount ?? 0} Ratings)',
                  style: TextStyle(
                    color: context.pelevo.textDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: PelevoSpacing.lg),
            Expanded(
              child: Column(
                children: [
                  for (final entry in bars.asMap().entries)
                    _RatingBar(label: '${5 - entry.key}', value: entry.value),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Write a Review',
          outlined: true,
          color: PelevoColors.green,
          onPressed:
              _busy ? null : () => _writeReview(context, episode.showId),
        ),
        const SizedBox(height: PelevoSpacing.md),
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
              child: Padding(
                padding: const EdgeInsets.all(PelevoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.reviewerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          review.createdAt.toIso8601String().split('T').first,
                          style: TextStyle(
                            color: context.pelevo.textDim,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (var i = 0; i < review.rating; i++)
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: PelevoColors.yellow,
                          ),
                      ],
                    ),
                    if (review.body != null && review.body!.isNotEmpty) ...[
                      const SizedBox(height: PelevoSpacing.xs),
                      Text(
                        review.body!,
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _notesView(BuildContext context, CatalogEpisode episode) {
    final notesAsync = ref.watch(catalogNotesProvider);
    if (notesAsync.isLoading) return const CatalogStatusBody();
    if (notesAsync.hasError) {
      return CatalogStatusBody(
        error: notesAsync.error,
        retry: () => ref.invalidate(catalogNotesProvider),
      );
    }
    final note = notesAsync.requireValue;
    final hasBody = note.body != null && note.body!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: PelevoSpacing.lg),
        Image.asset(
          'assets/episode/notes_hero.png',
          width: 120,
          height: 110,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text('Take Notes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          'Capture your thoughts while you listen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: hasBody ? 'Edit Note' : 'Add Note',
          color: PelevoColors.green,
          onPressed: _busy ? null : () => _editNote(context, episode, note),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        const Align(
          alignment: Alignment.centerLeft,
          child: PelevoSectionHeader(title: 'Your Notes'),
        ),
        if (!hasBody)
          Text(
            'No notes are saved for this episode.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          Card(
            color: context.pelevo.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: ListTile(
              title: Text(note.body!),
              subtitle: Text(
                note.positionSeconds == null
                    ? 'Saved'
                    : formatCatalogClock(note.positionSeconds!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _downloadView(BuildContext context, CatalogEpisode episode) {
    _ensureDownloadStatus(episode.id);
    final done = _alreadyDownloaded == true;
    final progress = _downloadProgress;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        DownloadHeroBadge(complete: done),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          done ? 'Downloaded' : 'Download Episode',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          done
              ? 'This episode is saved for offline listening on this device.'
              : 'Authorize and save this episode to offline storage on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(PelevoSpacing.md),
          decoration: BoxDecoration(
            color: context.pelevo.surface,
            borderRadius: BorderRadius.circular(PelevoRadii.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quality',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: PelevoSpacing.xs),
              DropdownButtonFormField<String>(
                value: _quality,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: PelevoColors.green.withValues(alpha: 0.7),
                    ),
                    borderRadius: BorderRadius.circular(PelevoRadii.small),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: PelevoColors.green),
                    borderRadius: BorderRadius.circular(PelevoRadii.small),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'High (128 kbps)',
                    child: Text('High (128 kbps)'),
                  ),
                  DropdownMenuItem(
                    value: 'Standard (96 kbps)',
                    child: Text('Standard (96 kbps)'),
                  ),
                  DropdownMenuItem(
                    value: 'Data saver (64 kbps)',
                    child: Text('Data saver (64 kbps)'),
                  ),
                ],
                onChanged:
                    _busy
                        ? null
                        : (value) {
                          if (value != null) setState(() => _quality = value);
                        },
              ),
              if (progress != null) ...[
                const SizedBox(height: PelevoSpacing.md),
                LinearProgressIndicator(
                  value: progress <= 0 || progress > 1 ? null : progress,
                  color: PelevoColors.green,
                  backgroundColor: context.pelevo.border,
                ),
                const SizedBox(height: PelevoSpacing.xs),
                Text(
                  progress > 0 && progress <= 1
                      ? 'Downloading ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                      : 'Downloading…',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: PelevoSpacing.md),
              PelevoButton(
                label:
                    done
                        ? 'Download Again'
                        : progress != null
                        ? 'Downloading…'
                        : 'Authorize Download',
                color: PelevoColors.green,
                icon: done
                    ? Icons.offline_pin_rounded
                    : Icons.cloud_download_rounded,
                onPressed: _busy ? null : () => _authorizeDownload(episode),
              ),
              if (done) ...[
                const SizedBox(height: PelevoSpacing.sm),
                PelevoButton(
                  label: 'Remove Offline Copy',
                  outlined: true,
                  color: PelevoColors.red,
                  onPressed: _busy ? null : () => _removeLocalDownload(episode),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _queueSheet(BuildContext context, CatalogEpisode episode) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: context.pelevo.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/episode/queue_hero.png',
        width: 96,
        height: 96,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.md),
      Text('Add to Queue', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.xs),
      Text(
        'Play this episode next or add it to your queue.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
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
          secondary:
              option.$1 == 2 ? const Icon(Icons.chevron_right_rounded) : null,
          onChanged:
              _busy ? null : (value) => setState(() => _queueChoice = value ?? 1),
        ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Confirm',
        color: PelevoColors.green,
        onPressed: _busy ? null : () => _selectQueue(episode, _queueChoice),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/episode-details'),
      ),
    ],
  );

  Widget _shareSheet(BuildContext context, CatalogEpisode episode) => Column(
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
      Card(
        color: context.pelevo.surface,
        child: ListTile(
          leading: CatalogArtwork(
            url: episode.artworkUrl,
            width: 52,
            height: 52,
            assetPath: 'assets/episode/share_thumb.png',
          ),
          title: Text(episode.title),
          subtitle: Text(episode.showTitle ?? ''),
        ),
      ),
      const SizedBox(height: PelevoSpacing.md),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: PelevoColors.greenDark,
          child: Text('P', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        title: const Text('Listen on Pelevo'),
        subtitle: Text(catalogShareEpisodeLink(episode.id)),
        onTap: () => _copyEpisodeLink(episode),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _shareAction(
            context,
            'Copy Link',
            Icons.link_rounded,
            PelevoColors.orange,
            () => _copyEpisodeLink(episode),
          ),
          _shareAction(
            context,
            'WhatsApp',
            Icons.chat_rounded,
            PelevoColors.green,
            () => context.go('/screen/share-card-preview'),
          ),
          _shareAction(
            context,
            'Instagram',
            Icons.camera_alt_outlined,
            const Color(0xFFC13584),
            () => context.go('/screen/share-card-preview'),
          ),
          _shareAction(
            context,
            'Twitter',
            Icons.alternate_email_rounded,
            PelevoColors.blue,
            () => context.go('/screen/share-card-preview'),
          ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.lg),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('More Options'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/screen/share-card-preview'),
      ),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/episode-details'),
      ),
    ],
  );

  Widget _optionsSheet(BuildContext context, CatalogEpisode episode) => Column(
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
      Text(
        'Episode Options',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.md),
      _optionTile(
        Icons.cloud_download_rounded,
        'Download',
        'Save for offline listening',
        () => context.go('/screen/episode-download'),
      ),
      _optionTile(
        Icons.playlist_add_rounded,
        'Add to Queue',
        'Play later in your queue',
        _busy
            ? () {}
            : () => enqueueCatalogEpisode(context, episodeId: episode.id),
      ),
      _optionTile(
        Icons.playlist_play_rounded,
        'Play Next',
        'Play this episode after the current one',
        _busy
            ? () {}
            : () => enqueueCatalogEpisode(
              context,
              episodeId: episode.id,
              playNext: true,
            ),
      ),
      _optionTile(
        Icons.playlist_play_rounded,
        'Add to Playlist',
        'Save to one of your playlists',
        _busy
            ? () {}
            : () async {
              setState(() => _busy = true);
              try {
                await pickPlaylistForEpisode(
                  context: context,
                  ref: ref,
                  episodeId: episode.id,
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      ),
      _optionTile(
        Icons.chat_bubble_outline_rounded,
        'Comments',
        'Join the conversation',
        () => context.go('/screen/episode-comments'),
      ),
      _optionTile(
        Icons.ios_share_rounded,
        'Share Episode',
        'Send this episode to friends',
        () => context.go('/screen/episode-share'),
      ),
      _optionTile(
        Icons.podcasts_rounded,
        'Go to Show',
        episode.showTitle == null || episode.showTitle!.isEmpty
            ? 'Open this show'
            : 'Open ${episode.showTitle}',
        () {
          openCatalogShow(context, episode.showId);
          context.go('/screen/podcast-details');
        },
      ),
      _optionTile(
        Icons.flag_outlined,
        'Report Episode',
        'Flag an issue with this episode',
        _busy ? () {} : () => _reportEpisode(episode),
      ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/episode-details'),
      ),
    ],
  );

  Widget _sleepSheet(BuildContext context) => Column(
    children: [
      Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: context.pelevo.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/episode/sleep_hero.png',
        width: 96,
        height: 90,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.md),
      Text('Sleep Timer', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.xs),
      Text(
        'Playback pauses on this device when the timer ends.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (final option in const [
        (0, '15 minutes'),
        (1, '30 minutes'),
        (2, '45 minutes'),
        (3, '1 hour'),
        (4, 'End of Episode'),
      ])
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: option.$1,
          groupValue: _timerChoice,
          activeColor: PelevoColors.green,
          title: Text(option.$2),
          onChanged: (value) => setState(() => _timerChoice = value ?? 1),
        ),
      PelevoButton(
        label: 'Start Timer',
        color: PelevoColors.green,
        onPressed: () {
          final choice = switch (_timerChoice) {
            0 => '15 min',
            1 => '30 min',
            2 => '45 min',
            3 => '1 hour',
            _ => 'End of episode',
          };
          ref.read(sleepTimerProvider.notifier).select(choice);
          context.showPelevoMessage(
            'Sleep timer set. Playback will pause when it ends.',
          );
          context.go('/screen/player-sleep');
        },
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/episode-details'),
      ),
    ],
  );

  Widget _speedSheet(BuildContext context, CatalogEpisode episode) => Column(
    children: [
      Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: context.pelevo.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/episode/speed_hero.png',
        width: 140,
        height: 110,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.md),
      Text('Playback Speed', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.xs),
      Text(
        'Adjust playback speed to your preference.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Wrap(
        spacing: PelevoSpacing.xs,
        runSpacing: PelevoSpacing.xs,
        alignment: WrapAlignment.center,
        children: [
          for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
            ChoiceChip(
              label: Text('${speed.toStringAsFixed(speed % 1 == 0 ? 1 : 2)}x'),
              selected: _speed == speed,
              selectedColor: PelevoColors.green,
              side: BorderSide(
                color:
                    _speed == speed ? PelevoColors.yellow : context.pelevo.border,
              ),
              onSelected:
                  _busy ? null : (_) => _setSpeed(episode, speed),
            ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Done',
        color: PelevoColors.green,
        onPressed: () => context.pelevoBack(
          fallback: '/screen/player-now-playing',
        ),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/episode-details'),
      ),
    ],
  );

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.all(PelevoSpacing.xs),
          child: Column(
            children: [
              Icon(icon, color: context.pelevo.text),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  Widget _linkTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: PelevoColors.green),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Widget _optionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: context.pelevo.text),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
  );

  Widget _shareAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: .55)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
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

  Future<void> _selectQueue(CatalogEpisode episode, int value) async {
    setState(() {
      _queueChoice = value;
      _busy = true;
    });
    try {
      if (value == 2) {
        await pickPlaylistForEpisode(
          context: context,
          ref: ref,
          episodeId: episode.id,
        );
        return;
      }
      await ref
          .read(catalogRepositoryProvider)
          .enqueueEpisode(episode.id, playNext: value == 0);
      ref.invalidate(catalogQueueProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        value == 0 ? 'Will play next' : 'Added to queue',
      );
      context.pelevoBack(fallback: '/screen/episode-details');
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

  Future<void> _copyEpisodeLink(CatalogEpisode episode) async {
    await Clipboard.setData(
      ClipboardData(text: catalogShareEpisodeLink(episode.id)),
    );
    if (!mounted) return;
    context.showPelevoMessage('Link copied');
  }

  void _ensureDownloadStatus(String episodeId) {
    if (_alreadyDownloaded != null) return;
    ref.read(downloadFileServiceProvider).isDownloaded(episodeId).then((value) {
      if (!mounted) return;
      setState(() => _alreadyDownloaded = value);
    });
  }

  Future<void> _authorizeDownload(CatalogEpisode episode) async {
    setState(() => _busy = true);
    try {
      await ensureWifiAllowsDownload(
        ref,
        confirmCellular: () async {
          if (!context.mounted) return false;
          return confirmDownloadOnMobileData(context);
        },
      );
      if (!mounted) return;
      setState(() => _downloadProgress = 0);
      final url = await ref
          .read(catalogRepositoryProvider)
          .authorizeDownload(episode.id);
      final record = await ref.read(downloadFileServiceProvider).downloadEpisode(
        episodeId: episode.id,
        url: url,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _alreadyDownloaded = true;
        _downloadProgress = null;
      });
      refreshAuthorizedDownloads(ref);
      context.showPelevoMessage(
        'Saved offline (${((record.bytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB · $_quality).',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      final failure = catalogFailure(error);
      if (failure.code != 'CANCELLED') {
        context.showPelevoMessage(failure.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLocalDownload(CatalogEpisode episode) async {
    setState(() => _busy = true);
    try {
      await ref.read(downloadFileServiceProvider).deleteLocal(episode.id);
      if (!mounted) return;
      setState(() => _alreadyDownloaded = false);
      context.showPelevoMessage('Offline copy removed');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportEpisode(CatalogEpisode episode) async {
    String reason = 'Spam';
    await showPelevoSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: StatefulBuilder(
          builder: (context, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report Episode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final option in reportReasonCodes.keys)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: option,
                  groupValue: reason,
                  title: Text(option),
                  onChanged:
                      (value) => setSheet(() => reason = value ?? reason),
                ),
              PelevoButton(
                label: 'Submit report',
                color: PelevoColors.purple,
                onPressed: () async {
                  final code = reportReasonCodes[reason];
                  if (code == null) return;
                  Navigator.pop(sheetContext);
                  setState(() => _busy = true);
                  try {
                    await ref.read(catalogRepositoryProvider).reportEpisode(
                      episodeId: episode.id,
                      reason: code,
                      details: reason == 'Spoiler' ? 'Spoiler' : null,
                    );
                    if (!mounted) return;
                    this.context.showPelevoMessage('Report submitted');
                    this.context.go('/screen/episode-details');
                  } catch (error) {
                    if (!mounted) return;
                    final failure = catalogFailure(error);
                    if (failure.code != 'CANCELLED') {
                      this.context.showPelevoMessage(failure.message);
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setSpeed(CatalogEpisode episode, double speed) async {
    setState(() => _busy = true);
    try {
      final live =
          pelevoAudioHandler != null ||
          ref.read(pelevoCastControllerProvider).isConnected;
      if (live) {
        await ref
            .read(pelevoPlaybackControllerProvider)
            .setSpeed(episode, speed);
      } else {
        ref.read(playbackPreferencesProvider.notifier).setSpeed(speed);
        final session = await ref.read(catalogPlayerSessionProvider.future);
        await ref
            .read(catalogRepositoryProvider)
            .savePlayerSession(
              episodeId: episode.id,
              playing: session.playing,
              playbackRate: speed,
              version: session.version,
            );
        ref.invalidate(catalogPlayerSessionProvider);
      }
      if (!mounted) return;
      setState(() => _speed = speed);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNote(
    BuildContext context,
    CatalogEpisode episode,
    CatalogNote note,
  ) async {
    _noteController.text = note.body ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: context.pelevo.surface,
            title: const Text('New note'),
            content: TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Write your note…'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (saved != true || !mounted) return;
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      if (!context.mounted) return;
      context.showPelevoMessage('Enter a note before saving.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(catalogRepositoryProvider)
          .saveNote(episode.id, body: body, version: note.version);
      ref.invalidate(catalogNotesProvider);
    } catch (error) {
      if (!context.mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeReview(BuildContext context, String showId) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Write a review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _reviewBody,
                  autofocus: true,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Submit'),
              ),
            ],
          ),
    );
    if (submitted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(catalogRepositoryProvider)
          .review(
            showId,
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
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(width: 12, child: Text(label)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: context.pelevo.surfaceHigh,
              color: PelevoColors.yellow,
            ),
          ),
        ),
      ],
    ),
  );
}
