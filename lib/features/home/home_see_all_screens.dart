import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/home/mood_discover_screens.dart';
import 'package:pelevo/features/home/system_home_feed.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum HomeSeeAllSection {
  continueListening,
  madeForYou,
  quickListen,
  becauseYouListened,
  trending,
  following,
  africanVoices,
  tryNew,
  topics,
}

final List<PelevoScreenSpec> homeSeeAllScreens = List.unmodifiable([
  PelevoScreenSpec(
    id: 'home-continue-listening',
    section: 'Home / Discover',
    title: 'Continue Listening',
    state: 'In-progress episodes',
    builder:
        (_) => const HomeSeeAllScreen(
          section: HomeSeeAllSection.continueListening,
        ),
  ),
  PelevoScreenSpec(
    id: 'home-made-for-you',
    section: 'Home / Discover',
    title: 'Made For You',
    state: 'Personalized picks',
    builder:
        (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.madeForYou),
  ),
  PelevoScreenSpec(
    id: 'home-quick-listen',
    section: 'Home / Discover',
    title: 'Quick Listen',
    state: 'Time-filtered episodes',
    builder:
        (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.quickListen),
  ),
  PelevoScreenSpec(
    id: 'home-because-you-listened',
    section: 'Home / Discover',
    title: 'Because You Listened',
    state: 'Similar shows',
    builder:
        (_) => const HomeSeeAllScreen(
          section: HomeSeeAllSection.becauseYouListened,
        ),
  ),
  PelevoScreenSpec(
    id: 'home-trending',
    section: 'Home / Discover',
    title: 'Trending on Pelevo',
    state: 'Ranked popular shows',
    builder: (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.trending),
  ),
  PelevoScreenSpec(
    id: 'home-following-new',
    section: 'Home / Discover',
    title: 'New From Shows You Follow',
    state: 'Followed-show episodes',
    builder:
        (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.following),
  ),
  PelevoScreenSpec(
    id: 'home-african-voices',
    section: 'Home / Discover',
    title: 'African Voices',
    state: 'Country collections',
    builder:
        (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.africanVoices),
  ),
  PelevoScreenSpec(
    id: 'home-try-new',
    section: 'Home / Discover',
    title: 'Try Something New',
    state: 'Discovery categories',
    builder: (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.tryNew),
  ),
  PelevoScreenSpec(
    id: 'home-topics',
    section: 'Home / Discover',
    title: 'Explore by Topic',
    state: 'Topic catalog',
    builder: (_) => const HomeSeeAllScreen(section: HomeSeeAllSection.topics),
  ),
  PelevoScreenSpec(
    id: 'home-mood-discover',
    section: 'Home / Discover',
    title: 'Mood Discover',
    state: 'Podcast Index mood results',
    builder: (_) => const MoodDiscoverScreen(),
  ),
]);

class HomeSeeAllScreen extends StatefulWidget {
  const HomeSeeAllScreen({required this.section, super.key});

  final HomeSeeAllSection section;

  @override
  State<HomeSeeAllScreen> createState() => _SystemHomeSeeAllScreenState();
}

class _SystemHomeSeeAllScreenState extends State<HomeSeeAllScreen> {
  @override
  Widget build(BuildContext context) => SystemHomeRailScreen(
    railKey: switch (widget.section) {
      HomeSeeAllSection.continueListening => 'continue_listening',
      HomeSeeAllSection.madeForYou => 'made_for_you',
      HomeSeeAllSection.quickListen => 'quick_listen',
      HomeSeeAllSection.becauseYouListened => 'because_you_listened',
      HomeSeeAllSection.trending => 'trending',
      HomeSeeAllSection.following => 'new_from_following',
      HomeSeeAllSection.africanVoices => 'african_voices',
      HomeSeeAllSection.tryNew => 'try_something_new',
      HomeSeeAllSection.topics => 'explore_by_topic',
    },
    fallbackTitle: _copyFor(widget.section).title,
  );
}

