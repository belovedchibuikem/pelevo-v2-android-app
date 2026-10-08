import 'package:pelevo/features/home/home_data.dart';

Map<String, dynamic> homeDiscoverFixture() => {
  'editors_picks': [
    {
      'id': 'editorial-1',
      'type': 'editorial_playlist',
      'title': 'Voices desk',
      'subtitle': 'Editor selected',
    },
  ],
  'trending': [
    {
      'id': 'ep-1',
      'type': 'episode',
      'title': 'Fresh episode',
      'show_title': 'Discover Show',
      'rank': 1,
    },
  ],
  'new_episodes': [
    {
      'id': 'ep-1',
      'type': 'episode',
      'title': 'Fresh episode',
      'show_title': 'Discover Show',
    },
  ],
  'categories': const [],
};

Map<String, dynamic> homeChartsFixture() => {
  'podcasts': [
    {
      'id': 'show-1',
      'type': 'show',
      'title': 'Ranked Show',
      'subtitle': 'Ada',
      'rank': 1,
    },
  ],
  'music': [
    {
      'id': 'show-music',
      'type': 'show',
      'title': 'Lagos Mix',
      'subtitle': 'DJ',
      'rank': 1,
    },
  ],
  'audiobooks': const [],
};

Map<String, dynamic> homePlaylistsFixture() => {
  'yours': [
    {
      'id': 'pl-1',
      'type': 'playlist',
      'title': 'Morning desk',
      'item_count': 1,
    },
  ],
  'editorial': const [],
  'live': const [],
};

Map<String, dynamic> homeRailFixture(HomeRail rail) => {
  'schema_version': 2,
  'rail': {
    'id': rail.id,
    'key': rail.key,
    'type': rail.type,
    'title': rail.title,
    'subtitle': rail.subtitle,
    'items': [
      for (final item in rail.items)
        {'id': item.id, 'type': item.type, 'title': item.title},
    ],
  },
};
