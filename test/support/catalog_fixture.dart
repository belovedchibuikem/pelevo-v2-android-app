import 'package:pelevo/features/podcast/catalog_data.dart';

const catalogShowId = 'catalog-show-1';
const catalogEpisodeId = 'catalog-episode-1';
const catalogChapterId = 'catalog-chapter-1';
const catalogQueueItemId = 'catalog-queue-1';

class CatalogHarnessShowId extends SelectedShowIdNotifier {
  @override
  String? build() => catalogShowId;
}

class CatalogHarnessEpisodeId extends SelectedEpisodeIdNotifier {
  @override
  String? build() => catalogEpisodeId;
}

Map<String, dynamic> catalogShowFixture({
  String id = catalogShowId,
  String title = 'The Honest Bunch',
  String author = 'With Toke & Friends',
  bool following = true,
  bool notificationsEnabled = false,
  int episodesCount = 2,
  int followerCount = 12,
  String? ratingAverage = '5.0',
  int ratingCount = 1,
}) => {
  'id': id,
  'title': title,
  'author': author,
  'artwork_url': null,
  'description':
      'Real conversations about life, culture, relationships, career, and everything that shapes how we grow.',
  'language': 'en',
  'country_code': 'NG',
  'explicit': 'false',
  'episodes_count': episodesCount,
  'follower_count': followerCount,
  'rating_average': ratingAverage,
  'rating_count': ratingCount,
  'following': following,
  'notifications_enabled': notificationsEnabled,
  'claimed_by_viewer': false,
  'categories': [
    {'name': 'Society & Culture', 'slug': 'society-culture'},
  ],
};

Map<String, dynamic> catalogEpisodeFixture({
  String id = catalogEpisodeId,
  String showId = catalogShowId,
  String title = 'Ep. 124 - The Shift Life',
  String showTitle = 'The Honest Bunch',
  String showAuthor = 'With Toke & Friends',
  int duration = 2700,
  bool detailed = false,
}) => {
  'id': id,
  'show_id': showId,
  'title': title,
  'description':
      'We talk about the turning points that change everything—growth, mindset, and the shifts that shape a better life.',
  'artwork_url': null,
  'duration_seconds': duration,
  'published_at': '2024-05-19T00:00:00Z',
  'show_title': showTitle,
  'show_author': showAuthor,
  if (detailed) 'audio_url': 'https://cdn.example.invalid/shift-life.mp3',
};

List<Map<String, dynamic>> catalogEpisodesFixture() => [
  catalogEpisodeFixture(),
  catalogEpisodeFixture(
    id: 'catalog-episode-2',
    title: 'Ep. 123 - Keep Going',
    duration: 2280,
  ),
];

Map<String, dynamic> catalogChapterFixture({
  String id = catalogChapterId,
  String title = 'Introduction',
  int startsAt = 0,
}) => {'id': id, 'title': title, 'starts_at_seconds': startsAt};

List<Map<String, dynamic>> catalogChaptersFixture() => [
  catalogChapterFixture(),
  catalogChapterFixture(
    id: 'catalog-chapter-2',
    title: 'The first big shift',
    startsAt: 225,
  ),
];

Map<String, dynamic> catalogTranscriptFixture() => {
  'language': 'en',
  'format': 'plain',
  'content':
      'Welcome back. Today we are talking about the shifts that quietly rewrite your life.',
};

Map<String, dynamic> catalogReviewFixture({
  String id = 'catalog-review-1',
  int rating = 5,
  String reviewer = 'Maya',
  String? body = 'Every episode feels honest and useful.',
}) => {
  'id': id,
  'rating': rating,
  'reviewer_name': reviewer,
  'created_at': '2026-09-10T10:00:00Z',
  'body': body,
};

Map<String, dynamic> catalogRelatedShowFixture({
  String id = 'catalog-related-1',
  String title = 'Ranked Show',
  String author = 'Ada',
}) => {'id': id, 'title': title, 'author': author, 'artwork_url': null};

Map<String, dynamic> catalogNoteFixture({
  String? body,
  int? positionSeconds,
  int version = 0,
}) => {
  'body': body,
  'position_seconds': positionSeconds,
  'version': version,
};

Map<String, dynamic> catalogPlaybackFixture({
  String owner = 'test-user',
  String episodeId = catalogEpisodeId,
  int position = 765,
  bool completed = false,
  int version = 0,
}) => {
  'user_id': owner,
  'episode_id': episodeId,
  'position_seconds': position,
  'completed': completed,
  'version': version,
};

Map<String, dynamic> catalogPlayerSessionFixture({
  String? episodeId = catalogEpisodeId,
  bool playing = true,
  double rate = 1,
  int version = 0,
}) => {
  'episode_id': episodeId,
  'playing': playing,
  'playback_rate': rate,
  'version': version,
};

Map<String, dynamic> catalogQueueFixture({
  int version = 1,
  List<Map<String, dynamic>>? items,
}) => {
  'version': version,
  'items':
      items ??
      [
        {
          'queue_item_id': catalogQueueItemId,
          'position': 0,
          'id': 'catalog-episode-2',
          'show_id': catalogShowId,
          'title': 'Ep. 123 - Keep Going',
          'show_title': 'The Honest Bunch',
          'duration_seconds': 2280,
          'artwork_url': null,
        },
      ],
};

Map<String, dynamic> catalogRecentEpisodeFixture({
  String id = 'catalog-episode-2',
  String title = 'Ep. 123 - Keep Going',
  bool completed = true,
  int position = 2280,
  String playedAt = '2026-09-09T12:00:00Z',
}) => {
  'id': id,
  'show_id': catalogShowId,
  'title': title,
  'show_title': 'The Honest Bunch',
  'artwork_url': null,
  'duration_seconds': 2280,
  'position_seconds': position,
  'completed': completed,
  'played_at': playedAt,
};

Map<String, dynamic> catalogStatsFixture({
  int listeningSeconds = 120,
  int episodesStarted = 1,
  int episodesCompleted = 1,
  int showsFollowed = 1,
  int downloadsCount = 0,
}) => {
  'listening_seconds': listeningSeconds,
  'episodes_started': episodesStarted,
  'episodes_completed': episodesCompleted,
  'shows_followed': showsFollowed,
  'episodes_saved': 0,
  'reviews': 0,
  'downloads_count': downloadsCount,
  'daily': [
    {
      'date': '2026-09-10',
      'listening_seconds': listeningSeconds,
      'episodes_started': episodesStarted,
      'episodes_completed': episodesCompleted,
    },
  ],
  'streak': {
    'current_days': 3,
    'longest_days': 5,
    'last_qualified_date': '2026-09-10',
  },
  'achievements': [
    {
      'slug': 'first-episode',
      'name': 'First Episode',
      'description': 'Finished an episode',
      'earned_at': '2026-09-10T12:00:00Z',
    },
  ],
  'shows': [
    {
      'id': catalogShowId,
      'title': 'The Honest Bunch',
      'artwork_url': null,
      'listening_seconds': listeningSeconds,
      'episodes_completed': episodesCompleted,
    },
  ],
  'categories': [
    {
      'id': 'catalog-category-1',
      'name': 'Society & Culture',
      'slug': 'society-culture',
      'listening_seconds': listeningSeconds,
    },
  ],
};