// Legacy visual fixture retained for golden-reference development.
// ignore: unused_element
class _HomeSeeAllScreenState extends State<HomeSeeAllScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(widget.section);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/screen/home-feed');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(copy.title),
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: switch (widget.section) {
            HomeSeeAllSection.tryNew => _TryNewSeeAll(subtitle: copy.subtitle),
            HomeSeeAllSection.topics => _TopicsSeeAll(
              selected: _filter,
              onSelected: (index) => setState(() => _filter = index),
              subtitle: copy.subtitle,
            ),
            HomeSeeAllSection.quickListen => _FilteredEpisodeSeeAll(
              subtitle: copy.subtitle,
              filters: const ['5-10 min', '10-20 min', '30+ min'],
              selected: _filter,
              onSelected: (index) => setState(() => _filter = index),
              items: _quickListenItems(_filter),
            ),
            HomeSeeAllSection.africanVoices => _FilteredEpisodeSeeAll(
              subtitle: copy.subtitle,
              filters: const ['Nigeria', 'Ghana', 'Kenya'],
              selected: _filter,
              onSelected: (index) => setState(() => _filter = index),
              items: _africanVoiceItems(_filter),
            ),
            HomeSeeAllSection.becauseYouListened => _EpisodeSeeAll(
              subtitle: copy.subtitle,
              bannerTitle: 'Inspired by The Mindset',
              bannerSubtitle: 'More thoughtful conversations about growth',
              items: _becauseYouListenedItems,
            ),
            HomeSeeAllSection.trending => _EpisodeSeeAll(
              subtitle: copy.subtitle,
              ranked: true,
              items: _trendingItems,
            ),
            HomeSeeAllSection.continueListening => _EpisodeSeeAll(
              subtitle: copy.subtitle,
              items: _continueListeningItems,
            ),
            HomeSeeAllSection.madeForYou => _EpisodeSeeAll(
              subtitle: copy.subtitle,
              items: _madeForYouItems,
            ),
            HomeSeeAllSection.following => _EpisodeSeeAll(
              subtitle: copy.subtitle,
              items: _followingItems,
            ),
          },
        ),
      ),
    );
  }
}

({String title, String subtitle}) _copyFor(HomeSeeAllSection section) =>
    switch (section) {
      HomeSeeAllSection.continueListening => (
        title: 'Continue Listening',
        subtitle: 'Pick up where you left off',
      ),
      HomeSeeAllSection.madeForYou => (
        title: 'Made For You',
        subtitle: 'Personalized episode picks',
      ),
      HomeSeeAllSection.quickListen => (
        title: 'Quick Listen',
        subtitle: 'Short episodes that fit your time',
      ),
      HomeSeeAllSection.becauseYouListened => (
        title: 'Because You Listened',
        subtitle: 'More like The Mindset',
      ),
      HomeSeeAllSection.trending => (
        title: 'Trending on Pelevo',
        subtitle: "What's popular right now",
      ),
      HomeSeeAllSection.following => (
        title: 'New From Shows You Follow',
        subtitle: 'Fresh episodes from followed shows',
      ),
      HomeSeeAllSection.africanVoices => (
        title: 'African Voices',
        subtitle: 'Stories from across the continent',
      ),
      HomeSeeAllSection.tryNew => (
        title: 'Try Something New',
        subtitle: "Categories you haven't explored",
      ),
      HomeSeeAllSection.topics => (
        title: 'Explore by Topic',
        subtitle: 'Browse Pelevo by topic',
      ),
    };

class _SeeAllItem {
  const _SeeAllItem({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    this.color = PelevoColors.red,
    this.route = '/screen/player-now-playing',
  });

  final String title;
  final String subtitle;
  final String assetPath;
  final Color color;
  final String route;
}

