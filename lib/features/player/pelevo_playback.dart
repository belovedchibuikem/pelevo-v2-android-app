import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

final pelevoAudioHandlerProvider = FutureProvider<PelevoAudioHandler>((
  ref,
) async {
  return initPelevoAudioHandler();
});

/// When true, the mini-player stays hidden on every screen until playback resumes
/// or a different episode is selected.
class MiniPlayerDismissedNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<String?>(nowPlayingEpisodeIdProvider, (previous, next) {
      if (next != null && next.isNotEmpty && next != previous && state) {
        state = false;
      }
    });
    return false;
  }

  void dismiss() => state = true;

  void restore() {
    if (state) state = false;
  }
}

final miniPlayerDismissedProvider =
    NotifierProvider<MiniPlayerDismissedNotifier, bool>(
      MiniPlayerDismissedNotifier.new,
    );

/// Live playhead while audio is loaded (seconds).
final pelevoPositionSecondsProvider = StreamProvider.autoDispose<int>((
  ref,
) async* {
  final cast = ref.watch(pelevoCastBackendProvider);
  final castSnap = ref.watch(pelevoCastSnapshotProvider).asData?.value;
  if (castSnap?.connected == true) {
    yield cast.position.inSeconds;
    yield* cast.positionStream.map((d) => d.inSeconds);
    return;
  }
  final handler = await ref.watch(pelevoAudioHandlerProvider.future);
  yield handler.position.inSeconds;
  yield* handler.positionStream.map((d) => d.inSeconds);
});

final pelevoIsPlayingProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final castSnap = ref.watch(pelevoCastSnapshotProvider).asData?.value;
  if (castSnap?.connected == true) {
    yield castSnap!.playing;
    yield* ref.watch(pelevoCastBackendProvider).snapshots.map((s) => s.playing);
    return;
  }
  final handler = await ref.watch(pelevoAudioHandlerProvider.future);
  yield handler.playing;
  yield* handler.playbackState.map((state) => state.playing);
});

/// True from the moment the user asks to play until the engine starts loading.
class PelevoPlayPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final pelevoPlayPendingProvider =
    NotifierProvider<PelevoPlayPendingNotifier, bool>(
      PelevoPlayPendingNotifier.new,
    );

final _pelevoEngineBufferingProvider = StreamProvider.autoDispose<bool>((
  ref,
) async* {
  final castSnap = ref.watch(pelevoCastSnapshotProvider).asData?.value;
  if (castSnap?.connected == true) {
    yield false;
    return;
  }
  final handler = await ref.watch(pelevoAudioHandlerProvider.future);
  bool waiting(PlaybackState state) =>
      state.processingState == AudioProcessingState.loading ||
      state.processingState == AudioProcessingState.buffering;
  yield waiting(handler.playbackState.value);
  yield* handler.playbackState.map(waiting).distinct();
});

/// True while audio is being fetched or buffered, so play buttons can show a
/// loading state instead of inviting repeated taps.
final pelevoBufferingProvider = Provider.autoDispose<bool>((ref) {
  final pending = ref.watch(pelevoPlayPendingProvider);
  final engine = ref.watch(_pelevoEngineBufferingProvider).asData?.value;
  return pending || (engine ?? false);
});

final pelevoMediaItemProvider = StreamProvider.autoDispose<MediaItem?>((
  ref,
) async* {
  final handler = await ref.watch(pelevoAudioHandlerProvider.future);
  yield handler.mediaItem.value;
  yield* handler.mediaItem;
});

class PelevoPlaybackController {
  PelevoPlaybackController(this._ref) {
    _listenForCompletion();
    _listenForCastCompletion();
  }
  final Ref _ref;

  Timer? _progressTimer;
  Timer? _progressKick;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<(String, String)>? _queueAdvancedSub;
  StreamSubscription<void>? _castCompletedSub;
  StreamSubscription<Duration>? _positionSub;
  CatalogEpisode? _activeEpisode;
  DateTime? _lastSavedAt;
  final Map<String, int> _playbackVersions = {};
  final Map<String, CatalogEpisode> _primedEpisodes = {};
  int? _sessionVersion;
  bool _advancingQueue = false;
  bool _listeningForCompletion = false;
  String? _progressCompletedId;
  String? _queueAdvancedId;

  Future<PelevoAudioHandler> get _handler =>
      _ref.read(pelevoAudioHandlerProvider.future);

