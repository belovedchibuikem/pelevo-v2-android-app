import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/player/playback_preferences.dart';
import 'package:pelevo/features/player/sleep_timer.dart';

void main() {
  test('sleep timer stores a choice and can be turned off', () {
    final container = ProviderContainer();
    final notifier = container.read(sleepTimerProvider.notifier);

    notifier.select('30 min');
    expect(container.read(sleepTimerProvider).active, isTrue);
    expect(container.read(sleepTimerProvider).choice, '30 min');

    notifier.select('End of episode');
    expect(container.read(sleepTimerProvider).endOfEpisode, isTrue);
    expect(container.read(sleepTimerProvider).label, 'End of episode');

    notifier.select('Off');
    expect(container.read(sleepTimerProvider).label, 'Off');
    expect(container.read(sleepTimerProvider).active, isFalse);
    container.dispose();
  });

  test('playback preferences remember speed, skip, and autoplay', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = container.read(playbackPreferencesProvider);
    expect(initial.speed, isNull);
    expect(initial.skipSeconds, 30);
    expect(initial.autoplay, isNull);

    final notifier = container.read(playbackPreferencesProvider.notifier);
    notifier.setSpeed(1.25);
    notifier.setSkip(15);
    notifier.setAutoplay(false);

    final next = container.read(playbackPreferencesProvider);
    expect(next.speed, 1.25);
    expect(next.skipSeconds, 15);
    expect(next.autoplay, isFalse);
    expect(playbackSpeedLabel(1.25), '1.25x');
    expect(playbackSpeedLabel(1), '1.0x');
  });
}
