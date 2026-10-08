import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/browse/browse_data.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/search/search_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _BrowseView {
  home,
  categories,
  music,
  detail,
  newCollections,
  preview,
  following,
  search,
  filters,
  added,
}

const _browseInventory =
    <({String id, String title, String state, _BrowseView view})>[
      (
        id: 'browse',
        title: 'Browse',
        state: 'Discovery home',
        view: _BrowseView.home,
      ),
      (
        id: 'browse-categories',
        title: 'All Categories',
        state: 'Category index',
        view: _BrowseView.categories,
      ),
      (
        id: 'browse-music',
        title: 'Music Collections',
        state: 'Category collections',
        view: _BrowseView.music,
      ),
      (
        id: 'browse-detail',
        title: 'Collection Detail',
        state: 'Selected category',
        view: _BrowseView.detail,
      ),
      (
        id: 'browse-new',
        title: 'New Collections',
        state: 'Latest collections',
        view: _BrowseView.newCollections,
      ),
      (
        id: 'browse-preview',
        title: 'Collection Preview',
        state: 'Category preview',
        view: _BrowseView.preview,
      ),
      (
        id: 'browse-following',
        title: 'Following',
        state: 'Followed collections',
        view: _BrowseView.following,
      ),
      (
        id: 'browse-search',
        title: 'Search Collections',
        state: 'Collection search',
        view: _BrowseView.search,
      ),
      (
        id: 'browse-filters',
        title: 'Collection Filters',
        state: 'Filters open',
        view: _BrowseView.filters,
      ),
      (
        id: 'browse-added',
        title: 'Collection Added',
        state: 'Added to library',
        view: _BrowseView.added,
      ),
    ];

final List<PelevoScreenSpec> browseScreens = List.unmodifiable(
  _browseInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Browse',
      title: item.title,
      state: item.state,
      builder: (_) => _BrowseScreen(view: item.view, title: item.title),
    ),
  ),
);

const _browseColors = [
  PelevoColors.red,
  PelevoColors.blue,
  PelevoColors.yellow,
  PelevoColors.orange,
  PelevoColors.green,
  PelevoColors.redDark,
  PelevoColors.greenDark,
];

Color _browseColor(String key) =>
    _browseColors[key.hashCode.abs() % _browseColors.length];

IconData _browseIcon(BrowseCategory category) {
  if (category.isMusic) return Icons.headphones_rounded;
  return switch (category.slug) {
    'true-crime' => Icons.fingerprint_rounded,
    'news' => Icons.public_rounded,
    'comedy' => Icons.mood_rounded,
    'technology' => Icons.memory_rounded,
    'business' => Icons.trending_up_rounded,
    'science' => Icons.science_outlined,
    'history' => Icons.account_balance_outlined,
    'sports' => Icons.sports_basketball_rounded,
    'wellness' => Icons.spa_outlined,
    'fiction' => Icons.auto_stories_rounded,
    _ => Icons.grid_view_rounded,
  };
}

class _BrowseScreen extends ConsumerStatefulWidget {
  const _BrowseScreen({required this.view, required this.title});

  final _BrowseView view;
  final String title;

