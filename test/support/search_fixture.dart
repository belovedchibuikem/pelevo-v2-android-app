Map<String, dynamic> searchShowFixture({
  String id = 'show-1',
  String title = 'Owned Show',
  String? author = 'Ada',
}) => {
  'id': id,
  'title': title,
  'author': author,
  'artwork_url': null,
  'description': 'A real catalog show.',
};

Map<String, dynamic> searchEpisodeFixture({
  String id = 'ep-1',
  String title = 'Fresh episode',
  String showId = 'show-1',
  String showTitle = 'Owned Show',
}) => {
  'id': id,
  'title': title,
  'show_id': showId,
  'show_title': showTitle,
  'artwork_url': null,
  'published_at': '2026-09-09T00:00:00Z',
  'duration_seconds': 1200,
};

Map<String, dynamic> searchPlaylistFixture({
  String id = 'pl-1',
  String title = 'Editors Choice',
  int itemCount = 1,
}) => {
  'id': id,
  'title': title,
  'description': 'Editor selected',
  'artwork_url': null,
  'item_count': itemCount,
};

Map<String, dynamic> searchPageFixture({
  String query = 'Owned',
  List<Map<String, dynamic>>? shows,
  List<Map<String, dynamic>>? episodes,
  List<Map<String, dynamic>>? playlists,
}) => {
  'query': query,
  'shows': shows ?? [searchShowFixture()],
  'episodes': episodes ?? [searchEpisodeFixture()],
  'playlists': playlists ?? [searchPlaylistFixture()],
};

Map<String, dynamic> recentSearchFixture({
  String id = 'recent-1',
  String query = 'Technology',
}) => {
  'id': id,
  'query': query,
  'searched_at': '2026-09-09T12:00:00Z',
};