  Future<void> playEpisode(CatalogEpisode episode, {Duration? position}) async {
    final pending = _ref.read(pelevoPlayPendingProvider.notifier);
    pending.set(true);
    try {
      await _playEpisode(episode, position: position);
    } finally {
      pending.set(false);
    }
  }

  Future<void> _playEpisode(
    CatalogEpisode episode, {
    Duration? position,
  }) async {
    _ref.read(miniPlayerDismissedProvider.notifier).restore();
    _setNowPlaying(episode);
    final speed = await _playbackRate();
    final cast = _ref.read(pelevoCastControllerProvider);
    if (cast.isConnected) {
      await cast.playOnConnectedSession(
        episode,
        position: position ?? Duration.zero,
        speed: speed,
      );
      _progressCompletedId = null;
      _queueAdvancedId = null;
      _startProgressSync(episode);
      unawaited(_syncSession(episodeId: episode.id, playing: true));
      final seedSeconds = position?.inSeconds ?? cast.position.inSeconds;
      if (seedSeconds > 0) {
        unawaited(
          saveProgress(episode, positionSeconds: seedSeconds, force: true),
        );
      }
      return;
    }
    final local = await _ref
        .read(downloadFileServiceProvider)
        .localPath(episode.id);
    final audio = local ?? episode.audioUrl;
    if (audio == null || audio.isEmpty) {
      throw const ApiFailure(
        code: 'NO_AUDIO',
        message: 'This episode has no playable audio URL.',
      );
    }
    final handler = await _handler;
    final headers = _mediaHeaders(audioUri: audio, isLocal: local != null);
    try {
      await handler.loadEpisode(
        episodeId: episode.id,
        title: episode.title,
        showId: episode.showId,
        showTitle: episode.showTitle,
        artworkUrl: episode.artworkUrl,
        durationSeconds: episode.durationSeconds,
        audioUri: local != null ? Uri.file(local) : Uri.parse(audio),
        position: position,
        headers: headers,
        speed: speed,
      );
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw ApiFailure(
        code: 'AUDIO_LOAD_FAILED',
        message:
            kIsWeb
                ? 'This episode could not be played in the browser. Try the mobile app, or another episode.'
                : 'This episode could not be loaded. Please try again.',
      );
    }
    await handler.play();
    _progressCompletedId = null;
    _queueAdvancedId = null;
    _primedEpisodes[episode.id] = episode;
    _listenForCompletion();
    _listenForPosition(handler, episode.id);
    _startProgressSync(episode);
    unawaited(_primeUpcomingQueue(episode.id));
    // Don't block play/pause UI on network session/progress sync.
    unawaited(_syncSession(episodeId: episode.id, playing: true));
    final seedSeconds = position?.inSeconds ?? handler.position.inSeconds;
    if (seedSeconds > 0) {
      unawaited(
        saveProgress(episode, positionSeconds: seedSeconds, force: true),
      );
    }
  }

  Future<void> toggle(CatalogEpisode episode) async {
    final cast = _ref.read(pelevoCastControllerProvider);
    if (cast.isConnected) {
      if (cast.isPlaying) {
        await cast.pause();
        _progressTimer?.cancel();
        _progressKick?.cancel();
        unawaited(
          saveProgress(
            episode,
            positionSeconds: cast.position.inSeconds,
            force: true,
          ),
        );
        unawaited(_syncSession(episodeId: episode.id, playing: false));
      } else {
        _ref.read(miniPlayerDismissedProvider.notifier).restore();
        await cast.play();
        _setNowPlaying(episode);
        _startProgressSync(episode);
        unawaited(_syncSession(episodeId: episode.id, playing: true));
        unawaited(
          saveProgress(
            episode,
            positionSeconds:
                cast.position.inSeconds > 0 ? cast.position.inSeconds : 1,
            force: true,
          ),
        );
      }
      return;
    }

    final handler = await _handler;
    final current = handler.mediaItem.value?.id;
    if (current != episode.id) {
      final pending = _ref.read(pelevoPlayPendingProvider.notifier);
      if (_ref.read(pelevoPlayPendingProvider)) return;
      pending.set(true);
      Duration? resume;
      try {
        final owner = _ref.read(authSessionProvider).userId;
        if (owner != null) {
          final playback = await _playbackFor(episode.id, owner);
          if (playback.positionSeconds > 0) {
            resume = Duration(seconds: playback.positionSeconds);
          }
        }
      } catch (_) {}
      await playEpisode(episode, position: resume);
      return;
    }
    if (handler.playing) {
      await handler.pause();
      _progressTimer?.cancel();
      _progressKick?.cancel();
      unawaited(
        saveProgress(
          episode,
          positionSeconds: handler.position.inSeconds,
          force: true,
        ),
      );
      unawaited(_syncSession(episodeId: episode.id, playing: false));
    } else {
      // Resume in place — do not reload when paused at position zero.
      _ref.read(miniPlayerDismissedProvider.notifier).restore();
      await handler.play();
      _setNowPlaying(episode);
      _startProgressSync(episode);
      unawaited(_syncSession(episodeId: episode.id, playing: true));
      unawaited(
        saveProgress(
          episode,
          positionSeconds:
              handler.position.inSeconds > 0 ? handler.position.inSeconds : 1,
          force: true,
        ),
      );
    }
  }

