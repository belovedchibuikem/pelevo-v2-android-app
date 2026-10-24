import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/home/system_home_feed.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _SystemBackedHomeFeedState();
}

class _SystemBackedHomeFeedState extends State<HomeFeedScreen> {
  @override
  Widget build(BuildContext context) => const SystemHomeFeed();
}

// Legacy visual fixture retained for golden-reference development.
// ignore: unused_element
class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int _playing = -1;
  int _quickListen = 0;
  int _africanVoice = 0;

  @override
  Widget build(BuildContext context) => _HomeShell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('/screen/profile'),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: PelevoColors.green.withValues(alpha: .18),
                      shape: BoxShape.circle,
                      border: Border.all(color: PelevoColors.green, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: PelevoColors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: PelevoSpacing.xs),
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications, 1 unread',
                  onPressed: () => context.push('/screen/notifications-1'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PelevoColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          'Good morning, Adesola',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'What are you in the mood for today?',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: const [
            _MoodTile(
              'Learn Something',
              Icons.menu_book_rounded,
              Color(0xFF1B4B4A),
            ),
            _MoodTile(
              'Money & Business',
              Icons.payments_outlined,
              Color(0xFF3A3218),
            ),
            _MoodTile(
              'Feel Something',
              Icons.favorite_outline_rounded,
              Color(0xFF4A1D2A),
            ),
            _MoodTile(
              'Faith & Purpose',
              Icons.auto_awesome_outlined,
              Color(0xFF2A2150),
            ),
            _MoodTile(
              'Be Entertained',
              Icons.celebration_outlined,
              Color(0xFF3A2748),
            ),
            _MoodTile(
              'Sleep & Unwind',
              Icons.nights_stay_outlined,
              Color(0xFF1A2748),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        const _PickForTodayCard(),
        const SizedBox(height: PelevoSpacing.xl),
        _Section(
          title: 'Continue Listening',
          seeAllRoute: '/screen/home-continue-listening',
          child: SizedBox(
            height: 214,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ContinueCard(
                  title: 'The Mindset',
                  progress: '32:14 / 48:20',
                  assetPath: 'assets/home/mindset.png',
                  playing: _playing == 1,
                  onPlay: () => _togglePlaying(1),
                ),
                _ContinueCard(
                  title: 'Ep. 124 • The Shift Life',
                  progress: '12:45 / 45:00',
                  assetPath: 'assets/home/honest_bunch.png',
                  playing: _playing == 0,
                  onPlay: () => _togglePlaying(0),
                ),
                _ContinueCard(
                  title: 'Deep Talk',
                  progress: '08:12 / 36:40',
                  assetPath: 'assets/home/deep_talk.png',
                  playing: _playing == 2,
                  onPlay: () => _togglePlaying(2),
                ),
                _ContinueCard(
                  title: 'African Tech',
                  progress: '18:02 / 41:10',
                  assetPath: 'assets/home/african_tech.png',
                  playing: _playing == 4,
                  onPlay: () => _togglePlaying(4),
                ),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Made For You',
          seeAllRoute: '/screen/home-made-for-you',
          child: Column(
            children: [
              _MadeForYouTile(
                title: 'Keep Going',
                show: 'The Honest Bunch',
                meta: '48 min · 96% match',
                assetPath: 'assets/home/trend_honest.png',
              ),
              _MadeForYouTile(
                title: 'AI in Africa',
                show: 'The Tech Point',
                meta: '36 min · 91% match',
                assetPath: 'assets/home/trend_tech.png',
              ),
              _MadeForYouTile(
                title: 'The Courage to Begin Again',
                show: 'Voices That Inspire',
                meta: '42 min · 88% match',
                assetPath: 'assets/home/voices_inspire.png',
              ),
            ],
          ),
        ),
        _Section(
          title: 'Quick Listen',
          seeAllRoute: '/screen/home-quick-listen',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const [
                    (0, '5-10 min'),
                    (1, '10-20 min'),
                    (2, '30+ min'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _quickListen == option.$1,
                      selectedColor: PelevoColors.green.withValues(alpha: .28),
                      onSelected:
                          (_) => setState(() => _quickListen = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.sm),
              SizedBox(
                height: 118,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final item in _quickListenItems)
                      _QuickListenCard(
                        title: item.$1,
                        duration: item.$2,
                        assetPath: item.$3,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Because You Listened',
          seeAllRoute: '/screen/home-because-you-listened',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RecommendationReason(
                title: 'Inspired by The Mindset',
                subtitle: 'More thoughtful conversations about growth',
              ),
              const SizedBox(height: PelevoSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth / 3;
                  return SizedBox(
                    height: cardWidth + 55,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SquareCard(
                          width: cardWidth,
                          title: 'Deep Talk',
                          subtitle: 'Honest conversations',
                          color: PelevoColors.green,
                          assetPath: 'assets/home/deep_talk.png',
                          showPlay: true,
                        ),
                        _SquareCard(
                          width: cardWidth,
                          title: 'Morning Motivation',
                          subtitle: 'Start your day stronger',
                          color: PelevoColors.red,
                          assetPath: 'assets/home/morning_motivation.png',
                          showPlay: true,
                        ),
                        _SquareCard(
                          width: cardWidth,
                          title: 'Voices That Inspire',
                          subtitle: 'Stories that move you',
                          color: PelevoColors.yellow,
                          assetPath: 'assets/home/voices_inspire.png',
                          showPlay: true,
                        ),
                        _SquareCard(
                          width: cardWidth,
                          title: 'Creative Minds',
                          subtitle: 'Ideas for your next move',
                          color: PelevoColors.purple,
                          assetPath: 'assets/home/creative_minds.png',
                          showPlay: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        _Section(
          title: 'Trending on Pelevo',
          seeAllRoute: '/screen/home-trending',
          child: Column(
            children: [
              PelevoEpisodeTile(
                rank: 1,
                title: 'The Honest Bunch',
                subtitle: '24.8K plays',
                assetPath: 'assets/home/trend_honest.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
              PelevoEpisodeTile(
                rank: 2,
                title: 'The Tech Point',
                subtitle: '18.2K plays',
                color: PelevoColors.green,
                assetPath: 'assets/home/trend_tech.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
              PelevoEpisodeTile(
                rank: 3,
                title: 'Voices That Inspire',
                subtitle: '15.6K plays',
                color: PelevoColors.yellow,
                assetPath: 'assets/home/voices_inspire.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
            ],
          ),
        ),
        _Section(
          title: 'New From Shows You Follow',
          seeAllRoute: '/screen/home-following-new',
          child: Column(
            children: [
              PelevoEpisodeTile(
                title: 'The Honest Bunch',
                subtitle: 'Ep. 124 · 48 min · 2h ago',
                assetPath: 'assets/home/honest_bunch.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
              PelevoEpisodeTile(
                title: 'The Tech Point',
                subtitle: 'Ep. 88 · 36 min · 5h ago',
                color: PelevoColors.green,
                assetPath: 'assets/home/trend_tech.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
              PelevoEpisodeTile(
                title: 'Deep Conversations',
                subtitle: 'Ep. 31 · 41 min · Yesterday',
                color: PelevoColors.yellow,
                assetPath: 'assets/home/deep_conversations.png',
                onTap: () => context.push('/screen/episode-details'),
                onPlay: () => context.push('/screen/player-now-playing'),
              ),
            ],
          ),
        ),
        _Section(
          title: 'African Voices',
          seeAllRoute: '/screen/home-african-voices',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const [
                    (0, 'Nigeria'),
                    (1, 'Ghana'),
                    (2, 'Kenya'),
                    (3, 'South Africa'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _africanVoice == option.$1,
                      selectedColor: PelevoColors.green.withValues(alpha: .28),
                      onSelected:
                          (_) => setState(() => _africanVoice = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.sm),
              SizedBox(
                height: 172,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final item in _africanVoiceItems)
                      _AfricanVoiceCard(
                        title: item.$1,
                        subtitle: item.$2,
                        assetPath: item.$3,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Try Something New',
          seeAllRoute: '/screen/home-try-new',
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .92,
            children: const [
              _TryNewTile(
                label: 'Science',
                icon: Icons.science_outlined,
                color: Color(0xFF1E3A5F),
              ),
              _TryNewTile(
                label: 'Comedy',
                icon: Icons.sentiment_satisfied_alt_outlined,
                color: Color(0xFF4A2A18),
              ),
              _TryNewTile(
                label: 'Sports',
                icon: Icons.sports_soccer_outlined,
                color: Color(0xFF1A3D2A),
              ),
              _TryNewTile(
                label: 'News',
                icon: Icons.newspaper_outlined,
                color: Color(0xFF3A1A3A),
              ),
              _TryNewTile(
                label: 'Health',
                icon: Icons.favorite_outline,
                color: Color(0xFF4A1A2A),
              ),
              _TryNewTile(
                label: 'History',
                icon: Icons.menu_book_outlined,
                color: Color(0xFF2A2A4A),
              ),
              _TryNewTile(
                label: 'True Crime',
                icon: Icons.gavel_outlined,
                color: Color(0xFF3A2A18),
              ),
              _TryNewTile(
                label: 'Kids',
                icon: Icons.child_care_outlined,
                color: Color(0xFF1A3A3A),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 4, 0, 16),
          child: _SurpriseBanner(),
        ),
        _Section(
          title: 'Explore by Topic',
          seeAllRoute: '/screen/home-topics',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TopicChip(label: 'Business'),
              _TopicChip(label: 'Relationships'),
              _TopicChip(label: 'Society'),
              _TopicChip(label: 'Faith'),
              _TopicChip(label: 'Culture'),
              _TopicChip(label: 'Technology'),
              _TopicChip(label: 'Health'),
              _TopicChip(label: 'Sports'),
            ],
          ),
        ),
        _Section(
          title: 'Trending Shorts',
          seeAllRoute: '/screen/reels',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth / 2.35;
              return SizedBox(
                height: cardWidth * 1.38 + 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ShortCard(
                      width: cardWidth,
                      title: 'Build quietly. Ship loudly.',
                      creator: 'African Tech',
                      assetPath: 'assets/home/trend_tech.png',
                      badge: '21.3K plays',
                      accent: PelevoColors.purple,
                    ),
                    _ShortCard(
                      width: cardWidth,
                      title: 'The take everyone is sharing',
                      creator: 'The Honest Bunch',
                      assetPath: 'assets/home/trend_honest.png',
                      badge: '18.9K plays',
                      accent: PelevoColors.red,
                    ),
                    _ShortCard(
                      width: cardWidth,
                      title: 'One truth to carry today',
                      creator: 'Voices That Inspire',
                      assetPath: 'assets/home/voices_inspire.png',
                      badge: '14.1K plays',
                      accent: PelevoColors.green,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _Section(
          title: 'Shorts You Might Like',
          seeAllRoute: '/screen/reels',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth / 2.35;
              return SizedBox(
                height: cardWidth * 1.38 + 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ShortCard(
                      width: cardWidth,
                      title: 'Protect your peace',
                      creator: 'Jay Shetty',
                      assetPath: 'assets/home/mindset.png',
                      badge: 'For you',
                      accent: PelevoColors.purple,
                    ),
                    _ShortCard(
                      width: cardWidth,
                      title: 'Real conversations start here',
                      creator: 'Toluy',
                      assetPath: 'assets/home/deep_talk.png',
                      badge: '98% match',
                      accent: PelevoColors.green,
                    ),
                    _ShortCard(
                      width: cardWidth,
                      title: 'Tell your story with courage',
                      creator: 'Chude Jideonwo',
                      assetPath: 'assets/home/story_circle.png',
                      badge: 'New for you',
                      accent: PelevoColors.yellow,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _Section(
          title: 'Browse Categories',
          seeAllRoute: '/screen/browse-categories',
          child: LayoutBuilder(
            builder:
                (context, constraints) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth < 280 ? 2 : 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    _Category('Podcasts', Icons.podcasts, PelevoColors.red),
                    _Category(
                      'Shorts',
                      Icons.smart_display_rounded,
                      PelevoColors.purple,
                    ),
                    _Category(
                      'Audiobooks',
                      Icons.headphones,
                      PelevoColors.green,
                    ),
                    _Category(
                      'More',
                      Icons.grid_view_rounded,
                      context.pelevo.surfaceHigh,
                    ),
                  ],
                ),
          ),
        ),
      ],
    ),
  );

  void _togglePlaying(int index) {
    setState(() => _playing = _playing == index ? -1 : index);
  }

  List<(String, String, String)> get _quickListenItems =>
      switch (_quickListen) {
        0 => const [
          ('One Idea', '7 min', 'assets/home/mindset.png'),
          ('Quick Win', '9 min', 'assets/home/deep_talk.png'),
          ('Daily Spark', '6 min', 'assets/home/morning_motivation.png'),
        ],
        1 => const [
          ('The Shift', '14 min', 'assets/home/honest_bunch.png'),
          ('AI Brief', '18 min', 'assets/home/trend_tech.png'),
          ('Voice Note', '12 min', 'assets/home/voices_inspire.png'),
        ],
        _ => const [
          ('Deep Cut', '36 min', 'assets/home/deep_conversations.png'),
          ('Long Form', '42 min', 'assets/home/african_tech.png'),
          ('Full Episode', '48 min', 'assets/home/trend_honest.png'),
        ],
      };

  List<(String, String, String)> get _africanVoiceItems =>
      switch (_africanVoice) {
        0 => const [
          ('Culture & Society', 'Nigeria', 'assets/home/story_circle.png'),
          ('Lagos Stories', 'Nigeria', 'assets/home/honest_bunch.png'),
          ('Naija Tech', 'Nigeria', 'assets/home/african_tech.png'),
        ],
        1 => const [
          ('Accra Voices', 'Ghana', 'assets/home/voices_inspire.png'),
          ('Gold Coast Talk', 'Ghana', 'assets/home/creative_minds.png'),
          ('Highlife Hours', 'Ghana', 'assets/home/afrobeats_vibes.png'),
        ],
        2 => const [
          ('Nairobi Now', 'Kenya', 'assets/home/trend_tech.png'),
          ('East African', 'Kenya', 'assets/home/next_gen.png'),
          ('Swahili Stories', 'Kenya', 'assets/home/deep_talk.png'),
        ],
        _ => const [
          ('Cape Town Talk', 'South Africa', 'assets/home/voices_inspire.png'),
          ('Joburg Stories', 'South Africa', 'assets/home/creative_minds.png'),
          ('Mzansi Now', 'South Africa', 'assets/home/next_gen.png'),
        ],
      };
}

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  static const _editorialColors = [
    PelevoColors.red,
    PelevoColors.green,
    PelevoColors.yellow,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(homeDiscoverProvider);
    return _HomeShell(
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => _DestinationError(
              onRetry: () => ref.invalidate(homeDiscoverProvider),
            ),
        data:
            (value) => Column(
              children: [
                _Section(
                  title: 'Editors Picks',
                  seeAllRoute: '/screen/browse-preview',
                  child:
                      value.editorsPicks.isEmpty
                          ? const _EmptyRail('No editor picks are published yet.')
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = constraints.maxWidth / 3;
                              return SizedBox(
                                height: cardWidth * 1.45,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: value.editorsPicks.length,
                                  itemBuilder: (context, index) {
                                    final item = value.editorsPicks[index];
                                    return _EditorialCard(
                                      width: cardWidth,
                                      title: item.title,
                                      subtitle: item.subtitle ?? '',
                                      color:
                                          _editorialColors[index %
                                              _editorialColors.length],
                                      assetPath:
                                          'assets/home/voices_inspire.png',
                                      artworkUrl: item.artworkUrl,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                ),
                _Section(
                  title: 'Trending Now',
                  seeAllRoute: '/screen/home-charts',
                  child:
                      value.trending.isEmpty
                          ? const _EmptyRail('Nothing is trending yet.')
                          : Column(
                            children: [
                              for (final item in value.trending.take(5))
                                PelevoEpisodeTile(
                                  rank: item.rank,
                                  title: item.title,
                                  subtitle: item.showTitle ?? '',
                                  artworkUrl: item.artworkUrl,
                                  onTap: () {
                                    openCatalogHomeItem(context, item);
                                    context.push('/screen/episode-details');
                                  },
                                  onPlay:
                                      item.type == 'episode'
                                          ? () => playCatalogHomeItem(
                                            context,
                                            item,
                                          )
                                          : null,
                                ),
                            ],
                          ),
                ),
                _Section(
                  title: 'New Episodes',
                  seeAllRoute: '/screen/podcast-episodes',
                  child:
                      value.newEpisodes.isEmpty
                          ? const _EmptyRail('No new episodes are available.')
                          : Column(
                            children: [
                              for (final item in value.newEpisodes.take(5))
                                PelevoEpisodeTile(
                                  title: item.title,
                                  subtitle: item.showTitle ?? '',
                                  color: PelevoColors.green,
                                  artworkUrl: item.artworkUrl,
                                  onTap: () {
                                    openCatalogHomeItem(context, item);
                                    context.push('/screen/episode-details');
                                  },
                                  onPlay:
                                      item.type == 'episode'
                                          ? () => playCatalogHomeItem(
                                            context,
                                            item,
                                          )
                                          : null,
                                ),
                            ],
                          ),
                ),
              ],
            ),
      ),
    );
  }
}

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  int _tab = 0;

  static const _tabs = ['Podcasts', 'Music', 'Audiobooks'];

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(homeChartsProvider);
    final creatorAccess = ref.watch(
      authSessionProvider.select((session) => session.creatorAccess),
    );
    return _HomeShell(
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => _DestinationError(
              onRetry: () => ref.invalidate(homeChartsProvider),
            ),
        data: (value) {
          final items = value.segment(_tab);
          return Column(
            children: [
              PelevoSectionHeader(
                title: 'Charts',
                onSeeAll: () => context.go('/screen/browse'),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              SegmentedButton<int>(
                segments: List.generate(
                  _tabs.length,
                  (index) =>
                      ButtonSegment(value: index, label: Text(_tabs[index])),
                ),
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged:
                    (value) => setState(() => _tab = value.first),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              if (items.isEmpty)
                const _EmptyRail('No titles are ranked in this catalog yet.')
              else
                ...items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      openCatalogHomeItem(context, item);
                      context.push(
                        _tab == 0
                            ? '/screen/podcast-details'
                            : '/screen/browse-detail',
                      );
                    },
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${item.rank ?? ''}',
                            style: const TextStyle(
                              color: PelevoColors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _NetworkOrAssetArt(
                          url: item.artworkUrl,
                          assetPath: 'assets/home/chart_honest.png',
                          size: 48,
                        ),
                      ],
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle ?? item.showTitle ?? ''),
                  ),
                ),
              const SizedBox(height: PelevoSpacing.lg),
              InkWell(
                borderRadius: PelevoRadii.card,
                onTap:
                    () => context.push(
                      creatorAccess
                          ? '/screen/creator-studio'
                          : '/screen/claim-podcast',
                    ),
                child: ClipRRect(
                  borderRadius: PelevoRadii.card,
                  child: Image.asset(
                    'assets/home/creator_banner.png',
                    width: double.infinity,
                    height: 126,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    semanticLabel:
                        'Create Your Own Show. Share your voice with the world.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  static const _playlistColors = [
    PelevoColors.red,
    PelevoColors.yellow,
    PelevoColors.green,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(homePlaylistsProvider);
    return _HomeShell(
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => _DestinationError(
              onRetry: () => ref.invalidate(homePlaylistsProvider),
            ),
        data:
            (value) => Column(
              children: [
                _Section(
                  title: 'Your Playlists',
                  seeAllRoute: '/screen/library-2',
                  child:
                      value.yours.isEmpty
                          ? const _EmptyRail('You have not created a playlist yet.')
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = constraints.maxWidth / 3;
                              return SizedBox(
                                height: cardWidth + 55,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: value.yours.length,
                                  itemBuilder: (context, index) {
                                    final item = value.yours[index];
                                    final count = item.itemCount ?? 0;
                                    return _SquareCard(
                                      width: cardWidth,
                                      title: item.title,
                                      subtitle:
                                          '$count ${count == 1 ? 'item' : 'items'}',
                                      color:
                                          _playlistColors[index %
                                              _playlistColors.length],
                                      assetPath:
                                          'assets/home/morning_motivation.png',
                                      artworkUrl: item.artworkUrl,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                ),
                _Section(
                  title: 'Shorts',
                  seeAllRoute: '/screen/browse',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Shortcut(
                        'Quick Tips',
                        'For Creators',
                        Icons.lightbulb,
                        PelevoColors.red,
                      ),
                      _Shortcut(
                        '1 Min',
                        'Motivation',
                        Icons.bolt,
                        PelevoColors.yellow,
                      ),
                      _Shortcut(
                        'News',
                        'Updates',
                        Icons.newspaper,
                        PelevoColors.green,
                      ),
                      _Shortcut(
                        'Daily',
                        'Wisdom',
                        Icons.auto_awesome,
                        context.pelevo.surfaceHigh,
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Live Now',
                  seeAllRoute: '/screen/home-discover',
                  child:
                      value.live.isEmpty
                          ? const _EmptyRail('No live sessions are on now.')
                          : Column(
                            children: [
                              for (final item in value.live)
                                _LiveTile(
                                  item.id,
                                  item.title,
                                  item.subtitle ?? '',
                                  _listenerLabel(item.viewerCount ?? 0),
                                  PelevoColors.red,
                                  'assets/home/live_midday.png',
                                  artworkUrl: item.artworkUrl,
                                ),
                            ],
                          ),
                ),
              ],
            ),
      ),
    );
  }

  static String _listenerLabel(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return '$count';
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.child});

  final Widget child;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _navigationIndex = 0;

  @override
  Widget build(BuildContext context) => PelevoPage(
    bottomNavigationBar: PelevoBottomNavigation(
      index: _navigationIndex,
      onDestinationSelected: (index) {
        setState(() => _navigationIndex = index);
        context.go(
          const [
            '/screen/home-feed',
            '/screen/search',
            '/screen/library-1',
            '/screen/earn',
            '/screen/reels',
          ][index],
        );
      },
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: widget.child,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.seeAllRoute});

  final String title;
  final Widget child;
  final String? seeAllRoute;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PelevoSpacing.xl),
    child: Column(
      children: [
        PelevoSectionHeader(
          title: title,
          onSeeAll: () => context.push(seeAllRoute ?? '/screen/home-discover'),
        ),
        const SizedBox(height: PelevoSpacing.xs),
        child,
      ],
    ),
  );
}

class _DestinationError extends StatelessWidget {
  const _DestinationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(PelevoSpacing.xl),
    child: Column(
      children: [
        const Text('Home content could not be loaded. Please try again.'),
        const SizedBox(height: PelevoSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _EmptyRail extends StatelessWidget {
  const _EmptyRail(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PelevoSpacing.md),
    child: Text(
      message,
      style: TextStyle(color: context.pelevo.textMuted),
    ),
  );
}

class _NetworkOrAssetArt extends StatelessWidget {
  const _NetworkOrAssetArt({
    required this.assetPath,
    required this.size,
    this.url,
  });

  final String assetPath;
  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final asset = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    final image =
        url != null && url!.isNotEmpty
            ? PelevoNetworkArt(
              url: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fallback: asset,
            )
            : asset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.small),
      child: image,
    );
  }
}

class _SquareCard extends StatelessWidget {
  const _SquareCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.assetPath,
    this.artworkUrl,
    this.showPlay = false,
  });

  final double width;
  final String title;
  final String subtitle;
  final Color color;
  final String assetPath;
  final String? artworkUrl;
  final bool showPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      onTap: () => context.push('/screen/library-3'),
      child: Padding(
        padding: const EdgeInsets.only(right: PelevoSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PelevoRadii.medium),
              child: Stack(
                children: [
                  ColoredBox(
                    color: color,
                    child: _NetworkOrAssetArt(
                      url: artworkUrl,
                      assetPath: assetPath,
                      size: width - PelevoSpacing.sm,
                    ),
                  ),
                  if (showPlay)
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: PelevoColors.green,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecommendationReason extends StatelessWidget {
  const _RecommendationReason({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.sm),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: PelevoColors.green.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(PelevoRadii.small),
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: PelevoColors.green,
            size: 20,
          ),
        ),
        const SizedBox(width: PelevoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({
    required this.width,
    required this.title,
    required this.creator,
    required this.assetPath,
    required this.badge,
    required this.accent,
  });

  final double width;
  final String title;
  final String creator;
  final String assetPath;
  final String badge;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.only(right: PelevoSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/screen/reels'),
        borderRadius: PelevoRadii.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: PelevoRadii.card,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: context.pelevo.surfaceHigh,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                    Positioned(
                      top: PelevoSpacing.xs,
                      left: PelevoSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PelevoSpacing.xs,
                          vertical: PelevoSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color:
                                accent == PelevoColors.yellow
                                    ? Colors.black
                                    : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    Positioned(
                      left: PelevoSpacing.sm,
                      right: PelevoSpacing.sm,
                      bottom: PelevoSpacing.sm,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.xs),
            Text(
              creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EditorialCard extends StatelessWidget {
  const _EditorialCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.assetPath,
    this.artworkUrl,
  });

  final double width;
  final String title;
  final String subtitle;
  final Color color;
  final String assetPath;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    margin: const EdgeInsets.only(right: PelevoSpacing.sm),
    decoration: BoxDecoration(
      borderRadius: PelevoRadii.card,
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child:
              artworkUrl != null && artworkUrl!.isNotEmpty
                  ? PelevoNetworkArt(
                    url: artworkUrl!,
                    fit: BoxFit.cover,
                    fallback: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  )
                  : Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
        ),
        Positioned.fill(
          child: InkWell(
            onTap: () => context.push('/screen/browse-preview'),
            child: Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MoodTile extends StatelessWidget {
  const _MoodTile(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: () => context.push('/screen/browse-categories'),
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.sm),
      decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PickForTodayCard extends StatelessWidget {
  const _PickForTodayCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: PelevoColors.green.withValues(alpha: .7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Pick for Today',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PelevoRadii.medium),
              child: Image.asset(
                'assets/home/mindset.png',
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Mindset',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A grounded conversation on showing up with intention.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: PelevoSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: const [
                      _MetaBadge(label: '41 min'),
                      _MetaBadge(label: '94% match', emphasize: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Row(
          children: [
            Icon(Icons.auto_awesome, color: PelevoColors.green, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Picked because you finished Morning Motivation',
                style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Listen Now',
          icon: Icons.play_arrow_rounded,
          color: PelevoColors.green,
          onPressed: () => context.push('/screen/player-now-playing'),
        ),
      ],
    ),
  );
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, this.emphasize = false});

  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:
          emphasize
              ? PelevoColors.green.withValues(alpha: .18)
              : context.pelevo.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: emphasize ? PelevoColors.green : context.pelevo.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.title,
    required this.progress,
    required this.assetPath,
    required this.playing,
    required this.onPlay,
  });

  final String title;
  final String progress;
  final String assetPath;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: Padding(
      padding: const EdgeInsets.only(right: PelevoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PelevoRadii.medium),
            child: Stack(
              children: [
                Image.asset(
                  assetPath,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: PelevoColors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            playing ? 'Pause' : 'Continue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            progress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _MadeForYouTile extends StatelessWidget {
  const _MadeForYouTile({
    required this.title,
    required this.show,
    required this.meta,
    required this.assetPath,
  });

  final String title;
  final String show;
  final String meta;
  final String assetPath;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: () => context.push('/screen/episode-details'),
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.small),
      child: Image.asset(
        assetPath,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '$show · $meta',
      maxLines: 1,overflow: TextOverflow.ellipsis,
    ),
    trailing: IconButton(
      tooltip: 'Play $title',
      onPressed: () => context.push('/screen/player-now-playing'),
      icon: const Icon(
        Icons.play_circle_fill_rounded,
        color: PelevoColors.green,
      ),
    ),
  );
}

class _QuickListenCard extends StatelessWidget {
  const _QuickListenCard({
    required this.title,
    required this.duration,
    required this.assetPath,
  });

  final String title;
  final String duration;
  final String assetPath;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    child: Padding(
      padding: const EdgeInsets.only(right: PelevoSpacing.sm),
      child: InkWell(
        borderRadius: PelevoRadii.card,
        onTap: () => context.push('/screen/episode-details'),
        child: Container(
          padding: const EdgeInsets.all(PelevoSpacing.sm),
          decoration: BoxDecoration(
            color: context.pelevo.surface,
            borderRadius: PelevoRadii.card,
            border: Border.all(color: context.pelevo.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(PelevoRadii.small),
                child: Image.asset(
                  assetPath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: PelevoSpacing.xs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      duration,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Play $title',
                onPressed: () => context.push('/screen/player-now-playing'),
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: PelevoColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AfricanVoiceCard extends StatelessWidget {
  const _AfricanVoiceCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  final String title;
  final String subtitle;
  final String assetPath;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: Padding(
      padding: const EdgeInsets.only(right: PelevoSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/screen/podcast-details'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PelevoRadii.medium),
              child: Stack(
                children: [
                  Image.asset(
                    assetPath,
                    width: 140,
                    height: 118,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: PelevoColors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _TryNewTile extends StatelessWidget {
  const _TryNewTile({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: () => context.push('/screen/browse-categories'),
    child: Container(
      decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
      padding: const EdgeInsets.all(PelevoSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _SurpriseBanner extends StatelessWidget {
  const _SurpriseBanner();

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: () => context.push('/screen/home-discover'),
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        borderRadius: PelevoRadii.card,
        gradient: LinearGradient(
          colors: [
            PelevoColors.purple.withValues(alpha: .85),
            const Color(0xFF3A2150),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.casino_outlined, color: Colors.white, size: 32),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surprise Me',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Get a suggestion',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    ),
  );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    backgroundColor: context.pelevo.surfaceHigh,
    onPressed: () => context.push('/screen/browse-categories'),
  );
}

class _Category extends StatelessWidget {
  const _Category(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      borderRadius: PelevoRadii.card,
      onTap:
          () => context.push(switch (label) {
            'Podcasts' => '/screen/browse-categories',
            'Shorts' => '/screen/reels',
            'Audiobooks' => '/screen/home-charts',
            _ => '/screen/home-playlists',
          }),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color == PelevoColors.yellow ? Colors.black : Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    color == PelevoColors.yellow ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap:
          () => context.push(switch (title) {
            'Quick Tips' => '/screen/home-discover',
            '1 Min' => '/screen/player-now-playing',
            'News' => '/screen/search',
            _ => '/screen/ai-hub',
          }),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color, child: Icon(icon)),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            subtitle,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _LiveTile extends StatelessWidget {
  const _LiveTile(
    this.id,
    this.title,
    this.subtitle,
    this.listeners,
    this.color,
    this.assetPath, {
    this.artworkUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String listeners;
  final Color color;
  final String assetPath;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: () => context.push('/live/$id'),
    leading: ColoredBox(
      color: color,
      child: _NetworkOrAssetArt(
        url: artworkUrl,
        assetPath: assetPath,
        size: 52,
      ),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          color: PelevoColors.red,
          child: const Text('LIVE', style: TextStyle(fontSize: 10)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, size: 13),
            const SizedBox(width: 2),
            Text(listeners, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    ),
  );
}
