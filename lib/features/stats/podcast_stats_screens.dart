import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';
import 'package:pelevo/features/stats/stats_data.dart';

enum _StatsView {
  overview,
  listeningTime,
  episodesPlayed,
  topPodcasts,
  habits,
  streaks,
  category,
  monthly,
  achievements,
  downloads,
  devices,
  compare,
}

const _statsInventory =
    <({String id, String title, String state, _StatsView view})>[
      (
        id: 'stats-overview',
        title: 'Your Stats',
        state: 'Overview dashboard',
        view: _StatsView.overview,
      ),
      (
        id: 'stats-time',
        title: 'Listening Time',
        state: 'Time breakdown',
        view: _StatsView.listeningTime,
      ),
      (
        id: 'stats-completion',
        title: 'Episodes Played',
        state: 'Episode totals',
        view: _StatsView.episodesPlayed,
      ),
      (
        id: 'stats-shows',
        title: 'Top Podcasts',
        state: 'Most played',
        view: _StatsView.topPodcasts,
      ),
      (
        id: 'stats-heatmap',
        title: 'Listening Habits',
        state: 'Rhythm heatmap',
        view: _StatsView.habits,
      ),
      (
        id: 'stats-streak',
        title: 'Streaks',
        state: 'Current streak',
        view: _StatsView.streaks,
      ),
      (
        id: 'stats-genres',
        title: 'Time by Category',
        state: 'Category mix',
        view: _StatsView.category,
      ),
      (
        id: 'stats-year',
        title: 'Monthly Progress',
        state: 'Year to date',
        view: _StatsView.monthly,
      ),
      (
        id: 'stats-discovery',
        title: 'Achievements',
        state: 'Badges and goals',
        view: _StatsView.achievements,
      ),
      (
        id: 'stats-goals',
        title: 'Download Stats',
        state: 'Offline totals',
        view: _StatsView.downloads,
      ),
      (
        id: 'stats-weekly',
        title: 'Listening by Device',
        state: 'Device split',
        view: _StatsView.devices,
      ),
      (
        id: 'stats-share',
        title: 'Compare Periods',
        state: 'Period comparison',
        view: _StatsView.compare,
      ),
    ];

List<Color> _palette(BuildContext context) => [
  PelevoColors.green,
  PelevoColors.orange,
  PelevoColors.red,
  const Color(0xFF8B5CF6),
  PelevoColors.blue,
  context.pelevo.textDim,
];

final List<PelevoScreenSpec> podcastStatsScreens = List.unmodifiable(
  _statsInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Podcast Stats',
      title: item.title,
      state: item.state,
      builder: (_) => _StatsScreen(view: item.view, title: item.title),
    ),
  ),
);

class _StatsScreen extends ConsumerStatefulWidget {
  const _StatsScreen({required this.view, required this.title});

  final _StatsView view;
  final String title;

