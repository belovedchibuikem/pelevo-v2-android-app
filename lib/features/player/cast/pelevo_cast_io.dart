import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_models.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

/// Android / iOS Google Cast backend.
class PelevoCastBackend {
  PelevoCastSnapshot _snapshot = PelevoCastSnapshot(
    supported: Platform.isAndroid || Platform.isIOS,
    ready: false,
    connected: false,
    playing: false,
  );
  final _controller = StreamController<PelevoCastSnapshot>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _nativeDevices = <String, GoogleCastDevice>{};
  StreamSubscription<List<GoogleCastDevice>>? _devicesSub;
  StreamSubscription<GoogleCastSession?>? _sessionSub;
  StreamSubscription<GoggleCastMediaStatus?>? _mediaSub;
  Future<void>? _initFuture;
  CastMediaPlayerState? _lastPlayerState;

  PelevoCastSnapshot get snapshot => _snapshot;

  Stream<PelevoCastSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  Stream<void> get completedStream => _completed.stream;

  void dispose() {
    _devicesSub?.cancel();
    _sessionSub?.cancel();
    _mediaSub?.cancel();
    _controller.close();
    _completed.close();
  }

  void _emit(PelevoCastSnapshot next) {
    _snapshot = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  Future<void> initialize() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _emit(PelevoCastSnapshot.unsupported);
      return;
    }
    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      final GoogleCastOptions options =
          Platform.isIOS
              ? IOSGoogleCastOptions(
                GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(
                  appId,
                ),
                stopCastingOnAppTerminated: true,
              )
              : GoogleCastOptionsAndroid(
                appId: appId,
                stopCastingOnAppTerminated: true,
              );
      await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      _devicesSub = GoogleCastDiscoveryManager.instance.devicesStream.listen((
        devices,
      ) {
        _nativeDevices
          ..clear()
          ..addEntries(devices.map((d) => MapEntry(d.deviceID, d)));
        _emit(
          _snapshot.copyWith(
            discovering: false,
            permissionDenied: false,
            clearStatusMessage: true,
            devices:
                devices
                    .map(
                      (d) => PelevoCastDevice(
                        id: d.deviceID,
                        name: d.friendlyName,
                        model: d.modelName,
                      ),
                    )
                    .toList(growable: false),
          ),
        );
      });
      _sessionSub = GoogleCastSessionManager.instance.currentSessionStream
          .listen((session) {
            final connected =
                GoogleCastSessionManager.instance.connectionState ==
                GoogleCastConnectState.connected;
            _emit(
              _snapshot.copyWith(
                connected: connected,
                deviceName: session?.device?.friendlyName,
                clearDeviceName: !connected,
                playing: connected ? _snapshot.playing : false,
              ),
            );
          });
      _mediaSub = GoogleCastRemoteMediaClient.instance.mediaStatusStream.listen((
        status,
      ) {
        final state = status?.playerState;
        final playing =
            state == CastMediaPlayerState.playing ||
            state == CastMediaPlayerState.buffering ||
            state == CastMediaPlayerState.loading;
        _emit(_snapshot.copyWith(playing: playing && _snapshot.connected));
        if (_snapshot.connected &&
            state == CastMediaPlayerState.idle &&
            _lastPlayerState != CastMediaPlayerState.idle &&
            status?.idleReason == GoogleCastMediaIdleReason.finished) {
          _completed.add(null);
        }
        _lastPlayerState = state;
      });
      _emit(_snapshot.copyWith(ready: true, supported: true));
      // Do not await discovery at startup — Cast scan can hang on some
      // devices and would freeze the native splash before runApp.
      unawaited(startDiscovery());
    } on Object catch (error) {
      _initFuture = null;
      _emit(
        _snapshot.copyWith(
          ready: false,
          statusMessage:
              'Chromecast could not start. ${error is ApiFailure ? error.message : 'Try again on Wi‑Fi.'}',
        ),
      );
      throw const ApiFailure(
        code: 'CAST_INIT',
        message:
            'Chromecast could not start on this device. Check Google Play Services and try again.',
      );
    }
  }

  Future<void> startDiscovery() async {
    if (!_snapshot.supported) return;
    if (!_snapshot.ready) await initialize();
    _emit(_snapshot.copyWith(discovering: true, permissionDenied: false));
    try {
      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } on Object {
      _emit(
        _snapshot.copyWith(
          discovering: false,
          statusMessage:
              'Could not scan for Cast devices. Stay on the same Wi‑Fi as your speaker.',
        ),
      );
    }
  }

  Future<void> stopDiscovery() async {
    if (!_snapshot.supported || !_snapshot.ready) return;
    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    } on Object {
      // Discovery stop is best-effort.
    }
    _emit(_snapshot.copyWith(discovering: false));
  }

  Future<void> connectAndPlay({
    required PelevoCastDevice device,
    required CatalogEpisode episode,
    required Uri contentUrl,
    Duration position = Duration.zero,
    double speed = 1,
  }) async {
    await initialize();
    final native = _nativeDevices[device.id];
    if (native == null) {
      throw const ApiFailure(
        code: 'CAST_DEVICE_GONE',
        message: 'That Cast device is no longer available. Refresh and try again.',
      );
    }
    final manager = GoogleCastSessionManager.instance;
    final alreadyOnDevice =
        manager.connectionState == GoogleCastConnectState.connected &&
        _snapshot.deviceName == device.name;
    if (!alreadyOnDevice) {
      final started = await manager.startSessionWithDevice(native);
      if (!started) {
        throw ApiFailure(
          code: 'CAST_CONNECT',
          message: 'Could not connect to ${device.name}.',
        );
      }
      await _waitUntilConnected();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await loadOnCurrentSession(
      episode: episode,
      contentUrl: contentUrl,
      position: position,
      speed: speed,
    );
    _emit(
      _snapshot.copyWith(
        connected: true,
        deviceName: device.name,
        playing: true,
        clearStatusMessage: true,
      ),
    );
  }

  Future<void> loadOnCurrentSession({
    required CatalogEpisode episode,
    required Uri contentUrl,
    Duration position = Duration.zero,
    double speed = 1,
  }) async {
    await initialize();
    await _waitUntilConnected();
    final art =
        episode.artworkUrl == null || episode.artworkUrl!.isEmpty
            ? null
            : Uri.tryParse(episode.artworkUrl!);
    final media = GoogleCastMediaInformation(
      contentId: contentUrl.toString(),
      streamType: CastMediaStreamType.buffered,
      contentType: _contentTypeFor(contentUrl),
      contentUrl: contentUrl,
      duration:
          episode.durationSeconds == null
              ? null
              : Duration(seconds: episode.durationSeconds!),
      metadata: GoogleCastMusicMediaMetadata(
        title: episode.title,
        albumName: episode.showTitle,
        artist: episode.showAuthor ?? episode.showTitle,
        images: art == null ? null : [GoogleCastImage(url: art)],
      ),
    );
    _lastPlayerState = CastMediaPlayerState.loading;
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      media,
      autoPlay: true,
      playPosition: position,
      playbackRate: speed,
    );
    _emit(
      _snapshot.copyWith(
        connected: true,
        playing: true,
        clearStatusMessage: true,
      ),
    );
  }

  Future<void> disconnect({bool stopCasting = true}) async {
    if (!_snapshot.ready) return;
    try {
      if (stopCasting) {
        await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      } else {
        await GoogleCastSessionManager.instance.endSession();
      }
    } on Object {
      // Session may already have ended.
    }
    _lastPlayerState = CastMediaPlayerState.idle;
    _emit(
      _snapshot.copyWith(
        connected: false,
        playing: false,
        clearDeviceName: true,
      ),
    );
  }

  Future<void> play() async {
    if (!_snapshot.connected) return;
    await GoogleCastRemoteMediaClient.instance.play();
  }

  Future<void> pause() async {
    if (!_snapshot.connected) return;
    await GoogleCastRemoteMediaClient.instance.pause();
  }

  Future<void> seek(Duration position) async {
    if (!_snapshot.connected) return;
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(position: position),
    );
  }

  Future<void> setSpeed(double speed) async {
    if (!_snapshot.connected) return;
    await GoogleCastRemoteMediaClient.instance.setPlaybackRate(speed);
  }

  Duration get position =>
      _snapshot.connected
          ? GoogleCastRemoteMediaClient.instance.playerPosition
          : Duration.zero;

  Stream<Duration> get positionStream =>
      GoogleCastRemoteMediaClient.instance.playerPositionStream;

  Future<void> _waitUntilConnected() async {
    final manager = GoogleCastSessionManager.instance;
    if (manager.connectionState == GoogleCastConnectState.connected) return;
    try {
      await manager.currentSessionStream
          .firstWhere(
            (_) => manager.connectionState == GoogleCastConnectState.connected,
          )
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw const ApiFailure(
        code: 'CAST_TIMEOUT',
        message:
            'Could not connect to the Cast device in time. Keep both devices on the same Wi‑Fi and try again.',
      );
    }
    if (manager.connectionState != GoogleCastConnectState.connected) {
      throw const ApiFailure(
        code: 'CAST_TIMEOUT',
        message:
            'Could not connect to the Cast device in time. Keep both devices on the same Wi‑Fi and try again.',
      );
    }
  }

  String _contentTypeFor(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.m4a') || path.endsWith('.mp4')) return 'audio/mp4';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (path.endsWith('.ogg') || path.endsWith('.opus')) return 'audio/ogg';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.flac')) return 'audio/flac';
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    return 'audio/mpeg';
  }
}

PelevoCastBackend createPelevoCastBackend() => PelevoCastBackend();