  @override
  ConsumerState<_BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<_BrowseScreen> {
  int _nav = 1;
  bool _following = false;

  BrowseCategory? _resolve(
    List<BrowseCategory> categories, {
    bool music = false,
    String? slug,
  }) {
    if (music) {
      for (final category in categories) {
        if (category.isMusic) return category;
      }
      return null;
    }
    if (slug != null) {
      for (final category in categories) {
        if (category.slug == slug) return category;
      }
    }
    return categories.isEmpty ? null : categories.first;
  }

  String get _backFallback => switch (widget.view) {
    _BrowseView.home => '/screen/search',
    _BrowseView.filters => '/screen/browse-search',
    _BrowseView.detail ||
    _BrowseView.music ||
    _BrowseView.preview => '/screen/browse-categories',
    _ => '/screen/browse',
  };

  void _openCategory(BrowseCategory category) {
    ref.read(browseUiProvider.notifier).select(category.slug);
    context.pelevoOpen(
      category.isMusic ? '/screen/browse-music' : '/screen/browse-detail',
    );
  }

  Future<void> _follow(BrowseShow show) async {
    if (_following) return;
    setState(() => _following = true);
    try {
      await ref.read(browseRepositoryProvider).follow(show.id);
      if (!mounted) return;
      ref.read(browseUiProvider.notifier).rememberAdded(show.title);
      ref.invalidate(browseFollowingProvider);
      context.pelevoOpen('/screen/browse-added');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(browseFailure(error).message);
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Widget _status({
    required AsyncValue<dynamic> value,
    required VoidCallback retry,
    required Widget Function() data,
  }) {
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(browseFailure(error).message),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
      data: (_) => data(),
    );
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: PelevoBackButton(fallback: _backFallback),
      automaticallyImplyLeading: false,
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Search browse catalog',
          onPressed:
              () => context.pelevoOpen(
                widget.view == _BrowseView.search
                    ? '/screen/browse-filters'
                    : '/screen/browse-search',
              ),
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: _nav,
      onDestinationSelected: (value) {
        setState(() => _nav = value);
        context.openPelevoTab(value);
      },
    ),
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    switch (widget.view) {
      case _BrowseView.home:
        return _home(context);
      case _BrowseView.categories:
        return _categories(context);
      case _BrowseView.music:
        return _music(context);
      case _BrowseView.detail:
        return _detail(context);
      case _BrowseView.newCollections:
        return _newCollections(context);
      case _BrowseView.preview:
        return _previewCollection(context);
      case _BrowseView.following:
        return _followingList(context);
      case _BrowseView.search:
        return _search(context);
      case _BrowseView.filters:
        return _filters(context);
      case _BrowseView.added:
        return _added(context);
    }
  }

  Widget _home(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your next listen',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        const Text(
          'Fresh voices, essential stories and conversations selected for you.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoSectionHeader(
          title: 'Categories',
          onSeeAll: () => context.pelevoOpen('/screen/browse-categories'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        _status(
          value: categories,
          retry: () => ref.invalidate(browseCategoriesProvider),
          data: () => _categoryGrid(categories.requireValue, compact: true),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoSectionHeader(
          title: 'Featured Collections',
          onSeeAll: () {
            final items = categories.asData?.value ?? const <BrowseCategory>[];
            if (items.isNotEmpty) {
              ref.read(browseUiProvider.notifier).select(items.first.slug);
            }
            context.pelevoOpen('/screen/browse-detail');
          },
        ),
        const SizedBox(height: PelevoSpacing.sm),
        _status(
          value: categories,
          retry: () => ref.invalidate(browseCategoriesProvider),
          data: () => _featureCard(context, categories.requireValue),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoSectionHeader(
          title: 'New Collections',
          onSeeAll: () => context.pelevoOpen('/screen/browse-new'),
        ),
        _newEpisodeTiles(limit: 4),
      ],
    );
  }

  Widget _categories(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore every topic',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        const Text(
          'Choose a category to see hand-picked podcasts and episodes.',
        ),
        const SizedBox(height: PelevoSpacing.lg),
        _status(
          value: categories,
          retry: () => ref.invalidate(browseCategoriesProvider),
          data: () => _categoryGrid(categories.requireValue),
        ),
      ],
    );
  }

  Widget _music(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _musicHero(context),
        const SizedBox(height: PelevoSpacing.xl),
        const PelevoSectionHeader(title: 'Music Collections'),
        _status(
          value: categories,
          retry: () => ref.invalidate(browseCategoriesProvider),
          data: () {
            final music = _resolve(categories.requireValue, music: true);
            if (music == null) {
              return const Text(
                'No music category is published yet.',
                style: TextStyle(color: PelevoColors.textMuted),
              );
            }
            return _categoryShows(music.slug);
          },
        ),
        const SizedBox(height: PelevoSpacing.lg),
        const PelevoSectionHeader(title: 'Popular Music'),
        _status(
          value: categories,
          retry: () => ref.invalidate(browseCategoriesProvider),
          data: () {
            final music = _resolve(categories.requireValue, music: true);
            if (music == null) {
              return const Text(
                'No music shows are published yet.',
                style: TextStyle(color: PelevoColors.textMuted),
              );
            }
            return _categoryShows(music.slug);
          },
        ),
      ],
    );
  }

  Widget _detail(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider);
    final chart = ref.watch(browseUiProvider.select((state) => state.chart));
    final slug = ref.watch(browseUiProvider.select((state) => state.slug));
    return _status(
      value: categories,
      retry: () => ref.invalidate(browseCategoriesProvider),
      data: () {
        final category = _resolve(categories.requireValue, slug: slug);
        if (category == null) {
          return const Text(
            'No categories are published yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          );
        }
        final page = ref.watch(browseCategoryProvider(category.slug));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryHero(
              context,
              category,
              page.asData?.value.shows ?? const <BrowseShow>[],
            ),
            const SizedBox(height: PelevoSpacing.md),
            Semantics(
              label: 'Chart type',
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Music')),
                ],
                selected: {chart},
                onSelectionChanged:
                    (value) =>
                        ref.read(browseUiProvider.notifier).setChart(value.first),
              ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _chooseRegion(context),
                icon: const Icon(Icons.more_horiz_rounded),
                label: const Text('More'),
              ),
            ),
            if (chart == 1 && !category.isMusic)
              const Text(
                'Music tracks are not listed for this category.',
                style: TextStyle(color: PelevoColors.textMuted),
              )
            else
              _status(
                value: page,
                retry: () => ref.invalidate(browseCategoryProvider(category.slug)),
                data: () => _showList(page.requireValue.shows),
              ),
          ],
        );
      },
    );
  }

  Widget _newCollections(BuildContext context) {
    return _bannerList(
      context,
      eyebrow: 'NEW COLLECTIONS',
      heading: 'Fresh stories to explore',
      description: 'Find the latest collections across every category.',
      colors: const [PelevoColors.green, PelevoColors.yellow],
      child: _newEpisodeTiles(),
    );
  }

  Widget _previewCollection(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider);
    final slug = ref.watch(browseUiProvider.select((state) => state.slug));
    return _status(
      value: categories,
      retry: () => ref.invalidate(browseCategoriesProvider),
      data: () {
        final category = _resolve(categories.requireValue, slug: slug);
        if (category == null) {
          return const Text(
            'No categories are published yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          );
        }
        return _bannerList(
          context,
          eyebrow: 'COLLECTION PREVIEW',
          heading: category.name,
          description: 'Shows in this category.',
          colors: const [PelevoColors.yellow, PelevoColors.red],
          child: _categoryShows(category.slug),
        );
      },
    );
  }

  Widget _followingList(BuildContext context) {
    final following = ref.watch(browseFollowingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Following', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: PelevoSpacing.lg),
        _status(
          value: following,
          retry: () => ref.invalidate(browseFollowingProvider),
          data: () {
            final items = following.requireValue;
            if (items.isEmpty) {
              return const Text(
                'You are not following any shows yet.',
                style: TextStyle(color: PelevoColors.textMuted),
              );
            }
            return Column(
              children: [
                for (final show in items)
                  Card(
                    color: PelevoColors.surface,
                    margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(PelevoSpacing.md),
                      leading: ClipOval(
                        child:
                            show.artworkUrl == null ||
                                    show.artworkUrl!.isEmpty
                                ? CircleAvatar(
                                  backgroundColor: _browseColor(show.id),
                                  foregroundColor: Colors.white,
                                  child: const Icon(Icons.podcasts_rounded),
                                )
                                : PelevoNetworkArt(
                                  url: show.artworkUrl!,
                                  width: 40,
                                  height: 40,
                                  fallback: CircleAvatar(
                                    backgroundColor: _browseColor(show.id),
                                    foregroundColor: Colors.white,
                                    child: const Icon(Icons.podcasts_rounded),
                                  ),
                                ),
                      ),
                      title: Text(show.title),
                      subtitle: Text(show.subtitle),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        openCatalogShow(context, show.id);
                        context.push('/screen/podcast-details');
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _search(BuildContext context) {
    final recent = ref.watch(searchRecentProvider);
    final categories = ref.watch(browseCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Search Collections'),
          subtitle: const Text('Find a collection'),
          trailing: const Icon(Icons.search_rounded),
          onTap: () => context.pelevoOpen('/screen/search'),
        ),
        const Divider(),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          'Popular Searches',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        _status(
          value: recent,
          retry: () => ref.invalidate(searchRecentProvider),
          data: () {
            final items = recent.requireValue;
            if (items.isNotEmpty) {
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(item.query),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.pelevoOpen('/screen/search'),
                    ),
                ],
              );
            }
            return _status(
              value: categories,
              retry: () => ref.invalidate(browseCategoriesProvider),
              data: () => _showList(
                [
                  for (final category in categories.requireValue)
                    BrowseShow(id: category.id, title: category.name),
                ],
                onTapCategory: (show) {
                  final match = categories.requireValue.where(
                    (item) => item.id == show.id,
                  );
                  if (match.isEmpty) return;
                  _openCategory(match.first);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    final type = ref.watch(browseUiProvider.select((state) => state.contentType));
    return Semantics(
      label: 'Collection filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Collections',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: PelevoSpacing.lg),
          const Text('Content Type'),
          const SizedBox(height: PelevoSpacing.xs),
          Wrap(
            spacing: PelevoSpacing.xs,
            children: [
              for (final (index, label)
                  in const ['All', 'Music', 'Podcasts', 'Mixed'].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: type == index,
                  onSelected:
                      (_) =>
                          ref.read(browseUiProvider.notifier).setContentType(index),
                ),
            ],
          ),
          const SizedBox(height: PelevoSpacing.lg),
          const Text('Category'),
          const SizedBox(height: PelevoSpacing.xs),
          const TextField(
            decoration: InputDecoration(hintText: 'All Categories'),
          ),
          const SizedBox(height: PelevoSpacing.md),
          const Text(
            'Collection filters stay on this screen until browse accepts type query parameters.',
            style: TextStyle(color: PelevoColors.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.xl),
          PelevoButton(
            label: 'Apply Filters',
            onPressed: () => context.pelevoOpen('/screen/browse-search'),
          ),
        ],
      ),
    );
  }

  Widget _added(BuildContext context) {
    final title = ref.watch(browseUiProvider).addedTitle;
    return Column(
      children: [
        PelevoStateHero(
          icon: Icons.check_rounded,
          title:
              title == null || title.isEmpty
                  ? 'Added to your library'
                  : '$title\nhas been added to your library',
          body: 'You can explore it now or keep browsing.',
          color: PelevoColors.green,
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'View in Library',
          icon: Icons.library_books_outlined,
          onPressed: () => context.pelevoOpen('/screen/library-2'),
        ),
      ],
    );
  }

  Widget _categoryGrid(
    List<BrowseCategory> categories, {
    bool compact = false,
  }) {
    if (categories.isEmpty) {
      return const Text(
        'No categories are published yet.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    var visible = categories;
    if (compact && visible.length > 6) {
      visible = visible.take(6).toList(growable: false);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: 1.9,
          crossAxisSpacing: PelevoSpacing.sm,
          mainAxisSpacing: PelevoSpacing.sm,
          children: [
            for (final item in visible)
              Semantics(
                button: true,
                label: 'Browse ${item.name}',
                child: InkWell(
                  borderRadius: PelevoRadii.card,
                  onTap: () => _openCategory(item),
                  child: Ink(
                    padding: const EdgeInsets.all(PelevoSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_browseColor(item.slug), Colors.black],
                      ),
                      borderRadius: PelevoRadii.card,
                    ),
                    child: Row(
                      children: [
                        Icon(_browseIcon(item), color: Colors.white),
                        const SizedBox(width: PelevoSpacing.sm),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _featureCard(BuildContext context, List<BrowseCategory> categories) {
    if (categories.isEmpty) {
      return const Text(
        'No featured collections are published yet.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    final featured = categories.first;
    final page = ref.watch(browseCategoryProvider(featured.slug));
    final artwork = page.asData?.value.shows.firstOrNull?.artworkUrl;
    return Semantics(
      button: true,
      label: 'Featured collection, ${featured.name}',
      child: InkWell(
        borderRadius: PelevoRadii.card,
        onTap: () => _openCategory(featured),
        child: Ink(
          height: 166,
          child: ClipRRect(
            borderRadius: PelevoRadii.card,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: _browseColor(featured.slug)),
                if (artwork == null || artwork.isEmpty)
                  Image.asset(
                    'assets/browse/afrobeats.png',
                    fit: BoxFit.cover,
                  )
                else
                  PelevoNetworkArt(
                    url: artwork,
                    fit: BoxFit.cover,
                    fallback: ColoredBox(color: _browseColor(featured.slug)),
                  ),
                Container(
                  padding: const EdgeInsets.all(PelevoSpacing.lg),
                  decoration: const BoxDecoration(
                    borderRadius: PelevoRadii.card,
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
                        featured.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _musicHero(BuildContext context) {
    final categories = ref.watch(browseCategoriesProvider).asData?.value;
    final music = categories == null ? null : _resolve(categories, music: true);
    final shows =
        music == null
            ? const <BrowseShow>[]
            : ref.watch(browseCategoryProvider(music.slug)).asData?.value.shows ??
                const <BrowseShow>[];
    if (music != null) {
      return _categoryHero(
        context,
        music,
        shows,
        eyebrow: 'MUSIC',
        subtitle: 'Playlists curated for every moment.',
      );
    }
    return _categoryHero(
      context,
      const BrowseCategory(id: 'music', name: 'Music Collections', slug: 'music'),
      shows,
      eyebrow: 'MUSIC',
      subtitle: 'Playlists curated for every moment.',
    );
  }

  Widget _categoryHero(
    BuildContext context,
    BrowseCategory category,
    List<BrowseShow> shows, {
    String? eyebrow,
    String? subtitle,
  }) {
    final color = _browseColor(category.slug);
    final count = shows.length;
    return Semantics(
      header: true,
      label: '${category.name} collection',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PelevoSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: PelevoRadii.card,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: .35), Colors.black],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_browseIcon(category), color: Colors.white, size: 28),
                  const SizedBox(height: PelevoSpacing.sm),
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 12,
                        color: PelevoColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: PelevoSpacing.xs),
                  ],
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: PelevoSpacing.xxs),
                  Text(
                    subtitle ??
                        (count == 0
                            ? 'Curated collection'
                            : '$count ${count == 1 ? 'show' : 'shows'} · Curated collection'),
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PelevoSpacing.md),
            _coverCollage(shows, label: category.name, color: color),
          ],
        ),
      ),
    );
  }

  Widget _coverCollage(
    List<BrowseShow> shows, {
    required String label,
    required Color color,
  }) {
    const size = 108.0;
    final covers = shows.take(4).toList(growable: false);
    if (covers.length < 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(PelevoRadii.large),
        child: _squareArt(
          covers.firstOrNull?.title ?? label,
          covers.firstOrNull?.artworkUrl,
          size: size,
          color: color,
        ),
      );
    }
    final tile = (size - 4) / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.large),
      child: SizedBox(
        width: size,
        height: size,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < 4; i++)
              _squareArt(
                covers[i % covers.length].title,
                covers[i % covers.length].artworkUrl,
                size: tile,
                color: color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _bannerList(
    BuildContext context, {
    required String eyebrow,
    required String heading,
    required String description,
    required List<Color> colors,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PelevoSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: PelevoRadii.card,
          gradient: LinearGradient(colors: [...colors, Colors.black]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: PelevoSpacing.xl),
            Text(heading, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: PelevoSpacing.xs),
            Text(description),
          ],
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      child,
    ],
  );

  Widget _categoryShows(String slug) {
    final page = ref.watch(browseCategoryProvider(slug));
    return _status(
      value: page,
      retry: () => ref.invalidate(browseCategoryProvider(slug)),
      data: () => _showList(page.requireValue.shows),
    );
  }

  Widget _showList(
    List<BrowseShow> shows, {
    void Function(BrowseShow show)? onTapCategory,
  }) {
    if (shows.isEmpty) {
      return const Text(
        'No shows in this collection yet.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return Column(
      children: [
        for (final show in shows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(PelevoRadii.small),
              child: _squareArt(show.title, show.artworkUrl),
            ),
            title: Text(show.title),
            subtitle: Text(show.subtitle),
            trailing:
                onTapCategory == null
                    ? IconButton(
                      tooltip: 'Follow ${show.title}',
                      onPressed: _following ? null : () => _follow(show),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    )
                    : const Icon(Icons.chevron_right_rounded),
            onTap:
                onTapCategory == null
                    ? () {
                      openCatalogShow(context, show.id);
                      context.push('/screen/podcast-details');
                    }
                    : () => onTapCategory(show),
          ),
      ],
    );
  }

  Widget _newEpisodeTiles({int? limit}) {
    final discover = ref.watch(homeDiscoverProvider);
    return _status(
      value: discover,
      retry: () => ref.invalidate(homeDiscoverProvider),
      data: () {
        var items = discover.requireValue.newEpisodes;
        if (limit != null) items = items.take(limit).toList(growable: false);
        if (items.isEmpty) {
          return const Text(
            'No new episodes are published yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          );
        }
        return Column(
          children: [
            for (final item in items)
              PelevoEpisodeTile(
                title: item.title,
                subtitle: item.showTitle ?? 'Episode',
                artworkUrl: item.artworkUrl,
                color: PelevoColors.green,
                onTap: () => openCatalogHomeDestination(context, item),
                onPlay:
                    item.type == 'episode'
                        ? () => playCatalogHomeItem(context, item)
                        : null,
              ),
          ],
        );
      },
    );
  }

  Widget _squareArt(
    String label,
    String? url, {
    double size = 58,
    Color color = PelevoColors.red,
  }) {
    if (url == null || url.isEmpty) {
      return PelevoArtwork(label: label, size: size, color: color);
    }
    return PelevoNetworkArt(
      url: url,
      width: size,
      height: size,
      fallback: PelevoArtwork(label: label, size: size, color: color),
    );
  }

  Future<void> _chooseRegion(BuildContext context) => showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Chart region'),
          content: const Text(
            'Charts currently show what listeners around the world play most.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Use Global'),
            ),
          ],
        ),
  );
}
