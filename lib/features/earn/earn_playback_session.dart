import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/earn/earn_catalog_data.dart';
import 'package:pelevo/features/earn/earn_integrity.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Isolated earn playback. It never writes the general player's progress.
class EarnPlaybackSession extends ChangeNotifier {
  EarnPlaybackSession._() {
    WidgetsBinding.instance.addObserver(_lifecycle);
    unawaited(_restorePlayheads());
  }

  static final EarnPlaybackSession instance = EarnPlaybackSession._();
  static const lockDuration = Duration(hours: 72);
  static const _finalStretchSeconds = 10;
  static const _finalizeBackoff = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 750),
    Duration(seconds: 1),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 2),
  ];

  final AudioPlayer _localPlayer = AudioPlayer();
  final _EarnLifecycle _lifecycle = _EarnLifecycle();
  final Map<String, Duration> _progress = {};
  final Map<String, int> _mediaDurationSeconds = {};
  final Map<String, DateTime> _lockedUntil = {};
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<double>? _speedSub;
  Timer? _evidenceTimer;
  var _guardingSeek = false;
  var _applyingResume = false;
  String? _loadedEpisodeId;
  EarnCatalogRepository? _repository;
  String? _deviceId;
  String? _completeKey;
  var _sequence = 0;
  var _verifiedPosition = 0;
  var _completing = false;
  var _transporting = false;
  var _syncFailures = 0;
  var _heartbeatInFlight = false;
  var _closing = false;
  DateTime? _lastEvidenceAt;
  DateTime? _seekGraceUntil;

  int get walletCoins => 0;
  String? activeEpisodeId;

  /// Live engine state. The stored [playing] flag can lag a notification tap.
  bool get isPlaying {
    final handler = pelevoAudioHandler;
    if (handler != null && handler.earnMode && _loadedEpisodeId != null) {
      return handler.playing;
    }
    if (handler == null && _loadedEpisodeId != null) {
      return _localPlayer.playing;
    }
    return false;
  }

  bool get _engineReady {
    final handler = pelevoAudioHandler;
    if (_loadedEpisodeId == null) return false;
    if (handler != null) {
      return handler.earnMode && handler.audioSource != null;
    }
    return _localPlayer.audioSource != null;
  }

  EarnEpisode? activeEpisode;
  bool playing = false;
  bool busy = false;
  bool finalizing = false;
  bool _engineWaiting = false;
  bool pendingWalletRefresh = false;

  /// Audio is being fetched or buffered, so the listener should wait.
  bool get buffering =>
      !finalizing && !playing && (busy || _transporting || _engineWaiting);
  String? lastError;
  Object? status;
  EarnSessionStart? serverSession;

  Duration progressFor(String episodeId) =>
      _progress[episodeId] ?? Duration.zero;

  Duration durationFor(EarnEpisode episode) =>
      Duration(seconds: _requiredSeconds(episode));

  bool isLocked(String episodeId, {DateTime? now}) {
    final until = _lockedUntil[episodeId];
    if (until == null) return false;
    return (now ?? DateTime.now()).isBefore(until);
  }

  Duration? lockRemaining(String episodeId, {DateTime? now}) {
    final until = _lockedUntil[episodeId];
    if (until == null) return null;
    final left = until.difference(now ?? DateTime.now());
    return left.isNegative ? null : left;
  }

  static int coinsForDuration(Duration duration) {
    final minutes = duration.inSeconds / 60;
    if (minutes < 10) return 1;
    if (minutes < 20) return 2;
    return 3;
  }

  void releaseUncreditedLock(String episodeId) {
    if (_lockedUntil.remove(episodeId) != null) notifyListeners();
  }

  void lockUntil(String episodeId, DateTime until) {
    _lockedUntil[episodeId] = until;
    _progress.remove(episodeId);
    _mediaDurationSeconds.remove(episodeId);
    playing = false;
    _evidenceTimer?.cancel();
    unawaited(_stopEngine());
    unawaited(_forgetPlayhead(episodeId));
    notifyListeners();
  }

  void openEpisode(String episodeId) {
    activeEpisodeId = episodeId;
    if (_loadedEpisodeId != null && _loadedEpisodeId != episodeId) {
      unawaited(pause());
    }
    notifyListeners();
  }

  Future<void> toggle({
    required EarnEpisode episode,
    required EarnCatalogRepository repository,
    required String? deviceId,
  }) async {
    if (!episode.isLocked) releaseUncreditedLock(episode.id);
    if (isLocked(episode.id) || episode.isLocked) {
      lastError = 'This episode is locked for Earn.';
      status = const ApiFailure(
        code: 'EPISODE_LOCKED',
        message: 'This episode is locked for 72 hours and cannot be opened.',
      );
      notifyListeners();
      return;
    }
    _repository = repository;
    _deviceId = deviceId;
    activeEpisode = episode;
    activeEpisodeId = episode.id;
    if (isPlaying && _loadedEpisodeId == episode.id) {
      await pause();
      return;
    }
    if (_engineReady && _loadedEpisodeId == episode.id) {
      _clearSoftStatus();
      await _startEngine();
      _armEvidence(episode);
      if (serverSession == null) {
        unawaited(_ensureSession(episode));
      }
      return;
    }
    if (_transporting) return;
    _transporting = true;
    notifyListeners();
    try {
      await playVerified(
        episode: episode,
        repository: repository,
        deviceId: deviceId,
      );
    } finally {
      _transporting = false;
      notifyListeners();
    }
  }

  Future<void> playVerified({
    required EarnEpisode episode,
    required EarnCatalogRepository repository,
    required String? deviceId,
  }) async {
    lastError = null;
    if (!episode.isLocked) releaseUncreditedLock(episode.id);
    if (isLocked(episode.id) || episode.isLocked) {
      lastError = 'This episode is locked for Earn.';
      status = const ApiFailure(
        code: 'EPISODE_LOCKED',
        message: 'This episode is locked for 72 hours and cannot be opened.',
      );
      notifyListeners();
      return;
    }
    busy = true;
    status = null;
    notifyListeners();
    _repository = repository;
    _deviceId = deviceId;
    try {
      final sameServer =
          serverSession?.episodeId == episode.id ? serverSession : null;
      final started = sameServer ?? await repository.start(episode.id);
      serverSession = started;
      _completeKey ??=
          'earn-${started.id}-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final continuing = sameServer != null && _loadedEpisodeId == episode.id;
      if (!continuing) {
        _sequence = started.lastSequence ?? 0;
        _verifiedPosition = started.resumePosition ?? 0;
        _lastEvidenceAt = DateTime.now();
      } else if (started.resumePosition != null &&
          started.resumePosition! > _verifiedPosition) {
        _verifiedPosition = started.resumePosition!;
      }
      final resumeAt = Duration(seconds: _verifiedPosition);
      await playEpisode(episode, resumeAt: resumeAt);
      if (lastError != null) {
        throw ApiFailure(code: 'NO_AUDIO', message: lastError!);
      }
      _armEvidence(episode);
      busy = false;
      notifyListeners();
    } catch (error) {
      final failure = earnFailure(error);
      if (failure.code == 'EPISODE_LOCKED') {
        lockUntil(episode.id, DateTime.now().add(lockDuration));
      }
      if (failure.code == 'MODERATION_HOLD' ||
          failure.code == 'NOT_FOUND' ||
          failure.code == 'FORBIDDEN') {
        serverSession = null;
        _completeKey = null;
        _sequence = 0;
      }
      busy = false;
      status = failure;
      notifyListeners();
    }
  }

  Future<void> playEpisode(EarnEpisode episode, {Duration? resumeAt}) async {
    lastError = null;
    if (isLocked(episode.id)) {
      lastError = 'This episode is locked for Earn.';
      notifyListeners();
      return;
    }
    final url = episode.audioUrl;
    if (url == null || url.isEmpty) {
      lastError = 'This earn episode has no playable audio URL.';
      notifyListeners();
      return;
    }
    activeEpisode = episode;
    activeEpisodeId = episode.id;
    final handler = pelevoAudioHandler;
    final sameEngine =
        _loadedEpisodeId == episode.id &&
        (handler?.audioSource != null || _localPlayer.audioSource != null);
    final startAt = resumeAt ?? _progress[episode.id] ?? Duration.zero;
    if (!sameEngine) {
      await _bindEngine();
      _progress[episode.id] = startAt;
      _applyingResume = true;
      try {
        if (handler != null) {
          await handler.loadEpisode(
            episodeId: episode.id,
            title: episode.title,
            showId: episode.showId,
            showTitle: episode.showTitle,
            artworkUrl: episode.artworkUrl,
            durationSeconds: episode.durationSeconds,
            audioUri: Uri.parse(url),
            position: startAt,
            earn: true,
          );
        } else {
          await _configureLocalSession();
          await _localPlayer.setUrl(url);
          if (startAt > Duration.zero) {
            _applyingResume = true;
            await _localPlayer.seek(startAt);
            _applyingResume = false;
          }
          try {
            await _localPlayer.setSpeed(1);
          } on Object {
            // A speed failure must not pretend the episode started.
          }
        }
        _loadedEpisodeId = episode.id;
        _applyingResume = false;
      } on Object catch (error) {
        _applyingResume = false;
        lastError = 'Could not load episode audio. ${error.toString()}';
        playing = false;
        notifyListeners();
        return;
      }
    } else if ((startAt - (_progress[episode.id] ?? Duration.zero)).inSeconds
            .abs() >
        2) {
      _applyingResume = true;
      if (handler != null) {
        await handler.seekWithinEarn(startAt);
      } else {
        await _localPlayer.seek(startAt);
      }
      _progress[episode.id] = startAt;
      _applyingResume = false;
    }
    try {
      await _startEngine();
    } on Object catch (error) {
      lastError = 'Playback failed. ${error.toString()}';
      playing = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (playing) unawaited(pause());
  }

  Future<void> pause() async {
    _evidenceTimer?.cancel();
    final handler = pelevoAudioHandler;
    if (handler != null && handler.earnMode) {
      await handler.pause();
    } else {
      await _localPlayer.pause();
    }
    playing = false;
    _clearSoftStatus();
    notifyListeners();
  }

  Future<void> _startEngine() async {
    _seekGraceUntil = DateTime.now().add(const Duration(seconds: 2));
    final handler = pelevoAudioHandler;
    if (handler != null && handler.earnMode) {
      await handler.play();
    } else {
      await playUntilAudible(_localPlayer);
    }
    playing = true;
    notifyListeners();
  }

  void stop() {
    playing = false;
    _evidenceTimer?.cancel();
    unawaited(_stopEngine());
    notifyListeners();
  }

  bool get audioActive {
    final handler = pelevoAudioHandler;
    if (handler != null && handler.earnMode && _loadedEpisodeId != null) {
      return handler.playing;
    }
    return _loadedEpisodeId != null && _localPlayer.playing;
  }

  Future<void> _bindEngine() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _stateSub?.cancel();
    await _speedSub?.cancel();
    final handler = pelevoAudioHandler;
    if (handler != null) {
      _positionSub = handler.positionStream.listen(_onPosition);
      _durationSub = handler.durationStream.listen(_onDuration);
      _stateSub = handler.playerStateStream.listen((state) {
        if (!handler.earnMode || _loadedEpisodeId == null) {
          if (playing) {
            playing = false;
            notifyListeners();
          }
          return;
        }
        _applyEngineState(state);
      });
      _speedSub = handler.speedStream.listen((speed) {
        if (handler.earnMode && (speed - 1).abs() > 0.01) {
          unawaited(handler.setSpeed(1));
        }
      });
      return;
    }
    _positionSub = _localPlayer.positionStream.listen(_onPosition);
    _durationSub = _localPlayer.durationStream.listen(_onDuration);
    _stateSub = _localPlayer.playerStateStream.listen(_applyEngineState);
    _speedSub = _localPlayer.speedStream.listen((speed) {
      if ((speed - 1).abs() > 0.01) {
        unawaited(_localPlayer.setSpeed(1));
      }
    });
  }

  void _onPosition(Duration position) {
    final id = activeEpisodeId;
    if (id == null || _guardingSeek || _applyingResume) return;
    final previous = _progress[id] ?? Duration.zero;
    final grace = _seekGraceUntil;
    if (grace != null && DateTime.now().isBefore(grace)) {
      final jumped = (position - previous).inMilliseconds.abs() > 5000;
      if (!jumped && position >= Duration.zero) {
        _progress[id] = position;
        notifyListeners();
      }
      return;
    }
    if (position < const Duration(seconds: 1) &&
        previous > const Duration(seconds: 2)) {
      return;
    }
    final deltaMs = position.inMilliseconds - previous.inMilliseconds;
    if (deltaMs < -1500) {
      return;
    }
    _progress[id] = position;
    final episode = activeEpisode;
    if (episode != null && episode.id == id && _reachedAward(episode)) {
      unawaited(_closeListen(episode));
    } else if (episode != null && episode.id == id && audioActive) {
      final remaining = _requiredSeconds(episode) - _cappedSeconds(episode);
      if (remaining <= _finalStretchSeconds) {
        unawaited(_sendHeartbeat(episode, tail: true));
      }
    }
    if (position.inSeconds % 5 == 0) {
      unawaited(_rememberPlayhead(id, position));
    }
    notifyListeners();
  }

  void _onDuration(Duration? duration) {
    final episode = activeEpisode;
    if (episode == null || duration == null || duration <= Duration.zero) {
      return;
    }
    final seconds = duration.inSeconds;
    if (seconds < episode.durationSeconds ||
        seconds <= (_mediaDurationSeconds[episode.id] ?? 0)) {
      return;
    }
    _mediaDurationSeconds[episode.id] = seconds;
    notifyListeners();
  }

  void _armEvidence(EarnEpisode episode) {
    _evidenceTimer?.cancel();
    _evidenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_sendHeartbeat(episode));
      unawaited(_maybeComplete(episode));
    });
  }

  void _applyEngineState(PlayerState state) {
    final ended = state.processingState == ProcessingState.completed;
    playing = state.playing && !ended;
    _engineWaiting =
        state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    final episode = activeEpisode;
    if (playing &&
        episode != null &&
        serverSession?.episodeId == episode.id &&
        !_closing &&
        !(_evidenceTimer?.isActive ?? false)) {
      _armEvidence(episode);
    }
    if (ended && episode != null) {
      final finalSeconds = progressFor(episode.id).inSeconds;
      final media = _mediaDurationSeconds[episode.id] ?? 0;
      if (media > finalSeconds) {
        _mediaDurationSeconds[episode.id] =
            finalSeconds > episode.durationSeconds
                ? finalSeconds
                : episode.durationSeconds;
      }
      unawaited(_closeListen(episode));
    }
    notifyListeners();
  }

  void bind({
    required EarnCatalogRepository repository,
    required String? deviceId,
  }) {
    _repository = repository;
    _deviceId = deviceId;
  }

  void reportFailure(Object error) {
    status = earnFailure(error);
    notifyListeners();
  }

  Future<void> finalize(EarnEpisode episode) => _closeListen(episode);

  Future<void> _closeListen(EarnEpisode episode) async {
    if (_closing || isLocked(episode.id)) return;
    if (serverSession == null) {
      _progress[episode.id] = Duration.zero;
      _verifiedPosition = 0;
      await _stopEngine();
      unawaited(_forgetPlayhead(episode.id));
      status = const ApiFailure(
        code: 'EARN_SESSION',
        message:
            'Playback ended without an active Earn session. Start this episode again to earn its reward.',
      );
      notifyListeners();
      return;
    }
    _closing = true;
    finalizing = true;
    _evidenceTimer?.cancel();
    status = 'Playback complete. Verifying your reward...';
    notifyListeners();
    try {
      for (var wait = 0; wait < 160 && _heartbeatInFlight; wait++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      for (var attempt = 0; attempt < _finalizeBackoff.length + 1; attempt++) {
        if (serverSession == null || isLocked(episode.id)) return;
        for (var burst = 0; burst < 12; burst++) {
          final before = _verifiedPosition;
          await _sendHeartbeat(episode, tail: true);
          if (serverSession == null || isLocked(episode.id)) return;
          if (_verifiedPosition <= before) break;
        }
        if (await _completeFromServer(episode, requireLocalEvidence: false)) {
          return;
        }
        if (serverSession == null || isLocked(episode.id)) return;
        final current = status;
        if (current is ApiFailure &&
            current.code != 'EARN_SYNC' &&
            current.code != 'UNEXPECTED' &&
            current.code != 'EARN_PENDING') {
          return;
        }
        if (attempt < _finalizeBackoff.length) {
          await Future<void>.delayed(_finalizeBackoff[attempt]);
        }
      }
      status = const ApiFailure(
        code: 'EARN_PENDING',
        message:
            'Playback is complete, but the final reward check is still pending. Tap Check reward to retry.',
      );
      notifyListeners();
    } finally {
      finalizing = false;
      _closing = false;
      notifyListeners();
    }
  }

  int _cappedSeconds(EarnEpisode episode) {
    final raw = progressFor(episode.id).inSeconds;
    final required = _requiredSeconds(episode);
    return raw > required ? required : raw;
  }

  bool _reachedAward(EarnEpisode episode) {
    final needed = _requiredSeconds(episode);
    return _cappedSeconds(episode) >= needed;
  }

  int _requiredSeconds(EarnEpisode episode) {
    final media = _mediaDurationSeconds[episode.id] ?? 0;
    return media > episode.durationSeconds ? media : episode.durationSeconds;
  }

  Future<void> _sendHeartbeat(EarnEpisode episode, {bool tail = false}) async {
    if (_heartbeatInFlight) return;
    final started = serverSession;
    final repository = _repository;
    final device = _deviceId;
    if (started == null ||
        repository == null ||
        device == null ||
        device.isEmpty) {
      return;
    }
    if ((!audioActive && !tail) || started.episodeId != episode.id) return;
    _heartbeatInFlight = true;
    var sentSequence = _sequence;
    try {
      final live = _cappedSeconds(episode);
      final unverified = live - _verifiedPosition;
      final minimum = tail ? 1 : 5;
      if (unverified < minimum) return;
      if (_lastEvidenceAt == null) return;
      final claimed = unverified > 30 ? 30 : unverified;
      final reported = _verifiedPosition + claimed;
      _sequence += 1;
      sentSequence = _sequence;
      final mediaDuration = _requiredSeconds(episode);
      final integrityToken = await EarnIntegrity.token(
        deviceId: device,
        sessionId: started.id,
        sequence: sentSequence,
        nonce: started.nonce,
        position: reported,
        elapsedSeconds: claimed,
        mediaDurationSeconds: mediaDuration,
      );
      final result = await repository.heartbeat(
        sessionId: started.id,
        position: reported,
        sequence: sentSequence,
        elapsedSeconds: claimed,
        mediaDurationSeconds: mediaDuration,
        nonce: started.nonce,
        integrityToken: integrityToken,
        foreground: _lifecycle.foreground,
        audioActive: true,
      );
      _verifiedPosition = result.verifiedSeconds ?? reported;
      final serverRequired = result.requiredSeconds;
      if (serverRequired != null &&
          serverRequired > (_mediaDurationSeconds[episode.id] ?? 0)) {
        _mediaDurationSeconds[episode.id] = serverRequired;
      }
      _lastEvidenceAt = DateTime.now();
      _syncFailures = 0;
      _clearSoftStatus();
      final award = result.award;
      if (award != null) {
        _acceptAward(episode, award);
        return;
      }
      unawaited(_maybeComplete(episode));
    } catch (error) {
      if (_sequence == sentSequence) _sequence = sentSequence - 1;
      final failure = earnFailure(error);
      if (failure.code == 'CANCELLED') return;
      if (failure.code == 'EARN_RESYNC') {
        final sequence = int.tryParse(failure.fields['last_sequence'] ?? '');
        final position = int.tryParse(failure.fields['last_position'] ?? '');
        if (sequence != null) _sequence = sequence;
        if (position != null && position > _verifiedPosition) {
          _verifiedPosition = position;
        }
        return;
      }
      if (failure.code == 'NOT_FOUND' && finalizing) {
        return;
      }
      final blocking =
          failure.code == 'MODERATION_HOLD' ||
          failure.code == 'NOT_FOUND' ||
          failure.code == 'EPISODE_LOCKED' ||
          failure.code == 'FORBIDDEN';
      if (!blocking) {
        _syncFailures += 1;
        if (_syncFailures >= 3 && audioActive) {
          status = const ApiFailure(
            code: 'EARN_SYNC',
            message: 'Still playing. Coin sync will keep trying.',
          );
          notifyListeners();
        }
        return;
      }
      serverSession = null;
      _completeKey = null;
      _sequence = 0;
      await pause();
      status = failure;
      notifyListeners();
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> _maybeComplete(EarnEpisode episode) async {
    await _completeFromServer(episode);
  }

  Future<bool> _completeFromServer(
    EarnEpisode episode, {
    bool requireLocalEvidence = true,
  }) async {
    final started = serverSession;
    final key = _completeKey;
    final repository = _repository;
    if (started == null || key == null || repository == null || _completing) {
      return false;
    }
    final needed = _requiredSeconds(episode);
    if (requireLocalEvidence &&
        (_cappedSeconds(episode) < needed || _verifiedPosition < needed)) {
      return false;
    }
    _completing = true;
    try {
      final award = await repository.complete(
        sessionId: started.id,
        idempotencyKey: key,
      );
      _acceptAward(episode, award);
      return true;
    } catch (error) {
      final failure = earnFailure(error);
      if (failure.code == 'EPISODE_LOCKED') {
        lockUntil(episode.id, DateTime.now().add(lockDuration));
        return true;
      }
      final notEnough =
          failure.code == 'MODERATION_HOLD' &&
          failure.message.contains('Not enough verified');
      if (!notEnough &&
          failure.code != 'CANCELLED' &&
          failure.code != 'EARN_SYNC' &&
          failure.code != 'UNEXPECTED') {
        await pause();
        status = failure;
        notifyListeners();
      }
      return false;
    } finally {
      _completing = false;
    }
  }

  void _acceptAward(EarnEpisode episode, EarnAward award) {
    serverSession = null;
    _completeKey = null;
    pendingWalletRefresh = true;
    status =
        'Awarded ${award.coins} coins. This episode is locked for 72 hours.';
    lockUntil(episode.id, award.lockedUntil);
  }

  Future<void> _ensureSession(EarnEpisode episode) async {
    final repository = _repository;
    if (repository == null || serverSession?.episodeId == episode.id) return;
    try {
      final started = await repository.start(episode.id);
      if (activeEpisodeId != episode.id) return;
      serverSession = started;
      _completeKey ??=
          'earn-${started.id}-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      _sequence = started.lastSequence ?? 0;
      _verifiedPosition = started.resumePosition ?? 0;
      _lastEvidenceAt = DateTime.now();
      _armEvidence(episode);
      _clearSoftStatus();
      notifyListeners();
    } catch (error) {
      if (!isPlaying) {
        status = earnFailure(error);
        notifyListeners();
      }
    }
  }

  void _clearSoftStatus() {
    final current = status;
    if (current is ApiFailure &&
        (current.code == 'EARN_SYNC' || current.code == 'UNEXPECTED')) {
      status = null;
    }
  }

  Future<void> _stopEngine() async {
    final handler = pelevoAudioHandler;
    if (handler != null && handler.earnMode) {
      await handler.stop();
    } else {
      await _localPlayer.stop();
    }
    _loadedEpisodeId = null;
  }

  Future<void> _configureLocalSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } on Object {
      // Tests and hosts without an audio session still play in the foreground.
    }
  }

  Future<void> _restorePlayheads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('earn_playhead_')) continue;
        final seconds = prefs.getInt(key);
        if (seconds == null || seconds <= 0) continue;
        final id = key.substring('earn_playhead_'.length);
        _progress.putIfAbsent(id, () => Duration(seconds: seconds));
      }
      notifyListeners();
    } on Object {
      // Playhead restore is optional.
    }
  }

  Future<void> _rememberPlayhead(String id, Duration position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('earn_playhead_$id', position.inSeconds);
    } on Object {
      // The in-memory playhead still resumes this session.
    }
  }

  Future<void> _forgetPlayhead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('earn_playhead_$id');
    } on Object {
      // Clearing a saved playhead is optional after the lock is stored.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycle);
    _evidenceTimer?.cancel();
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_speedSub?.cancel());
    unawaited(_localPlayer.dispose());
    super.dispose();
  }
}

class _EarnLifecycle with WidgetsBindingObserver {
  bool foreground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }
}
