import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract final class ReelWakeLock {
  static Future<void> setEnabled(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // Tests and unsupported platforms keep the default timeout.
    }
  }
}

abstract final class ReelPlayback {
  static void halt() {
    ReelVideoCache.instance.pauseAll();
    unawaited(ReelWakeLock.setEnabled(false));
  }
}

class ReelVideoCache {
  ReelVideoCache._();
  static final ReelVideoCache instance = ReelVideoCache._();

  final _ready = <String, VideoPlayerController>{};
  final _loading = <String, Future<VideoPlayerController?>>{};

  Future<VideoPlayerController?> controllerFor(String url) {
    final existing = _ready[url];
    if (existing != null) return Future<VideoPlayerController?>.value(existing);
    return _loading.putIfAbsent(url, () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.pause();
        _ready[url] = controller;
        return controller;
      } on Object {
        await controller.dispose();
        return null;
      } finally {
        _loading.remove(url);
      }
    });
  }

  void preload(Iterable<String?> urls, {int limit = 5}) {
    var queued = 0;
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      if (!_ready.containsKey(url) && !_loading.containsKey(url)) {
        unawaited(controllerFor(url));
      }
      queued += 1;
      if (queued >= limit) break;
    }
  }

  Future<void> seek(String url, Duration position) async {
    final controller = _ready[url];
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    var next = position;
    if (next.isNegative) next = Duration.zero;
    if (duration > Duration.zero && next > duration) next = duration;
    await controller.seekTo(next);
  }

  Future<void> evictExcept(Set<String> keep) async {
    final drop = _ready.keys.where((url) => !keep.contains(url)).toList();
    for (final url in drop) {
      final controller = _ready.remove(url);
      await controller?.dispose();
    }
  }

  void pauseAll() {
    for (final controller in _ready.values) {
      unawaited(controller.setVolume(0));
      unawaited(controller.pause());
    }
  }

  Future<void> disposeAll() => evictExcept(const {});
}

class PelevoReelVideo extends StatefulWidget {
  const PelevoReelVideo({
    super.key,
    required this.playing,
    this.coverUrl,
    this.mediaUrl,
    this.muted = false,
    this.looping = true,
    this.showProgress = true,
    this.onEnded,
    this.onProgress,
  });

  final String? coverUrl;
  final String? mediaUrl;
  final bool playing;
  final bool muted;
  final bool looping;
  final bool showProgress;
  final VoidCallback? onEnded;
  final void Function(Duration position, Duration duration)? onProgress;

  @override
  State<PelevoReelVideo> createState() => _PelevoReelVideoState();
}

class _PelevoReelVideoState extends State<PelevoReelVideo> {
  VideoPlayerController? _player;
  var _ended = false;
  String? _attachedUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_attach());
  }

  @override
  void didUpdateWidget(covariant PelevoReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaUrl != oldWidget.mediaUrl) {
      _ended = false;
      unawaited(_attach());
      return;
    }
    unawaited(_applyPlayback());
  }

  Future<void> _attach() async {
    final url = widget.mediaUrl;
    _detach();
    _attachedUrl = url;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final controller = await ReelVideoCache.instance.controllerFor(url);
    if (!mounted || _attachedUrl != url) return;
    _player = controller;
    controller?.addListener(_onTick);
    await _applyPlayback();
    if (mounted) setState(() {});
    if (widget.playing && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.playing) unawaited(_applyPlayback());
      });
    }
  }

  void _detach() {
    _player?.removeListener(_onTick);
    unawaited(_player?.pause());
    _player = null;
  }

  Future<void> _applyPlayback() async {
    final player = _player;
    if (player == null) {
      if (widget.playing) await _attach();
      return;
    }
    await player.setVolume(widget.muted || !widget.playing ? 0 : 1);
    await player.setLooping(widget.looping);
    if (widget.playing) {
      _ended = false;
      await player.play();
    } else {
      await player.pause();
    }
  }

  void _onTick() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final duration = player.value.duration;
    final position = player.value.position;
    widget.onProgress?.call(position, duration);
    if (!widget.looping &&
        duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 180) &&
        !_ended) {
      _ended = true;
      widget.onEnded?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player != null && player.value.isInitialized) {
      final duration = player.value.duration.inMilliseconds;
      final progress =
          duration <= 0
              ? 0.0
              : (player.value.position.inMilliseconds / duration).clamp(
                0.0,
                1.0,
              );
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: player.value.size.width,
              height: player.value.size.height,
              child: VideoPlayer(player),
            ),
          ),
          if (widget.showProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }
    return _ReelCover(url: widget.coverUrl);
  }
}

class _ReelCover extends StatelessWidget {
  const _ReelCover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ColoredBox(
        color: context.pelevo.surfaceHigh,
        child: Center(
          child: Icon(Icons.movie_creation_outlined, size: 42),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget:
          (context, error, stackTrace) => ColoredBox(
            color: context.pelevo.surfaceHigh,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 42),
            ),
          ),
    );
  }
}

class ReelScrubber extends StatefulWidget {
  const ReelScrubber({
    super.key,
    required this.progress,
    required this.duration,
    required this.onSeek,
    this.enabled = true,
  });

  final double progress;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool enabled;

  @override
  State<ReelScrubber> createState() => _ReelScrubberState();
}

class _ReelScrubberState extends State<ReelScrubber> {
  static const _restHeight = 2.0;
  static const _activeHeight = 4.0;
  static const _knobSize = 12.0;
  static const _hitHeight = 28.0;

  var _active = false;

  void _setActive(bool value) {
    if (!widget.enabled || _active == value) return;
    setState(() => _active = value);
  }

  void _seekAt(Offset local, double width) {
    if (!widget.enabled || widget.duration <= Duration.zero || width <= 0) {
      return;
    }
    final fraction = (local.dx / width).clamp(0.0, 1.0);
    widget.onSeek(
      Duration(
        milliseconds: (widget.duration.inMilliseconds * fraction).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    final barHeight = _active ? _activeHeight : _restHeight;
    return SizedBox(
      height: _hitHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:
                widget.enabled
                    ? (details) {
                      _setActive(true);
                      _seekAt(details.localPosition, width);
                    }
                    : null,
            onTapUp: (_) => _setActive(false),
            onTapCancel: () => _setActive(false),
            onHorizontalDragStart:
                widget.enabled
                    ? (details) {
                      _setActive(true);
                      _seekAt(details.localPosition, width);
                    }
                    : null,
            onHorizontalDragUpdate:
                widget.enabled
                    ? (details) => _seekAt(details.localPosition, width)
                    : null,
            onHorizontalDragEnd: (_) => _setActive(false),
            onHorizontalDragCancel: () => _setActive(false),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: _active ? _knobSize : _activeHeight,
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        curve: Curves.easeOut,
                        height: barHeight,
                        width: width,
                        color: const Color(0x3DFFFFFF),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          heightFactor: 1,
                          child: const ColoredBox(color: Colors.white),
                        ),
                      ),
                    ),
                    if (_active)
                      Positioned(
                        left: (width * progress - _knobSize / 2).clamp(
                          0.0,
                          width > _knobSize ? width - _knobSize : 0.0,
                        ),
                        bottom: (barHeight - _knobSize) / 2,
                        child: const IgnorePointer(
                          child: SizedBox(
                            width: _knobSize,
                            height: _knobSize,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