const _continueListeningItems = [
  _SeeAllItem(
    title: 'The Mindset',
    subtitle: '32:14 / 48:20 left',
    assetPath: 'assets/home/mindset.png',
  ),
  _SeeAllItem(
    title: 'Ep. 124 • The Shift Life',
    subtitle: '12:45 / 45:00 left',
    assetPath: 'assets/home/honest_bunch.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Deep Talk',
    subtitle: '08:12 / 36:40 left',
    assetPath: 'assets/home/deep_talk.png',
    color: PelevoColors.yellow,
  ),
  _SeeAllItem(
    title: 'African Tech',
    subtitle: '18:02 / 41:10 left',
    assetPath: 'assets/home/african_tech.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Morning Motivation',
    subtitle: '05:40 / 22:10 left',
    assetPath: 'assets/home/morning_motivation.png',
    route: '/screen/library-3',
  ),
  _SeeAllItem(
    title: 'Voices That Inspire',
    subtitle: '21:08 / 42:00 left',
    assetPath: 'assets/home/voices_inspire.png',
    color: PelevoColors.yellow,
  ),
];

const _madeForYouItems = [
  _SeeAllItem(
    title: 'Keep Going',
    subtitle: 'The Honest Bunch · 48 min · 96% match',
    assetPath: 'assets/home/trend_honest.png',
  ),
  _SeeAllItem(
    title: 'AI in Africa',
    subtitle: 'The Tech Point · 36 min · 91% match',
    assetPath: 'assets/home/trend_tech.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'The Courage to Begin Again',
    subtitle: 'Voices That Inspire · 42 min · 88% match',
    assetPath: 'assets/home/voices_inspire.png',
    color: PelevoColors.yellow,
  ),
  _SeeAllItem(
    title: 'Build in Public',
    subtitle: 'African Tech · 39 min · 86% match',
    assetPath: 'assets/home/african_tech.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Boundaries at Work',
    subtitle: 'Tea With Tay · 31 min · 84% match',
    assetPath: 'assets/home/tea_with_tay.png',
    color: PelevoColors.purple,
  ),
  _SeeAllItem(
    title: 'Story as Strategy',
    subtitle: 'Story Circle · 44 min · 81% match',
    assetPath: 'assets/home/story_circle.png',
  ),
];

List<_SeeAllItem> _quickListenItems(int filter) => switch (filter) {
  0 => const [
    _SeeAllItem(
      title: 'One Idea',
      subtitle: 'The Mindset · 7 min',
      assetPath: 'assets/home/mindset.png',
    ),
    _SeeAllItem(
      title: 'Quick Win',
      subtitle: 'Deep Talk · 9 min',
      assetPath: 'assets/home/deep_talk.png',
      color: PelevoColors.green,
    ),
    _SeeAllItem(
      title: 'Daily Spark',
      subtitle: 'Morning Motivation · 6 min',
      assetPath: 'assets/home/morning_motivation.png',
      route: '/screen/library-3',
    ),
    _SeeAllItem(
      title: 'One Honest Take',
      subtitle: 'The Honest Bunch · 8 min',
      assetPath: 'assets/home/honest_bunch.png',
    ),
  ],
  1 => const [
    _SeeAllItem(
      title: 'The Shift',
      subtitle: 'The Honest Bunch · 14 min',
      assetPath: 'assets/home/honest_bunch.png',
    ),
    _SeeAllItem(
      title: 'AI Brief',
      subtitle: 'The Tech Point · 18 min',
      assetPath: 'assets/home/trend_tech.png',
      color: PelevoColors.green,
    ),
    _SeeAllItem(
      title: 'Voice Note',
      subtitle: 'Voices That Inspire · 12 min',
      assetPath: 'assets/home/voices_inspire.png',
      color: PelevoColors.yellow,
    ),
    _SeeAllItem(
      title: 'Founder Check-In',
      subtitle: 'African Tech · 16 min',
      assetPath: 'assets/home/african_tech.png',
      color: PelevoColors.green,
    ),
  ],
  _ => const [
    _SeeAllItem(
      title: 'Deep Cut',
      subtitle: 'Deep Conversations · 36 min',
      assetPath: 'assets/home/deep_conversations.png',
      route: '/screen/library-3',
    ),
    _SeeAllItem(
      title: 'Long Form',
      subtitle: 'African Tech · 42 min',
      assetPath: 'assets/home/african_tech.png',
      color: PelevoColors.green,
    ),
    _SeeAllItem(
      title: 'Full Episode',
      subtitle: 'The Honest Bunch · 48 min',
      assetPath: 'assets/home/trend_honest.png',
    ),
    _SeeAllItem(
      title: 'Creative Hours',
      subtitle: 'Creative Minds · 39 min',
      assetPath: 'assets/home/creative_minds.png',
      color: PelevoColors.purple,
    ),
  ],
};

