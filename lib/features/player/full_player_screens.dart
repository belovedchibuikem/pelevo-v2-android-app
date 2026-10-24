import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:pelevo/features/downloads/download_gate.dart';
import 'package:pelevo/features/downloads/download_hero.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/library/playlist_picker.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_sheet.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';
import 'package:pelevo/features/player/sleep_timer.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/queue/queue_reorder_list.dart';
import 'package:pelevo/features/search/search_data.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _PlayerView {
  nowPlaying,
  miniSearch,
  miniDiscover,
  sleepActive,
  speedChanged,
  casting,
  chapters,
  notes,
  queue,
  share,
  download,
  moreOptions,
}

const _playerInventory =
    <({String id, String title, String state, _PlayerView view})>[
      (
        id: 'player-now-playing',
        title: 'Now Playing',
        state: 'Full player',
        view: _PlayerView.nowPlaying,
      ),
      (
        id: 'player-paused',
        title: 'Miniplayer · Search',
        state: 'Collapsed over search',
        view: _PlayerView.miniSearch,
      ),
      (
        id: 'player-buffering',
        title: 'Miniplayer · Discover',
        state: 'Collapsed over discover',
        view: _PlayerView.miniDiscover,
      ),
      (
        id: 'player-sleep',
        title: 'Sleep Timer Active',
        state: 'Timer running',
        view: _PlayerView.sleepActive,
      ),
      (
        id: 'player-speed',
        title: 'Playback Speed',
        state: '1.5x active',
        view: _PlayerView.speedChanged,
      ),
      (
        id: 'player-device',
        title: 'Casting',
        state: 'Cast to speaker',
        view: _PlayerView.casting,
      ),
      (
        id: 'player-chapters',
        title: 'Chapters',
        state: 'Chapter list',
        view: _PlayerView.chapters,
      ),
      (
        id: 'player-transcript',
        title: 'Add Notes',
        state: 'Empty notes',
        view: _PlayerView.notes,
      ),
      (
        id: 'player-details',
        title: 'Queue',
        state: 'Up next',
        view: _PlayerView.queue,
      ),
      (
        id: 'player-video',
        title: 'Share Options',
        state: 'Share sheet',
        view: _PlayerView.share,
      ),
      (
        id: 'player-completed',
        title: 'Download Episode',
        state: 'Download quality',
        view: _PlayerView.download,
      ),
      (
        id: 'player-offline',
        title: 'More Options',
        state: 'Player menu',
        view: _PlayerView.moreOptions,
      ),
    ];

final List<PelevoScreenSpec> fullPlayerScreens = List.unmodifiable(
  _playerInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Full Player',
      title: item.title,
      state: item.state,
      builder: (_) => _PlayerScreen(view: item.view, title: item.title),
    ),
  ),
);

class _PlayerScreen extends ConsumerStatefulWidget {
  const _PlayerScreen({required this.view, required this.title});

  final _PlayerView view;
  final String title;

