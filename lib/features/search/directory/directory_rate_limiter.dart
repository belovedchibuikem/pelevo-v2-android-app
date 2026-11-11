enum DirectoryBucket { apple, podcastIndex, probe }

/// Sliding-window limiter for directory hosts and feed probes.
class DirectoryRateLimiter {
  DirectoryRateLimiter({
    this.applePerMinute = 20,
    this.podcastIndexPerMinute = 10,
    this.probePerMinute = 12,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int applePerMinute;
  final int podcastIndexPerMinute;
  final int probePerMinute;
  final DateTime Function() _clock;
  final Map<DirectoryBucket, List<DateTime>> _hits = {};
  final Map<DirectoryBucket, DateTime> _blockedUntil = {};

  bool tryAcquire(DirectoryBucket bucket) {
    final now = _clock();
    final blocked = _blockedUntil[bucket];
    if (blocked != null && now.isBefore(blocked)) return false;
    final window = _hits.putIfAbsent(bucket, () => []);
    window.removeWhere((hit) => now.difference(hit) >= const Duration(minutes: 1));
    if (window.length >= _limit(bucket)) return false;
    window.add(now);
    return true;
  }

  void block(DirectoryBucket bucket, Duration duration) {
    final until = _clock().add(duration);
    final current = _blockedUntil[bucket];
    if (current == null || until.isAfter(current)) {
      _blockedUntil[bucket] = until;
    }
  }

  Duration retryAfter(DirectoryBucket bucket) {
    final now = _clock();
    final blocked = _blockedUntil[bucket];
    if (blocked != null && blocked.isAfter(now)) return blocked.difference(now);
    final window = _hits[bucket];
    if (window == null || window.length < _limit(bucket)) return Duration.zero;
    final oldest = window.first;
    final release = oldest.add(const Duration(minutes: 1));
    final remaining = release.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int _limit(DirectoryBucket bucket) => switch (bucket) {
    DirectoryBucket.apple => applePerMinute,
    DirectoryBucket.podcastIndex => podcastIndexPerMinute,
    DirectoryBucket.probe => probePerMinute,
  };
}