const _becauseYouListenedItems = [
  _SeeAllItem(
    title: 'Deep Talk',
    subtitle: 'Honest conversations · Ep. 19',
    assetPath: 'assets/home/deep_talk.png',
    color: PelevoColors.green,
    route: '/screen/podcast-details',
  ),
  _SeeAllItem(
    title: 'Morning Motivation',
    subtitle: 'Start your day stronger · Ep. 42',
    assetPath: 'assets/home/morning_motivation.png',
    route: '/screen/library-3',
  ),
  _SeeAllItem(
    title: 'Voices That Inspire',
    subtitle: 'Stories that move you · Ep. 11',
    assetPath: 'assets/home/voices_inspire.png',
    color: PelevoColors.yellow,
    route: '/screen/podcast-details',
  ),
  _SeeAllItem(
    title: 'Creative Minds',
    subtitle: 'Ideas for your next move · Ep. 08',
    assetPath: 'assets/home/creative_minds.png',
    color: PelevoColors.purple,
    route: '/screen/podcast-details',
  ),
  _SeeAllItem(
    title: 'AfroBeats Vibes',
    subtitle: 'Music and culture · Ep. 12',
    assetPath: 'assets/home/afrobeats_vibes.png',
    color: PelevoColors.yellow,
    route: '/screen/library-3',
  ),
  _SeeAllItem(
    title: 'Deep Conversations',
    subtitle: 'Thoughtful talks · Ep. 08',
    assetPath: 'assets/home/deep_conversations.png',
    color: PelevoColors.green,
    route: '/screen/library-3',
  ),
];

const _trendingItems = [
  _SeeAllItem(
    title: 'The Honest Bunch',
    subtitle: '24.8K plays',
    assetPath: 'assets/home/trend_honest.png',
  ),
  _SeeAllItem(
    title: 'The Tech Point',
    subtitle: '18.2K plays',
    assetPath: 'assets/home/trend_tech.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Voices That Inspire',
    subtitle: '15.6K plays',
    assetPath: 'assets/home/voices_inspire.png',
    color: PelevoColors.yellow,
  ),
  _SeeAllItem(
    title: 'I Said What I Said',
    subtitle: '13.4K plays',
    assetPath: 'assets/home/trend_said.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Tea With Tay',
    subtitle: '11.9K plays',
    assetPath: 'assets/home/tea_with_tay.png',
    color: PelevoColors.purple,
  ),
  _SeeAllItem(
    title: 'Next Gen Leaders',
    subtitle: '9.8K plays',
    assetPath: 'assets/home/next_gen.png',
    color: PelevoColors.green,
  ),
];