  @override
  ConsumerState<_StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<_StatsScreen> {
  String _range = 'This Week';
  int _nav = 2;
  late DateTimeRange _primaryRange;
  late DateTimeRange _comparisonRange;

  @override
  void initState() {
    super.initState();
    _range = switch (widget.view) {
      _StatsView.listeningTime ||
      _StatsView.episodesPlayed ||
      _StatsView.habits ||
      _StatsView.category ||
      _StatsView.devices => 'This Month',
      _StatsView.monthly || _StatsView.compare => 'This Year',
      _ => 'This Week',
    };
    final now = DateTime.now();
    _primaryRange = DateTimeRange(
      start: now.subtract(const Duration(days: 29)),
      end: now,
    );
    _comparisonRange = DateTimeRange(
      start: now.subtract(const Duration(days: 59)),
      end: now.subtract(const Duration(days: 30)),
    );
  }

  DateTime get _rangeStart {
    final now = DateTime.now();
    return switch (_range) {
      'This Month' => DateTime(now.year, now.month, 1),
      'This Year' => DateTime(now.year, 1, 1),
      _ => now.subtract(const Duration(days: 6)),
    };
  }

  List<ListenerDailyStat> _daily(ListenerStats stats) =>
      stats.inRange(_rangeStart, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(listenerStatsProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (widget.view == _StatsView.overview) {
              context.pelevoBack(fallback: '/screen/library-1');
            } else {
              context.pelevoBack(fallback: '/screen/stats-overview');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(widget.title),
        actions: [
          if (widget.view != _StatsView.streaks &&
              widget.view != _StatsView.compare)
            PopupMenuButton<String>(
              tooltip: 'Select range',
              initialValue: _range,
              onSelected: (value) => setState(() => _range = value),
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 'This Week', child: Text('This Week')),
                    PopupMenuItem(
                      value: 'This Month',
                      child: Text('This Month'),
                    ),
                    PopupMenuItem(value: 'This Year', child: Text('This Year')),
                  ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PelevoSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      _range,
                      style: const TextStyle(color: PelevoColors.green),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: PelevoColors.green,
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Share stats',
            onPressed: () {
              final stats = ref.read(listenerStatsProvider).asData?.value;
              final text =
                  stats == null
                      ? 'My listening on Pelevo'
                      : 'My Pelevo listening\n${formatStatsDuration(stats.listeningSeconds)} listened\n${stats.episodesCompleted} episodes finished\n${stats.showsFollowed} podcasts followed';
              _shareText(context, text);
            },
            icon: const Icon(Icons.ios_share_rounded),
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
      child:
          statsAsync.isLoading
              ? const CatalogStatusBody()
              : statsAsync.hasError
              ? CatalogStatusBody(
                error: statsAsync.error,
                retry: () => ref.invalidate(listenerStatsProvider),
              )
              : switch (widget.view) {
                _StatsView.overview => _overview(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.listeningTime => _listeningTime(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.episodesPlayed => _episodesPlayed(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.topPodcasts => _topPodcasts(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.habits => _habits(context, statsAsync.requireValue),
                _StatsView.streaks => _streaks(context, statsAsync.requireValue),
                _StatsView.category => _category(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.monthly => _monthly(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.achievements => _achievements(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.downloads => _downloads(
                  context,
                  statsAsync.requireValue,
                ),
                _StatsView.devices => _devices(context, statsAsync.requireValue),
                _StatsView.compare => _compare(context, statsAsync.requireValue),
              },
    );
  }

  Widget _overview(BuildContext context, ListenerStats stats) {
    final daily = _daily(stats);
    final listening =
        daily.isEmpty ? stats.listeningSeconds : stats.listeningIn(daily);
    final started =
        daily.isEmpty ? stats.episodesStarted : stats.startedIn(daily);
    final average = started == 0 ? 0 : listening ~/ started;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricHeader(
          context,
          value: formatStatsDuration(listening),
          onTap: () => context.go('/screen/stats-time'),
        ),
        const SizedBox(height: PelevoSpacing.md),
        _chartCard(
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: _chartPoints(daily.map((row) => row.listeningSeconds)),
                color: PelevoColors.green,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: PelevoSpacing.sm,
          crossAxisSpacing: PelevoSpacing.sm,
          childAspectRatio: 1.45,
          children: [
            _statTile(
              'Episodes Played',
              '$started',
              () => context.go('/screen/stats-completion'),
            ),
            _statTile(
              'Podcasts Listened',
              '${stats.shows.length}',
              () => context.go('/screen/stats-shows'),
            ),
            _statTile(
              'Avg. Listen Time',
              formatStatsDuration(average),
              () => context.go('/screen/stats-time'),
            ),
            _statTile(
              'Longest Streak',
              '${stats.streak?.longestDays ?? 0} days',
              () => context.go('/screen/stats-streak'),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoSectionHeader(
          title: 'Explore',
          onSeeAll: () => context.go('/screen/stats-share'),
        ),
        Wrap(
          spacing: PelevoSpacing.xs,
          runSpacing: PelevoSpacing.xs,
          children: [
            for (final item in const [
              ('Habits', '/screen/stats-heatmap'),
              ('Categories', '/screen/stats-genres'),
              ('Monthly', '/screen/stats-year'),
              ('Achievements', '/screen/stats-discovery'),
              ('Downloads', '/screen/stats-goals'),
              ('Devices', '/screen/stats-weekly'),
            ])
              ActionChip(
                label: Text(item.$1),
                onPressed: () => context.go(item.$2),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Continue Listening', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        _continueCard(context),
      ],
    );
  }

  Widget _continueCard(BuildContext context) {
    final recent = ref.watch(catalogLibraryRecentProvider).asData?.value;
    final incomplete = recent?.where((row) => !row.completed).toList();
    if (incomplete != null && incomplete.isNotEmpty) {
      final item = incomplete.first;
      return _continueTile(
        context,
        id: item.episode.id,
        showId: item.episode.showId,
        title: item.episode.title,
        subtitle: item.episode.showTitle ?? '',
        artworkUrl: item.episode.artworkUrl,
      );
    }
    final session = ref.watch(catalogPlayerSessionProvider).asData?.value;
    final episodeId = session?.episodeId;
    if (episodeId == null || episodeId.isEmpty) {
      return Text(
        'Nothing in progress.',
        style: TextStyle(color: context.pelevo.textMuted),
      );
    }
    final episode = ref.watch(catalogEpisodeByIdProvider(episodeId)).asData?.value;
    if (episode == null) {
      return const CatalogStatusBody();
    }
    return _continueTile(
      context,
      id: episode.id,
      showId: episode.showId,
      title: episode.title,
      subtitle: episode.showTitle ?? '',
      artworkUrl: episode.artworkUrl,
    );
  }

  Widget _continueTile(
    BuildContext context, {
    required String id,
    required String showId,
    required String title,
    required String subtitle,
    required String? artworkUrl,
  }) => Card(
    color: context.pelevo.surface,
    child: ListTile(
      leading: CatalogArtwork(url: artworkUrl, width: 48, height: 48),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Play episode',
        onPressed: () {
          openCatalogEpisode(context, episodeId: id, showId: showId);
          context.go('/screen/player-now-playing');
        },
        icon: const Icon(Icons.play_circle_fill_rounded),
      ),
      onTap: () {
        openCatalogEpisode(context, episodeId: id, showId: showId);
        context.go('/screen/episode-details');
      },
    ),
  );

  Widget _listeningTime(BuildContext context, ListenerStats stats) {
    final daily = _daily(stats);
    final listening =
        daily.isEmpty ? stats.listeningSeconds : stats.listeningIn(daily);
    final days = daily.where((row) => row.listeningSeconds > 0).toList();
    final average =
        days.isEmpty ? 0 : stats.listeningIn(days) ~/ days.length;
    ListenerDailyStat? longest;
    for (final row in daily) {
      if (longest == null || row.listeningSeconds > longest.listeningSeconds) {
        longest = row;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricHeader(context, value: formatStatsDuration(listening)),
        const SizedBox(height: PelevoSpacing.md),
        _chartCard(
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _BarChartPainter(
                values: _normalized(daily.map((row) => row.listeningSeconds)),
                labels: [
                  for (final row in daily) '${row.date.month}/${row.date.day}',
                ],
                color: PelevoColors.green,
                labelColor: context.pelevo.textMuted,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            Expanded(child: _miniMetric('Daily Average', formatStatsDuration(average))),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: _miniMetric(
                'Longest Day',
                longest == null
                    ? '—'
                    : '${formatStatsDuration(longest.listeningSeconds)}\n${longest.date.year}-${longest.date.month.toString().padLeft(2, '0')}-${longest.date.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Time by Range', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          'Episode length buckets are not available yet.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
      ],
    );
  }

  Widget _episodesPlayed(BuildContext context, ListenerStats stats) {
    final daily = _daily(stats);
    final started =
        daily.isEmpty ? stats.episodesStarted : stats.startedIn(daily);
    final completed = stats.episodesCompleted;
    final inProgress = stats.inProgress;
    final total = completed + inProgress;
    final ratio = total == 0 ? 0.0 : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricHeader(context, value: '$started'),
        const SizedBox(height: PelevoSpacing.md),
        _chartCard(
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _BarChartPainter(
                values: _normalized(daily.map((row) => row.episodesStarted)),
                labels: [
                  for (final row in daily) '${row.date.month}/${row.date.day}',
                ],
                color: PelevoColors.red,
                labelColor: context.pelevo.textMuted,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text('By Status', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: [
                    (ratio == 0 ? 1 : ratio, PelevoColors.red),
                    if (ratio > 0 && ratio < 1)
                      (1 - ratio, context.pelevo.surfaceHigh),
                  ],
                  centerLabel: total == 0 ? '0%' : '${(ratio * 100).round()}%',
                  labelColor: context.pelevo.text,
                ),
              ),
            ),
            const SizedBox(width: PelevoSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completed  $completed${total == 0 ? '' : ' (${(ratio * 100).round()}%)'}',
                  ),
                  const SizedBox(height: 8),
                  Text('In Progress  $inProgress'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _topPodcasts(BuildContext context, ListenerStats stats) {
    final total = stats.shows.fold<int>(
      0,
      (sum, show) => sum + show.listeningSeconds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Most Played', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (stats.shows.isEmpty)
          Text(
            'No played shows yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final show in stats.shows)
            Padding(
              padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: InkWell(
                onTap: () {
                  openCatalogShow(context, show.id);
                  context.go('/screen/podcast-details');
                },
                child: Row(
                  children: [
                    CatalogArtwork(
                      url: show.artworkUrl,
                      width: 44,
                      height: 44,
                    ),
                    const SizedBox(width: PelevoSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(show.title),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value:
                                  total == 0
                                      ? 0
                                      : show.listeningSeconds / total,
                              minHeight: 6,
                              color: PelevoColors.orange,
                              backgroundColor: context.pelevo.surfaceHigh,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: PelevoSpacing.sm),
                    Text(
                      formatStatsDuration(show.listeningSeconds),
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('By Time Spent', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: _donut(stats.shows.map((show) => show.listeningSeconds)),
                  centerLabel: formatStatsDuration(total),
                  labelColor: context.pelevo.text,
                ),
              ),
            ),
            const SizedBox(width: PelevoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.shows.isEmpty)
                    Text(
                      'No played shows yet.',
                      style: TextStyle(color: context.pelevo.textMuted),
                    )
                  else
                    for (final show in stats.shows)
                      Text(
                        '${show.title}  ${total == 0 ? '0' : ((show.listeningSeconds / total) * 100).round()}%',
                      ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _habits(BuildContext context, ListenerStats stats) {
    final daily = _daily(stats);
    final listeningDays = daily.where((row) => row.listeningSeconds > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Listening by Day', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.md),
        _chartCard(
          child: SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _HeatmapPainter(
                values: _normalized(daily.map((row) => row.listeningSeconds)),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Peak Times', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Weekdays'),
          subtitle: Text('Not available yet'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Weekends'),
          subtitle: Text('Not available yet'),
        ),
        const SizedBox(height: PelevoSpacing.md),
        _miniMetric('Listening Days', '$listeningDays / ${daily.length} days'),
        const SizedBox(height: PelevoSpacing.md),
        PelevoButton(
          label: 'View Streaks',
          outlined: true,
          color: PelevoColors.orange,
          onPressed: () => context.go('/screen/stats-streak'),
        ),
      ],
    );
  }

  Widget _streaks(BuildContext context, ListenerStats stats) {
    final current = stats.streak?.currentDays ?? 0;
    final longest = stats.streak?.longestDays ?? 0;
    final byDate = {
      for (final row in stats.daily) row.date: row.listeningSeconds > 0,
    };
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.lg),
        Image.asset(
          'assets/stats/streak_hero.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text('$current Days', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          'Current Streak — Keep it up!',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 7; i++)
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    byDate[DateTime(start.year, start.month, start.day + i)] ==
                            true
                        ? PelevoColors.green
                        : context.pelevo.surfaceHigh,
                child: Text(
                  labels[i],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Row(
          children: [
            Expanded(child: _miniMetric('Longest Streak', '$longest days')),
            const SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: _miniMetric(
                'Total Days',
                '${stats.daily.where((row) => row.listeningSeconds > 0).length} days',
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'View Achievements',
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/stats-discovery'),
        ),
      ],
    );
  }

  Widget _category(BuildContext context, ListenerStats stats) {
    final total = stats.categories.fold<int>(
      0,
      (sum, row) => sum + row.listeningSeconds,
    );
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: _donut(stats.categories.map((row) => row.listeningSeconds)),
              centerLabel: '${formatStatsDuration(total)}\nTotal',
              labelColor: context.pelevo.text,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        if (stats.categories.isEmpty)
          Text(
            'No category totals yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (var i = 0; i < stats.categories.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.circle,
                size: 14,
                color: _palette(context)[i % _palette(context).length],
              ),
              title: Text(stats.categories[i].name),
              subtitle: Text(
                formatStatsDuration(stats.categories[i].listeningSeconds),
              ),
              trailing: Text(
                total == 0
                    ? '0%'
                    : '${((stats.categories[i].listeningSeconds / total) * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => context.go('/screen/browse'),
            ),
      ],
    );
  }

  Widget _monthly(BuildContext context, ListenerStats stats) {
    final grouped = <String, int>{};
    for (final row in stats.daily) {
      final key =
          '${row.date.year}-${row.date.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + row.listeningSeconds;
    }
    final months = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final total = grouped.values.fold<int>(0, (sum, value) => sum + value);
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricHeader(
          context,
          value: formatStatsDuration(total == 0 ? stats.listeningSeconds : total),
          label: 'Total Time',
        ),
        const SizedBox(height: PelevoSpacing.md),
        _chartCard(
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: _chartPoints(months.reversed.map((row) => row.value)),
                color: PelevoColors.green,
                labels: [
                  for (final row in months.reversed)
                    names[int.parse(row.key.split('-')[1]) - 1].substring(0, 3),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (months.isEmpty)
          Text(
            'No monthly totals yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final row in months)
            Card(
              color: context.pelevo.surface,
              margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: ListTile(
                title: Text(names[int.parse(row.key.split('-')[1]) - 1]),
                subtitle: Text(formatStatsDuration(row.value)),
                onTap: () => context.go('/screen/stats-time'),
              ),
            ),
      ],
    );
  }

  Widget _achievements(BuildContext context, ListenerStats stats) {
    if (stats.achievements.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
        child: Text(
          'No achievements yet.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final item in stats.achievements)
          Card(
            color: context.pelevo.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: PelevoColors.green.withValues(alpha: .2),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: PelevoColors.green,
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                item.description.isEmpty ? 'Completed' : item.description,
                style: const TextStyle(color: PelevoColors.green),
              ),
              onTap: () {
                if (item.slug.contains('streak')) {
                  context.go('/screen/stats-streak');
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _downloads(BuildContext context, ListenerStats stats) => Column(
    children: [
      Image.asset(
        'assets/stats/download_hero.png',
        width: 110,
        height: 110,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.md),
      _metricHeader(
        context,
        value: '${stats.downloadsCount}',
        label: 'Total Downloads',
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Row(
        children: [
          const Expanded(child: _UnavailableMetric('Storage Used')),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(child: _miniMetric('Episodes', '${stats.downloadsCount}')),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text('By Quality', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: PelevoSpacing.md),
      Text(
        'Download quality split is not available yet.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Open Downloads',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/downloads-1'),
      ),
    ],
  );

  Widget _devices(BuildContext context, ListenerStats stats) => Column(
    children: [
      SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _DonutPainter(
            segments: [(1, context.pelevo.surfaceHigh)],
            centerLabel: '${formatStatsDuration(stats.listeningSeconds)}\nTotal',
            labelColor: context.pelevo.text,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Device split is not available yet.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
    ],
  );

  Future<void> _shareText(BuildContext context, String text) async {
    try {
      await pelevoShare(
        context: context,
        text: text,
        title: 'Pelevo listening',
        subject: 'Pelevo listening',
      );
    } on Object {
      if (context.mounted) {
        context.showPelevoMessage('Sharing is not available on this device.');
      }
    }
  }

  Widget _compare(BuildContext context, ListenerStats stats) {
    final primary = stats.inRange(_primaryRange.start, _primaryRange.end);
    final comparison = stats.inRange(
      _comparisonRange.start,
      _comparisonRange.end,
    );
    final rows = [
      (
        'Listening Time',
        formatStatsDuration(stats.listeningIn(primary)),
        formatStatsDelta(stats.listeningIn(primary), stats.listeningIn(comparison)),
      ),
      (
        'Episodes Played',
        '${stats.startedIn(primary)}',
        formatStatsDelta(stats.startedIn(primary), stats.startedIn(comparison)),
      ),
      (
        'Podcasts Listened',
        '${stats.shows.length}',
        null,
      ),
      (
        'Avg. Listen Time',
        formatStatsDuration(
          stats.startedIn(primary) == 0
              ? 0
              : stats.listeningIn(primary) ~/ stats.startedIn(primary),
        ),
        formatStatsDelta(
          stats.startedIn(primary) == 0
              ? 0
              : stats.listeningIn(primary) ~/ stats.startedIn(primary),
          stats.startedIn(comparison) == 0
              ? 0
              : stats.listeningIn(comparison) ~/ stats.startedIn(comparison),
        ),
      ),
      (
        'Longest Streak',
        '${stats.streak?.longestDays ?? 0} days',
        null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    () => _pickComparisonRange(context, _primaryRange, true),
                child: Text(_formatRange(_primaryRange)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('vs'),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    () =>
                        _pickComparisonRange(context, _comparisonRange, false),
                child: Text(_formatRange(_comparisonRange)),
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        for (final item in rows)
          Card(
            color: context.pelevo.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: ListTile(
              title: Text(item.$1),
              subtitle: Text(item.$2),
              trailing:
                  item.$3 == null
                      ? null
                      : Text(
                        item.$3!,
                        style: const TextStyle(
                          color: PelevoColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Share Comparison',
          color: PelevoColors.green,
          onPressed: () {
            final lines = rows
                .map((row) {
                  final delta = row.$3;
                  return delta == null
                      ? '${row.$1}: ${row.$2}'
                      : '${row.$1}: ${row.$2} ($delta)';
                })
                .join('\n');
            _shareText(context, 'Pelevo listening comparison\n$lines');
          },
        ),
      ],
    );
  }

  Future<void> _pickComparisonRange(
    BuildContext context,
    DateTimeRange initialRange,
    bool primary,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
    );
    if (range != null && context.mounted) {
      setState(() {
        if (primary) {
          _primaryRange = range;
        } else {
          _comparisonRange = range;
        }
      });
    }
  }

  String _formatRange(DateTimeRange range) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[range.start.month - 1]} ${range.start.day} – '
        '${months[range.end.month - 1]} ${range.end.day}';
  }

  Widget _metricHeader(
    BuildContext context, {
    required String value,
    String? delta,
    String? label,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(label, style: TextStyle(color: context.pelevo.textMuted)),
        Text(value, style: Theme.of(context).textTheme.displaySmall),
        if (delta != null && delta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            delta,
            style: const TextStyle(
              color: PelevoColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _statTile(String label, String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(PelevoRadii.medium),
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        color: context.pelevo.surface,
        borderRadius: BorderRadius.circular(PelevoRadii.medium),
        border: Border.all(color: context.pelevo.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  Widget _miniMetric(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.pelevo.textMuted)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _chartCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: BorderRadius.circular(PelevoRadii.large),
    ),
    child: child,
  );

  List<double> _normalized(Iterable<int> raw) {
    final values = raw.toList(growable: false);
    if (values.isEmpty) return const [];
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return List<double>.filled(values.length, 0);
    return [for (final value in values) value / max];
  }

  List<double> _chartPoints(Iterable<int> raw) {
    final values = _normalized(raw);
    if (values.length == 1) return [0, values.first];
    return values;
  }

  List<(double, Color)> _donut(Iterable<int> raw) {
    final values = raw.toList(growable: false);
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (values.isEmpty || total <= 0) {
      return [(1, context.pelevo.surfaceHigh)];
    }
    return [
      for (var i = 0; i < values.length; i++)
        (values[i] / total, _palette(context)[i % _palette(context).length]),
    ];
  }
}

class _UnavailableMetric extends StatelessWidget {
  const _UnavailableMetric(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.pelevo.textMuted)),
        const SizedBox(height: 6),
        const Text(
          'Not available yet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    this.labels = const [],
  });

  final List<double> values;
  final Color color;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final fill =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .35), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size);
    final path = Path();
    final fillPath = Path();
    final denom = values.length == 1 ? 1 : values.length - 1;
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / denom);
      final y = size.height * (1 - values[i]) * .85 + size.height * .05;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()..color = color;
    final gap = size.width * .08;
    final barWidth = (size.width - gap * (values.length + 1)) / values.length;
    for (var i = 0; i < values.length; i++) {
      final left = gap + i * (barWidth + gap);
      final height = size.height * values[i] * .75;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height - 18, barWidth, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(color: labelColor, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(left + (barWidth - tp.width) / 2, size.height - 14),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.labelColor != labelColor;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.centerLabel,
    required this.labelColor,
  });

  final List<(double, Color)> segments;
  final String centerLabel;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius * .85);
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = segment.$1 * math.pi * 2;
      final paint =
          Paint()
            ..color = segment.$2
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * .28
            ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.centerLabel != centerLabel ||
      oldDelegate.labelColor != labelColor;
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({this.values = const []});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const days = 7;
    const slots = 6;
    final cellW = size.width / days;
    final cellH = size.height / slots;
    for (var d = 0; d < days; d++) {
      for (var s = 0; s < slots; s++) {
        final index = d * slots + s;
        final intensity = index < values.length ? values[index] : 0.0;
        final paint =
            Paint()
              ..color = PelevoColors.green.withValues(
                alpha: .15 + intensity * .75,
              );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(d * cellW + 2, s * cellH + 2, cellW - 4, cellH - 4),
            const Radius.circular(3),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.values != values;
}
