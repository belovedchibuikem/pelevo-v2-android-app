import 'package:pelevo/features/player/cast/pelevo_cast_models.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

/// Web / unsupported-platform Cast backend.
class PelevoCastBackend {
  PelevoCastSnapshot get snapshot => PelevoCastSnapshot.unsupported;

  Stream<PelevoCastSnapshot> get snapshots async* {
    yield PelevoCastSnapshot.unsupported;
  }

  Stream<void> get completedStream async* {}

  Future<void> initialize() async {}

  Future<void> startDiscovery() async {}

  Future<void> stopDiscovery() async {}

  Future<void> connectAndPlay({
    required PelevoCastDevice device,
    required CatalogEpisode episode,
    required Uri contentUrl,
    Duration position = Duration.zero,
    double speed = 1,
  }) async {
    throw UnsupportedError('Cast is only available on Android and iOS.');
  }

  Future<void> loadOnCurrentSession({
    required CatalogEpisode episode,
    required Uri contentUrl,
    Duration position = Duration.zero,
    double speed = 1,
  }) async {
    throw UnsupportedError('Cast is only available on Android and iOS.');
  }

  Future<void> disconnect({bool stopCasting = true}) async {}

  Future<void> play() async {}

  Future<void> pause() async {}

  Future<void> seek(Duration position) async {}

  Future<void> setSpeed(double speed) async {}

  Duration get position => Duration.zero;

  Stream<Duration> get positionStream async* {
    yield Duration.zero;
  }

  void dispose() {}
}

PelevoCastBackend createPelevoCastBackend() => PelevoCastBackend();
