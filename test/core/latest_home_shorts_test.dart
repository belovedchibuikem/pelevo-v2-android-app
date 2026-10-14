import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/reels/reel_data.dart';

PublishedReel _reel({
  required String id,
  String? publishedAt,
  String title = '',
  String caption = 'Caption',
  String creatorName = 'Ada Creator',
}) => PublishedReel(
  id: id,
  creatorProfileId: 'creator-1',
  creatorName: creatorName,
  creatorHandle: 'ada',
  likesCount: 0,
  commentsCount: 0,
  savesCount: 0,
  liked: false,
  saved: false,
  following: false,
  title: title,
  caption: caption,
  publishedAt: publishedAt,
  thumbnailPath: 'https://cdn.example/thumb.jpg',
);

void main() {
  test('home shorts follow publish time, not the order the feed returned', () {
    final rankedByViews = [
      _reel(id: 'old-hit', publishedAt: '2026-09-01T00:00:00Z'),
      _reel(
        id: 'newer',
        publishedAt: '2026-10-10T12:00:00Z',
        title: 'New drop',
      ),
      _reel(id: 'newest', publishedAt: '2026-10-14T01:00:00Z'),
      _reel(id: 'undated'),
    ];

    final latest = latestHomeShorts(rankedByViews, limit: 3);

    expect(latest.map((reel) => reel.id), ['newest', 'newer', 'old-hit']);
    final card = homeItemFromReel(latest[1]);
    expect(card.title, 'New drop');
    expect(card.subtitle, 'Ada Creator');
    expect(card.type, 'reel');
    expect(card.artworkUrl, 'https://cdn.example/thumb.jpg');
  });
}
