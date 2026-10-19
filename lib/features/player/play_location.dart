import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Coarse listener fix attached to episode and Reel play requests.
///
/// Uses the location permission already declared for this app. A low-accuracy
/// fix is enough for a country or city report and is cached so progress
/// updates do not read location again. Playback continues when location is
/// denied, unavailable, or still waiting on the permission prompt.
class PlayFix {
  const PlayFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() => {
    'latitude': _roundCoordinate(latitude),
    'longitude': _roundCoordinate(longitude),
    'source': 'device',
    if (accuracyMeters != null) 'accuracy_m': accuracyMeters!.round(),
  };
}

double _roundCoordinate(double value) => double.parse(value.toStringAsFixed(3));

class PlayLocation {
  PlayLocation._();

  static final PlayLocation instance = PlayLocation._();

  static const Duration _cacheFor = Duration(minutes: 30);
  static const Duration _wait = Duration(seconds: 4);

  @visibleForTesting
  PlayFix? debugFix;

  PlayFix? _cached;
  DateTime? _cachedAt;
  DateTime? _nextTry;
  bool _asked = false;
  bool _unavailable = false;
  Future<void>? _reading;

  @visibleForTesting
  void reset() {
    debugFix = null;
    _cached = null;
    _cachedAt = null;
    _nextTry = null;
    _asked = false;
    _unavailable = false;
    _reading = null;
  }

  Future<Map<String, dynamic>> fields() async {
    try {
      final seeded = debugFix;
      if (seeded != null) return seeded.toJson();
      final fresh = _fresh();
      if (fresh != null) return fresh.toJson();
      if (!_canRead || _unavailable) return _cached?.toJson() ?? const {};
      final wait = _nextTry;
      if (wait != null && DateTime.now().isBefore(wait)) {
        return _cached?.toJson() ?? const {};
      }
      final reading = _reading ??= _readAndStore();
      try {
        await reading.timeout(_wait);
      } on Object {
        // The read keeps going and fills the cache for the next play.
      }
      return _cached?.toJson() ?? const {};
    } on Object {
      return _cached?.toJson() ?? const {};
    }
  }

  bool get _canRead {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  PlayFix? _fresh() {
    final cached = _cached;
    final at = _cachedAt;
    if (cached == null || at == null) return null;
    if (DateTime.now().difference(at) > _cacheFor) return null;
    return cached;
  }

  Future<void> _readAndStore() async {
    try {
      if (!await _granted()) {
        _unavailable = true;
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _recent(last.timestamp)) {
        _store(_fromPosition(last));
        if (DateTime.now().difference(last.timestamp) >
            const Duration(hours: 1)) {
          unawaited(_refresh());
        }
        return;
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      final fix = _fromPosition(current);
      if (fix == null) {
        _backoff();
        return;
      }
      _store(fix);
    } on Object {
      _backoff();
    } finally {
      _reading = null;
    }
  }

  Future<void> _refresh() async {
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      _store(_fromPosition(current));
    } on Object {
      // The play already has the last known fix.
    }
  }

  Future<bool> _granted() async {
    var permission = await Geolocator.checkPermission();
    if (_allowed(permission)) return true;
    if (permission == LocationPermission.deniedForever || _asked) return false;
    _asked = true;
    permission = await Geolocator.requestPermission();
    return _allowed(permission);
  }

  bool _allowed(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  bool _recent(DateTime timestamp) =>
      DateTime.now().difference(timestamp) < const Duration(hours: 6);

  void _store(PlayFix? fix) {
    if (fix == null) return;
    _cached = fix;
    _cachedAt = DateTime.now();
    _nextTry = null;
  }

  void _backoff() {
    _nextTry = DateTime.now().add(const Duration(minutes: 10));
  }

  PlayFix? _fromPosition(Position position) {
    final latitude = position.latitude;
    final longitude = position.longitude;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final accuracy = position.accuracy;
    return PlayFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracy.isFinite && accuracy >= 0 ? accuracy : null,
    );
  }
}
