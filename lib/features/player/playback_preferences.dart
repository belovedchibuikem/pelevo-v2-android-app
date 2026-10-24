import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const playbackSpeedKey = 'pelevo_playback_speed';
const playbackSkipKey = 'pelevo_skip_seconds';
const playbackAutoplayKey = 'pelevo_autoplay';

const playbackSpeedChoices = <double>[0.75, 1, 1.25, 1.5, 2];
const playbackSkipChoices = <int>[10, 15, 30, 45, 60];

class PlaybackPreferences {
  const PlaybackPreferences({
    this.speed,
    this.skipSeconds = 30,
    this.autoplay,
  });

  /// Null follows the saved player session until the listener chooses a speed.
  final double? speed;
  final int skipSeconds;

  /// Null follows the account preference until this device stores a choice.
  final bool? autoplay;

  PlaybackPreferences copyWith({
    double? speed,
    int? skipSeconds,
    bool? autoplay,
  }) => PlaybackPreferences(
    speed: speed ?? this.speed,
    skipSeconds: skipSeconds ?? this.skipSeconds,
    autoplay: autoplay ?? this.autoplay,
  );
}

class PlaybackPreferencesNotifier extends Notifier<PlaybackPreferences> {
  @override
  PlaybackPreferences build() {
    final preferences = _preferences();
    final storedSpeed = preferences?.getDouble(playbackSpeedKey);
    final storedSkip = preferences?.getInt(playbackSkipKey);
    final storedAutoplay =
        preferences != null && preferences.containsKey(playbackAutoplayKey)
            ? preferences.getBool(playbackAutoplayKey)
            : null;
    return PlaybackPreferences(
      speed: storedSpeed != null && storedSpeed > 0 ? storedSpeed : null,
      skipSeconds: (storedSkip ?? 30).clamp(5, 60),
      autoplay: storedAutoplay,
    );
  }

  void setSpeed(double speed) {
    final chosen = speed.clamp(0.5, 3.0).toDouble();
    state = state.copyWith(speed: chosen);
    _preferences()?.setDouble(playbackSpeedKey, chosen);
  }

  void setSkip(int seconds) {
    final chosen = seconds.clamp(5, 60);
    state = state.copyWith(skipSeconds: chosen);
    _preferences()?.setInt(playbackSkipKey, chosen);
    pelevoAudioHandler?.skipSeconds = chosen;
  }

  void setAutoplay(bool enabled) {
    state = state.copyWith(autoplay: enabled);
    _preferences()?.setBool(playbackAutoplayKey, enabled);
  }

  SharedPreferences? _preferences() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }
}

final playbackPreferencesProvider =
    NotifierProvider<PlaybackPreferencesNotifier, PlaybackPreferences>(
      PlaybackPreferencesNotifier.new,
    );

String playbackSpeedLabel(double speed) {
  final places = speed % 1 == 0 ? 1 : 2;
  return '${speed.toStringAsFixed(places)}x';
}
