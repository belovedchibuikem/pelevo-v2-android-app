import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/earn/earn_catalog_data.dart';
import 'package:pelevo/features/earn/earn_playback_session.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

/// Persistent mini-player shown above bottom navigation when an episode is loaded.
///
/// Swipe left and release, or press and hold, to reveal Close. Dismissing hides
/// the bar on every screen until playback starts again.
class PelevoMiniPlayer extends ConsumerWidget {
  const PelevoMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(miniPlayerDismissedProvider);
    final live = ref.watch(nowPlayingEpisodeProvider);
    final nowPlayingId = ref.watch(nowPlayingEpisodeIdProvider);
    final media = ref.watch(pelevoMediaItemProvider).asData?.value;
    final activeId = live?.id ?? media?.id ?? nowPlayingId;
    final handler =
        ref.watch(pelevoAudioHandlerProvider).asData?.value ??
        pelevoAudioHandler;
    return ListenableBuilder(
      listenable: EarnPlaybackSession.instance,
      builder: (context, _) {
        final earn = EarnPlaybackSession.instance;
        if (handler?.earnMode == true && earn.activeEpisode != null) {
          return const _EarnMiniBar();
        }
        final visible = !dismissed && activeId != null && activeId.isNotEmpty;
        return AnimatedSize(
          duration: PelevoMotion.fast,
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child:
              visible
                  ? _MiniPlayerBar(activeId: activeId)
                  : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({required this.activeId});

  final String activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler =
        ref.watch(pelevoAudioHandlerProvider).asData?.value ??
        pelevoAudioHandler;
    final live = ref.watch(nowPlayingEpisodeProvider);
    final media = ref.watch(pelevoMediaItemProvider).asData?.value;
    final fetched =
        ref.watch(catalogEpisodeByIdProvider(activeId)).asData?.value;
    final episode = (live?.id == activeId ? live : null) ?? fetched;
    final playing =
        ref.watch(pelevoIsPlayingProvider).asData?.value ??
        handler?.playing ??
        false;
    final buffering = ref.watch(pelevoBufferingProvider);
    final title = episode?.title ?? media?.title ?? 'Playing';
    final show = episode?.showTitle ?? media?.album ?? '';
    final art = episode?.artworkUrl ?? media?.artUri?.toString();

    return _MiniPlayerDismissGesture(
      onOpen: () => context.push('/screen/player-now-playing'),
      onClose:
          () => ref.read(pelevoPlaybackControllerProvider).dismissMiniPlayer(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PelevoSpacing.md,
          vertical: PelevoSpacing.sm,
        ),
        child: Row(
          children: [
            CatalogArtwork(
              key: ValueKey<String>(art ?? activeId),
              url: art,
              width: 40,
              height: 40,
            ),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (show.isNotEmpty)
                    Text(
                      show,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip:
                  buffering
                      ? 'Loading audio'
                      : playing
                      ? 'Pause'
                      : 'Play',
              onPressed:
                  buffering && !playing
                      ? null
                      : () async {
                        final ep = episode;
                        if (ep == null) {
                          playCatalogEpisode(
                            context,
                            episodeId: activeId,
                            keepQueue: true,
                          );
                          return;
                        }
                        try {
                          await ref
                              .read(pelevoPlaybackControllerProvider)
                              .toggle(ep);
                        } catch (_) {}
                      },
              icon:
                  buffering
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PelevoColors.green,
                          semanticsLabel: 'Loading audio',
                        ),
                      )
                      : Icon(
                        playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: PelevoColors.green,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipe left past a threshold (and hold/release) or long-press to reveal Close.
class _MiniPlayerDismissGesture extends StatefulWidget {
  const _MiniPlayerDismissGesture({
    required this.onOpen,
    required this.onClose,
    required this.child,
  });

  final VoidCallback onOpen;
  final Future<void> Function() onClose;
  final Widget child;

  @override
  State<_MiniPlayerDismissGesture> createState() =>
      _MiniPlayerDismissGestureState();
}

class _MiniPlayerDismissGestureState extends State<_MiniPlayerDismissGesture>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 88.0;
  static const _revealThreshold = 0.4;

  late final AnimationController _reveal;
  bool _hapticSent = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: PelevoMotion.fast);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  bool get _isRevealed => _reveal.value >= _revealThreshold;

  void _revealClose() {
    _reveal.forward();
    HapticFeedback.selectionClick();
  }

  void _hideClose() {
    _hapticSent = false;
    _reveal.reverse();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final next = (_reveal.value - delta / _actionWidth).clamp(0.0, 1.0);
    _reveal.value = next;
    if (!_hapticSent && next >= _revealThreshold) {
      _hapticSent = true;
      HapticFeedback.selectionClick();
    } else if (next < _revealThreshold) {
      _hapticSent = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_reveal.value >= _revealThreshold) {
      _reveal.forward();
    } else {
      _hideClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, child) {
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => _revealClose(),
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(-_actionWidth * _reveal.value, 0),
                  child: child,
                ),
              ),
              if (_reveal.value > 0.02)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _actionWidth,
                  child: _CloseMiniPlayerButton(onPressed: widget.onClose),
                ),
            ],
          );
        },
        child: Material(
          color: context.pelevo.surfaceHigh,
          child: InkWell(
            onTap: () {
              if (_isRevealed) {
                _hideClose();
                return;
              }
              widget.onOpen();
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _EarnMiniBar extends ConsumerWidget {
  const _EarnMiniBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = EarnPlaybackSession.instance;
    final episode = session.activeEpisode;
    if (episode == null) return const SizedBox(width: double.infinity);
    return Material(
      color: const Color(0xFF102117),
      child: InkWell(
        onTap: () => context.push('/screen/earn-player'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PelevoSpacing.md,
            vertical: PelevoSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.headphones_rounded, color: PelevoColors.green),
              const SizedBox(width: PelevoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session.buffering
                          ? 'Buffering...'
                          : session.isPlaying
                          ? 'Playing'
                          : 'Paused',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    session.buffering
                        ? 'Loading audio'
                        : session.isPlaying
                        ? 'Pause'
                        : 'Play',
                onPressed:
                    session.buffering && !session.isPlaying
                        ? null
                        : () async {
                          if (!session.isPlaying) {
                            await ref
                                .read(pelevoPlaybackControllerProvider)
                                .releaseForEarn();
                          }
                          await session.toggle(
                            episode: episode,
                            repository: ref.read(earnCatalogRepositoryProvider),
                            deviceId: ref.read(installationIdProvider),
                          );
                        },
                icon:
                    session.buffering
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: PelevoColors.green,
                            semanticsLabel: 'Loading audio',
                          ),
                        )
                        : Icon(
                          session.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          color: PelevoColors.green,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseMiniPlayerButton extends StatelessWidget {
  const _CloseMiniPlayerButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PelevoColors.red,
      child: InkWell(
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: 'Close mini player',
          child: const Tooltip(
            message: 'Close mini player',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close_rounded, color: Colors.white),
                SizedBox(height: 2),
                Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
