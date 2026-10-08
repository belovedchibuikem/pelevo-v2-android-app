import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_models.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_permissions.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_stub.dart'
    if (dart.library.io) 'package:pelevo/features/player/cast/pelevo_cast_io.dart'
    as cast_impl;
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

export 'package:pelevo/features/player/cast/pelevo_cast_models.dart';

final _castBackend = cast_impl.createPelevoCastBackend();

final pelevoCastBackendProvider = Provider<cast_impl.PelevoCastBackend>((ref) {
  return _castBackend;
});

final pelevoCastSnapshotProvider =
    StreamProvider.autoDispose<PelevoCastSnapshot>((ref) {
      final backend = ref.watch(pelevoCastBackendProvider);
      return backend.snapshots;
    });

/// Initializes Google Cast on supported mobile platforms. Safe to call on web.
Future<void> initPelevoCast() => _castBackend.initialize();

class PelevoCastController {
  PelevoCastController(this._ref);
  final Ref _ref;

  cast_impl.PelevoCastBackend get _backend =>
      _ref.read(pelevoCastBackendProvider);

  PelevoCastSnapshot get snapshot => _backend.snapshot;

  bool get isConnected => snapshot.connected;

  bool get isPlaying => snapshot.playing;

  Future<void> ensureReady() => _backend.initialize();

  Future<void> refreshDevices() async {
    final allowed = await ensureCastDiscoveryPermissions();
    if (!allowed) {
      throw const ApiFailure(
        code: 'CAST_PERMISSION',
        message:
            'Allow Nearby devices (or Location on older Android) so Pelevo can find Chromecast speakers on your Wi‑Fi.',
      );
    }
    await _backend.initialize();
    await _backend.startDiscovery();
  }

  Future<void> castEpisode(
    PelevoCastDevice device,
    CatalogEpisode episode,
  ) async {
    final uri = _publicAudioUri(episode);
    await _backend.initialize();
    final handler = pelevoAudioHandler;
    final position = handler?.position ?? Duration.zero;
    final speed =
        (await _ref.read(catalogPlayerSessionProvider.future)).playbackRate;

    if (handler != null && handler.playing) {
      await handler.pause();
    }

    await _backend.connectAndPlay(
      device: device,
      episode: episode,
      contentUrl: uri,
      position: position,
      speed: speed,
    );
  }

  Future<void> playOnConnectedSession(
    CatalogEpisode episode, {
    Duration position = Duration.zero,
    double speed = 1,
  }) async {
    if (!isConnected) {
      throw const ApiFailure(
        code: 'CAST_DISCONNECTED',
        message: 'Connect to a Cast device first.',
      );
    }
    final uri = _publicAudioUri(episode);
    final handler = pelevoAudioHandler;
    if (handler != null && handler.playing) {
      await handler.pause();
    }
    await _backend.loadOnCurrentSession(
      episode: episode,
      contentUrl: uri,
      position: position,
      speed: speed,
    );
  }

  Future<void> disconnect({bool stopCasting = true}) =>
      _backend.disconnect(stopCasting: stopCasting);

  Future<void> play() => _backend.play();

  Future<void> pause() => _backend.pause();

  Future<void> seek(Duration position) => _backend.seek(position);

  Future<void> setSpeed(double speed) => _backend.setSpeed(speed);

  Duration get position => _backend.position;

  Uri _publicAudioUri(CatalogEpisode episode) {
    final audio = episode.audioUrl;
    if (audio == null || audio.isEmpty) {
      throw const ApiFailure(
        code: 'NO_AUDIO',
        message: 'This episode has no playable audio URL for casting.',
      );
    }
    final uri = Uri.tryParse(audio);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const ApiFailure(
        code: 'NO_AUDIO',
        message:
            'Cast requires a public http(s) audio URL. Offline files cannot be sent to Chromecast.',
      );
    }
    return uri;
  }
}

final pelevoCastControllerProvider = Provider<PelevoCastController>(
  (ref) => PelevoCastController(ref),
);
