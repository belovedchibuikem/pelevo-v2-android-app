import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/browse/browse_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/search/search_data.dart';

/// Mood / topic discovery target used by Home tiles.
class MoodDiscoverTarget {
  const MoodDiscoverTarget({
    required this.title,
    required this.query,
    this.category,
    this.browseSlug,
    this.subtitle =
        'Podcasts discovered for this mood. Follow a show or open it to load episodes.',
  });

  final String title;
  final String query;
  final String? category;
  final String? browseSlug;
  final String subtitle;
}

/// Maps mood labels (and topic/category names) to Podcast Index search terms.
MoodDiscoverTarget moodDiscoverTargetFor(String label, {String? slug}) {
  final key = (slug ?? label).trim().toLowerCase();
  final normalized = label.trim().toLowerCase();

  MoodDiscoverTarget? mapped = switch (key) {
    'learn something' || 'education' || 'learn' => const MoodDiscoverTarget(
      title: 'Learn Something',
      query: 'education',
      category: 'Education',
      browseSlug: 'education',
    ),
    'money & business' || 'business' || 'money' => const MoodDiscoverTarget(
      title: 'Money & Business',
      query: 'business',
      category: 'Business',
      browseSlug: 'business',
    ),
    'feel something' || 'society' || 'relationships' => const MoodDiscoverTarget(
      title: 'Feel Something',
      query: 'relationships',
      category: 'Society',
      browseSlug: 'society',
    ),
    'faith & purpose' || 'faith' || 'religion' || 'spirituality' =>
      const MoodDiscoverTarget(
        title: 'Faith & Purpose',
        query: 'faith',
        category: 'Religion',
        browseSlug: 'religion',
      ),
    'be entertained' || 'comedy' || 'entertainment' => const MoodDiscoverTarget(
      title: 'Be Entertained',
      query: 'comedy',
      category: 'Comedy',
      browseSlug: 'comedy',
    ),
    'sleep & unwind' || 'health' || 'sleep' => const MoodDiscoverTarget(
      title: 'Sleep & Unwind',
      query: 'sleep',
      category: 'Health',
      browseSlug: 'health',
    ),
    _ => null,
  };

  if (mapped != null) return mapped;

  // Topic / try-something-new tiles: use the visible label as a constructive query.
  final title = label.trim().isEmpty ? 'Discover' : label.trim();
  final query = switch (normalized) {
    'true crime' => 'true crime podcast',
    'kids' => 'kids children stories',
    'news' => 'news africa current affairs',
    'sports' => 'sports africa football',
    'science' => 'science technology',
    'history' => 'history africa',
    'technology' => 'technology africa tech',
    'culture' => 'culture africa society',
    _ => '$title podcast',
  };

  return MoodDiscoverTarget(
    title: title,
    query: query,
    category: _categoryHint(normalized),
    browseSlug: _browseSlugHint(normalized),
  );
}

String? _browseSlugHint(String normalized) => switch (normalized) {
  'science' => 'science',
  'comedy' => 'comedy',
  'sports' => 'sports',
  'news' => 'news',
  'health' => 'health',
  'history' => 'history',
  'true crime' => 'true-crime',
  'kids' => 'kids-family',
  'business' => 'business',
  'technology' => 'technology',
  'faith' => 'religion',
  'culture' || 'society' || 'relationships' => 'society',
  _ => null,
};

String? _categoryHint(String normalized) => switch (normalized) {
  'science' => 'Science',
  'comedy' => 'Comedy',
  'sports' => 'Sports',
  'news' => 'News',
  'health' => 'Health',
  'history' => 'History',
  'true crime' => 'True Crime',
  'kids' => 'Kids & Family',
  'business' => 'Business',
  'technology' => 'Technology',
  'faith' => 'Religion',
  'culture' || 'society' || 'relationships' => 'Society',
  _ => null,
};

class MoodDiscoverTargetNotifier extends Notifier<MoodDiscoverTarget?> {
  @override
  MoodDiscoverTarget? build() => null;

  void select(MoodDiscoverTarget target) => state = target;

  void clear() => state = null;
}

final moodDiscoverTargetProvider =
    NotifierProvider<MoodDiscoverTargetNotifier, MoodDiscoverTarget?>(
      MoodDiscoverTargetNotifier.new,
    );

void openMoodDiscover(
  BuildContext context,
  WidgetRef ref,
  String label, {
  String? slug,
}) {
  final target = moodDiscoverTargetFor(label, slug: slug);
  ref.read(moodDiscoverTargetProvider.notifier).select(target);
  context.push('/screen/home-mood-discover');
}

class MoodDiscoverScreen extends ConsumerStatefulWidget {
  const MoodDiscoverScreen({super.key});