const _followingItems = [
  _SeeAllItem(
    title: 'The Honest Bunch',
    subtitle: 'Ep. 124 · 48 min · 2h ago',
    assetPath: 'assets/home/honest_bunch.png',
  ),
  _SeeAllItem(
    title: 'The Tech Point',
    subtitle: 'Ep. 88 · 36 min · 5h ago',
    assetPath: 'assets/home/trend_tech.png',
    color: PelevoColors.green,
  ),
  _SeeAllItem(
    title: 'Deep Conversations',
    subtitle: 'Ep. 31 · 41 min · Yesterday',
    assetPath: 'assets/home/deep_conversations.png',
    color: PelevoColors.yellow,
    route: '/screen/library-3',
  ),
  _SeeAllItem(
    title: 'Story Circle',
    subtitle: 'Ep. 54 · 39 min · Yesterday',
    assetPath: 'assets/home/story_circle.png',
  ),
  _SeeAllItem(
    title: 'Creative Minds',
    subtitle: 'Ep. 17 · 28 min · 2d ago',
    assetPath: 'assets/home/creative_minds.png',
    color: PelevoColors.purple,
  ),
  _SeeAllItem(
    title: 'African Tech',
    subtitle: 'Ep. 62 · 33 min · 3d ago',
    assetPath: 'assets/home/african_tech.png',
    color: PelevoColors.green,
  ),
];

List<_SeeAllItem> _africanVoiceItems(int filter) => switch (filter) {
  0 => const [
    _SeeAllItem(
      title: 'Culture & Society',
      subtitle: 'Nigeria · Story Circle',
      assetPath: 'assets/home/story_circle.png',
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Lagos Stories',
      subtitle: 'Nigeria · The Honest Bunch',
      assetPath: 'assets/home/honest_bunch.png',
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Naija Tech',
      subtitle: 'Nigeria · African Tech',
      assetPath: 'assets/home/african_tech.png',
      color: PelevoColors.green,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Naija Conversations',
      subtitle: 'Nigeria · Deep Talk',
      assetPath: 'assets/home/deep_talk.png',
      color: PelevoColors.yellow,
      route: '/screen/podcast-details',
    ),
  ],
  1 => const [
    _SeeAllItem(
      title: 'Accra Voices',
      subtitle: 'Ghana · Voices That Inspire',
      assetPath: 'assets/home/voices_inspire.png',
      color: PelevoColors.yellow,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Gold Coast Talk',
      subtitle: 'Ghana · Creative Minds',
      assetPath: 'assets/home/creative_minds.png',
      color: PelevoColors.purple,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Highlife Hours',
      subtitle: 'Ghana · AfroBeats Vibes',
      assetPath: 'assets/home/afrobeats_vibes.png',
      color: PelevoColors.yellow,
      route: '/screen/library-3',
    ),
    _SeeAllItem(
      title: 'Accra After Dark',
      subtitle: 'Ghana · Tea With Tay',
      assetPath: 'assets/home/tea_with_tay.png',
      color: PelevoColors.purple,
      route: '/screen/podcast-details',
    ),
  ],
  _ => const [
    _SeeAllItem(
      title: 'Nairobi Now',
      subtitle: 'Kenya · The Tech Point',
      assetPath: 'assets/home/trend_tech.png',
      color: PelevoColors.green,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'East African',
      subtitle: 'Kenya · Next Gen Leaders',
      assetPath: 'assets/home/next_gen.png',
      color: PelevoColors.green,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Swahili Stories',
      subtitle: 'Kenya · Deep Talk',
      assetPath: 'assets/home/deep_talk.png',
      color: PelevoColors.yellow,
      route: '/screen/podcast-details',
    ),
    _SeeAllItem(
      title: 'Nairobi Mornings',
      subtitle: 'Kenya · Morning Motivation',
      assetPath: 'assets/home/morning_motivation.png',
      route: '/screen/library-3',
    ),
  ],
};

class _EpisodeSeeAll extends StatelessWidget {
  const _EpisodeSeeAll({
    required this.subtitle,
    required this.items,
    this.ranked = false,
    this.bannerTitle,
    this.bannerSubtitle,
  });

