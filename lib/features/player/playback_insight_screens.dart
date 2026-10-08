import 'package:pelevo/features/ai/ai_hub_screens.dart';
import 'package:pelevo/features/player/full_player_screens.dart';
import 'package:pelevo/features/queue/queue_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:pelevo/features/stats/podcast_stats_screens.dart';

/// The complete playback and listening-insight board inventory.
///
/// Keep this collection at 48 entries: 12 full-player states, 12 queue states,
/// 12 podcast-stat states, and 12 AI Hub states.
final List<PelevoScreenSpec> playbackInsightScreens = [
  ...fullPlayerScreens,
  ...queueScreens,
  ...podcastStatsScreens,
  ...aiHubScreens,
];