  @override
  ConsumerState<MoodDiscoverScreen> createState() => _MoodDiscoverScreenState();
}

class _MoodDiscoverScreenState extends ConsumerState<MoodDiscoverScreen> {
  final Map<String, bool> _followOverrides = {};
  bool _followBusy = false;

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(moodDiscoverTargetProvider);
    if (target == null) {
      return PelevoPage(
        appBar: AppBar(title: const Text('Discover')),
        bottomNavigationBar: PelevoBottomNavigation(
          index: 0,
          onDestinationSelected: context.openPelevoTab,
        ),
        child: Center(
          child: Text(
            'Pick a mood from Home to discover podcasts.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
      );
    }

    final request = SearchRequest(target.query, category: target.category);
    final page = ref.watch(searchPageProvider(request));
    final browseSlug = target.browseSlug;
    final browse =
        browseSlug == null ? null : ref.watch(browseCategoryProvider(browseSlug));

    return PelevoPage(
      scrollable: true,
      appBar: AppBar(title: Text(target.title)),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            target.subtitle,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.xs),
          Text(
            'Searching for “${target.query}”'
            '${target.category == null ? '' : ' · ${target.category}'}',
            style: TextStyle(
              color: context.pelevo.textDim,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          _results(target, request, page, browse),
        ],
      ),
    );
  }

  Widget _results(
    MoodDiscoverTarget target,
    SearchRequest request,
    AsyncValue<SearchPage> page,
    AsyncValue<BrowseCategoryPage>? browse,
  ) {
    final searchShows = page.asData?.value.shows ?? const <SearchShow>[];
    final searchEpisodes = page.asData?.value.episodes ?? const <SearchEpisode>[];
    final browseShows = browse?.asData?.value.shows ?? const <BrowseShow>[];
    final shows = <String, SearchShow>{};
    for (final show in browseShows) {
      shows[show.id] = SearchShow(
        id: show.id,
        title: show.title,
        author: show.author,
        artworkUrl: show.artworkUrl,
      );
    }
    for (final show in searchShows) {
      shows[show.id] = show;
    }
    final stillLoading = page.isLoading || (browse?.isLoading ?? false);
    if (shows.isEmpty && searchEpisodes.isEmpty) {
      if (stillLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final error = page.error ?? browse?.error;
      if (error != null) {
        return Column(
          children: [
            Text(searchFailure(error).message),
            TextButton(
              onPressed: () {
                ref.invalidate(searchPageProvider(request));
                final slug = target.browseSlug;
                if (slug != null) {
                  ref.invalidate(browseCategoryProvider(slug));
                }
              },
              child: const Text('Retry'),
            ),
          ],
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
        child: Text(
          'No podcasts matched this mood yet. Try another mood or Search.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final show in shows.values) _showTile(show),
        if (searchEpisodes.isNotEmpty) ...[
          const SizedBox(height: PelevoSpacing.lg),
          Text('Episodes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.sm),
          for (final episode in searchEpisodes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatalogArtwork(
                url: episode.artworkUrl,
                width: 58,
                height: 58,
              ),
              title: Text(episode.title),
              subtitle: Text(episode.subtitle),
              trailing: const Icon(Icons.play_circle_fill_rounded),
              onTap: () {
                openCatalogEpisodeDetails(
                  context,
                  episodeId: episode.id,
                  showId: episode.showId,
                );
              },
            ),
        ],
      ],
    );
  }

  bool _isFollowing(SearchShow show) =>
      _followOverrides[show.id] ?? show.following;

  Widget _showTile(SearchShow show) {
    final following = _isFollowing(show);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CatalogArtwork(
        url: show.artworkUrl,
        width: 58,
        height: 58,
      ),
      title: Text(show.title),
      subtitle: Text(show.subtitle),
      trailing: IconButton(
        tooltip: following ? 'Unfollow' : 'Follow',
        onPressed: _followBusy ? null : () => _toggleFollow(show),
        icon: Icon(
          following
              ? Icons.check_circle_rounded
              : Icons.add_circle_outline_rounded,
          color: following ? PelevoColors.green : null,
        ),
      ),
      onTap: () {
        openCatalogShow(context, show.id);
        context.push('/screen/podcast-details');
      },
    );
  }

  Future<void> _toggleFollow(SearchShow show) async {
    if (_followBusy) return;
    final next = !_isFollowing(show);
    setState(() {
      _followBusy = true;
      _followOverrides[show.id] = next;
    });
    try {
      await ref.read(searchRepositoryProvider).follow(show.id, following: next);
      if (!mounted) return;
      context.showPelevoMessage(
        next ? '${show.title} followed' : '${show.title} unfollowed',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _followOverrides[show.id] = !next);
      context.showPelevoMessage(searchFailure(error).message);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }
}