  final String subtitle;
  final List<_SeeAllItem> items;
  final bool ranked;
  final String? bannerTitle;
  final String? bannerSubtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(subtitle, style: const TextStyle(color: PelevoColors.textMuted)),
      const SizedBox(height: PelevoSpacing.md),
      if (bannerTitle != null) ...[
        Container(
          padding: const EdgeInsets.all(PelevoSpacing.sm),
          decoration: BoxDecoration(
            color: PelevoColors.surface,
            borderRadius: PelevoRadii.card,
            border: Border.all(color: PelevoColors.border),
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
                    Text(
                      bannerTitle!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      bannerSubtitle ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PelevoSpacing.md),
      ],
      for (var index = 0; index < items.length; index++)
        PelevoEpisodeTile(
          rank: ranked ? index + 1 : null,
          title: items[index].title,
          subtitle: items[index].subtitle,
          color: items[index].color,
          assetPath: items[index].assetPath,
          onTap: () => context.push(items[index].route),
        ),
    ],
  );
}

class _FilteredEpisodeSeeAll extends StatelessWidget {
  const _FilteredEpisodeSeeAll({
    required this.subtitle,
    required this.filters,
    required this.selected,
    required this.onSelected,
    required this.items,
  });

  final String subtitle;
  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<_SeeAllItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(subtitle, style: const TextStyle(color: PelevoColors.textMuted)),
      const SizedBox(height: PelevoSpacing.sm),
      Wrap(
        spacing: 8,
        children: [
          for (var index = 0; index < filters.length; index++)
            ChoiceChip(
              label: Text(filters[index]),
              selected: selected == index,
              selectedColor: PelevoColors.green.withValues(alpha: .28),
              onSelected: (_) => onSelected(index),
            ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.md),
      for (final item in items)
        PelevoEpisodeTile(
          title: item.title,
          subtitle: item.subtitle,
          color: item.color,
          assetPath: item.assetPath,
          onTap: () => context.push(item.route),
        ),
    ],
  );
}

class _TryNewSeeAll extends StatelessWidget {
  const _TryNewSeeAll({required this.subtitle});

  final String subtitle;

