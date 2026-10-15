import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/ads/feed_native_ads.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/search/search_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _SearchView {
  landing,
  typing,
  results,
  filters,
  people,
  playlists,
  empty,
  recent,
  voice,
  voiceResults,
}

const _searchInventory =
    <({String id, String title, String state, _SearchView view})>[
      (
        id: 'search',
        title: 'Search',
        state: 'Discovery landing',
        view: _SearchView.landing,
      ),
      (
        id: 'search-typing',
        title: 'Search',
        state: 'Query in progress',
        view: _SearchView.typing,
      ),
      (
        id: 'search-results',
        title: 'Search Results',
        state: 'All results',
        view: _SearchView.results,
      ),
      (
        id: 'search-filters',
        title: 'Search Filters',
        state: 'Filters open',
        view: _SearchView.filters,
      ),
      (
        id: 'search-people',
        title: 'People Search',
        state: 'People results',
        view: _SearchView.people,
      ),
      (
        id: 'search-playlists',
        title: 'Playlists Search',
        state: 'Playlist results',
        view: _SearchView.playlists,
      ),
      (
        id: 'search-empty',
        title: 'No Results',
        state: 'Empty search',
        view: _SearchView.empty,
      ),
      (
        id: 'search-recent',
        title: 'Recent Searches',
        state: 'History populated',
        view: _SearchView.recent,
      ),
      (
        id: 'search-voice',
        title: 'Voice Search',
        state: 'Listening',
        view: _SearchView.voice,
      ),
      (
        id: 'search-voice-results',
        title: 'Voice Results',
        state: 'Voice query results',
        view: _SearchView.voiceResults,
      ),
    ];

final List<PelevoScreenSpec> searchScreens = List.unmodifiable(
  _searchInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Search',
      title: item.title,
      state: item.state,
      builder: (_) => _SearchScreen(view: item.view),
    ),
  ),
);

class _SearchScreen extends ConsumerStatefulWidget {
  const _SearchScreen({required this.view});

  final _SearchView view;

