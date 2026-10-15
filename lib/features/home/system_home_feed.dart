import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/ads/feed_native_ads.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/home/mood_discover_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';

class SystemHomeFeed extends ConsumerStatefulWidget {
  const SystemHomeFeed({super.key});

  @override
  ConsumerState<SystemHomeFeed> createState() => _SystemHomeFeedState();
}

class _SystemHomeFeedState extends ConsumerState<SystemHomeFeed>
    with WidgetsBindingObserver {
  int _quickListen = 0;
  int _africanVoice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(homeLatestShortsProvider);
    final saved = ref.read(homeRepositoryProvider).cachedAt();
    final age = saved == null ? null : DateTime.now().toUtc().difference(saved);
    if (age != null && age <= HomeRepository.freshFor) return;
    ref.invalidate(homeFeedProvider);
    ref.invalidate(homeRailProvider);
  }

  static const _quickListenFilters = [
    (label: '5-10 min', min: 300, max: 600),
    (label: '10-20 min', min: 600, max: 1200),
    (label: '30+ min', min: 1800, max: null),
  ];

  static const _africanVoiceFilters = [
    (label: 'Nigeria', code: 'NG'),
    (label: 'Ghana', code: 'GH'),
    (label: 'Kenya', code: 'KE'),
    (label: 'South Africa', code: 'ZA'),
  ];

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final continueMemory = ref.watch(continueListeningMemoryProvider);
    final name = ref.watch(userDisplayNameProvider);
    final quickFilter = _quickListenFilters[_quickListen];
    final africanFilter = _africanVoiceFilters[_africanVoice];
    final quickRail = ref.watch(
      homeRailProvider(
        HomeRailRequest(
          'quick_listen',
          minDurationSeconds: quickFilter.min,
          maxDurationSeconds: quickFilter.max,
        ),
      ),
    );
    final africanRail = ref.watch(
      homeRailProvider(
        HomeRailRequest('african_voices', countryCode: africanFilter.code),
      ),
    );

    return PelevoPage(
      scrollable: false,
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(homeRailProvider);
          ref.invalidate(homeLatestShortsProvider);
          await ref.read(homeFeedProvider.future);
          await ref.read(homeLatestShortsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(name: name)),
            feed.when(
              loading:
                  () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (_, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      onRetry: () => ref.invalidate(homeFeedProvider),
                    ),
                  ),
              data: (value) {
                final byKey = {for (final rail in value.rails) rail.key: rail};
                final children = <Widget>[
                  _MoodGrid(items: byKey['moods']?.items ?? const []),
                  if (byKey['pick_for_today'] case final pick?
                      when pick.items.isNotEmpty)
                    _PickForTodayCard(rail: pick, item: pick.items.first),
                  if (mergeContinueListeningRail(
                        byKey['continue_listening'],
                        continueMemory,
                      )
                      case final rail?)
                    _ContinueListeningSection(rail: rail),
                  const HomeFeedNativeAd(),
                  if (byKey['made_for_you'] case final rail?
                      when rail.items.isNotEmpty)
                    _MadeForYouSection(rail: rail),
                  if (byKey['quick_listen'] case final rail?
                      when rail.items.isNotEmpty)
                    _QuickListenSection(
                      rail: rail,
                      selected: _quickListen,
                      labels: [
                        for (final filter in _quickListenFilters) filter.label,
                      ],
                      filteredItems:
                          quickRail.asData?.value.items ?? rail.items,
                      onFilter: (index) => setState(() => _quickListen = index),
                    ),
                  if (byKey['because_you_listened'] case final rail?
                      when rail.items.isNotEmpty)
                    _BecauseYouListenedSection(rail: rail),
                  if (byKey['trending'] case final rail?
                      when rail.items.isNotEmpty)
                    _TrendingShowsSection(rail: rail),
                  if (byKey['new_from_following'] case final rail?
                      when rail.items.isNotEmpty)
                    _FollowingNewSection(rail: rail),
                  if (byKey['african_voices'] case final rail?
                      when rail.items.isNotEmpty)
                    _AfricanVoicesSection(
                      rail: rail,
                      selected: _africanVoice,
                      labels: [
                        for (final filter in _africanVoiceFilters) filter.label,
                      ],
                      filteredItems:
                          africanRail.asData?.value.items ?? rail.items,
                      onFilter:
                          (index) => setState(() => _africanVoice = index),
                    ),
                  if (byKey['try_something_new'] case final rail?)
                    _TrySomethingNewSection(
                      rail: rail,
                      surpriseFallback: byKey['moods']?.items ?? const [],
                    ),
                  if (byKey['explore_by_topic'] case final rail?
                      when rail.items.isNotEmpty)
                    _ExploreByTopicSection(rail: rail),
                  _LatestShortsSection(
                    fallback:
                        byKey['shorts_for_you'] ?? byKey['trending_shorts'],
                  ),
                  if (byKey['browse_categories'] case final rail?)
                    _BrowseCategoriesSection(rail: rail),
                  const SizedBox(height: PelevoSpacing.xl),
                ];

                if (value.rails.every((rail) => rail.items.isEmpty) &&
                    byKey['moods'] == null) {
                  children.add(
                    const Padding(
                      padding: EdgeInsets.all(PelevoSpacing.xl),
                      child: Column(
                        children: [
                          Icon(Icons.podcasts_rounded, size: 46),
                          SizedBox(height: PelevoSpacing.sm),
                          Text(
                            'Your Home is getting ready',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: PelevoSpacing.xs),
                          Text(
                            'Follow a show or play an episode to shape your recommendations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: PelevoColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList.list(children: children);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SystemHomeRailScreen extends ConsumerStatefulWidget {
  const SystemHomeRailScreen({
    required this.railKey,
    required this.fallbackTitle,
    super.key,
  });

  final String railKey;
  final String fallbackTitle;

  @override
  ConsumerState<SystemHomeRailScreen> createState() =>
      _SystemHomeRailScreenState();
}

class _SystemHomeRailScreenState extends ConsumerState<SystemHomeRailScreen> {
  int _filter = 0;

  static const _quickListenFilters = [
    (label: '5-10 min', min: 300, max: 600),
    (label: '10-20 min', min: 600, max: 1200),
    (label: '30+ min', min: 1800, max: null),
  ];

  static const _africanVoiceFilters = [
    (label: 'Nigeria', code: 'NG'),
    (label: 'Ghana', code: 'GH'),
    (label: 'Kenya', code: 'KE'),
    (label: 'South Africa', code: 'ZA'),
  ];

  HomeRailRequest get _request {
    if (widget.railKey == 'quick_listen') {
      final selected = _quickListenFilters[_filter];
      return HomeRailRequest(
        widget.railKey,
        minDurationSeconds: selected.min,
        maxDurationSeconds: selected.max,
      );
    }
    if (widget.railKey == 'african_voices') {
      return HomeRailRequest(
        widget.railKey,
        countryCode: _africanVoiceFilters[_filter].code,
      );
    }
    return HomeRailRequest(widget.railKey);
  }

  HomeRail? _seededFromFeed() {
    final feed = ref.watch(homeFeedProvider).asData?.value;
    if (feed == null) return null;
    for (final rail in feed.rails) {
      if (rail.key == widget.railKey && rail.items.isNotEmpty) return rail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final state = ref.watch(homeRailProvider(request));
    final seeded = _seededFromFeed();
    final filters =
        widget.railKey == 'quick_listen'
            ? [for (final filter in _quickListenFilters) filter.label]
            : widget.railKey == 'african_voices'
            ? [for (final filter in _africanVoiceFilters) filter.label]
            : const <String>[];
    return PelevoPage(
      scrollable: false,
      appBar: AppBar(
        title: Text(
          state.asData?.value.title ?? seeded?.title ?? widget.fallbackTitle,
        ),
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: state.when(
        skipLoadingOnReload: true,
        loading:
            () =>
                seeded == null
                    ? const Center(child: CircularProgressIndicator())
                    : _railContent(seeded, filters, refreshing: true),
        error:
            (_, _) =>
                seeded != null
                    ? _railContent(seeded, filters)
                    : _ErrorState(
                      onRetry: () => ref.invalidate(homeRailProvider(request)),
                    ),
        data: (rail) => _railContent(rail, filters),
      ),
    );
  }

  Widget _railContent(
    HomeRail rail,
    List<String> filters, {
    bool refreshing = false,
  }) {
    if (rail.items.isEmpty && filters.isEmpty) {
      return const Center(
        child: Text(
          'No items are available yet.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (refreshing) const LinearProgressIndicator(minHeight: 2),
        if (rail.subtitle != null && rail.subtitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: Text(
              rail.subtitle!,
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
          ),
        if (filters.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < filters.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                    child: _FilterChip(
                      label: filters[index],
                      selected: _filter == index,
                      onSelected: () => setState(() => _filter = index),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child:
              rail.items.isEmpty
                  ? const Center(
                    child: Text(
                      'No items match this filter yet.',
                      style: TextStyle(color: PelevoColors.textMuted),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: PelevoSpacing.md,
                    ),
                    itemCount: rail.items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = rail.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _Artwork(url: item.artworkUrl, size: 58),
                        title: Text(item.title),
                        subtitle: Text(
                          item.showTitle ??
                              item.playCountLabel ??
                              item.subtitle ??
                              '',
                        ),
                        trailing:
                            item.type == 'episode'
                                ? IconButton(
                                  tooltip: 'Play ${item.title}',
                                  onPressed:
                                      () => _playItem(context, item, ref),
                                  icon: const Icon(
                                    Icons.play_circle_outline_rounded,
                                  ),
                                )
                                : const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openItem(context, item, ref),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

void _openItem(BuildContext context, HomeItem item, [WidgetRef? ref]) {
  if (ref != null && (item.type == 'mood' || item.type == 'category')) {
    openMoodDiscover(context, ref, item.title, slug: item.slug);
    return;
  }
  openCatalogHomeDestination(context, item);
}

void _playItem(BuildContext context, HomeItem item, [WidgetRef? ref]) {
  if (item.type != 'episode') {
    _openItem(context, item, ref);
    return;
  }
  playCatalogHomeItem(context, item);
}

class _Header extends ConsumerWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.md,
      bottom: PelevoSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('/screen/profile'),
              child: Row(
                children: [
                  ProfileAvatar(
                    url: ref.watch(profileProvider).asData?.value.avatarUrl,
                    size: 34,
                    borderWidth: 1.5,
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
                  tooltip: 'Notifications',
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
          'Good ${_dayPart()}, $name',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'What are you in the mood for today?',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    ),
  );

  static String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (seeAllRoute != null)
              TextButton(
                onPressed: () => context.push(seeAllRoute!),
                child: const Text(
                  'See All',
                  style: TextStyle(color: PelevoColors.green),
                ),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.sm),
        child,
      ],
    ),
  );
}

class _MoodGrid extends ConsumerWidget {
  const _MoodGrid({required this.items});

  final List<HomeItem> items;

  static const _fallback = [
    (
      'Learn Something',
      Icons.menu_book_rounded,
      Color(0xFF1B4B4A),
      'education',
    ),
    (
      'Money & Business',
      Icons.payments_outlined,
      Color(0xFF3A3218),
      'business',
    ),
    (
      'Feel Something',
      Icons.favorite_outline_rounded,
      Color(0xFF4A1D2A),
      'society',
    ),
    (
      'Faith & Purpose',
      Icons.auto_awesome_outlined,
      Color(0xFF2A2150),
      'faith',
    ),
    ('Be Entertained', Icons.celebration_outlined, Color(0xFF3A2748), 'comedy'),
    ('Sleep & Unwind', Icons.nights_stay_outlined, Color(0xFF1A2748), 'health'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles =
        items.isEmpty
            ? _fallback
            : [
              for (final item in items.take(6))
                (
                  item.title,
                  _moodIcon(item.icon),
                  _parseColor(item.color) ?? const Color(0xFF1B4B4A),
                  item.slug ?? item.title,
                ),
            ];

    return Padding(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.xl),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          for (final tile in tiles)
            _MoodTile(
              label: tile.$1,
              icon: tile.$2,
              color: tile.$3,
              slug: tile.$4,
              onTap:
                  () => openMoodDiscover(context, ref, tile.$1, slug: tile.$4),
            ),
        ],
      ),
    );
  }

  static IconData _moodIcon(String? key) => switch (key) {
    'payments' => Icons.payments_outlined,
    'favorite' => Icons.favorite_outline_rounded,
    'auto_awesome' => Icons.auto_awesome_outlined,
    'celebration' => Icons.celebration_outlined,
    'nights_stay' => Icons.nights_stay_outlined,
    _ => Icons.menu_book_rounded,
  };
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.slug,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String slug;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: onTap,
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
  const _PickForTodayCard({required this.rail, required this.item});

  final HomeRail rail;
  final HomeItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PelevoSpacing.xl),
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        color: PelevoColors.surface,
        borderRadius: PelevoRadii.card,
        border: Border.all(color: PelevoColors.green.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(rail.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openItem(context, item),
                child: _Artwork(url: item.artworkUrl, size: 92),
              ),
              const SizedBox(width: PelevoSpacing.sm),
              Expanded(
                child: InkWell(
                  onTap: () => _openItem(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description ??
                            item.showTitle ??
                            'A recommendation shaped for you.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: PelevoSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (item.durationLabel != null)
                            _MetaBadge(label: item.durationLabel!),
                          if (item.matchPercent != null)
                            _MetaBadge(
                              label: '${item.matchPercent}% match',
                              emphasize: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (item.reason case final reason?) ...[
            const SizedBox(height: PelevoSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: PelevoColors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: PelevoSpacing.sm),
          PelevoButton(
            label: 'Listen Now',
            icon: Icons.play_arrow_rounded,
            color: PelevoColors.green,
            onPressed: () => _playItem(context, item),
          ),
        ],
      ),
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
              : PelevoColors.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: emphasize ? PelevoColors.green : PelevoColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ContinueListeningSection extends StatelessWidget {
  const _ContinueListeningSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-continue-listening',
      child: SizedBox(
        height: 214,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: rail.items.length,
          separatorBuilder: (_, _) => const SizedBox(width: PelevoSpacing.sm),
          itemBuilder: (context, index) {
            final item = rail.items[index];
            return _ContinueCard(item: item);
          },
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item});

  final HomeItem item;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(PelevoRadii.medium),
          child: Stack(
            children: [
              InkWell(
                onTap: () => _openItem(context, item),
                child: _Artwork(url: item.artworkUrl, size: 140),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Material(
                  color: PelevoColors.green,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => _playItem(context, item),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openItem(context, item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _progressLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PelevoColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _progressLabel(HomeItem item) {
    final position = item.positionSeconds ?? 0;
    final duration = item.durationSeconds ?? 0;
    if (duration <= 0) return item.showTitle ?? '';
    return '${_clock(position)} / ${_clock(duration)}';
  }

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _MadeForYouSection extends StatelessWidget {
  const _MadeForYouSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-made-for-you',
      child: Column(
        children: [
          for (final item in rail.items.take(5))
            PelevoEpisodeTile(
              title: item.title,
              subtitle: [
                if (item.showTitle case final show?) show,
                if (item.durationLabel case final duration?) duration,
                if (item.matchPercent case final match?) '$match% match',
              ].join(' · '),
              artworkUrl: item.artworkUrl,
              trailing: Icons.play_circle_fill_rounded,
              color: PelevoColors.green,
              onTap: () => _openItem(context, item),
              onPlay: () => _playItem(context, item),
            ),
        ],
      ),
    );
  }
}

class _QuickListenSection extends StatelessWidget {
  const _QuickListenSection({
    required this.rail,
    required this.selected,
    required this.labels,
    required this.filteredItems,
    required this.onFilter,
  });

  final HomeRail rail;
  final int selected;
  final List<String> labels;
  final List<HomeItem> filteredItems;
  final ValueChanged<int> onFilter;

  @override
  Widget build(BuildContext context) => _Section(
    title: rail.title,
    seeAllRoute: '/screen/home-quick-listen',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var index = 0; index < labels.length; index++)
              _FilterChip(
                label: labels[index],
                selected: selected == index,
                onSelected: () => onFilter(index),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.sm),
        if (filteredItems.isEmpty)
          const Text(
            'No episodes match this length yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filteredItems.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: PelevoSpacing.sm),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _QuickListenCard(item: item);
              },
            ),
          ),
      ],
    ),
  );
}

class _QuickListenCard extends StatelessWidget {
  const _QuickListenCard({required this.item});

  final HomeItem item;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: InkWell(
      borderRadius: PelevoRadii.card,
      onTap: () => _openItem(context, item),
      child: Container(
        padding: const EdgeInsets.all(PelevoSpacing.sm),
        decoration: BoxDecoration(
          color: PelevoColors.surface,
          borderRadius: PelevoRadii.card,
          border: Border.all(color: PelevoColors.border),
        ),
        child: Row(
          children: [
            _Artwork(url: item.artworkUrl, size: 56),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    item.durationLabel ?? item.showTitle ?? '',
                    style: const TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Play ${item.title}',
              onPressed: () => _playItem(context, item),
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: PelevoColors.green,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BecauseYouListenedSection extends StatelessWidget {
  const _BecauseYouListenedSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    final inspiration = rail.inspiration;
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-because-you-listened',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inspiration != null) ...[
            _RecommendationReason(
              title: inspiration.title,
              subtitle: inspiration.subtitle,
            ),
            const SizedBox(height: PelevoSpacing.sm),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth / 3;
              return SizedBox(
                height: cardWidth + 55,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: rail.items.length,
                  itemBuilder: (context, index) {
                    final item = rail.items[index];
                    return _SquareCard(
                      width: cardWidth,
                      item: item,
                      color:
                          [
                            PelevoColors.green,
                            PelevoColors.red,
                            PelevoColors.yellow,
                            PelevoColors.purple,
                          ][index % 4],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecommendationReason extends StatelessWidget {
  const _RecommendationReason({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
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

class _SquareCard extends StatelessWidget {
  const _SquareCard({
    required this.width,
    required this.item,
    required this.color,
  });

  final double width;
  final HomeItem item;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      onTap: () => _openItem(context, item),
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
                    child: _Artwork(
                      url: item.artworkUrl,
                      size: width - PelevoSpacing.sm,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      tooltip: 'Play ${item.title}',
                      onPressed: () => _playItem(context, item),
                      icon: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: PelevoColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              item.showTitle ?? item.subtitle ?? '',
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

class _TrendingShowsSection extends StatelessWidget {
  const _TrendingShowsSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-trending',
      child: Column(
        children: [
          for (final item in rail.items.take(5))
            PelevoEpisodeTile(
              rank: item.rank,
              title: item.title,
              subtitle:
                  (item.playCount ?? 0) > 0 && item.playCountLabel != null
                      ? '${item.playCountLabel} plays'
                      : 'Trending',
              artworkUrl: item.artworkUrl,
              trailing: Icons.play_circle_outline_rounded,
              color: PelevoColors.yellow,
              onTap: () => _openItem(context, item),
              onPlay:
                  item.type == 'episode'
                      ? () => _playItem(context, item)
                      : null,
            ),
        ],
      ),
    );
  }
}

class _FollowingNewSection extends StatelessWidget {
  const _FollowingNewSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-following-new',
      child: Column(
        children: [
          for (final item in rail.items.take(5))
            PelevoEpisodeTile(
              title: item.showTitle ?? item.title,
              subtitle: [
                item.title,
                if (item.durationLabel case final duration?) duration,
                if (item.publishedLabel case final published?) published,
              ].join(' · '),
              artworkUrl: item.artworkUrl,
              trailing: Icons.play_circle_fill_rounded,
              onTap: () => _openItem(context, item),
              onPlay: () => _playItem(context, item),
            ),
        ],
      ),
    );
  }
}

class _AfricanVoicesSection extends StatelessWidget {
  const _AfricanVoicesSection({
    required this.rail,
    required this.selected,
    required this.labels,
    required this.filteredItems,
    required this.onFilter,
  });

  final HomeRail rail;
  final int selected;
  final List<String> labels;
  final List<HomeItem> filteredItems;
  final ValueChanged<int> onFilter;

  @override
  Widget build(BuildContext context) => _Section(
    title: rail.title,
    seeAllRoute: '/screen/home-african-voices',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var index = 0; index < labels.length; index++)
              _FilterChip(
                label: labels[index],
                selected: selected == index,
                onSelected: () => onFilter(index),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.sm),
        if (filteredItems.isEmpty)
          const Text(
            'No shows for this country yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filteredItems.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: PelevoSpacing.sm),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return SizedBox(
                  width: 132,
                  child: InkWell(
                    onTap: () => _openItem(context, item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            _Artwork(url: item.artworkUrl, size: 132),
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
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          _countryLabel(item.countryCode) ??
                              item.subtitle ??
                              '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PelevoColors.textMuted,
                            fontSize: 12,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );

  static String? _countryLabel(String? code) => switch (code) {
    'NG' => 'Nigeria',
    'GH' => 'Ghana',
    'KE' => 'Kenya',
    'ZA' => 'South Africa',
    _ => code,
  };
}

class _TrySomethingNewSection extends ConsumerWidget {
  const _TrySomethingNewSection({
    required this.rail,
    this.surpriseFallback = const [],
  });

  final HomeRail rail;
  final List<HomeItem> surpriseFallback;

  static const _styles = <String, (IconData, Color)>{
    'science': (Icons.science_outlined, Color(0xFF1E3A5F)),
    'comedy': (Icons.sentiment_satisfied_alt_outlined, Color(0xFF4A2A18)),
    'sports': (Icons.sports_soccer_outlined, Color(0xFF1A3D2A)),
    'news': (Icons.newspaper_outlined, Color(0xFF3A1A3A)),
    'health': (Icons.favorite_outline, Color(0xFF4A1A2A)),
    'history': (Icons.menu_book_outlined, Color(0xFF2A2A4A)),
    'true-crime': (Icons.gavel_outlined, Color(0xFF3A2A18)),
    'kids': (Icons.child_care_outlined, Color(0xFF1A3A3A)),
    'technology': (Icons.memory_outlined, Color(0xFF1A2A4A)),
    'business': (Icons.payments_outlined, Color(0xFF3A3218)),
    'education': (Icons.school_outlined, Color(0xFF1B4B4A)),
    'music': (Icons.headphones_outlined, Color(0xFF3A1848)),
    'fiction': (Icons.auto_stories_outlined, Color(0xFF2A2150)),
    'religion': (Icons.auto_awesome_outlined, Color(0xFF2A2150)),
    'society': (Icons.groups_outlined, Color(0xFF4A1D2A)),
    'arts': (Icons.palette_outlined, Color(0xFF4A2A40)),
    'leisure': (Icons.sports_esports_outlined, Color(0xFF1A3A3A)),
    'tv': (Icons.tv_outlined, Color(0xFF1A2748)),
    'government': (Icons.account_balance_outlined, Color(0xFF2A2A3A)),
    'culture': (Icons.public_outlined, Color(0xFF1B3A4A)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = rail.items.isNotEmpty ? rail.items : surpriseFallback;

    return Column(
      children: [
        if (rail.items.isNotEmpty)
          _Section(
            title: rail.title,
            seeAllRoute: '/screen/home-try-new',
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .92,
              children: [
                for (final item in rail.items.take(8))
                  _TryNewTile(
                    label: item.title,
                    icon: _styles[item.slug]?.$1 ?? Icons.explore_outlined,
                    color: _styles[item.slug]?.$2 ?? const Color(0xFF2A2A4A),
                    onTap:
                        () => openMoodDiscover(
                          context,
                          ref,
                          item.title,
                          slug: item.slug,
                        ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: _SurpriseBanner(
            onTap: () {
              final choices =
                  pool.isNotEmpty
                      ? pool
                      : const [
                        HomeItem(
                          id: 'surprise',
                          type: 'category',
                          title: 'Be Entertained',
                          slug: 'comedy',
                        ),
                      ];
              final pick = choices[DateTime.now().millisecond % choices.length];
              openMoodDiscover(context, ref, pick.title, slug: pick.slug);
            },
          ),
        ),
      ],
    );
  }
}

class _TryNewTile extends StatelessWidget {
  const _TryNewTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SurpriseBanner extends StatelessWidget {
  const _SurpriseBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: PelevoRadii.card,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        borderRadius: PelevoRadii.card,
        gradient: const LinearGradient(
          colors: [Color(0xFF5B2C8A), Color(0xFF2A2150)],
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.casino_outlined, color: Colors.white),
          SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surprise Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Get a suggestion',
                  style: TextStyle(color: Color(0xFFD7C6F0), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    ),
  );
}

class _ExploreByTopicSection extends ConsumerWidget {
  const _ExploreByTopicSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/home-topics',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in rail.items.take(12))
            ActionChip(
              label: Text(item.title),
              onPressed:
                  () => openMoodDiscover(
                    context,
                    ref,
                    item.title,
                    slug: item.slug,
                  ),
              side: const BorderSide(color: Colors.white54),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

class _LatestShortsSection extends ConsumerWidget {
  const _LatestShortsSection({required this.fallback});

  final HomeRail? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(homeLatestShortsProvider);
    return latest.when(
      data: (shorts) {
        if (shorts.isEmpty) return _fallbackRail();
        return _ShortsSection(
          rail: HomeRail(
            id: 'home.latest_shorts',
            key: 'latest_shorts',
            type: 'shorts',
            title: 'Latest Shorts',
            items: [for (final reel in shorts) homeItemFromReel(reel)],
          ),
        );
      },
      loading: _fallbackRail,
      error: (_, _) => _fallbackRail(),
    );
  }

  Widget _fallbackRail() {
    final rail = fallback;
    if (rail == null || rail.items.isEmpty) return const SizedBox.shrink();
    return _ShortsSection(rail: rail);
  }
}

class _ShortsSection extends StatelessWidget {
  const _ShortsSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) {
    if (rail.items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: rail.title,
      seeAllRoute: '/screen/reels',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth / 2.35;
          return SizedBox(
            height: cardWidth * 1.38 + 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: rail.items.length,
              itemBuilder: (context, index) {
                final item = rail.items[index];
                return _ShortCard(
                  width: cardWidth,
                  item: item,
                  accent:
                      _parseColor(item.badgeColor) ??
                      [
                        PelevoColors.purple,
                        PelevoColors.red,
                        PelevoColors.green,
                        PelevoColors.yellow,
                      ][index % 4],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({
    required this.width,
    required this.item,
    required this.accent,
  });

  final double width;
  final HomeItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final art = sanitizeArtworkUrl(item.artworkUrl);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: PelevoSpacing.sm),
        child: InkWell(
          onTap:
              () => context.push(
                Uri(
                  path: '/screen/reels',
                  queryParameters: {if (item.id.isNotEmpty) 'reelId': item.id},
                ).toString(),
              ),
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
                        color: PelevoColors.surfaceHigh,
                        child:
                            art == null
                                ? const Icon(
                                  Icons.smart_display_rounded,
                                  size: 42,
                                )
                                : PelevoNetworkArt(
                                  url: art,
                                  fit: BoxFit.cover,
                                  fallback: const Icon(
                                    Icons.smart_display_rounded,
                                    size: 42,
                                  ),
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
                      if (item.badge case final badge?)
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
                          item.title,
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
                item.subtitle ?? '',
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
}

class _BrowseCategoriesSection extends StatelessWidget {
  const _BrowseCategoriesSection({required this.rail});

  final HomeRail rail;

  @override
  Widget build(BuildContext context) => _Section(
    title: rail.title,
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
            children: [for (final item in rail.items) _BrowseTile(item: item)],
          ),
    ),
  );
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.item});

  final HomeItem item;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(item.color) ?? PelevoColors.surfaceHigh;
    final route = switch (item.slug) {
      'shorts' => '/screen/reels',
      'more' => '/screen/browse',
      _ => '/screen/browse-categories',
    };
    return InkWell(
      borderRadius: PelevoRadii.card,
      onTap: () => context.push(route),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_browseIcon(item.icon), color: Colors.white),
            const SizedBox(height: 8),
            Text(
              item.title,
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

  static IconData _browseIcon(String? key) => switch (key) {
    'smart_display' => Icons.smart_display_rounded,
    'headphones' => Icons.headphones,
    'grid_view' => Icons.grid_view_rounded,
    _ => Icons.podcasts,
  };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          const Icon(Icons.check, size: 14, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(label),
      ],
    ),
    selected: selected,
    selectedColor: PelevoColors.green.withValues(alpha: .45),
    backgroundColor: Colors.transparent,
    side: BorderSide(color: selected ? PelevoColors.green : Colors.white54),
    labelStyle: TextStyle(
      color: selected ? Colors.white : PelevoColors.text,
      fontWeight: FontWeight.w600,
    ),
    onSelected: (_) => onSelected(),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeUrl = sanitizeArtworkUrl(url);
    final fallback = const ColoredBox(
      color: Color(0xFF1B2D2B),
      child: Icon(Icons.podcasts_rounded, size: 42),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: size,
        child:
            safeUrl == null
                ? fallback
                : PelevoNetworkArt(
                  url: safeUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fallback: fallback,
                ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(PelevoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 46),
          const SizedBox(height: PelevoSpacing.md),
          Text(
            'Home is temporarily unavailable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PelevoSpacing.xs),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(color: PelevoColors.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) return null;
  var hex = value.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