  static const _categories = [
    (label: 'Science', icon: Icons.science_outlined, color: Color(0xFF1E3A5F)),
    (
      label: 'Comedy',
      icon: Icons.sentiment_satisfied_alt_outlined,
      color: Color(0xFF4A2A18),
    ),
    (
      label: 'Sports',
      icon: Icons.sports_soccer_outlined,
      color: Color(0xFF1A3D2A),
    ),
    (label: 'News', icon: Icons.newspaper_outlined, color: Color(0xFF3A1A3A)),
    (label: 'Health', icon: Icons.favorite_outline, color: Color(0xFF4A1A2A)),
    (
      label: 'History',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF2A2A4A),
    ),
    (label: 'True Crime', icon: Icons.gavel_outlined, color: Color(0xFF3A2A18)),
    (label: 'Kids', icon: Icons.child_care_outlined, color: Color(0xFF1A3A3A)),
    (
      label: 'Business',
      icon: Icons.payments_outlined,
      color: Color(0xFF3A3218),
    ),
    (
      label: 'Faith',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFF2A2150),
    ),
    (label: 'Culture', icon: Icons.public_outlined, color: Color(0xFF1B4B4A)),
    (
      label: 'Technology',
      icon: Icons.memory_outlined,
      color: Color(0xFF1A2748),
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(subtitle, style: const TextStyle(color: PelevoColors.textMuted)),
      const SizedBox(height: PelevoSpacing.md),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (final category in _categories)
            InkWell(
              borderRadius: PelevoRadii.card,
              onTap: () => context.push('/screen/browse-categories'),
              child: Container(
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: PelevoRadii.card,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(category.icon, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      category.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _TopicsSeeAll extends StatelessWidget {
  const _TopicsSeeAll({
    required this.selected,
    required this.onSelected,
    required this.subtitle,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final String subtitle;

  static const _topics = [
    'Business',
    'Relationships',
    'Society',
    'Faith',
    'Culture',
    'Technology',
    'Health',
    'Sports',
  ];

  static const _itemsByTopic = [
    [
      _SeeAllItem(
        title: 'Money & Markets',
        subtitle: 'Business · 36 min',
        assetPath: 'assets/home/african_tech.png',
        color: PelevoColors.green,
      ),
      _SeeAllItem(
        title: 'Founder Hours',
        subtitle: 'Business · 41 min',
        assetPath: 'assets/home/next_gen.png',
        color: PelevoColors.green,
      ),
    ],
    [
      _SeeAllItem(
        title: 'Honest Love',
        subtitle: 'Relationships · 44 min',
        assetPath: 'assets/home/honest_bunch.png',
      ),
      _SeeAllItem(
        title: 'Boundaries',
        subtitle: 'Relationships · 31 min',
        assetPath: 'assets/home/tea_with_tay.png',
        color: PelevoColors.purple,
      ),
    ],
    [
      _SeeAllItem(
        title: 'Culture & Society',
        subtitle: 'Society · 39 min',
        assetPath: 'assets/home/story_circle.png',
      ),
      _SeeAllItem(
        title: 'Civic Voices',
        subtitle: 'Society · 33 min',
        assetPath: 'assets/home/voices_inspire.png',
        color: PelevoColors.yellow,
      ),
    ],
    [
      _SeeAllItem(
        title: 'Faith & Purpose',
        subtitle: 'Faith · 28 min',
        assetPath: 'assets/home/morning_motivation.png',
        route: '/screen/library-3',
      ),
      _SeeAllItem(
        title: 'Quiet Strength',
        subtitle: 'Faith · 22 min',
        assetPath: 'assets/home/voices_inspire.png',
        color: PelevoColors.yellow,
      ),
    ],
    [
      _SeeAllItem(
        title: 'AfroBeats Vibes',
        subtitle: 'Culture · 18 items',
        assetPath: 'assets/home/afrobeats_vibes.png',
        color: PelevoColors.yellow,
        route: '/screen/library-3',
      ),
      _SeeAllItem(
        title: 'Story Circle',
        subtitle: 'Culture · 42 min',
        assetPath: 'assets/home/story_circle.png',
      ),
    ],
    [
      _SeeAllItem(
        title: 'AI in Africa',
        subtitle: 'Technology · 36 min',
        assetPath: 'assets/home/trend_tech.png',
        color: PelevoColors.green,
      ),
      _SeeAllItem(
        title: 'Build quietly',
        subtitle: 'Technology · 29 min',
        assetPath: 'assets/home/african_tech.png',
        color: PelevoColors.green,
      ),
    ],
    [
      _SeeAllItem(
        title: 'Sleep & Unwind',
        subtitle: 'Health · 24 min',
        assetPath: 'assets/home/mindset.png',
      ),
      _SeeAllItem(
        title: 'Body & Mind',
        subtitle: 'Health · 27 min',
        assetPath: 'assets/home/deep_talk.png',
        color: PelevoColors.green,
      ),
    ],
    [
      _SeeAllItem(
        title: 'Match Day Talk',
        subtitle: 'Sports · 32 min',
        assetPath: 'assets/home/next_gen.png',
        color: PelevoColors.green,
      ),
      _SeeAllItem(
        title: 'Locker Room',
        subtitle: 'Sports · 21 min',
        assetPath: 'assets/home/creative_minds.png',
        color: PelevoColors.purple,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(subtitle, style: const TextStyle(color: PelevoColors.textMuted)),
      const SizedBox(height: PelevoSpacing.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < _topics.length; index++)
            ChoiceChip(
              label: Text(_topics[index]),
              selected: selected == index,
              selectedColor: PelevoColors.green.withValues(alpha: .28),
              onSelected: (_) => onSelected(index),
            ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.md),
      for (final item in _itemsByTopic[selected])
        PelevoEpisodeTile(
          title: item.title,
          subtitle: item.subtitle,
          color: item.color,
          assetPath: item.assetPath,
          onTap: () => context.push(item.route),
        ),
    ],
  );
}
