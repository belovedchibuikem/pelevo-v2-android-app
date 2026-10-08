import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';

/// Next-up episode the native player can continue without a Dart round-trip.
class PelevoQueuedAudio {
  const PelevoQueuedAudio({
    required this.episodeId,
    required this.title,
    required this.audioUri,
    this.showId,
    this.showTitle,
    this.artworkUrl,
    this.durationSeconds,
    this.headers,
  });

  final String episodeId;
  final String title;
  final String? showId;
  final String? showTitle;
  final String? artworkUrl;
  final int? durationSeconds;
  final Uri audioUri;
  final Map<String, String>? headers;
}

/// Background audio handler that drives Android/iOS lock-screen media controls.
class PelevoAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  PelevoAudioHandler({String? userAgent})
    : _player = AudioPlayer(
        userAgent: userAgent ?? PelevoUserAgent.current,
        useProxyForRequestHeaders: false,
      ) {
    _player.playbackEventStream.listen(_broadcastState);
    _player.currentIndexStream.listen(_onCurrentIndex);
    _player.processingStateStream.distinct().listen((state) {
      if (state == ProcessingState.completed && !hasUpcoming) {
        _ended.add(null);
      }
    });
  }

  /// Fires when the last queued item reaches the end.
  Stream<void> get completedStream => _ended.stream;

  /// Fires when native playback moves to the next cached queue item.
  Stream<(String, String)> get queueAdvancedStream => _advanced.stream;

  final AudioPlayer _player;
  bool earnMode = false;
  final _ended = StreamController<void>.broadcast();
  final _advanced = StreamController<(String, String)>.broadcast();
  final List<PelevoQueuedAudio> _playlist = [];
  ConcatenatingAudioSource? _concat;
  int? _lastIndex;
  int _skipSeconds = 30;
  int get skipSeconds => _skipSeconds;
  set skipSeconds(int value) => _skipSeconds = value.clamp(5, 60);

  bool get hasUpcoming {
    final index = _player.currentIndex ?? 0;
    return index + 1 < _playlist.length;
  }

  Future<void> ensureSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration.speech().copyWith(
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp |
            AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.longFormAudio,
      ),
    );
  }

  Future<void> loadEpisode({
    required String episodeId,
    required String title,
    required Uri audioUri,
    String? showId,
    String? showTitle,
    String? artworkUrl,
    int? durationSeconds,
    Duration? position,
    Map<String, String>? headers,
    double speed = 1,
    bool earn = false,
  }) async {
    earnMode = earn;
    await ensureSession();
    final current = PelevoQueuedAudio(
      episodeId: episodeId,
      title: title,
      showId: showId,
      showTitle: showTitle,
      artworkUrl: artworkUrl,
      durationSeconds: durationSeconds,
      audioUri: audioUri,
      headers: headers,
    );
    _playlist
      ..clear()
      ..add(current);
    _lastIndex = 0;
    _applyMediaItem(current);
    _concat = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: [AudioSource.uri(audioUri, headers: headers)],
    );
    await _player.setAudioSource(
      _concat!,
      initialPosition: position ?? Duration.zero,
    );
    await _player.setSpeed(earn ? 1 : speed);
    final duration = _player.duration;
    if (duration != null) {
      _applyMediaItem(current, duration: duration);
    }
  }

  Future<void> primeUpcoming(List<PelevoQueuedAudio> tracks) async {
    final concat = _concat;
    if (concat == null) {
      return;
    }
    final known = {for (final track in _playlist) track.episodeId};
    for (final track in tracks) {
      if (known.contains(track.episodeId)) {
        continue;
      }
      try {
        await concat.add(
          AudioSource.uri(track.audioUri, headers: track.headers),
        );
        _playlist.add(track);
        known.add(track.episodeId);
      } catch (_) {}
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    earnMode = false;
    _playlist.clear();
    _concat = null;
    _lastIndex = null;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    if (earnMode) return Future<void>.value();
    return _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(earnMode ? 1 : speed);

  @override
  Future<void> skipToNext() async {
    if (earnMode) return;
    if (hasUpcoming) {
      await _player.seekToNext();
      return;
    }
    await seek(_player.position + Duration(seconds: skipSeconds));
  }

  @override
  Future<void> skipToPrevious() async {
    if (earnMode) return;
    final index = _player.currentIndex ?? 0;
    if (index > 0) {
      await _player.seekToPrevious();
      return;
    }
    final next = _player.position - Duration(seconds: skipSeconds);
    await seek(next < Duration.zero ? Duration.zero : next);
  }

  Future<void> skipForward() =>
      seek(_player.position + Duration(seconds: skipSeconds));
  Future<void> skipBackward() => skipToPrevious();

  Stream<double> get speedStream => _player.speedStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  AudioSource? get audioSource => _player.audioSource;

  Future<void> seekWithinEarn(Duration position) => _player.seek(position);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;

  void _onCurrentIndex(int? index) {
    _broadcastState(_player.playbackEvent);
    if (index == null || index < 0 || index >= _playlist.length) {
      return;
    }
    final track = _playlist[index];
    _applyMediaItem(track, duration: _player.duration);
    final previous = _lastIndex;
    if (previous != null && index > previous && previous < _playlist.length) {
      _advanced.add((_playlist[previous].episodeId, track.episodeId));
    }
    _lastIndex = index;
  }

  void _applyMediaItem(PelevoQueuedAudio track, {Duration? duration}) {
    mediaItem.add(
      MediaItem(
        id: track.episodeId,
        title: track.title,
        album: track.showTitle,
        artUri:
            kIsWeb || track.artworkUrl == null || track.artworkUrl!.isEmpty
                ? null
                : Uri.tryParse(track.artworkUrl!),
        duration:
            duration ??
            (track.durationSeconds == null
                ? null
                : Duration(seconds: track.durationSeconds!)),
        extras: {'show_title': track.showTitle, 'show_id': track.showId},
      ),
    );
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls:
            earnMode
                ? [if (playing) MediaControl.pause else MediaControl.play]
                : [
                  MediaControl.skipToPrevious,
                  if (playing) MediaControl.pause else MediaControl.play,
                  MediaControl.skipToNext,
                  MediaControl.stop,
                ],
        systemActions:
            earnMode
                ? const {MediaAction.play, MediaAction.pause, MediaAction.stop}
                : const {
                  MediaAction.seek,
                  MediaAction.seekForward,
                  MediaAction.seekBackward,
                  MediaAction.skipToNext,
                  MediaAction.skipToPrevious,
                  MediaAction.play,
                  MediaAction.pause,
                  MediaAction.stop,
                },
        androidCompactActionIndices: earnMode ? const [0] : const [0, 1, 2],
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex ?? 0,
      ),
    );
  }

  Future<void> disposePlayer() async {
    await _ended.close();
    await _advanced.close();
    await _player.dispose();
  }
}

PelevoAudioHandler? _handler;

Future<PelevoAudioHandler> initPelevoAudioHandler() async {
  if (_handler != null) return _handler!;
  try {
    _handler = await AudioService.init(
      builder: () => PelevoAudioHandler(userAgent: PelevoUserAgent.current),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pelevo_playback',
        androidNotificationChannelName: 'Pelevo Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
        fastForwardInterval: Duration(seconds: 30),
        rewindInterval: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    // Widget/unit tests and unsupported hosts still get a local handler.
    _handler = PelevoAudioHandler(userAgent: PelevoUserAgent.current);
  }
  return _handler!;
}

PelevoAudioHandler? get pelevoAudioHandler => _handler;