  @override
  ConsumerState<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<_SearchScreen> {
  late final TextEditingController _query;
  final _focus = FocusNode();
  Timer? _debounce;
  String _debounced = '';
  bool _focused = false;
  int _nav = 1;
  bool _followBusy = false;
  bool _filtersOpen = false;
  final Map<String, bool> _followOverrides = {};
  SearchPage? _previewPage;
  String _previewQuery = '';

  bool get _preview => ref.read(catalogPreviewProvider);

  /// Android 10 and older never mount a search ad, so no ad object is retained.
  bool get _searchNativeAdsEnabled {
    final sdk = ref.watch(androidSdkIntProvider);
    return searchNativeAdAllowed(
      platform: defaultTargetPlatform,
      androidSdk: sdk.asData?.value,
      androidSdkResolved: sdk.hasValue,
    );
  }

  List<Widget> _withSearchAd(List<Widget> tiles, String slotKey) {
    if (!_searchNativeAdsEnabled) return tiles;
    return insertAtSearchAdSlot(
      tiles,
      SearchFeedNativeAd(key: ValueKey(slotKey)),
    );
  }

  @override
  void initState() {
    super.initState();
    final existing = ref.read(searchUiProvider).submittedQuery.trim();
    _query = TextEditingController(text: existing);
    _debounced = existing;
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  static const _minQueryLength = 3;

  _SearchView get _shown {
    if (ref.watch(catalogPreviewProvider)) return widget.view;
    final ui = ref.watch(searchUiProvider);
    if (ui.listening) return _SearchView.voice;
    if (_filtersOpen) return _SearchView.filters;
    final typed = _query.text.trim();
    final submitted = ui.submittedQuery.trim();
    if (submitted.length >= _minQueryLength && typed == submitted) {
      if (ui.chip == 3) return _SearchView.people;
      return _SearchView.results;
    }
    if (typed.isNotEmpty) return _SearchView.typing;
    if (_focused) return _SearchView.recent;
    return _SearchView.landing;
  }

  SearchRequest? get _activeRequest {
    final shown = _shown;
    final ui = ref.read(searchUiProvider);
    final submitted = ui.submittedQuery.trim();
    if (shown == _SearchView.voiceResults) {
      final voice = (ui.voiceQuery ?? submitted).trim();
      if (voice.length < _minQueryLength) return null;
      return SearchRequest(voice);
    }
    if (shown == _SearchView.people) return null;
    if (shown == _SearchView.results ||
        shown == _SearchView.playlists ||
        shown == _SearchView.empty ||
        shown == _SearchView.filters) {
      if (submitted.length < _minQueryLength) return null;
      final type = switch (shown) {
        _SearchView.playlists => 'playlist',
        _ => switch (ui.chip) {
          1 => 'show',
          2 => 'episode',
          _ => null,
        },
      };
      return SearchRequest(submitted, type: type);
    }
    if (shown == _SearchView.typing &&
        _debounced.trim().length >= _minQueryLength) {
      final chip = ref.read(searchUiProvider).chip;
      return SearchRequest(
        _debounced.trim(),
        preview: true,
        type: chip == 2 ? 'episode' : 'show',
        limit: 8,
      );
    }
    return null;
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _debounced = value.trim());
    });
    if (_preview && widget.view == _SearchView.landing) {
      context.go('/screen/search-typing');
    }
  }

  void _submit([String? value]) {
    final query = (value ?? _query.text).trim();
    if (query.length < _minQueryLength) return;
    _debounce?.cancel();
    _query.text = query;
    _query.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _debounced = query);
    ref.read(searchUiProvider.notifier).submit(query);
    if (_preview) {
      context.go('/screen/search-results');
    } else {
      setState(() {});
    }
  }

  void _openSearchPlaylist(BuildContext context, SearchPlaylist playlist) {
    if (playlist.isUserPlaylist) {
      openLibraryPlaylist(context, playlist.id);
      return;
    }
    context.push('/screen/library-2');
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

  bool _isFollowing(SearchShow show) =>
      _followOverrides[show.id] ?? show.following;

  SearchPage? _usablePreview(String typed) {
    final held = _previewPage;
    if (held == null || (held.shows.isEmpty && held.episodes.isEmpty)) {
      return null;
    }
    final previous = _previewQuery.trim().toLowerCase();
    final next = typed.trim().toLowerCase();
    if (previous.isEmpty || next.isEmpty) return null;
    if (next.startsWith(previous) || previous.startsWith(next)) return held;
    return null;
  }

  Future<void> _clearRecent() async {
    try {
      await ref.read(searchRepositoryProvider).clearRecent();
      ref.invalidate(searchRecentProvider);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(searchFailure(error).message);
    }
  }

  Future<void> _removeRecent(RecentSearch item) async {
    try {
      await ref.read(searchRepositoryProvider).deleteRecent(item.id);
      ref.invalidate(searchRecentProvider);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(searchFailure(error).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final ui = ref.watch(searchUiProvider);
    final request = _activeRequest;
    final page =
        request == null ? null : ref.watch(searchPageProvider(request));
    return PelevoPage(
      appBar: AppBar(title: const Text('Search'), actions: const []),
      bottomNavigationBar: PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Search podcasts and episodes',
            child: TextField(
              controller: _query,
              focusNode: _focus,
              autofocus: shown == _SearchView.typing,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onTap: () {
                if (_preview && widget.view == _SearchView.landing) {
                  context.go('/screen/search-typing');
                }
              },
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Podcasts, episodes or topics',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _query.text.isEmpty
                        ? IconButton(
                          tooltip: 'Voice search',
                          onPressed: () {
                            ref.read(searchUiProvider.notifier).listen();
                            if (_preview) context.go('/screen/search-voice');
                            setState(() {});
                          },
                          icon: const Icon(Icons.mic_none_rounded),
                        )
                        : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _debounce?.cancel();
                            setState(() {
                              _query.clear();
                              _debounced = '';
                              _previewPage = null;
                              _previewQuery = '';
                            });
                            ref
                                .read(searchUiProvider.notifier)
                                .clearSubmitted();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
              ),
            ),
          ),
          const SizedBox(height: PelevoSpacing.lg),
          _body(context, shown, ui, page),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    _SearchView shown,
    SearchUiState ui,
    AsyncValue<SearchPage>? page,
  ) {
    switch (shown) {
      case _SearchView.landing:
        return _landing(context);
      case _SearchView.typing:
        return _suggestions(context, page);
      case _SearchView.recent:
        return _recent(context);
      case _SearchView.results:
      case _SearchView.voiceResults:
        return _results(
          context,
          ui,
          page,
          voice: shown == _SearchView.voiceResults,
        );
      case _SearchView.people:
        return _people(context);
      case _SearchView.playlists:
        return _playlists(context, page);
      case _SearchView.empty:
        return _empty(
          context,
          _query.text.trim().isEmpty ? ui.submittedQuery : _query.text,
        );
      case _SearchView.voice:
        return _voice(context);
      case _SearchView.filters:
        return _filterPanel(context, page);
    }
  }

  Widget _landing(BuildContext context) {
    final recent = ref.watch(searchRecentProvider);
    final charts = ref.watch(homeChartsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PelevoSectionHeader(
          title: 'Popular Searches',
          onSeeAll: () {
            if (_preview) {
              context.go('/screen/search-recent');
            } else {
              _focus.requestFocus();
              setState(() {});
            }
          },
        ),
        const SizedBox(height: PelevoSpacing.sm),
        recent.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => _inlineError(
                searchFailure(error).message,
                () => ref.invalidate(searchRecentProvider),
              ),
          data:
              (items) => Wrap(
                spacing: PelevoSpacing.xs,
                runSpacing: PelevoSpacing.xs,
                children: [
                  for (final item in items)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 18),
                      label: Text(item.query),
                      onPressed: () => _submit(item.query),
                    ),
                ],
              ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        const PelevoSectionHeader(title: 'Trending Now'),
        charts.when(
          skipLoadingOnReload: true,
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => _inlineError(
                searchFailure(error).message,
                () => ref.invalidate(homeChartsProvider),
              ),
          data: (value) {
            if (value.podcasts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: PelevoSpacing.md),
                child: Text(
                  'No trending shows are published yet.',
                  style: TextStyle(color: PelevoColors.textMuted),
                ),
              );
            }
            final trending = [
              for (final item in value.podcasts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _SearchArtwork(
                    label: item.title,
                    color: PelevoColors.red,
                    artworkUrl: item.artworkUrl,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle ?? item.showTitle ?? 'Podcast'),
                  trailing: const Icon(Icons.play_circle_fill_rounded),
                  onTap: () {
                    openCatalogHomeItem(context, item);
                    context.push('/screen/podcast-details');
                  },
                ),
            ];
            return Column(
              children: _withSearchAd(trending, 'trending-native-ad'),
            );
          },
        ),
        const SizedBox(height: PelevoSpacing.lg),
        const PelevoSectionHeader(title: 'Browse Categories'),
        const _SearchCategoryGrid(),
      ],
    );
  }

  Widget _suggestions(BuildContext context, AsyncValue<SearchPage>? page) {
    final typed = _query.text.trim();
    final episodesOnly = ref.watch(searchUiProvider).chip == 2;
    final ready = typed.length >= _minQueryLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          episodesOnly ? 'Episodes' : 'Podcasts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        if (!ready)
          const Text(
            'Type at least 3 characters to search podcasts.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else if (page == null)
          const Text(
            'Type at least 3 characters to search podcasts.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          page.when(
            skipLoadingOnReload: true,
            loading: () {
              final held = _usablePreview(typed);
              final heldItems =
                  episodesOnly ? held?.episodes ?? const [] : held?.shows ?? const [];
              if (held == null || heldItems.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: [
                  const LinearProgressIndicator(minHeight: 2),
                  if (episodesOnly)
                    for (final episode in held.episodes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(episode.title),
                        subtitle: Text(episode.subtitle),
                      )
                  else
                    for (final show in held.shows) _showTile(context, show),
                ],
              );
            },
            error: (error, _) {
              if (searchFailure(error).code == 'CANCELLED') {
                final held = _usablePreview(typed);
                if (held != null && held.shows.isNotEmpty) {
                  return Column(
                    children: [
                      for (final show in held.shows) _showTile(context, show),
                    ],
                  );
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _inlineError(searchFailure(error).message, () {
                final request = _activeRequest;
                if (request != null) {
                  ref.invalidate(searchPageProvider(request));
                }
              });
            },
            data: (value) {
              _previewPage = value;
              _previewQuery = _debounced.trim();
              final episodesOnly = ref.watch(searchUiProvider).chip == 2;
              if (episodesOnly) {
                if (value.episodes.isEmpty) {
                  return const Text(
                    'No matching episodes yet.',
                    style: TextStyle(color: PelevoColors.textMuted),
                  );
                }
                return Column(
                  children: [
                    for (final episode in value.episodes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _SearchArtwork(
                          label: episode.title,
                          color: PelevoColors.blue,
                          artworkUrl: episode.artworkUrl,
                        ),
                        title: Text(episode.title),
                        subtitle: Text(episode.subtitle),
                        onTap: () {
                          openCatalogEpisodeDetails(
                            context,
                            episodeId: episode.id,
                            showId: episode.showId,
                          );
                        },
                      ),
                  ],
                );
              }
              if (value.shows.isEmpty) {
                return const Text(
                  'No matching podcasts yet.',
                  style: TextStyle(color: PelevoColors.textMuted),
                );
              }
              return Column(
                children: [
                  for (final show in value.shows) _showTile(context, show),
                ],
              );
            },
          ),
        if (ready && page?.asData?.value.suggestions.isNotEmpty == true) ...[
          const SizedBox(height: PelevoSpacing.lg),
          Text('Suggestions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PelevoSpacing.sm),
          for (final suggestion in page!.asData!.value.suggestions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.search_rounded,
                color: PelevoColors.textMuted,
              ),
              title: Text(suggestion),
              onTap: () => _submit(suggestion),
            ),
        ],
      ],
    );
  }

  Widget _recent(BuildContext context) {
    final recent = ref.watch(searchRecentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PelevoSectionHeader(
          title: 'Recent searches',
          trailing: 'Clear',
          onSeeAll: _clearRecent,
        ),
        recent.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => _inlineError(
                searchFailure(error).message,
                () => ref.invalidate(searchRecentProvider),
              ),
          data: (items) {
            if (items.isEmpty) {
              return const Text(
                'No recent searches yet.',
                style: TextStyle(color: PelevoColors.textMuted),
              );
            }
            return Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(item.query),
                    trailing: IconButton(
                      tooltip: 'Remove ${item.query}',
                      onPressed: () => _removeRecent(item),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    onTap: () => _submit(item.query),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    SearchUiState ui,
    AsyncValue<SearchPage>? page, {
    required bool voice,
  }) {
    final labelQuery =
        voice ? (ui.voiceQuery ?? ui.submittedQuery) : ui.submittedQuery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterBar(ui),
        const SizedBox(height: PelevoSpacing.lg),
        if (voice && labelQuery.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
            child: Text(
              'Results for “${labelQuery.trim()}”',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (page == null) ...[
          const PelevoSectionHeader(title: 'Podcasts'),
          const Text(
            'Enter at least 3 characters to search.',
            style: TextStyle(color: PelevoColors.textMuted),
          ),
        ] else
          page.when(
            skipLoadingOnReload: true,
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (error, _) {
              if (searchFailure(error).code == 'CANCELLED') {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _inlineError(searchFailure(error).message, () {
                final request = _activeRequest;
                if (request != null) {
                  ref.invalidate(searchPageProvider(request));
                }
              });
            },
            data: (value) {
              if (value.isEmpty) {
                return _empty(
                  context,
                  value.query.isEmpty ? labelQuery : value.query,
                );
              }
              final podcasts =
                  ui.chip == 2 ? const <SearchShow>[] : value.shows;
              final episodes =
                  ui.chip == 1 ? const <SearchEpisode>[] : value.episodes;
              final podcastTiles = [
                for (final show in podcasts) _showTile(context, show),
              ];
              final episodeTiles = [
                for (final episode in episodes)
                  PelevoEpisodeTile(
                    title: episode.title,
                    subtitle: episode.subtitle,
                    artworkUrl: episode.artworkUrl,
                    color: PelevoColors.green,
                    onTap: () {
                      openCatalogEpisodeDetails(
                        context,
                        episodeId: episode.id,
                        showId: episode.showId,
                      );
                    },
                    onPlay: () {
                      playCatalogEpisode(
                        context,
                        episodeId: episode.id,
                        showId: episode.showId,
                      );
                    },
                    onQueue: () {
                      enqueueCatalogEpisode(context, episodeId: episode.id);
                    },
                  ),
              ];
              final playlistTiles = [
                for (final playlist in value.playlists)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _SearchArtwork(
                      label: playlist.title,
                      color: PelevoColors.green,
                      artworkUrl: playlist.artworkUrl,
                    ),
                    title: Text(playlist.title),
                    subtitle: Text(playlist.subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openSearchPlaylist(context, playlist),
                  ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PelevoSectionHeader(title: 'Podcasts'),
                  if (podcastTiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: PelevoSpacing.md),
                      child: Text(
                        'No matching shows.',
                        style: TextStyle(color: PelevoColors.textMuted),
                      ),
                    )
                  else
                    ..._withSearchAd(podcastTiles, 'search-results-native-ad'),
                  const SizedBox(height: PelevoSpacing.lg),
                  const PelevoSectionHeader(title: 'Episodes'),
                  if (episodeTiles.isEmpty)
                    const Text(
                      'No matching episodes.',
                      style: TextStyle(color: PelevoColors.textMuted),
                    )
                  else
                    ...(podcastTiles.isNotEmpty
                        ? episodeTiles
                        : _withSearchAd(
                          episodeTiles,
                          'search-results-native-ad',
                        )),
                  const SizedBox(height: PelevoSpacing.lg),
                  const PelevoSectionHeader(title: 'Playlists'),
                  if (playlistTiles.isEmpty)
                    const Text(
                      'No matching playlists.',
                      style: TextStyle(color: PelevoColors.textMuted),
                    )
                  else
                    ...(podcastTiles.isEmpty && episodeTiles.isEmpty
                        ? _withSearchAd(
                          playlistTiles,
                          'search-results-native-ad',
                        )
                        : playlistTiles),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _people(BuildContext context) {
    final ui = ref.watch(searchUiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterBar(ui),
        const SizedBox(height: PelevoSpacing.md),
        Text('People', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        const Text(
          'People search is not available yet.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    );
  }

  Widget _playlists(BuildContext context, AsyncValue<SearchPage>? page) {
    final ui = ref.watch(searchUiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterBar(ui),
        const SizedBox(height: PelevoSpacing.md),
        Text('Playlists', style: Theme.of(context).textTheme.titleLarge),
        if (page == null)
          const Padding(
            padding: EdgeInsets.only(top: PelevoSpacing.sm),
            child: Text(
              'Search to see matching playlists.',
              style: TextStyle(color: PelevoColors.textMuted),
            ),
          )
        else
          page.when(
            skipLoadingOnReload: true,
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: PelevoSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (error, _) => _inlineError(searchFailure(error).message, () {
                  final request = _activeRequest;
                  if (request != null) {
                    ref.invalidate(searchPageProvider(request));
                  }
                }),
            data: (value) {
              if (value.playlists.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: PelevoSpacing.sm),
                  child: Text(
                    'No matching playlists.',
                    style: TextStyle(color: PelevoColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final playlist in value.playlists)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _SearchArtwork(
                        label: playlist.title,
                        color: PelevoColors.green,
                        artworkUrl: playlist.artworkUrl,
                      ),
                      title: Text(playlist.title),
                      subtitle: Text(playlist.subtitle),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openSearchPlaylist(context, playlist),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _empty(BuildContext context, String query) {
    final trimmed = query.trim();
    return Column(
      children: [
        PelevoStateHero(
          icon: Icons.search_off_rounded,
          title: trimmed.isEmpty ? 'No matches' : 'No matches for “$trimmed”',
          body:
              'Try fewer words, check the spelling, or browse a topic instead.',
          color: PelevoColors.yellow,
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Browse popular shows',
          icon: Icons.explore_outlined,
          onPressed: () => context.go('/screen/browse'),
        ),
      ],
    );
  }

  Widget _voice(BuildContext context) {
    return Column(
      children: [
        const PelevoStateHero(
          icon: Icons.mic_rounded,
          title: 'Listening...',
          body: 'Speak now to search for podcasts, episodes, and more.',
          color: PelevoColors.yellow,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        const Text(
          'Voice capture is not available in this build. Type a search instead.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Cancel',
          outlined: true,
          onPressed: () {
            ref.read(searchUiProvider.notifier).cancelVoice();
            if (_preview) context.go('/screen/search');
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _filterBar(SearchUiState ui) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (index, label)
            in const ['All', 'Podcasts', 'Episodes', 'People'].indexed)
          Padding(
            padding: const EdgeInsets.only(right: PelevoSpacing.xs),
            child: ChoiceChip(
              label: Text(label),
              selected: ui.chip == index,
              onSelected: (_) {
                ref.read(searchUiProvider.notifier).setChip(index);
                if (_preview) {
                  context.go(
                    const [
                      '/screen/search-results',
                      '/screen/search-results',
                      '/screen/search-results',
                      '/screen/search-people',
                    ][index],
                  );
                } else {
                  setState(() {});
                }
              },
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filters'),
          onPressed: () {
            if (_preview) {
              context.go('/screen/search-filters');
            } else {
              setState(() => _filtersOpen = true);
            }
          },
        ),
      ],
    ),
  );

  Widget _filterPanel(BuildContext context, AsyncValue<SearchPage>? page) {
    final ui = ref.watch(searchUiProvider);
    final count = page?.asData?.value.resultCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Narrow your results',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        const Text('Published'),
        const SizedBox(height: PelevoSpacing.xs),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Any time')),
            ButtonSegment(value: 1, label: Text('This week')),
            ButtonSegment(value: 2, label: Text('This month')),
          ],
          selected: {ui.filterPublished.clamp(0, 2)},
          onSelectionChanged:
              (value) =>
                  ref.read(searchUiProvider.notifier).setPublished(value.first),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Only show unplayed episodes'),
          subtitle: const Text('Hide episodes already marked as played'),
          value: ui.unplayedOnly,
          onChanged:
              (value) => ref.read(searchUiProvider.notifier).setUnplayed(value),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include explicit content'),
          value: true,
          onChanged: (_) {
            context.showPelevoMessage(
              'Explicit-content filtering is not offered by search yet.',
            );
          },
        ),
        const SizedBox(height: PelevoSpacing.sm),
        const Text(
          'Date, unplayed and explicit filters are not offered by search yet. Results still follow your query.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: count == null ? 'Show results' : 'Show $count results',
          onPressed: () {
            if (_preview) {
              context.go('/screen/search-results');
            } else {
              setState(() => _filtersOpen = false);
            }
          },
        ),
      ],
    );
  }

  Widget _showTile(BuildContext context, SearchShow show) {
    final following = _isFollowing(show);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SearchArtwork(
        label: show.title,
        color: PelevoColors.red,
        artworkUrl: show.artworkUrl,
      ),
      title: Text(show.title),
      subtitle: Text(show.subtitle),
      trailing: IconButton(
        tooltip: following ? 'Unfollow ${show.title}' : 'Follow ${show.title}',
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

  Widget _inlineError(String message, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );
}

class _SearchArtwork extends StatelessWidget {
  const _SearchArtwork({
    required this.label,
    required this.color,
    this.artworkUrl,
  });

  final String label;
  final Color color;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.small),
      child:
          url == null || url.isEmpty
              ? PelevoArtwork(label: label, size: 58, color: color)
              : PelevoNetworkArt(
                url: url,
                width: 58,
                height: 58,
                fallback: PelevoArtwork(label: label, size: 58, color: color),
              ),
    );
  }
}

class _SearchCategoryGrid extends StatelessWidget {
  const _SearchCategoryGrid();

  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 4,
    crossAxisSpacing: PelevoSpacing.xs,
    mainAxisSpacing: PelevoSpacing.xs,
    childAspectRatio: 1,
    children: [
      _SearchCategory(
        label: 'Podcasts',
        icon: Icons.podcasts_rounded,
        color: PelevoColors.red,
        onTap: () => context.go('/screen/search-results'),
      ),
      _SearchCategory(
        label: 'Shorts',
        icon: Icons.smart_display_rounded,
        color: PelevoColors.purple,
        onTap: () => context.go('/screen/reels'),
      ),
      _SearchCategory(
        label: 'Audiobooks',
        icon: Icons.headphones_rounded,
        color: PelevoColors.green,
        onTap: () => context.go('/screen/browse'),
      ),
      _SearchCategory(
        label: 'More',
        icon: Icons.grid_view_rounded,
        color: PelevoColors.surfaceHigh,
        onTap: () => context.go('/screen/browse'),
      ),
    ],
  );
}

class _SearchCategory extends StatelessWidget {
  const _SearchCategory({
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: PelevoRadii.card,
      child: Ink(
        decoration: BoxDecoration(color: color, borderRadius: PelevoRadii.card),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color == PelevoColors.yellow ? Colors.black : Colors.white,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
