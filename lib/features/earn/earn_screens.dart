import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/config/app_config.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/earn/earn_catalog_data.dart';
import 'package:pelevo/features/earn/earn_playback_session.dart';

export 'package:pelevo/features/earn/earn_playback_session.dart';
import 'package:pelevo/features/earn/earn_wallet_data.dart';
import 'package:pelevo/features/player/pelevo_playback.dart';

class EarnBrowseFilter {
  static String? showId;
  static String query = '';

  static void openAll(
    BuildContext context, {
    String? showFilter,
    String? search,
  }) {
    showId = showFilter;
    query = search?.trim() ?? '';
    context.push('/screen/earn-all');
  }
}

class EarnHomeScreen extends ConsumerWidget {
  const EarnHomeScreen({super.key});

  static const _previewPerShow = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(earnCatalogProvider);
    final blocked = earnRegionBlock(context, ref);
    if (blocked != null) return blocked;
    final config = ref.watch(appConfigProvider).asData?.value;
    if (config != null && !config.enabled('earn_enabled', fallback: true)) {
      return PelevoPage(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Earn is currently unavailable.'),
              TextButton(
                onPressed: () => context.go('/screen/home-feed'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }
    return PelevoPage(
      bottomNavigationBar: PelevoBottomNavigation(
        index: PelevoBottomNavigation.indexForRoute(config, '/screen/earn'),
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: catalog.when(
            skipLoadingOnRefresh: false,
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (error, stack) {
              final failure = earnFailure(error);
              if (failure.code == 'CANCELLED') {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: [
                  Text(failure.message),
                  TextButton(
                    onPressed: () => ref.invalidate(earnCatalogProvider),
                    child: const Text('Retry'),
                  ),
                ],
              );
            },
            data:
                (page) => ListenableBuilder(
                  listenable: EarnPlaybackSession.instance,
                  builder: (context, _) {
                    final session = EarnPlaybackSession.instance;
                    if (session.pendingWalletRefresh) {
                      session.pendingWalletRefresh = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        ref.invalidate(earnWalletProvider);
                        ref.invalidate(earnCatalogProvider);
                      });
                    }
                    final resume = session.activeEpisode;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Earn',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed:
                                  () => context.push('/screen/earn-wallet'),
                              child: const EarnBalanceLabel(),
                            ),
                          ],
                        ),
                        const Text(
                          'Finish a marked episode to earn coins. Pause whenever you need to, then resume from the same place.',
                          style: TextStyle(
                            color: PelevoColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: PelevoSpacing.md),
                        TextField(
                          textInputAction: TextInputAction.search,
                          onSubmitted:
                              (value) => EarnBrowseFilter.openAll(
                                context,
                                search: value,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Search podcasts and episodes',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: PelevoColors.surface,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: PelevoSpacing.md),
                        if (resume != null &&
                            session.progressFor(resume.id) > Duration.zero &&
                            !session.isLocked(resume.id) &&
                            !resume.isLocked)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: PelevoSpacing.md,
                            ),
                            child: Material(
                              color: const Color(0xFF102117),
                              borderRadius: BorderRadius.circular(
                                PelevoRadii.large,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  PelevoRadii.large,
                                ),
                                onTap: () => _openPlayer(context, ref, resume),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    PelevoSpacing.md,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: PelevoColors.green,
                                      ),
                                      const SizedBox(width: PelevoSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Continue listening',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: PelevoColors.green,
                                              ),
                                            ),
                                            Text(
                                              resume.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(PelevoSpacing.md),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF143021), Color(0xFF101211)],
                            ),
                            borderRadius: BorderRadius.circular(
                              PelevoRadii.large,
                            ),
                            border: Border.all(color: const Color(0xFF245C38)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reward Rules',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _RuleChip(label: '< 10 mins → 1 coin'),
                                  _RuleChip(label: '< 20 mins → 2 coins'),
                                  _RuleChip(label: '> 20 mins → 3 coins'),
                                  _RuleChip(label: '1 coin = \$0.004 USD'),
                                ],
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Coins are credited only after the episode is completed. Pause and play are allowed. Forward and backward are disabled. Completed episodes lock for 72 hours. Earn progress is isolated from the main player.',
                                style: TextStyle(
                                  color: PelevoColors.textMuted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: PelevoSpacing.xl),
                        PelevoSectionHeader(
                          title: 'Monetized Podcasts',
                          onSeeAll: () => EarnBrowseFilter.openAll(context),
                        ),
                        const SizedBox(height: PelevoSpacing.sm),
                        if (page.shows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: PelevoSpacing.lg),
                            child: Text(
                              'No monetized podcasts are available yet.',
                              style: TextStyle(color: PelevoColors.textMuted),
                            ),
                          )
                        else
                          SizedBox(
                            height: 148,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: page.orderedShows.length,
                              separatorBuilder:
                                  (context, index) =>
                                      const SizedBox(width: PelevoSpacing.sm),
                              itemBuilder: (context, index) {
                                final show = page.orderedShows[index];
                                return _ShowCard(
                                  show: show,
                                  onTap:
                                      () => EarnBrowseFilter.openAll(
                                        context,
                                        showFilter: show.id,
                                      ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: PelevoSpacing.xl),
                        for (final section in page.sections) ...[
                          if (section.label != null) ...[
                            Text(
                              section.label!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: PelevoColors.green,
                              ),
                            ),
                            const SizedBox(height: PelevoSpacing.sm),
                          ],
                          for (final show in section.shows) ...[
                            PelevoSectionHeader(
                              title: show.title,
                              onSeeAll:
                                  () => EarnBrowseFilter.openAll(
                                    context,
                                    showFilter: show.id,
                                  ),
                            ),
                            const SizedBox(height: PelevoSpacing.xs),
                            ...page
                                .episodesForShow(show.id)
                                .take(_previewPerShow)
                                .map(
                                  (episode) => _EarnEpisodeTile(
                                    episode: episode,
                                    locked:
                                        session.isLocked(episode.id) ||
                                        episode.isLocked,
                                    progress: session.progressFor(episode.id),
                                    lockRemaining:
                                        session.lockRemaining(episode.id) ??
                                        (episode.isLocked
                                            ? episode.lockedUntil!.difference(
                                              DateTime.now(),
                                            )
                                            : null),
                                    onPlay:
                                        () =>
                                            _openPlayer(context, ref, episode),
                                  ),
                                ),
                            if (page.episodesForShow(show.id).length >
                                _previewPerShow)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed:
                                      () => EarnBrowseFilter.openAll(
                                        context,
                                        showFilter: show.id,
                                      ),
                                  child: Text(
                                    'See all ${page.episodesForShow(show.id).length} ${show.title} episodes',
                                    style: const TextStyle(
                                      color: PelevoColors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: PelevoSpacing.lg),
                          ],
                        ],
                      ],
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }
}

void _openPlayer(BuildContext context, WidgetRef ref, EarnEpisode episode) {
  final session = EarnPlaybackSession.instance;
  if (!episode.isLocked) session.releaseUncreditedLock(episode.id);
  final locked = episode.isLocked || session.isLocked(episode.id);
  if (locked) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This episode is locked for 72 hours and cannot be opened.',
        ),
      ),
    );
    return;
  }
  ref.read(selectedEarnEpisodeProvider.notifier).select(episode);
  session.openEpisode(episode.id);
  context.push('/screen/earn-player');
}