  @override
  ConsumerState<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<_PlayerScreen> {
  bool _playing = false;
  bool _busy = false;
  double _progress = 0;
  double _speed = 1;
  int _nav = 0;
  String _quality = 'High (320 kbps)';
  double? _downloadProgress;
  bool? _alreadyDownloaded;
  bool _progressReady = false;
  bool _autoStarted = false;
  bool _scrubbing = false;
  StreamSubscription<Duration>? _positionSub;
  String? _boundEpisodeId;

  bool get _isSheet =>
      widget.view == _PlayerView.share ||
      widget.view == _PlayerView.moreOptions;

  bool get _isFullPlayer => const {
    _PlayerView.nowPlaying,
    _PlayerView.sleepActive,
    _PlayerView.speedChanged,
    _PlayerView.casting,
  }.contains(widget.view);

  bool get _showMiniChrome => const {
    _PlayerView.miniSearch,
    _PlayerView.miniDiscover,
    _PlayerView.chapters,
    _PlayerView.notes,
    _PlayerView.queue,
    _PlayerView.download,
  }.contains(widget.view);

  @override
  void initState() {
    super.initState();
    if (widget.view == _PlayerView.speedChanged) _speed = 1.5;
    if (widget.view == _PlayerView.miniSearch ||
        widget.view == _PlayerView.miniDiscover) {
      _playing = false;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _bindPosition(PelevoAudioHandler handler, CatalogEpisode episode) {
    if (_boundEpisodeId == episode.id && _positionSub != null) return;
    _positionSub?.cancel();
    _boundEpisodeId = episode.id;
    final duration =
        episode.durationSeconds ?? handler.duration?.inSeconds ?? 0;
    void apply(Duration position) {
      if (!mounted || _scrubbing || duration <= 0) return;
      setState(() {
        _progress = (position.inSeconds / duration).clamp(0, 1);
        _playing = handler.playing;
        _progressReady = true;
      });
    }

    apply(handler.position);
    _positionSub = handler.positionStream.listen(apply);
  }

  Future<void> _ensurePlaying(CatalogEpisode episode) async {
    if (_boundEpisodeId != null && _boundEpisodeId != episode.id) {
      _autoStarted = false;
      _progressReady = false;
    }
    if (!_isFullPlayer) return;
    try {
      final cast = ref.read(pelevoCastControllerProvider).snapshot;
      if (cast.connected) {
        if (!mounted) return;
        setState(() {
          _playing = cast.playing;
          _progressReady = true;
        });
        return;
      }
      final handler = await ref.read(pelevoAudioHandlerProvider.future);
      // Same episode already loaded (playing or paused): bind UI only — never
      // reload, or pause/resume breaks and playback restarts from the seed.
      if (handler.mediaItem.value?.id == episode.id) {
        final restart =
            ref.read(playbackPlayIntentProvider) &&
            ref.read(playbackResumeHintProvider) == 0;
        ref.read(playbackPlayIntentProvider.notifier).clear();
        ref.read(playbackResumeHintProvider.notifier).clear();
        if (restart) {
          await handler.seek(Duration.zero);
          await handler.play();
        }
        if (!mounted) return;
        _bindPosition(handler, episode);
        final playing = handler.playing;
        if (!_autoStarted || _playing != playing) {
          _autoStarted = true;
          setState(() {
            _playing = playing;
            _progressReady = true;
          });
        }
        return;
      }
      if (_autoStarted) return;
      if (!ref.read(playbackPlayIntentProvider.notifier).consume()) return;
      _autoStarted = true;
      Duration? resume;
      final hintSeconds = ref.read(playbackResumeHintProvider);
      ref.read(playbackResumeHintProvider.notifier).clear();
      final restart = hintSeconds == 0;
      if (restart) {
        resume = Duration.zero;
      } else if (hintSeconds != null && hintSeconds > 0) {
        resume = Duration(seconds: hintSeconds);
      }
      if (!restart) {
        try {
          final playback = await ref.read(
            catalogPlaybackByIdProvider(episode.id).future,
          );
          if (playback.positionSeconds > 0) {
            resume = Duration(seconds: playback.positionSeconds);
          }
        } catch (_) {
          // Keep home/continue hint when playback progress is unavailable.
        }
      }
      await ref
          .read(pelevoPlaybackControllerProvider)
          .playEpisode(episode, position: resume);
      if (!mounted) return;
      _bindPosition(handler, episode);
      setState(() => _playing = handler.playing);
    } catch (error) {
      _autoStarted = false;
      if (!mounted) return;
      final failure = catalogFailure(error);
      // Provider dispose / navigation cancels in-flight GETs; not a play failure.
      if (failure.code == 'CANCELLED') return;
      context.showPelevoMessage(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedEpisodeIdProvider);
    final nowPlayingId = ref.watch(nowPlayingEpisodeIdProvider);
    final handler =
        ref.watch(pelevoAudioHandlerProvider).asData?.value ??
        pelevoAudioHandler;
    final mediaId = handler?.mediaItem.value?.id;
    final intentArmed = ref.watch(playbackPlayIntentProvider);
    final episodeId =
        (intentArmed && selectedId != null && selectedId.isNotEmpty)
            ? selectedId
            : (nowPlayingId ?? mediaId ?? selectedId);
    if (episodeId == null || episodeId.isEmpty) {
      final page = CatalogStatusBody(
        error: missingCatalogEpisode,
        retry: () => context.go('/screen/podcast-episodes'),
      );
      return _isFullPlayer
          ? Scaffold(backgroundColor: context.pelevo.background, body: page)
          : PelevoPage(appBar: AppBar(title: Text(widget.title)), child: page);
    }
    final live = ref.watch(nowPlayingEpisodeProvider);
    final episodeAsync = ref.watch(catalogEpisodeByIdProvider(episodeId));
    final episode =
        (live?.id == episodeId ? live : null) ?? episodeAsync.asData?.value;
    if (episode == null) {
      if (episodeAsync.hasError && !episodeAsync.hasValue) {
        final error = CatalogStatusBody(
          error: episodeAsync.error,
          retry: () => ref.invalidate(catalogEpisodeByIdProvider(episodeId)),
        );
        return _isFullPlayer
            ? Scaffold(backgroundColor: context.pelevo.background, body: error)
            : PelevoPage(
              appBar: AppBar(title: Text(widget.title)),
              child: error,
            );
      }
      const loading = CatalogStatusBody();
      return _isFullPlayer
          ? Scaffold(
            backgroundColor: context.pelevo.background,
            body: loading,
          )
          : PelevoPage(
            appBar: AppBar(title: Text(widget.title)),
            child: loading,
          );
    }
    final playback =
        ref.watch(catalogPlaybackByIdProvider(episodeId)).asData?.value;
    final session = ref.watch(catalogPlayerSessionProvider).asData?.value;
    final duration = episode.durationSeconds ?? 0;
    if (!_progressReady && playback != null && duration > 0 && _progress == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _progressReady) return;
        setState(() {
          _progress = (playback.positionSeconds / duration).clamp(0, 1);
          _progressReady = true;
          if (session != null) {
            _playing = session.playing;
            if (widget.view != _PlayerView.speedChanged) {
              _speed = session.playbackRate;
            }
          }
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensurePlaying(episode);
    });

    if (_isFullPlayer) {
      return _fullPlayerScaffold(context, episode, playback);
    }

    return PelevoPage(
      scrollable: widget.view != _PlayerView.queue,
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
                  onPressed:
                      () => context.pelevoBack(
                        fallback: '/screen/player-now-playing',
                      ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(widget.title),
                actions: [
                  if (widget.view == _PlayerView.queue)
                    TextButton(
                      onPressed: () => context.go('/screen/queue-multi-select'),
                      child: const Text(
                        'Edit',
                        style: TextStyle(color: PelevoColors.green),
                      ),
                    ),
                ],
              ),
      bottomNavigationBar:
          _showMiniChrome ? _bottomChrome(context, episode) : null,
      child: switch (widget.view) {
        _PlayerView.miniSearch => _miniSearch(context),
        _PlayerView.miniDiscover => _miniDiscover(context),
        _PlayerView.chapters => _chaptersView(context),
        _PlayerView.notes => _notesView(context),
        _PlayerView.queue => _queueView(context, episode),
        _PlayerView.share => _shareSheet(context, episode),
        _PlayerView.download => _downloadView(context, episode),
        _PlayerView.moreOptions => _moreOptions(context, episode, playback),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _fullPlayerScaffold(
    BuildContext context,
    CatalogEpisode episode,
    CatalogPlayback? playback,
  ) {
    final speedLabel = '${_speed.toStringAsFixed(1)}x'.replaceAll('.0x', 'x');
    final duration = episode.durationSeconds ?? 0;
    final cast = ref.watch(pelevoCastSnapshotProvider).asData?.value;
    final livePlaying =
        ref.watch(pelevoIsPlayingProvider).asData?.value ?? _playing;
    final liveSeconds = ref.watch(pelevoPositionSecondsProvider).asData?.value;
    final displayPlaying = livePlaying;
    final buffering = ref.watch(pelevoBufferingProvider);
    final displayProgress =
        !_scrubbing && duration > 0 && liveSeconds != null
            ? (liveSeconds / duration).clamp(0.0, 1.0)
            : _progress;

    return Scaffold(
      backgroundColor: context.pelevo.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A0E12), context.pelevo.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PelevoSpacing.page),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Collapse player',
                      onPressed: () => context.pelevoBack(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'PLAYING FROM',
                            style: TextStyle(
                              color: context.pelevo.textDim,
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            episode.showTitle ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'More options',
                      onPressed: () => context.go('/screen/player-offline'),
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: PelevoSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CatalogArtwork(
                          url: episode.artworkUrl,
                          width: double.infinity,
                          height: 280,
                          radius: PelevoRadii.large,
                          assetPath: 'assets/player/player_cover.png',
                        ),
                        const SizedBox(height: PelevoSpacing.xl),
                        Text(
                          episode.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: PelevoSpacing.xxs),
                        Text(
                          episode.showTitle ?? '',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                        if (widget.view == _PlayerView.casting ||
                            cast?.connected == true) ...[
                          const SizedBox(height: PelevoSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cast?.connected == true
                                    ? Icons.cast_connected_rounded
                                    : Icons.cast_rounded,
                                size: 16,
                                color:
                                    cast?.connected == true
                                        ? PelevoColors.green
                                        : context.pelevo.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cast?.connected == true
                                    ? 'Casting to ${cast!.deviceName ?? 'speaker'}'
                                    : 'Ready to cast',
                                style: TextStyle(
                                  color:
                                      cast?.connected == true
                                          ? PelevoColors.green
                                          : context.pelevo.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.view == _PlayerView.sleepActive ||
                            ref.watch(sleepTimerProvider).active) ...[
                          const SizedBox(height: PelevoSpacing.md),
                          Text(
                            ref.watch(sleepTimerProvider).active
                                ? 'Sleep timer · ${ref.watch(sleepTimerProvider).label}'
                                : 'Sleep timer is off',
                            style: TextStyle(
                              color:
                                  ref.watch(sleepTimerProvider).active
                                      ? PelevoColors.yellow
                                      : context.pelevo.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: PelevoSpacing.lg),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: PelevoColors.red,
                            inactiveTrackColor: context.pelevo.surfaceHigh,
                            thumbColor: Colors.white,
                            overlayColor: PelevoColors.red.withValues(
                              alpha: .2,
                            ),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: displayProgress.clamp(0, 1),
                            onChanged: (value) {
                              setState(() {
                                _scrubbing = true;
                                _progress = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              await _seek(episode, playback, value);
                              if (mounted) setState(() => _scrubbing = false);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PelevoSpacing.xs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatCatalogClock(
                                  (displayProgress * duration).round(),
                                ),
                                style: TextStyle(
                                  color: context.pelevo.textMuted,
                                ),
                              ),
                              Text(
                                duration == 0
                                    ? '—'
                                    : formatCatalogClock(duration),
                                style: TextStyle(
                                  color: context.pelevo.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: PelevoSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed:
                                  () => context.go('/screen/player-speed'),
                              child: Text(
                                widget.view == _PlayerView.speedChanged
                                    ? '1.5x'
                                    : speedLabel,
                                style: TextStyle(
                                  color:
                                      widget.view == _PlayerView.speedChanged
                                          ? PelevoColors.yellow
                                          : context.pelevo.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Back 10 seconds',
                              onPressed: () => _skipBy(episode, -10),
                              icon: const Icon(
                                Icons.replay_10_rounded,
                                size: 32,
                              ),
                            ),
                            Tooltip(
                              message:
                                  buffering
                                      ? 'Loading audio'
                                      : displayPlaying
                                      ? 'Pause'
                                      : 'Play',
                              child: Material(
                                color: PelevoColors.red,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap:
                                      buffering && !displayPlaying
                                          ? null
                                          : () => _togglePlay(episode),
                                  child: SizedBox(
                                    width: 68,
                                    height: 68,
                                    child:
                                        buffering
                                            ? const Padding(
                                              padding: EdgeInsets.all(20),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color: Colors.white,
                                                semanticsLabel: 'Loading audio',
                                              ),
                                            )
                                            : Icon(
                                              displayPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 36,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Forward 10 seconds',
                              onPressed: () => _skipBy(episode, 10),
                              icon: const Icon(
                                Icons.forward_10_rounded,
                                size: 32,
                              ),
                            ),
                            if (widget.view == _PlayerView.casting)
                              IconButton(
                                tooltip: 'Cast',
                                onPressed:
                                    _busy
                                        ? null
                                        : () => showPelevoCastSheet(
                                          context,
                                          ref,
                                          episode,
                                        ),
                                icon: Icon(
                                  (cast?.connected ?? false)
                                      ? Icons.cast_connected_rounded
                                      : Icons.cast_rounded,
                                  color:
                                      (cast?.connected ?? false)
                                          ? PelevoColors.green
                                          : context.pelevo.text,
                                ),
                              )
                            else
                              IconButton(
                                tooltip: 'Sleep timer',
                                onPressed:
                                    () => context.go('/screen/player-sleep'),
                                icon: Icon(
                                  Icons.bedtime_outlined,
                                  color:
                                      widget.view == _PlayerView.sleepActive
                                          ? PelevoColors.yellow
                                          : context.pelevo.text,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: PelevoSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _utility(
                              Icons.format_list_bulleted_rounded,
                              'Chapters',
                              () => context.go('/screen/player-chapters'),
                            ),
                            _utility(
                              Icons.queue_music_rounded,
                              'Queue',
                              () => context.go('/screen/player-details'),
                            ),
                            _utility(
                              Icons.chat_bubble_outline_rounded,
                              'Comments',
                              () => showPelevoCommentSheet(
                                context,
                                target: CommentTarget.episode(episode.id),
                                title: 'Comments',
                              ),
                            ),
                            _utility(
                              Icons.ios_share_rounded,
                              'Share',
                              () => context.go('/screen/player-video'),
                            ),
                            _utility(
                              (ref
                                          .watch(pelevoCastSnapshotProvider)
                                          .asData
                                          ?.value
                                          .connected ??
                                      false)
                                  ? Icons.cast_connected_rounded
                                  : Icons.cast_rounded,
                              'Cast',
                              () => showPelevoCastSheet(context, ref, episode),
                            ),
                          ],
                        ),
                        const SizedBox(height: PelevoSpacing.lg),
                        if (widget.view == _PlayerView.speedChanged)
                          Wrap(
                            spacing: PelevoSpacing.xs,
                            children: [
                              for (final speed in const [
                                0.75,
                                1.0,
                                1.25,
                                1.5,
                                2.0,
                              ])
                                ChoiceChip(
                                  label: Text('${speed}x'),
                                  selected: _speed == speed,
                                  selectedColor: PelevoColors.green,
                                  onSelected:
                                      _busy
                                          ? null
                                          : (_) => _setSpeed(episode, speed),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom nav only — [PelevoPage] already mounts the global [PelevoMiniPlayer].
  Widget _bottomChrome(BuildContext context, CatalogEpisode episode) =>
      PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      );

  Widget _miniSearch(BuildContext context) {
    final recent = ref.watch(searchRecentProvider);
    final charts = ref.watch(homeChartsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          readOnly: true,
          onTap: () => context.go('/screen/search'),
          decoration: const InputDecoration(
            hintText: 'Search podcasts, people, topics',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Recent Searches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (recent.isLoading)
          const CatalogStatusBody()
        else if (recent.hasError)
          CatalogStatusBody(
            error: recent.error,
            retry: () => ref.invalidate(searchRecentProvider),
          )
        else if (recent.requireValue.isEmpty)
          Text(
            'No recent searches.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final term in recent.requireValue)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(term.query),
              onTap: () => context.go('/screen/search-results'),
            ),
        const SizedBox(height: PelevoSpacing.md),
        Text('Popular Searches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (charts.isLoading)
          const CatalogStatusBody()
        else if (charts.hasError)
          CatalogStatusBody(
            error: charts.error,
            retry: () => ref.invalidate(homeChartsProvider),
          )
        else if (charts.requireValue.podcasts.isEmpty)
          Text(
            'No trending shows are published yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          Wrap(
            spacing: PelevoSpacing.xs,
            children: [
              for (final item in charts.requireValue.podcasts)
                ActionChip(
                  label: Text(item.title),
                  onPressed: () {
                    openCatalogHomeItem(context, item);
                    context.go('/screen/search-results');
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _miniDiscover(BuildContext context) {
    final discover = ref.watch(homeDiscoverProvider);
    if (discover.isLoading) return const CatalogStatusBody();
    if (discover.hasError) {
      return CatalogStatusBody(
        error: discover.error,
        retry: () => ref.invalidate(homeDiscoverProvider),
      );
    }
    final page = discover.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Collections',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        if (page.editorsPicks.isEmpty)
          Text(
            'No featured collections are published yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in page.editorsPicks)
                  Padding(
                    padding: const EdgeInsets.only(right: PelevoSpacing.sm),
                    child: InkWell(
                      onTap: () => context.go('/screen/browse'),
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: PelevoColors.red.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(
                            PelevoRadii.large,
                          ),
                          border: Border.all(
                            color: PelevoColors.red.withValues(alpha: .5),
                          ),
                        ),
                        padding: const EdgeInsets.all(PelevoSpacing.md),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoSectionHeader(
          title: 'Top Podcasts',
          onSeeAll: () => context.go('/screen/browse'),
        ),
        if (page.trending.isEmpty)
          Text(
            'Nothing is trending yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in page.trending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: item.artworkUrl,
                width: 48,
                height: 48,
                assetPath: 'assets/player/player_thumb.png',
              ),
              title: Text(item.title),
              subtitle: Text(item.showTitle ?? item.subtitle ?? ''),
              onTap: () {
                openCatalogHomeItem(context, item);
                context.go(
                  item.type == 'show'
                      ? '/screen/podcast-details'
                      : '/screen/episode-details',
                );
              },
            ),
      ],
    );
  }

  Widget _chaptersView(BuildContext context) {
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
              onPressed: () => context.go('/screen/player-now-playing'),
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
            onTap: () => context.go('/screen/player-now-playing'),
          ),
      ],
    );
  }

  Widget _notesView(BuildContext context) {
    final notesAsync = ref.watch(catalogNotesProvider);
    if (notesAsync.isLoading) return const CatalogStatusBody();
    if (notesAsync.hasError) {
      return CatalogStatusBody(
        error: notesAsync.error,
        retry: () => ref.invalidate(catalogNotesProvider),
      );
    }
    final note = notesAsync.requireValue;
    final empty = note.body == null || note.body!.trim().isEmpty;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        Image.asset(
          'assets/player/notes_hero.png',
          width: 120,
          height: 110,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          empty ? 'No Notes Yet' : 'Your Notes',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          empty ? 'Be the first to take notes on this episode.' : note.body!,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Add Note',
          color: PelevoColors.green,
          icon: Icons.add_rounded,
          onPressed: () => context.go('/screen/episode-notes'),
        ),
      ],
    );
  }

  Widget _queueView(BuildContext context, CatalogEpisode episode) {
    return QueueReorderList(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Now Playing', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CatalogArtwork(
              url: episode.artworkUrl,
              width: 52,
              height: 52,
              assetPath: 'assets/player/player_thumb.png',
            ),
            title: Text(episode.title),
            subtitle: Text(episode.showTitle ?? ''),
            trailing: const Icon(
              Icons.equalizer_rounded,
              color: PelevoColors.green,
            ),
            onTap: () => context.go('/screen/player-now-playing'),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          PelevoSectionHeader(
            title: 'Up Next',
            trailing: 'See All',
            onSeeAll: () => context.go('/screen/queue-up-next'),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: Text(
              'Hold and drag to rearrange play order.',
              style: TextStyle(color: context.pelevo.textMuted, fontSize: 13),
            ),
          ),
        ],
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
            assetPath: 'assets/player/player_thumb.png',
          ),
          title: Text(episode.title),
          subtitle: Text(
            episode.subtitle.isEmpty
                ? episode.showTitle ?? ''
                : episode.subtitle,
          ),
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Wrap(
        spacing: PelevoSpacing.md,
        runSpacing: PelevoSpacing.lg,
        alignment: WrapAlignment.spaceAround,
        children: [
          for (final item in [
            (
              pelevoAirDropAvailable ? 'AirDrop' : 'Share',
              pelevoAirDropAvailable
                  ? Icons.ios_share_rounded
                  : Icons.share_rounded,
              PelevoColors.blue,
            ),
            ('Copy Link', Icons.link_rounded, PelevoColors.orange),
            ('Share Card', Icons.image_outlined, PelevoColors.purple),
            ('WhatsApp', Icons.chat_rounded, PelevoColors.green),
            ('Messages', Icons.sms_rounded, PelevoColors.yellow),
            ('More', Icons.more_horiz_rounded, context.pelevo.textMuted),
          ])
            SizedBox(
              width: 72,
              child: _shareAction(context, item.$1, item.$2, item.$3, () {
                if (item.$1 == 'Copy Link') {
                  _copyLink(episode);
                } else if (item.$1 == 'Share Card') {
                  context.go('/screen/share-card-preview');
                } else {
                  _shareEpisode(context, episode);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/player-now-playing'),
      ),
    ],
  );

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
                    value: 'High (320 kbps)',
                    child: Text('High (320 kbps)'),
                  ),
                  DropdownMenuItem(
                    value: 'High (128 kbps)',
                    child: Text('High (128 kbps)'),
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
                icon:
                    done
                        ? Icons.offline_pin_rounded
                        : Icons.cloud_download_rounded,
                onPressed: _busy ? null : () => _authorize(episode),
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

  Widget _moreOptions(
    BuildContext context,
    CatalogEpisode episode,
    CatalogPlayback? playback,
  ) => Column(
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
      Text('More Options', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.md),
      _option(
        Icons.playlist_add_rounded,
        'Add to Queue',
        _busy
            ? null
            : () => enqueueCatalogEpisode(context, episodeId: episode.id),
      ),
      _option(
        Icons.playlist_play_rounded,
        'Play Next',
        _busy
            ? null
            : () => enqueueCatalogEpisode(
              context,
              episodeId: episode.id,
              playNext: true,
            ),
      ),
      _option(
        Icons.playlist_add_rounded,
        'Add to Playlist',
        _busy ? null : () => _pickPlaylist(episode),
      ),
      _option(Icons.podcasts_rounded, 'Go to Show', () {
        openCatalogShow(context, episode.showId);
        context.push('/screen/podcast-details');
      }),
      _option(
        Icons.notes_rounded,
        'View Show Notes',
        () => context.go('/screen/episode-description'),
      ),
      _option(
        Icons.edit_note_rounded,
        'Add Notes',
        () => context.go('/screen/episode-notes'),
      ),
      _option(
        Icons.cloud_download_rounded,
        'Download Episode',
        _busy
            ? null
            : () {
              if (kIsWeb) {
                context.showPelevoMessage(
                  'Offline downloads are not available on web.',
                );
                return;
              }
              context.go('/screen/player-completed');
            },
      ),
      _option(
        Icons.cast_rounded,
        'Cast to Device',
        _busy ? null : () => showPelevoCastSheet(context, ref, episode),
      ),
      _option(
        Icons.flag_outlined,
        'Report Episode',
        _busy ? null : () => _reportEpisode(episode),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.close_rounded, color: PelevoColors.red),
        title: const Text('Remove from Queue'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _busy ? null : () => _removeFromQueue(episode),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.check_circle_outline_rounded,
          color: PelevoColors.green,
        ),
        title: const Text('Mark as Played'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _busy ? null : () => _markPlayed(episode, playback),
      ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Cancel',
        outlined: true,
        onPressed: () => context.go('/screen/player-now-playing'),
      ),
    ],
  );

  Widget _utility(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: Padding(
      padding: const EdgeInsets.all(PelevoSpacing.xs),
      child: Column(
        children: [
          Icon(icon, color: context.pelevo.text),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  Widget _option(IconData icon, String title, VoidCallback? onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Widget _shareAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => InkWell(
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
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Future<void> _togglePlay(CatalogEpisode episode) async {
    try {
      await ref.read(pelevoPlaybackControllerProvider).toggle(episode);
      final handler = pelevoAudioHandler;
      if (!mounted) return;
      if (handler != null) _bindPosition(handler, episode);
      setState(() => _playing = handler?.playing ?? !_playing);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    }
  }

  Future<void> _pickPlaylist(CatalogEpisode episode) async {
    if (_busy) return;
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
  }

  Future<void> _removeFromQueue(CatalogEpisode episode) async {
    setState(() => _busy = true);
    try {
      final queue = await ref.read(catalogQueueProvider.future);
      await ref
          .read(catalogRepositoryProvider)
          .removeEpisodeFromQueue(episode.id, queue.version);
      ref.invalidate(catalogQueueProvider);
      if (!mounted) return;
      context.showPelevoMessage('Removed from queue');
      context.go('/screen/player-now-playing');
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
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: StatefulBuilder(
              builder:
                  (context, setSheet) => Column(
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
                              (value) =>
                                  setSheet(() => reason = value ?? reason),
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
                            await ref
                                .read(catalogRepositoryProvider)
                                .reportEpisode(
                                  episodeId: episode.id,
                                  reason: code,
                                  details:
                                      reason == 'Spoiler' ? 'Spoiler' : null,
                                );
                            if (!mounted) return;
                            this.context.showPelevoMessage('Report submitted');
                            this.context.go('/screen/player-now-playing');
                          } catch (error) {
                            if (!mounted) return;
                            this.context.showPelevoMessage(
                              catalogFailure(error).message,
                            );
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

  Future<void> _skipBy(CatalogEpisode episode, int seconds) async {
    final duration = episode.durationSeconds ?? 0;
    if (duration <= 0) return;
    final current = (_progress * duration).round();
    final next = (current + seconds).clamp(0, duration);
    setState(() => _progress = next / duration);
    await _seek(episode, null, next / duration);
  }

  Future<void> _setSpeed(CatalogEpisode episode, double speed) async {
    setState(() => _busy = true);
    try {
      await ref.read(pelevoPlaybackControllerProvider).setSpeed(episode, speed);
      if (!mounted) return;
      setState(() => _speed = speed);
      if (speed == 1) context.go('/screen/player-now-playing');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seek(
    CatalogEpisode episode,
    CatalogPlayback? playback,
    double value,
  ) async {
    final duration = episode.durationSeconds ?? 0;
    if (duration == 0) return;
    try {
      await ref
          .read(pelevoPlaybackControllerProvider)
          .seek(episode, Duration(seconds: (value * duration).round()));
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    }
  }

  Future<void> _markPlayed(
    CatalogEpisode episode,
    CatalogPlayback? playback,
  ) async {
    final owner = ref.read(authSessionProvider).userId;
    if (owner == null) {
      context.showPelevoMessage('Sign in to update playback progress.');
      return;
    }
    setState(() => _busy = true);
    try {
      final CatalogPlayback current =
          playback ??
          await ref.read(catalogPlaybackByIdProvider(episode.id).future);
      await ref
          .read(catalogRepositoryProvider)
          .savePlayback(
            episode.id,
            owner,
            positionSeconds: episode.durationSeconds ?? current.positionSeconds,
            completed: true,
            version: current.version,
          );
      ref.invalidate(catalogPlaybackByIdProvider(episode.id));
      ref.invalidate(catalogPlaybackProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;
      context.showPelevoMessage('Marked as played');
      context.go('/screen/player-now-playing');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink(CatalogEpisode episode) async {
    await Clipboard.setData(
      ClipboardData(text: catalogShareEpisodeLink(episode.id)),
    );
    if (!mounted) return;
    context.showPelevoMessage('Link copied');
  }

  Future<void> _shareEpisode(
    BuildContext originContext,
    CatalogEpisode episode,
  ) async {
    final url = catalogShareEpisodeLink(episode.id);
    final title =
        episode.showTitle == null || episode.showTitle!.isEmpty
            ? episode.title
            : '${episode.title} · ${episode.showTitle}';
    try {
      await pelevoShareEpisodeLink(
        context: originContext,
        url: url,
        title: title,
      );
    } on Object {
      if (!mounted) return;
      context.showPelevoMessage('Sharing is not available on this device.');
    }
  }

  Future<void> _authorize(CatalogEpisode episode) async {
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
      final record = await ref
          .read(downloadFileServiceProvider)
          .downloadEpisode(
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

  void _ensureDownloadStatus(String episodeId) {
    if (_alreadyDownloaded != null) return;
    ref.read(downloadFileServiceProvider).isDownloaded(episodeId).then((value) {
      if (!mounted) return;
      setState(() => _alreadyDownloaded = value);
    });
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
}