  /// Hides the mini-player on every screen and stops local/cast playback.
  Future<void> dismissMiniPlayer() async {
    _ref.read(miniPlayerDismissedProvider.notifier).dismiss();
    _progressTimer?.cancel();
    _progressKick?.cancel();
    await _positionSub?.cancel();
    _positionSub = null;
    final episode = _activeEpisode;
    try {
      final cast = _ref.read(pelevoCastControllerProvider);
      if (cast.isConnected) {
        if (episode != null) {
          unawaited(
            saveProgress(
              episode,
              positionSeconds: cast.position.inSeconds,
              force: true,
            ),
          );
          unawaited(_syncSession(episodeId: episode.id, playing: false));
        }
        await cast.pause();
        _setNowPlaying(null);
        return;
      }
    } catch (_) {}
    try {
      final handler = pelevoAudioHandler;
      if (handler != null) {
        if (episode != null) {
          unawaited(
            saveProgress(
              episode,
              positionSeconds: handler.position.inSeconds,
              force: true,
            ),
          );
          unawaited(_syncSession(episodeId: episode.id, playing: false));
        }
        await handler.stop();
        handler.mediaItem.add(null);
      }
    } catch (_) {}
    _setNowPlaying(null);
  }

  Future<void> seek(CatalogEpisode episode, Duration position) async {
    final cast = _ref.read(pelevoCastControllerProvider);
    if (cast.isConnected) {
      await cast.seek(position);
      unawaited(
        saveProgress(episode, positionSeconds: position.inSeconds, force: true),
      );
      return;
    }
    final handler = await _handler;
    await handler.seek(position);
    unawaited(
      saveProgress(episode, positionSeconds: position.inSeconds, force: true),
    );
  }

  Future<void> setSpeed(CatalogEpisode episode, double speed) async {
    final cast = _ref.read(pelevoCastControllerProvider);
    if (cast.isConnected) {
      await cast.setSpeed(speed);
      await _syncSession(
        episodeId: episode.id,
        playing: cast.isPlaying,
        rate: speed,
      );
      return;
    }
    final handler = await _handler;
    await handler.setSpeed(speed);
    await _syncSession(
      episodeId: episode.id,
      playing: handler.playing,
      rate: speed,
    );
  }

  void _listenForCompletion() {
    if (_listeningForCompletion) return;
    _listeningForCompletion = true;
    unawaited(() async {
      try {
        final handler = await _handler;
        await _completedSub?.cancel();
        _completedSub = handler.completedStream.listen((_) {
          final finishedId = handler.mediaItem.value?.id;
          unawaited(_advanceQueue(finishedId: finishedId));
        });
        await _queueAdvancedSub?.cancel();
        _queueAdvancedSub = handler.queueAdvancedStream.listen((record) {
          unawaited(_onHandlerAdvanced(record.$1, record.$2));
        });
      } catch (_) {
        _listeningForCompletion = false;
      }
    }());
  }

  void _listenForCastCompletion() {
    unawaited(_castCompletedSub?.cancel());
    _castCompletedSub = _ref
        .read(pelevoCastBackendProvider)
        .completedStream
        .listen((_) {
          unawaited(_advanceQueue(finishedId: _activeEpisode?.id));
        });
  }