Widget? earnRegionBlock(BuildContext context, WidgetRef ref) {
  final access = ref.watch(earnAccessProvider);
  if (access.isLoading && !access.hasValue) {
    return const PelevoPage(child: Center(child: CircularProgressIndicator()));
  }
  final decision = access.asData?.value;
  if (decision != null && !decision.allowed) {
    return const EarnOutsideUsScreen();
  }
  if (access.hasError && !access.hasValue) {
    final failure = earnFailure(access.error!);
    if (failure.code == 'CANCELLED') {
      return const PelevoPage(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (failure.code == 'REGION_RESTRICTED' || failure.statusCode == 403) {
      return const EarnOutsideUsScreen();
    }
    return PelevoPage(
      child: Column(
        children: [
          Text(failure.message),
          TextButton(
            onPressed: () => ref.invalidate(earnAccessProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  return null;
}

class EarnOutsideUsScreen extends ConsumerWidget {
  const EarnOutsideUsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).asData?.value;
    return PelevoPage(
      bottomNavigationBar: PelevoBottomNavigation(
        index: PelevoBottomNavigation.indexForRoute(config, '/screen/earn'),
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              const SizedBox(height: PelevoSpacing.xl),
              const _UsConnectionMark(),
              const SizedBox(height: PelevoSpacing.xl),
              Text(
                'EARN',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PelevoColors.green,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              Text(
                "You're not on a US IP",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              const Text(
                'Earn opens for connections in the United States. Switch to a US address, then check again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PelevoColors.textMuted, height: 1.45),
              ),
              const SizedBox(height: PelevoSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(PelevoSpacing.md),
                decoration: BoxDecoration(
                  color: PelevoColors.surface,
                  borderRadius: BorderRadius.circular(PelevoRadii.large),
                  border: Border.all(color: PelevoColors.border),
                ),
                child: const Column(
                  children: [
                    _UsHint(
                      icon: Icons.public_rounded,
                      title: 'United States only',
                      body:
                          'Localhost and other countries stay on this screen.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PelevoSpacing.xl),
              PelevoButton(
                label: 'Check again',
                color: PelevoColors.green,
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(earnAccessProvider),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              PelevoButton(
                label: 'Back to Home',
                outlined: true,
                color: PelevoColors.green,
                foregroundColor: PelevoColors.text,
                onPressed: () => context.go('/screen/home-feed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsConnectionMark extends StatelessWidget {
  const _UsConnectionMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x552FA44F), Color(0x002FA44F)],
              ),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PelevoColors.surface,
              border: Border.all(color: PelevoColors.border),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: PelevoColors.yellow,
              size: 52,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsHint extends StatelessWidget {
  const _UsHint({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0x222FA44F),
            borderRadius: BorderRadius.circular(PelevoRadii.medium),
          ),
          child: Icon(icon, color: PelevoColors.green, size: 20),
        ),
        const SizedBox(width: PelevoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: PelevoColors.textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EarnAllScreen extends ConsumerStatefulWidget {
  const EarnAllScreen({super.key});

  @override
  ConsumerState<EarnAllScreen> createState() => _EarnAllScreenState();
}

class _EarnAllScreenState extends ConsumerState<EarnAllScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  CancelToken? _request;
  String? _showId;
  int _page = 1;
  bool _loading = true;
  String? _error;
  List<EarnShow> _shows = [];
  List<EarnEpisode> _episodes = [];
  EarnPage<EarnEpisode>? _episodePage;
  EarnPage<EarnShow>? _showPage;

  @override
  void initState() {
    super.initState();
    _showId = EarnBrowseFilter.showId;
    _search.text = EarnBrowseFilter.query;
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = CancelToken();
    _request?.cancel();
    _request = request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = _search.text.trim();
    final repository = ref.read(earnCatalogRepositoryProvider);
    try {
      if (_showId == null) {
        final shows = await repository.shows(
          query: query,
          page: _page,
          token: request,
        );
        final episodes = await repository.episodes(
          query: query,
          page: _page,
          token: request,
        );
        if (!mounted || request.isCancelled) return;
        setState(() {
          _shows = shows.items;
          _showPage = shows;
          _episodes = episodes.items;
          _episodePage = episodes;
          _loading = false;
        });
        return;
      }
      final episodes = await repository.episodes(
        showId: _showId,
        query: query,
        page: _page,
        token: request,
      );
      if (!mounted || request.isCancelled) return;
      setState(() {
        _episodes = episodes.items;
        _episodePage = episodes;
        _shows = [];
        _showPage = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request.isCancelled) return;
      final failure = earnFailure(error);
      if (failure.code == 'CANCELLED') return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      EarnBrowseFilter.query = value.trim();
      setState(() => _page = 1);
      unawaited(_load());
    });
  }

  void _openShow(String showId) {
    _debounce?.cancel();
    EarnBrowseFilter.showId = showId;
    EarnBrowseFilter.query = '';
    _search.clear();
    setState(() {
      _showId = showId;
      _page = 1;
    });
    unawaited(_load());
  }

  void _showAll() {
    EarnBrowseFilter.showId = null;
    EarnBrowseFilter.query = '';
    _search.clear();
    setState(() {
      _showId = null;
      _page = 1;
    });
    unawaited(_load());
  }

  void _changePage(int page) {
    setState(() => _page = page);
    unawaited(_load());
  }

  EarnShow _showHeader(
    String id,
    String fallbackTitle,
    Map<String, List<EarnEpisode>> groups,
    EarnShow? knownShow,
  ) {
    for (final show in _shows) {
      if (show.id == id) return show;
    }
    if (knownShow != null && knownShow.id == id) return knownShow;
    final sample = groups[id];
    final episode = sample == null || sample.isEmpty ? null : sample.first;
    return EarnShow(
      id: id,
      title: episode?.showTitle ?? fallbackTitle,
      episodeCount: sample?.length ?? (_episodePage?.total ?? 0),
      author: episode?.showAuthor,
      artworkUrl: episode?.artworkUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = earnRegionBlock(context, ref);
    if (blocked != null) return blocked;
    final knownShow =
        _showId == null
            ? null
            : ref.watch(earnCatalogProvider).asData?.value.showById(_showId!);
    final episodeShowTitle =
        _episodes.isEmpty ? null : _episodes.first.showTitle;
    final title =
        _showId == null
            ? 'All Earn Podcasts'
            : (knownShow?.title ?? episodeShowTitle ?? 'Monetized Episodes');
    final paging = _showId == null ? _showPage : _episodePage;
    final episodeTotal = _episodePage?.total ?? _episodes.length;
    return ListenableBuilder(
      listenable: EarnPlaybackSession.instance,
      builder: (context, _) {
        final session = EarnPlaybackSession.instance;
        final groups = <String, List<EarnEpisode>>{};
        for (final episode in _episodes) {
          (groups[episode.showId] ??= []).add(episode);
        }
        final showIds =
            _showId == null
                ? {for (final show in _shows) show.id, ...groups.keys}.toList()
                : [_showId!];
        return PelevoPage(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed:
                  () =>
                      _showId == null ? context.go('/screen/earn') : _showAll(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(title),
            actions: [
              if (_showId != null)
                TextButton(onPressed: _showAll, child: const Text('All')),
            ],
          ),
          bottomNavigationBar: PelevoBottomNavigation(
            index: PelevoBottomNavigation.indexForRoute(
              ref.watch(appConfigProvider).asData?.value,
              '/screen/earn',
            ),
            onDestinationSelected: context.openPelevoTab,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText:
                          _showId == null
                              ? 'Search podcasts and episodes'
                              : 'Search episodes in this podcast',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: PelevoColors.surface,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: PelevoSpacing.md),
                  Text(
                    _showId == null
                        ? '${_showPage?.total ?? _shows.length} podcast${(_showPage?.total ?? _shows.length) == 1 ? '' : 's'} · $episodeTotal episodes'
                        : '$episodeTotal episode${episodeTotal == 1 ? '' : 's'}',
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                  const SizedBox(height: PelevoSpacing.md),
                  if (_loading && _episodes.isEmpty && _shows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null &&
                      _episodes.isEmpty &&
                      _shows.isEmpty)
                    Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => unawaited(_load()),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (showIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text(
                        'No monetized episodes in this category yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final id in showIds) ...[
                      _ShowHeader(
                        show: _showHeader(id, title, groups, knownShow),
                        onOpenShow:
                            _showId == null ? () => _openShow(id) : null,
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      ...(groups[id] ?? const <EarnEpisode>[]).map(
                        (episode) => _EarnEpisodeTile(
                          episode: episode,
                          locked:
                              session.isLocked(episode.id) || episode.isLocked,
                          progress: session.progressFor(episode.id),
                          lockRemaining:
                              session.lockRemaining(episode.id) ??
                              (episode.isLocked
                                  ? episode.lockedUntil!.difference(
                                    DateTime.now(),
                                  )
                                  : null),
                          onPlay: () => _openPlayer(context, ref, episode),
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.lg),
                    ],
                  if (paging != null && (paging.hasPrevious || paging.hasMore))
                    _EarnPager(
                      page: paging.page,
                      lastPage: paging.lastPage,
                      loading: _loading,
                      onPrevious:
                          paging.hasPrevious
                              ? () => _changePage(paging.page - 1)
                              : null,
                      onNext:
                          paging.hasMore
                              ? () => _changePage(paging.page + 1)
                              : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EarnPager extends StatelessWidget {
  const _EarnPager({
    required this.page,
    required this.lastPage,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.lg),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: loading ? null : onPrevious,
            child: const Text('Previous'),
          ),
          Expanded(
            child: Text(
              'Page $page of $lastPage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: loading ? null : onNext,
            style: FilledButton.styleFrom(backgroundColor: PelevoColors.green),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.show, required this.onTap});

  final EarnShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(PelevoRadii.large),
    child: SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EarnArt(url: show.artworkUrl, width: 120, height: 100),
          const SizedBox(height: 6),
          Text(
            show.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            '${show.episodeCount} episodes',
            style: const TextStyle(color: PelevoColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _ShowHeader extends StatelessWidget {
  const _ShowHeader({required this.show, this.onOpenShow});

  final EarnShow show;
  final VoidCallback? onOpenShow;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpenShow,
    borderRadius: BorderRadius.circular(PelevoRadii.large),
    child: Row(
      children: [
        _EarnArt(url: show.artworkUrl, width: 56, height: 56, radius: 10),
        const SizedBox(width: PelevoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                show.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${show.host} · ${show.episodeCount} earn episodes',
                style: const TextStyle(
                  color: PelevoColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (onOpenShow != null)
          const Icon(Icons.chevron_right_rounded, color: PelevoColors.green),
      ],
    ),
  );
}

class EarnPlayerScreen extends ConsumerStatefulWidget {
  const EarnPlayerScreen({super.key});

  @override
  ConsumerState<EarnPlayerScreen> createState() => _EarnPlayerScreenState();
}

class _EarnPlayerScreenState extends ConsumerState<EarnPlayerScreen> {
  String? _startedId;

  Future<void> _play(EarnEpisode episode) async {
    final playback = EarnPlaybackSession.instance;
    try {
      if (!playback.isPlaying) {
        await ref.read(pelevoPlaybackControllerProvider).releaseForEarn();
      }
      await playback.toggle(
        episode: episode,
        repository: ref.read(earnCatalogRepositoryProvider),
        deviceId: ref.read(installationIdProvider),
      );
    } catch (error) {
      playback.reportFailure(error);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final blocked = earnRegionBlock(context, ref);
    if (blocked != null) return blocked;
    final selected = ref.watch(selectedEarnEpisodeProvider);
    final catalog = ref.watch(earnCatalogProvider);
    return catalog.when(
      skipLoadingOnRefresh: false,
      loading:
          () => PelevoPage(
            appBar: AppBar(title: const Text('Earn Playback')),
            child: const Center(child: CircularProgressIndicator()),
          ),
      error: (error, stack) {
        final failure = earnFailure(error);
        if (failure.code == 'CANCELLED') {
          return PelevoPage(
            appBar: AppBar(title: const Text('Earn Playback')),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return PelevoPage(
          appBar: AppBar(title: const Text('Earn Playback')),
          child: Column(
            children: [
              Text(failure.message),
              TextButton(
                onPressed: () => ref.invalidate(earnCatalogProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (page) {
        final episode =
            selected ??
            page.episodeById(
              EarnPlaybackSession.instance.activeEpisodeId ?? '',
            );
        return ListenableBuilder(
          listenable: EarnPlaybackSession.instance,
          builder: (context, _) {
            final session = EarnPlaybackSession.instance;
            if (session.pendingWalletRefresh) {
              session.pendingWalletRefresh = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ref.invalidate(earnWalletProvider);
                ref.invalidate(earnCatalogProvider);
              });
            }
            if (episode == null) {
              return PelevoPage(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.go('/screen/earn'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: const Text('Earn Playback'),
                ),
                child: const Center(
                  child: Text(
                    'Select a monetized episode from Earn to start a verified session.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final progress = session.progressFor(episode.id);
            final locked = session.isLocked(episode.id) || episode.isLocked;
            if (locked) {
              final left =
                  session.lockRemaining(episode.id) ??
                  episode.lockedUntil?.difference(DateTime.now());
              return PelevoPage(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.go('/screen/earn'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: const Text('Earn Playback'),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PelevoSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_clock_rounded,
                          color: PelevoColors.yellow,
                          size: 56,
                        ),
                        const SizedBox(height: PelevoSpacing.md),
                        Text(
                          episode.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: PelevoSpacing.sm),
                        const Text(
                          'This episode is locked for 72 hours. It cannot be opened or streamed until the lock ends.',
                          textAlign: TextAlign.center,
                        ),
                        if (left != null && !left.isNegative) ...[
                          const SizedBox(height: PelevoSpacing.sm),
                          Text(
                            '${_formatDuration(left)} remaining',
                            style: const TextStyle(
                              color: PelevoColors.yellow,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
            final playbackDuration = session.durationFor(episode);
            final shown =
                progress > playbackDuration ? playbackDuration : progress;
            final fraction =
                playbackDuration.inMilliseconds == 0
                    ? 0.0
                    : shown.inMilliseconds / playbackDuration.inMilliseconds;
            final reward =
                session.serverSession?.expectedAward ?? episode.reward;
            final playing =
                session.isPlaying && session.activeEpisodeId == episode.id;
            final atEnd =
                playbackDuration > Duration.zero && shown >= playbackDuration;
            final canResume =
                shown > const Duration(seconds: 3) &&
                !playing &&
                !locked &&
                !atEnd &&
                !session.finalizing;
            final buffering =
                session.buffering &&
                (session.activeEpisodeId == episode.id || session.busy);
            final status = session.status;
            if (_startedId != episode.id && !session.busy) {
              final playingEpisode = episode;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _startedId == playingEpisode.id) return;
                _startedId = playingEpisode.id;
                unawaited(_play(playingEpisode));
              });
            }
            return PelevoPage(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go('/screen/earn'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: const Text('Earn Playback'),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      const SizedBox(height: PelevoSpacing.lg),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x552FA44F),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _EarnArt(
                          url: episode.artworkUrl,
                          width: 240,
                          height: 240,
                          radius: 28,
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.xl),
                      Text(
                        episode.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        episode.showTitle,
                        style: const TextStyle(color: PelevoColors.textMuted),
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x332FA44F),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Complete to earn $reward coin${reward == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: PelevoColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.xl),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: PelevoColors.border,
                          color: PelevoColors.green,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(shown)),
                          Text(
                            session.finalizing
                                ? 'Finalizing reward'
                                : buffering
                                ? 'Buffering audio...'
                                : atEnd
                                ? 'Playback complete'
                                : canResume
                                ? 'Resume ready'
                                : playbackDuration > episode.duration
                                ? 'Ad-adjusted'
                                : 'Earn session',
                            style: const TextStyle(
                              color: PelevoColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(_formatDuration(playbackDuration)),
                        ],
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      const Text(
                        'Pause and play only. Forward, backward, and speed changes are disabled so listening evidence stays valid. Playback keeps going when you leave this screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PelevoColors.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: PelevoSpacing.xl),
                      PelevoButton(
                        loading: buffering,
                        label:
                            session.finalizing
                                ? 'Finalizing reward...'
                                : buffering
                                ? (playing
                                    ? 'Buffering... tap to pause'
                                    : 'Loading audio...')
                                : playing
                                ? 'Pause'
                                : atEnd
                                ? 'Check reward'
                                : canResume
                                ? 'Resume'
                                : 'Play to Earn',
                        icon:
                            session.finalizing
                                ? Icons.hourglass_top_rounded
                                : playing
                                ? Icons.pause_rounded
                                : atEnd
                                ? Icons.verified_rounded
                                : Icons.play_arrow_rounded,
                        color: PelevoColors.green,
                        onPressed:
                            locked ||
                                    session.finalizing ||
                                    (buffering && !playing)
                                ? null
                                : atEnd
                                ? () => unawaited(session.finalize(episode))
                                : () => _play(episode),
                      ),
                      const SizedBox(height: PelevoSpacing.sm),
                      const Text(
                        'Earn progress is isolated from the general podcast player. Awards are posted only after verified heartbeats complete.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PelevoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          status is ApiFailure
                              ? (status.code == 'SERVICE_DEGRADED'
                                  ? 'Earn writes are disabled on the server (FINANCE_PUBLIC_ENABLED). Enable finance after sign-off, then try again.'
                                  : status.message)
                              : '$status',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PelevoColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class EarnWalletScreen extends ConsumerWidget {
  const EarnWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(earnWalletProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading:
            () => EarnWalletStatus(
              retry: () => ref.invalidate(earnWalletProvider),
            ),
        error:
            (error, stack) => EarnWalletStatus(
              error: error,
              retry: () => ref.invalidate(earnWalletProvider),
            ),
        data: (wallet) {
          return PelevoPage(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/screen/profile');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Earn Wallet'),
              actions: [
                IconButton(
                  tooltip: 'Refresh balance',
                  onPressed: () => ref.invalidate(earnWalletProvider),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Withdrawal history',
                  onPressed: () => context.push('/screen/withdraw-history'),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(PelevoSpacing.xl),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(PelevoRadii.large),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14532D), Color(0xFF0B1F14)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text('Available Balance'),
                          const SizedBox(height: 8),
                          Text(
                            '${wallet.balance} coins',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ECN · Earn wallet',
                            style: TextStyle(color: PelevoColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1 coin = \$0.004 USD · about ${wallet.usdLabel}',
                            style: const TextStyle(color: PelevoColors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PelevoSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(PelevoSpacing.md),
                      decoration: BoxDecoration(
                        color: PelevoColors.surface,
                        borderRadius: BorderRadius.circular(PelevoRadii.large),
                        border: Border.all(color: PelevoColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payout rules',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text('• Payouts are processed monthly'),
                          const Text(
                            '• You request payout after reaching the coin threshold',
                          ),
                          Text('• Minimum withdrawal: ${wallet.minimum} coins'),
                          const Text(
                            '• A server-verified payout method is required',
                          ),
                          Text(
                            wallet.withdrawalsEnabled
                                ? '• Verified payout methods can submit a withdrawal request.'
                                : '• Withdrawals are awaiting finance sign-off.',
                          ),
                          const Text(
                            '• This balance is separate from gifts and creator revenue.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PelevoSpacing.lg),
                    PelevoButton(
                      label: 'Request Payout',
                      color: PelevoColors.green,
                      onPressed: () {
                        if (!wallet.withdrawalsEnabled) {
                          showDialog<void>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Payout unavailable'),
                                  content: const Text(
                                    'Withdrawals are awaiting finance sign-off. No withdrawal has been submitted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                          return;
                        }
                        context.push('/screen/withdraw');
                      },
                    ),
                    const SizedBox(height: PelevoSpacing.sm),
                    PelevoButton(
                      label: 'Withdrawal History',
                      outlined: true,
                      color: PelevoColors.green,
                      onPressed: () => context.push('/screen/withdraw-history'),
                    ),
                    const SizedBox(height: PelevoSpacing.sm),
                    PelevoButton(
                      label: 'Continue Earning',
                      outlined: true,
                      color: PelevoColors.yellow,
                      foregroundColor: PelevoColors.text,
                      onPressed: () => context.go('/screen/earn'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x332FA44F),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EarnEpisodeTile extends StatelessWidget {
  const _EarnEpisodeTile({
    required this.episode,
    required this.locked,
    required this.progress,
    required this.onPlay,
    this.lockRemaining,
  });

  final EarnEpisode episode;
  final bool locked;
  final Duration progress;
  final Duration? lockRemaining;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final reward = episode.reward;
    final fraction =
        episode.duration.inMilliseconds == 0
            ? 0.0
            : progress.inMilliseconds / episode.duration.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
      child: Material(
        color: PelevoColors.surface,
        borderRadius: BorderRadius.circular(PelevoRadii.large),
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(PelevoRadii.large),
          child: Padding(
            padding: const EdgeInsets.all(PelevoSpacing.sm),
            child: Row(
              children: [
                _EarnArt(
                  url: episode.artworkUrl,
                  width: 56,
                  height: 56,
                  radius: 12,
                ),
                const SizedBox(width: PelevoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${episode.showTitle} · ${_formatDuration(episode.duration)} · $reward coin${reward == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PelevoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: locked ? 1 : fraction.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: PelevoColors.border,
                          color:
                              locked ? PelevoColors.yellow : PelevoColors.green,
                        ),
                      ),
                      if (locked)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Locked ${_formatDuration(lockRemaining ?? Duration.zero)} remaining',
                            style: const TextStyle(
                              color: PelevoColors.yellow,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: PelevoSpacing.xs),
                Icon(
                  locked
                      ? Icons.lock_clock_rounded
                      : Icons.play_circle_fill_rounded,
                  color: locked ? PelevoColors.yellow : PelevoColors.green,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EarnArt extends StatelessWidget {
  const _EarnArt({
    required this.url,
    required this.width,
    required this.height,
    this.radius,
  });

  final String? url;
  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: const Color(0xFF111016),
      alignment: Alignment.center,
      child: const Icon(Icons.podcasts_rounded, color: PelevoColors.textMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? PelevoRadii.medium),
      child:
          url != null && url!.isNotEmpty
              ? PelevoNetworkArt(
                url: url!,
                width: width,
                height: height,
                fallback: fallback,
              )
              : Image.asset(
                'assets/home/honest_bunch.png',
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
    );
  }
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}
