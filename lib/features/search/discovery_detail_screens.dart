import 'package:pelevo/features/browse/browse_screens.dart';
import 'package:pelevo/features/episode/episode_screens.dart';
import 'package:pelevo/features/podcast/podcast_screens.dart';
import 'package:pelevo/features/search/search_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

/// The complete Search, Browse, Podcast Details, and Episode Details board.
final List<PelevoScreenSpec> discoveryDetailScreens = List.unmodifiable([
  ...searchScreens,
  ...browseScreens,
  ...podcastScreens,
  ...episodeScreens,
]);