  void _listenForPosition(PelevoAudioHandler handler, String episodeId) {
    unawaited(_positionSub?.cancel());
    _positionSub = handler.positionStream.listen((position) {
      _handlePlaybackPosition(episodeId, position);
    });
  }

  void _handlePlaybackPosition(String episodeId, Duration position) {
    if (_activeEpisode?.id != episodeId) return;
    final handler = pelevoAudioHandler;
    final durationSeconds =
        _activeEpisode?.durationSeconds ?? handler?.duration?.inSeconds ?? 0;
    if (durationSeconds < 30) return;
    final seconds = position.inSeconds;
    if (_isCompleted(seconds, durationSeconds) &&
        _progressCompletedId != episodeId) {
      _progressCompletedId = episodeId;
      final finished = _activeEpisode;
      if (finished != null) {
        unawaited(
          saveProgress(
            finished,
            positionSeconds: seconds.clamp(0, durationSeconds),
            force: true,
            finished: true,
          ),
        );
      }
    }
    final remaining = durationSeconds - seconds;
    if (remaining <= 1) {
      final audio = pelevoAudioHandler;
      if (audio != null && audio.hasUpcoming) {
        return;
      }
      unawaited(_advanceQueue(finishedId: episodeId));
    }
  }

  Future<void> _advanceQueue({String? finishedId}) async {
    final handler = pelevoAudioHandler;
    if (handler != null && handler.hasUpcoming) {
      return;
    }
    final finishedEpisodeId = finishedId ?? _activeEpisode?.id;
    if (finishedEpisodeId != null && _queueAdvancedId == finishedEpisodeId) {
      return;
    }
    if (_advancingQueue) return;
    _advancingQueue = true;
    if (finishedEpisodeId != null) {
      _queueAdvancedId = finishedEpisodeId;
    }
    try {
      final finished = _activeEpisode;
      if (finished != null) {
        final handler = pelevoAudioHandler;
        final duration =
            finished.durationSeconds ?? handler?.duration?.inSeconds ?? 0;
        final position =
            duration > 0 ? duration : handler?.position.inSeconds ?? 0;
        await saveProgress(
          finished,
          positionSeconds: position,
          force: true,
          finished: true,
        );
        unawaited(_syncSession(episodeId: finished.id, playing: false));
      }

      final repo = _ref.read(catalogRepositoryProvider);
      CatalogQueue? queue;
      try {
        queue = await repo.queue(CancelToken());
      } catch (_) {
        queue = _ref.read(catalogQueueProvider).asData?.value;
      }
      if (queue == null) {
        await _stopAtEnd();
        return;
      }

      final upcoming = [
        for (final item in queue.items)
          if (item.episode.id != finishedEpisodeId) item,
      ];
      if (finishedEpisodeId != null) {
        await _removeFromQueue(repo, finishedEpisodeId);
      }
      if (upcoming.isEmpty) {
        _ref.invalidate(catalogQueueProvider);
        await _stopAtEnd();
        return;
      }

      try {
        await pelevoAudioHandler?.stop();
      } catch (_) {}

      for (final item in upcoming) {
        try {
          final next = await repo.episode(item.episode.id, CancelToken());
          _ref.read(selectedEpisodeIdProvider.notifier).select(next.id);
          if (next.showId.isNotEmpty) {
            _ref.read(selectedShowIdProvider.notifier).select(next.showId);
          }
          await playEpisode(next);
          await _removeFromQueue(repo, next.id);
          _ref.invalidate(catalogQueueProvider);
          return;
        } catch (_) {
          // Skip items that cannot be loaded and try the following episode.
        }
      }
      await _stopAtEnd();
    } finally {
      _advancingQueue = false;
    }
  }

