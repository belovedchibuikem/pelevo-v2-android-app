import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';

class LinkedPodcastEpisode {
  const LinkedPodcastEpisode({
    required this.id,
    required this.title,
    required this.show,
    required this.metadata,
    required this.asset,
    required this.route,
    required this.chipLabel,
  });

  final String id;
  final String title;
  final String show;
  final String metadata;
  final String asset;
  final String route;
  final String chipLabel;
}

const linkableEpisodes = <LinkedPodcastEpisode>[
  LinkedPodcastEpisode(
    id: 'episode-124',
    title: 'Ep. 124 - The Shift Life',
    show: 'The Honest Bunch',
    metadata: 'May 19, 2024 · 45 min',
    asset: 'assets/episode/episode_thumb.png',
    route: '/screen/episode-details',
    chipLabel: 'Ep. 124',
  ),
  LinkedPodcastEpisode(
    id: 'episode-42',
    title: 'Ep 42: The conversation nobody expected',
    show: 'The Relationship Podcast',
    metadata: 'May 9, 2024 · 50:56',
    asset: 'assets/creator/episode_42.png',
    route: '/screen/creator-episode-details',
    chipLabel: 'Ep 42',
  ),
  LinkedPodcastEpisode(
    id: 'episode-41',
    title: 'Ep 41: Learning to let go',
    show: 'The Relationship Podcast',
    metadata: 'May 2, 2024 · 48:22',
    asset: 'assets/creator/episode_41.png',
    route: '/screen/podcast-episodes',
    chipLabel: 'Ep 41',
  ),
  LinkedPodcastEpisode(
    id: 'episode-40',
    title: 'Ep 40: Building trust',
    show: 'The Relationship Podcast',
    metadata: 'Apr 25, 2024 · 45:10',
    asset: 'assets/creator/episode_40.png',
    route: '/screen/podcast-episodes',
    chipLabel: 'Ep 40',
  ),
];

class ReelEpisodeLinkService extends ChangeNotifier {
  ReelEpisodeLinkService._();

  static final instance = ReelEpisodeLinkService._();

  final Map<String, String> _links = {
    'reel-jay': 'episode-42',
    'reel-chude': 'episode-41',
    'reel-tolu': 'episode-40',
    'reel-tech': 'episode-124',
    'reel-follow-jay': 'episode-42',
    'reel-follow-chude': 'episode-41',
    'reel-follow-honest': 'episode-124',
    'reel-trend-tech': 'episode-124',
    'reel-trend-honest': 'episode-124',
    'reel-trend-voices': 'episode-40',
  };

  LinkedPodcastEpisode episodeFor(String reelId) {
    final id = _links[reelId] ?? linkableEpisodes.first.id;
    return linkableEpisodes.firstWhere(
      (episode) => episode.id == id,
      orElse: () => linkableEpisodes.first,
    );
  }

  void link({required String reelId, required String episodeId}) {
    _links[reelId] = episodeId;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _links
      ..clear()
      ..addAll({
        'reel-jay': 'episode-42',
        'reel-chude': 'episode-41',
        'reel-tolu': 'episode-40',
        'reel-tech': 'episode-124',
        'reel-follow-jay': 'episode-42',
        'reel-follow-chude': 'episode-41',
        'reel-follow-honest': 'episode-124',
        'reel-trend-tech': 'episode-124',
        'reel-trend-honest': 'episode-124',
        'reel-trend-voices': 'episode-40',
      });
    notifyListeners();
  }
}

Future<void> showLinkedEpisodeSheet(
  BuildContext context, {
  required String reelId,
}) {
  return showPelevoSheet<void>(
    context: context,
    builder:
        (sheetContext) => ListenableBuilder(
          listenable: ReelEpisodeLinkService.instance,
          builder:
              (context, _) => _LinkedEpisodeSheet(
                reelId: reelId,
                sheetContext: sheetContext,
              ),
        ),
  );
}

class _LinkedEpisodeSheet extends StatelessWidget {
  const _LinkedEpisodeSheet({required this.reelId, required this.sheetContext});

  final String reelId;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final episode = ReelEpisodeLinkService.instance.episodeFor(reelId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.pelevo.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Linked episode',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Open this episode or link the reel to a different one.',
              style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(episode.route);
              },
              borderRadius: PelevoRadii.card,
              child: _EpisodePreview(episode: episode),
            ),
            const SizedBox(height: 16),
            PelevoButton(
              label: 'Open Episode',
              color: PelevoColors.purple,
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push(episode.route);
              },
            ),
            const SizedBox(height: 8),
            PelevoButton(
              label: 'Change Linked Episode',
              outlined: true,
              color: PelevoColors.purple,
              onPressed: () async {
                final selected = await showChangeLinkedEpisodeSheet(
                  context,
                  selectedId: episode.id,
                );
                if (selected != null) {
                  ReelEpisodeLinkService.instance.link(
                    reelId: reelId,
                    episodeId: selected.id,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<LinkedPodcastEpisode?> showChangeLinkedEpisodeSheet(
  BuildContext context, {
  required String selectedId,
}) {
  return showPelevoSheet<LinkedPodcastEpisode>(
    context: context,
    isScrollControlled: true,
    heightFactor: .72,
    builder:
        (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.pelevo.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change linked episode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the podcast episode this reel should open.',
                style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final episode in linkableEpisodes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, episode),
                          borderRadius: PelevoRadii.card,
                          child: _EpisodePreview(
                            episode: episode,
                            selected: episode.id == selectedId,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
  );
}

class _EpisodePreview extends StatelessWidget {
  const _EpisodePreview({required this.episode, this.selected = false});

  final LinkedPodcastEpisode episode;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.pelevo.surfaceHigh,
      borderRadius: PelevoRadii.card,
      border: Border.all(
        color: selected ? PelevoColors.purple : context.pelevo.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            episode.asset,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(
                  width: 58,
                  height: 58,
                  color: context.pelevo.surface,
                  child: const Icon(Icons.podcasts_rounded),
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                episode.show,
                style: TextStyle(
                  color: context.pelevo.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                episode.metadata,
                style: TextStyle(
                  color: context.pelevo.textDim,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: selected ? PelevoColors.purple : context.pelevo.textDim,
        ),
      ],
    ),
  );
}
