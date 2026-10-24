import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/player/cast/pelevo_cast.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

class SleepTimerState {
  const SleepTimerState._({
    required this.choice,
    this.endsAt,
    this.tick = 0,
  });

  const SleepTimerState.off() : this._(choice: 'Off');

  const SleepTimerState.end() : this._(choice: 'End of episode');

  const SleepTimerState.counting(String choice, DateTime endsAt, {int tick = 0})
    : this._(choice: choice, endsAt: endsAt, tick: tick);

  final String choice;
  final DateTime? endsAt;
  final int tick;

  bool get active => choice != 'Off';
  bool get endOfEpisode => choice == 'End of episode';

  String get label {
    if (!active) return 'Off';
    if (endOfEpisode) return 'End of episode';
    final ends = endsAt;
    if (ends == null) return choice;
    final left = ends.difference(DateTime.now());
    if (left.inSeconds <= 0) return 'Off';
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60);
    final seconds = left.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _ticker;

  @override
  SleepTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const SleepTimerState.off();
  }

  void select(String choice) {
    _ticker?.cancel();
    _ticker = null;
    switch (choice) {
      case 'Off':
        state = const SleepTimerState.off();
      case '15 min':
      case '30 min':
      case '45 min':
      case '1 hour':
        final duration = switch (choice) {
          '15 min' => const Duration(minutes: 15),
          '30 min' => const Duration(minutes: 30),
          '45 min' => const Duration(minutes: 45),
          _ => const Duration(hours: 1),
        };
        final endsAt = DateTime.now().add(duration);
        state = SleepTimerState.counting(choice, endsAt);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (DateTime.now().isBefore(endsAt)) {
            state = SleepTimerState.counting(
              choice,
              endsAt,
              tick: state.tick + 1,
            );
            return;
          }
          complete();
        });
      case 'End of episode':
      case 'End of Episode':
        state = const SleepTimerState.end();
        _watchEpisodeEnd();
      default:
        state = const SleepTimerState.off();
    }
  }

  void complete() {
    if (!state.active) return;
    _ticker?.cancel();
    _ticker = null;
    state = const SleepTimerState.off();
    unawaited(_pausePlayback());
  }

  void _watchEpisodeEnd() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.endOfEpisode) return;
      if (_episodeIsEnding()) complete();
    });
  }

  bool _episodeIsEnding() {
    final episode = ref.read(nowPlayingEpisodeProvider);
    final cast = ref.read(pelevoCastControllerProvider);
    final Duration position;
    Duration? duration;
    if (cast.isConnected) {
      position = cast.position;
    } else {
      final handler = pelevoAudioHandler;
      if (handler == null) return false;
      position = handler.position;
      duration = handler.duration;
    }
    final seconds = episode?.durationSeconds;
    if (duration == null && seconds != null && seconds > 0) {
      duration = Duration(seconds: seconds);
    }
    if (duration == null || duration <= Duration.zero) return false;
    return duration - position <= const Duration(seconds: 1);
  }

  Future<void> _pausePlayback() async {
    try {
      final cast = ref.read(pelevoCastControllerProvider);
      if (cast.isConnected) {
        if (cast.isPlaying) await cast.pause();
        return;
      }
    } catch (_) {}
    try {
      final handler = pelevoAudioHandler;
      if (handler != null && handler.playing) await handler.pause();
    } catch (_) {}
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(
  SleepTimerNotifier.new,
);