  Future<void> _primeUpcomingQueue(String currentId) async {
    try {
      final repo = _ref.read(catalogRepositoryProvider);
      CatalogQueue? queue = _ref.read(catalogQueueProvider).asData?.value;
      try {
        queue = await repo.queue(CancelToken());
      } catch (_) {}
      if (queue == null) {
        return;
      }
      final tracks = <PelevoQueuedAudio>[];
      for (final item in queue.items) {
        if (item.episode.id == currentId) {
          continue;
        }
        var episode = item.episode;
        if (episode.audioUrl == null || episode.audioUrl!.isEmpty) {
          try {
            episode = await repo.episode(episode.id, CancelToken());
          } catch (_) {
            continue;
          }
        }
        final local = await _ref
            .read(downloadFileServiceProvider)
            .localPath(episode.id);
        final audio = local ?? episode.audioUrl;
        if (audio == null || audio.isEmpty) {
          continue;
        }
        _primedEpisodes[episode.id] = episode;
        tracks.add(
          PelevoQueuedAudio(
            episodeId: episode.id,
            title: episode.title,
            showId: episode.showId,
            showTitle: episode.showTitle,
            artworkUrl: episode.artworkUrl,
            durationSeconds: episode.durationSeconds,
            audioUri: local != null ? Uri.file(local) : Uri.parse(audio),
            headers: _mediaHeaders(audioUri: audio, isLocal: local != null),
          ),
        );
        if (tracks.length >= 8) {
          break;
        }
      }
      await pelevoAudioHandler?.primeUpcoming(tracks);
    } catch (_) {}
  }

  Future<void> _onHandlerAdvanced(String fromId, String toId) async {
    _queueAdvancedId = fromId;
    final finished = _primedEpisodes[fromId] ?? _activeEpisode;
    final next = _primedEpisodes[toId];
    if (next == null) {
      return;
    }
    _setNowPlaying(next);
    final handler = pelevoAudioHandler;
    if (handler != null) {
      _listenForPosition(handler, next.id);
    }
    _startProgressSync(next);
    _progressCompletedId = null;
    _ref.read(selectedEpisodeIdProvider.notifier).select(next.id);
    if (next.showId.isNotEmpty) {
      _ref.read(selectedShowIdProvider.notifier).select(next.showId);
    }
    if (finished != null) {
      final duration =
          finished.durationSeconds ?? handler?.duration?.inSeconds ?? 0;
      unawaited(
        saveProgress(
          finished,
          positionSeconds: duration > 0 ? duration : 1,
          force: true,
          finished: true,
        ),
      );
      unawaited(
        _removeFromQueue(_ref.read(catalogRepositoryProvider), finished.id),
      );
    }
    unawaited(_syncSession(episodeId: next.id, playing: true));
    _ref.invalidate(catalogQueueProvider);
    unawaited(_primeUpcomingQueue(next.id));
  }

  Future<void> _stopAtEnd() async {
    _progressTimer?.cancel();
    _progressKick?.cancel();
    try {
      final cast = _ref.read(pelevoCastControllerProvider);
      if (cast.isConnected) {
        await cast.pause();
      }
    } catch (_) {}
    final handler = pelevoAudioHandler;
    try {
      if (handler != null && handler.playing) {
        await handler.pause();
      }
    } catch (_) {}
    final finished = _activeEpisode;
    if (finished != null && !finished.completed) {
      _setNowPlaying(
        finished.copyWith(
          completed: true,
          played: true,
          positionSeconds: finished.durationSeconds ?? finished.positionSeconds,
        ),
      );
    }
  }

  Future<void> _removeFromQueue(
    CatalogRepository repo,
    String episodeId,
  ) async {
    try {
      var queue = await repo.queue(CancelToken());
      if (!queue.items.any((item) => item.episode.id == episodeId)) return;
      try {
        await repo.removeEpisodeFromQueue(episodeId, queue.version);
      } on ApiFailure catch (error) {
        if (error.code == 'NOT_FOUND') return;
        if (error.code != 'VERSION_CONFLICT') rethrow;
        queue = await repo.queue(CancelToken());
        if (!queue.items.any((item) => item.episode.id == episodeId)) return;
        await repo.removeEpisodeFromQueue(episodeId, queue.version);
      }
    } catch (_) {}
  }

  void _setNowPlaying(CatalogEpisode? episode) {
    _activeEpisode = episode;
    _ref.read(nowPlayingEpisodeProvider.notifier).set(episode);
  }

  /// Stops catalog progress writes so Earn can use the same audio engine
  /// without mixing playheads.
  Future<void> releaseForEarn() async {
    _progressTimer?.cancel();
    _progressKick?.cancel();
    _progressTimer = null;
    _progressKick = null;
    _activeEpisode = null;
    _ref.read(nowPlayingEpisodeProvider.notifier).set(null);
  }

