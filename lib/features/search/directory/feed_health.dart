enum FeedHealth { alive, dead, unreachable }

/// Classifies an HTTP response from a podcast feed.
FeedHealth classifyFeedHttp({required int status, String body = ''}) {
  if (status == 404 || status == 410) return FeedHealth.dead;
  if (status == 408 || status == 429 || status >= 500) {
    return FeedHealth.unreachable;
  }
  if (status < 200 || status >= 300) return FeedHealth.unreachable;
  final sample = body.toLowerCase();
  if (sample.contains('<rss') ||
      sample.contains('<feed') ||
      sample.contains('<channel')) {
    return FeedHealth.alive;
  }
  return FeedHealth.dead;
}

String feedHealthMessage(FeedHealth health) => switch (health) {
  FeedHealth.dead =>
    'This podcast feed is unavailable, so it can’t be added.',
  FeedHealth.unreachable =>
    'This podcast feed didn’t respond. Try again in a moment.',
  FeedHealth.alive => '',
};