  void _startProgressSync(CatalogEpisode episode) {
    _progressTimer?.cancel();
    _progressKick?.cancel();
    Future<void> tick({bool force = false}) async {
      final cast = _ref.read(pelevoCastControllerProvider);
      if (cast.isConnected) {
        if (!cast.isPlaying) return;
        final active = _activeEpisode;
        if (active == null || active.id != episode.id) return;
        await saveProgress(
          active,
          positionSeconds: cast.position.inSeconds,
          force: force,
        );
        return;
      }
      final handler = pelevoAudioHandler;
      if (handler == null) return;
      final active = _activeEpisode;
      if (active == null || active.id != episode.id) return;
      if (!handler.playing) {
        final duration =
            active.durationSeconds ?? handler.duration?.inSeconds ?? 0;
        if (force && _isCompleted(handler.position.inSeconds, duration)) {
          await saveProgress(
            active,
            positionSeconds: handler.position.inSeconds,
            force: true,
            finished: true,
          );
        }
        return;
      }
      await saveProgress(
        active,
        positionSeconds: handler.position.inSeconds,
        force: force,
      );
    }

    _progressKick = Timer(const Duration(seconds: 1), () {
      unawaited(tick(force: true));
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(tick());
    });
  }

  void _rememberContinueListening(
    CatalogEpisode episode, {
    required int positionSeconds,
    required bool completed,
  }) {
    final memory = _ref.read(continueListeningMemoryProvider.notifier);
    if (completed || positionSeconds <= 0) {
      memory.remove(episode.id);
      return;
    }
    memory.upsert(
      HomeItem(
        id: episode.id,
        type: 'episode',
        title: episode.title,
        showId: episode.showId,
        showTitle: episode.showTitle,
        artworkUrl: episode.artworkUrl,
        durationSeconds: episode.durationSeconds,
        positionSeconds: positionSeconds,
      ),
    );
  }

  Future<void> saveProgress(
    CatalogEpisode episode, {
    required int positionSeconds,
    bool force = false,
    bool finished = false,
  }) async {
    final owner = _ref.read(authSessionProvider).userId;
    if (owner == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastSavedAt != null &&
        now.difference(_lastSavedAt!) < const Duration(seconds: 4) &&
        positionSeconds > 1) {
      return;
    }
    _lastSavedAt = now;
    try {
      final repo = _ref.read(catalogRepositoryProvider);
      var version = await _versionFor(episode.id, owner);
      final handler = pelevoAudioHandler;
      final handlerMatches = handler?.mediaItem.value?.id == episode.id;
      final duration =
          episode.durationSeconds ??
          (handlerMatches ? handler?.duration?.inSeconds : null) ??
          0;
      final clamped =
          duration > 0 ? positionSeconds.clamp(0, duration) : positionSeconds;
      final completed = finished || _isCompleted(clamped, duration);
      _rememberContinueListening(
        episode,
        positionSeconds: clamped,
        completed: completed,
      );

      Future<CatalogPlayback> put(int v) => repo.savePlayback(
        episode.id,
        owner,
        positionSeconds: clamped,
        completed: completed,
        version: v,
      );

      CatalogPlayback saved;
      try {
        saved = await put(version);
      } on ApiFailure catch (error) {
        if (!_isVersionConflict(error)) rethrow;
        version = (await _playbackFor(episode.id, owner)).version;
        saved = await put(version);
      }

      _playbackVersions[episode.id] = saved.version;
      _rememberContinueListening(
        episode,
        positionSeconds: saved.positionSeconds,
        completed: saved.completed,
      );
      if (saved.completed) {
        _progressCompletedId ??= episode.id;
        final current = _ref.read(nowPlayingEpisodeProvider);
        if (current?.id == episode.id && current?.completed != true) {
          _setNowPlaying(
            current!.copyWith(
              completed: true,
              played: true,
              positionSeconds: saved.positionSeconds,
            ),
          );
        } else if (_activeEpisode?.id == episode.id &&
            _activeEpisode?.completed != true) {
          _setNowPlaying(
            _activeEpisode!.copyWith(
              completed: true,
              played: true,
              positionSeconds: saved.positionSeconds,
            ),
          );
        }
      }
      _ref.invalidate(catalogPlaybackByIdProvider(episode.id));
      if (_ref.read(selectedEpisodeIdProvider) == episode.id) {
        _ref.invalidate(catalogPlaybackProvider);
      }
      // Do not refetch episode/home on periodic progress saves — that rebuilds
      // the now-playing screen into a loading state while audio continues.
      if (saved.completed) {
        _ref.invalidate(catalogEpisodeByIdProvider(episode.id));
        if (_ref.read(selectedEpisodeIdProvider) == episode.id) {
          _ref.invalidate(catalogEpisodeProvider);
        }
        _ref.invalidate(homeFeedProvider);
        _ref.invalidate(libraryRecentProvider);
        _ref.invalidate(catalogLibraryRecentProvider);
      }
      try {
        _ref
            .read(catalogEpisodesProvider.notifier)
            .markListened(
              episode.id,
              positionSeconds: saved.positionSeconds,
              completed: saved.completed,
            );
      } catch (_) {}
    } on DioException {
      // Keep local playback even if progress sync fails.
    } on ApiFailure {
      // Keep local playback even if progress sync fails.
    } catch (_) {}
  }

  Future<void> _syncSession({
    required String episodeId,
    required bool playing,
    double? rate,
  }) async {
    try {
      final repo = _ref.read(catalogRepositoryProvider);
      var version = _sessionVersion;
      if (version == null) {
        try {
          final session = await _ref.read(catalogPlayerSessionProvider.future);
          version = session.version;
          rate ??= session.playbackRate;
        } catch (_) {
          version = 0;
          rate ??= 1;
        }
      }
      rate ??= 1;

      Future<CatalogPlayerSession> patch(int v) => repo.savePlayerSession(
        episodeId: episodeId,
        playing: playing,
        playbackRate: rate!,
        version: v,
      );

      CatalogPlayerSession saved;
      try {
        saved = await patch(version);
      } on ApiFailure catch (error) {
        if (!_isVersionConflict(error)) rethrow;
        final fresh = await repo.playerSession(CancelToken());
        saved = await patch(fresh.version);
      }
      _sessionVersion = saved.version;
      _ref.invalidate(catalogPlayerSessionProvider);
    } on DioException {
      // Local playback continues even if session sync fails.
    } on ApiFailure {
      // Local playback continues even if session sync fails.
    }
  }

  Future<double> _playbackRate() async {
    final cached = _ref.read(catalogPlayerSessionProvider).asData?.value;
    if (cached != null) return cached.playbackRate;
    try {
      return (await _ref.read(
        catalogPlayerSessionProvider.future,
      )).playbackRate;
    } catch (_) {
      return 1;
    }
  }

  Future<int> _versionFor(String episodeId, String owner) async {
    final cached = _playbackVersions[episodeId];
    if (cached != null) return cached;
    final selected = _ref.read(selectedEpisodeIdProvider);
    if (selected == episodeId) {
      final fromProvider = _ref.read(catalogPlaybackProvider).asData?.value;
      if (fromProvider != null) {
        _playbackVersions[episodeId] = fromProvider.version;
        return fromProvider.version;
      }
    }
    final playback = await _playbackFor(episodeId, owner);
    return playback.version;
  }

  Future<CatalogPlayback> _playbackFor(String episodeId, String owner) async {
    final playback = await _ref
        .read(catalogRepositoryProvider)
        .playback(episodeId, owner, CancelToken());
    _playbackVersions[episodeId] = playback.version;
    return playback;
  }

  /// Identifies Pelevo on every remote media request. Authorization is only
  /// attached for first-party hosts so third-party CDNs are not sent tokens.
  Map<String, String>? _mediaHeaders({
    required String audioUri,
    required bool isLocal,
  }) {
    final session = _ref.read(authSessionProvider);
    final device = session.deviceId;
    return PelevoUserAgent.playbackHeaders(
      userAgent: _ref.read(pelevoUserAgentProvider),
      audioUri: audioUri,
      isLocal: isLocal,
      isWeb: kIsWeb,
      accessToken: session.accessToken,
      deviceId:
          (device != null && device.isNotEmpty)
              ? device
              : _ref.read(installationIdProvider),
    );
  }

  bool _isCompleted(int positionSeconds, int durationSeconds) {
    if (positionSeconds <= 0) return false;
    if (durationSeconds < 30) return false;
    final remaining = durationSeconds - positionSeconds;
    return remaining <= 15 ||
        positionSeconds >= (durationSeconds * 0.95).floor();
  }

  bool _isVersionConflict(ApiFailure error) =>
      error.code == 'VERSION_CONFLICT' || error.statusCode == 409;
}

final pelevoPlaybackControllerProvider = Provider(
  (ref) => PelevoPlaybackController(ref),
);
