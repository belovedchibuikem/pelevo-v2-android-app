import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:pelevo/features/profile/account_feed.dart';
import 'package:pelevo/features/notifications/notification_preferences.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/stats/stats_data.dart';

enum _NotifView {
  home,
  filters,
  newEpisode,
  downloadComplete,
  dailyReminder,
  mentions,
  settings,
  scheduled,
  promotions,
  markAsRead,
  clearAll,
  history,
}

const _notifInventory =
    <({String id, String title, String state, _NotifView view})>[
      (
        id: 'notifications-1',
        title: 'Notifications',
        state: 'All · unread',
        view: _NotifView.home,
      ),
      (
        id: 'notifications-2',
        title: 'Notification Filters',
        state: 'Type preferences',
        view: _NotifView.filters,
      ),
      (
        id: 'notifications-3',
        title: 'New Episode',
        state: 'Episode alert',
        view: _NotifView.newEpisode,
      ),
      (
        id: 'notifications-4',
        title: 'Download Complete',
        state: 'Success',
        view: _NotifView.downloadComplete,
      ),
      (
        id: 'notifications-5',
        title: 'Daily Reminder',
        state: 'Time to listen',
        view: _NotifView.dailyReminder,
      ),
      (
        id: 'notifications-6',
        title: 'Mentions & Follows',
        state: 'Social activity',
        view: _NotifView.mentions,
      ),
      (
        id: 'notifications-7',
        title: 'Notification Settings',
        state: 'Preferences',
        view: _NotifView.settings,
      ),
      (
        id: 'notifications-8',
        title: 'Scheduled Summary',
        state: 'Daily digest',
        view: _NotifView.scheduled,
      ),
      (
        id: 'notifications-9',
        title: 'Promotions',
        state: 'Offers',
        view: _NotifView.promotions,
      ),
      (
        id: 'notifications-10',
        title: 'Mark as Read',
        state: 'Selection mode',
        view: _NotifView.markAsRead,
      ),
      (
        id: 'notifications-11',
        title: 'Clear All',
        state: 'Confirmation',
        view: _NotifView.clearAll,
      ),
      (
        id: 'notifications-12',
        title: 'Notification History',
        state: 'Archive',
        view: _NotifView.history,
      ),
    ];

final List<PelevoScreenSpec> notificationScreens = List.unmodifiable(
  _notifInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Notifications',
      title: item.title,
      state: item.state,
      builder: (_) => _NotifScreen(view: item.view, title: item.title),
    ),
  ),
);

class _NotifScreen extends ConsumerStatefulWidget {
  const _NotifScreen({required this.view, required this.title});

  final _NotifView view;
  final String title;

  @override
  ConsumerState<_NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends ConsumerState<_NotifScreen> {
  int _nav = 0;
  int _homeFilter = 0;
  final Set<String> _selected = {};

  bool get _isModal =>
      widget.view == _NotifView.clearAll ||
      widget.view == _NotifView.downloadComplete;

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((session) => session.userId), (
      previous,
      next,
    ) {
      if (previous != next) {
        setState(_selected.clear);
      }
    });
    return PelevoPage(
      appBar:
          _isModal
              ? null
              : AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    if (widget.view == _NotifView.home) {
                      context.pelevoBack(fallback: '/screen/library-1');
                    } else if (widget.view == _NotifView.filters ||
                        widget.view == _NotifView.scheduled) {
                      context.pelevoBack(fallback: '/screen/notifications-7');
                    } else {
                      context.pelevoBack(fallback: '/screen/notifications-1');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(
                  widget.view == _NotifView.markAsRead
                      ? '${_selected.length} selected'
                      : widget.title,
                ),
                actions: [
                  if (widget.view == _NotifView.home) ...[
                    IconButton(
                      tooltip: 'History',
                      onPressed: () => context.go('/screen/notifications-12'),
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                    IconButton(
                      tooltip: 'Notification settings',
                      onPressed: () => context.go('/screen/notifications-7'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                  if (widget.view == _NotifView.markAsRead)
                    TextButton(
                      onPressed: () => context.go('/screen/notifications-1'),
                      child: const Text('Cancel'),
                    ),
                  if (widget.view == _NotifView.newEpisode)
                    IconButton(
                      tooltip: 'More',
                      onPressed:
                          () => context.showPelevoMessage('More options'),
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                ],
              ),
      bottomNavigationBar:
          _isModal
              ? null
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PelevoBottomNavigation(
                    index: _nav,
                    onDestinationSelected: (value) {
                      setState(() => _nav = value);
                      context.openPelevoTab(value);
                    },
                  ),
                ],
              ),
      child: switch (widget.view) {
        _NotifView.home => _home(context),
        _NotifView.filters => _filters(context),
        _NotifView.newEpisode => AccountFeedPanel(
          feed: AccountFeed.newEpisode,
          builder: (state) => _newEpisode(context, state),
        ),
        _NotifView.downloadComplete => _downloadComplete(context),
        _NotifView.dailyReminder => _dailyReminder(context),
        _NotifView.mentions => _mentions(context),
        _NotifView.settings => _settings(context),
        _NotifView.scheduled => _scheduled(context),
        _NotifView.promotions => AccountFeedPanel(
          feed: AccountFeed.broadcast,
          builder: (state) => _promotions(context, state),
        ),
        _NotifView.markAsRead => _markAsRead(context),
        _NotifView.clearAll => AccountFeedPanel(
          feed: AccountFeed.all,
          builder: (state) => _clearAll(context, state),
        ),
        _NotifView.history => _history(context),
      },
    );
  }

  Widget _home(BuildContext context) => _inbox(
    context,
    _homeFilter == 1
        ? AccountFeed.unread
        : _homeFilter == 2
        ? AccountFeed.mentions
        : AccountFeed.all,
    filters: true,
  );

  Widget _inbox(
    BuildContext context,
    AccountFeed feed, {
    bool filters = false,
    bool selection = false,
  }) => AccountFeedPanel(
    feed: feed,
    builder:
        (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filters)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in [
                      (0, 'All'),
                      (1, 'Unread (${state.unread ?? 0})'),
                      (2, 'Mentions'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: PelevoSpacing.xs),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: _homeFilter == entry.$1,
                          selectedColor: PelevoColors.green,
                          onSelected:
                              state.busy
                                  ? null
                                  : (_) =>
                                      setState(() => _homeFilter = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: PelevoSpacing.lg),
            if (state.items.isEmpty) const Text('No notifications to show.'),
            for (final item in state.items)
              Row(
                children: [
                  if (selection)
                    Checkbox(
                      value: _selected.contains(item.id),
                      onChanged:
                          state.busy
                              ? null
                              : (value) => setState(() {
                                if (value == true && _selected.length < 100) {
                                  _selected.add(item.id);
                                } else {
                                  _selected.remove(item.id);
                                }
                              }),
                    ),
                  Expanded(
                    child: _notifTile(
                      item.read
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      item.read ? PelevoColors.textMuted : PelevoColors.green,
                      item.title,
                      item.body,
                      _notificationDate(item.createdAt),
                      () async {
                        if (state.busy || state.loading) return;
                        if (selection) {
                          setState(() {
                            if (!_selected.remove(item.id) &&
                                _selected.length < 100) {
                              _selected.add(item.id);
                            }
                          });
                          return;
                        }
                        if (!item.read &&
                            !await state.mutate(
                              (repo) => repo.read(item.id),
                              'Marked as read',
                            )) {
                          return;
                        }
                        if (!context.mounted) return;
                        if (item.hasDestination) {
                          _openNotification(context, item);
                          return;
                        }
                        await showDialog<void>(
                          context: context,
                          builder:
                              (dialogContext) => AlertDialog(
                                title: Text(item.title),
                                content: SingleChildScrollView(
                                  child: SelectableText(item.body),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                        );
                      },
                      onLongPress: () => context.go('/screen/notifications-10'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: PelevoSpacing.lg),
            if (selection)
              Row(
                children: [
                  Expanded(
                    child: PelevoButton(
                      label: 'Mark as Read',
                      color: PelevoColors.green,
                      onPressed:
                          state.busy || _selected.isEmpty
                              ? null
                              : () async {
                                if (await state.mutate(
                                      (repo) =>
                                          repo.bulk(Set.of(_selected), 'read'),
                                      'Selected notifications marked as read',
                                    ) &&
                                    mounted) {
                                  setState(_selected.clear);
                                }
                              },
                    ),
                  ),
                  const SizedBox(width: PelevoSpacing.sm),
                  Expanded(
                    child: PelevoButton(
                      label: 'Delete',
                      color: PelevoColors.red,
                      onPressed:
                          state.busy || _selected.isEmpty
                              ? null
                              : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (dialogContext) => AlertDialog(
                                        title: const Text(
                                          'Remove selected notifications?',
                                        ),
                                        content: const Text(
                                          'They will remain available in notification history.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirmed == true &&
                                    state.mounted &&
                                    await state.mutate(
                                      (repo) => repo.bulk(
                                        Set.of(_selected),
                                        'dismiss',
                                      ),
                                      'Selected notifications removed',
                                    ) &&
                                    mounted) {
                                  setState(_selected.clear);
                                }
                              },
                    ),
                  ),
                ],
              )
            else if (filters)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/screen/notifications-10'),
                      child: const Text('Select'),
                    ),
                  ),
                  const SizedBox(width: PelevoSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/screen/notifications-11'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PelevoColors.red,
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                ],
              ),
          ],
        ),
  );

  void _openNotification(BuildContext context, AccountFeedItem item) {
    final episodeId = item.episodeId;
    if (episodeId != null && episodeId.isNotEmpty) {
      openCatalogEpisodeDetails(
        context,
        episodeId: episodeId,
        showId: item.showId,
      );
      return;
    }
    final reelId = item.reelId;
    if (reelId != null && reelId.isNotEmpty) {
      context.push('/reels/$reelId');
      return;
    }
    final showId = item.showId;
    if (showId != null && showId.isNotEmpty) {
      openCatalogShow(context, showId);
      context.push('/screen/podcast-details');
    }
  }

  String _notificationDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}\n${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _filters(BuildContext context) => const NotificationPreferencesContent(
    view: NotificationPreferenceView.filters,
  );

  Widget _newEpisode(BuildContext context, AccountFeedPanelState state) {
    if (state.loading) return const CatalogStatusBody();
    if (state.error != null) {
      return CatalogStatusBody(error: state.error, retry: () { state.refresh(); });
    }
    final item = state.items.isEmpty ? null : state.items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: PelevoSpacing.sm),
        CatalogArtwork(
          url: item?.artwork,
          width: 220,
          height: 220,
          radius: PelevoRadii.large,
          assetPath: 'assets/notifications/ep_cover.png',
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          'New Episode Out Now!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          item?.title ?? 'No new-episode alerts yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        if (item != null)
          Text(
            item.body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Play Now',
          color: PelevoColors.green,
          icon: Icons.play_arrow_rounded,
          onPressed:
              item == null
                  ? () => context.showPelevoMessage(
                    'This notification does not include an episode to play.',
                  )
                  : item.hasDestination
                  ? () => _openNotification(context, item)
                  : () => context.showPelevoMessage(
                    'This notification does not include an episode to play.',
                  ),
        ),
        TextButton(
          onPressed: () => context.go('/screen/library-4'),
          child: const Text(
            'Save to Library',
            style: TextStyle(color: PelevoColors.green),
          ),
        ),
      ],
    );
  }

  Widget _downloadComplete(BuildContext context) {
    final async = ref.watch(libraryDownloadsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(libraryDownloadsProvider),
      );
    }
    final download = async.requireValue.isEmpty ? null : async.requireValue.first;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PelevoColors.green.withValues(alpha: .18),
            border: Border.all(color: PelevoColors.green, width: 2),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 56,
            color: PelevoColors.green,
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text(
          'Download Complete!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          download == null
              ? 'No authorized downloads yet.'
              : '${download.title} is authorized on your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Play Episode'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: download == null
              ? () => context.showPelevoMessage('No authorized download to play.')
              : () {
                openCatalogEpisode(context, episodeId: download.episodeId);
                context.go('/screen/player-now-playing');
              },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('View in Downloads'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/screen/library-5'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share Episode'),
          trailing: const Icon(Icons.ios_share_rounded),
          onTap: download == null
              ? () => context.showPelevoMessage('No authorized download to share.')
              : () {
                openCatalogEpisode(context, episodeId: download.episodeId);
                context.go('/screen/episode-share');
              },
        ),
        const SizedBox(height: PelevoSpacing.lg),
        TextButton(
          onPressed: () => context.go('/screen/notifications-1'),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _dailyReminder(BuildContext context) {
    final statsAsync = ref.watch(listenerStatsProvider);
    final recentAsync = ref.watch(libraryRecentProvider);
    if (statsAsync.isLoading || recentAsync.isLoading) {
      return const CatalogStatusBody();
    }
    if (statsAsync.hasError) {
      return CatalogStatusBody(
        error: statsAsync.error,
        retry: () => ref.invalidate(listenerStatsProvider),
      );
    }
    if (recentAsync.hasError) {
      return CatalogStatusBody(
        error: recentAsync.error,
        retry: () => ref.invalidate(libraryRecentProvider),
      );
    }
    final streak = statsAsync.requireValue.streak?.currentDays ?? 0;
    final recent =
        recentAsync.requireValue.isEmpty ? null : recentAsync.requireValue.first;
    return Column(
      children: [
        const SizedBox(height: PelevoSpacing.xl),
        const Icon(
          Icons.notifications_active_rounded,
          size: 88,
          color: PelevoColors.yellow,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          'Time to Listen!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.sm),
        Text(
          streak == 0
              ? 'No current listening streak.'
              : 'You’re on a $streak-day streak. Keep it going with a quick session.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        if (recent == null)
          const Text(
            'Nothing in recents.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          Card(
            color: PelevoColors.surface,
            child: ListTile(
              leading: CatalogArtwork(
                url: recent.artworkUrl,
                width: 48,
                height: 48,
                assetPath: 'assets/notifications/ep_thumb.png',
              ),
              title: Text(recent.title),
              subtitle: Text(
                [
                  recent.showTitle,
                  'Continue Listening',
                ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.play_circle_fill_rounded),
              onTap: () {
                openCatalogEpisode(
                  context,
                  episodeId: recent.id,
                  showId: recent.showId,
                );
                context.go('/screen/player-now-playing');
              },
            ),
          ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Play Now',
          color: PelevoColors.green,
          icon: Icons.play_arrow_rounded,
          onPressed: recent == null
              ? () => context.showPelevoMessage('Nothing in recents to play.')
              : () {
                openCatalogEpisode(
                  context,
                  episodeId: recent.id,
                  showId: recent.showId,
                );
                context.go('/screen/player-now-playing');
              },
        ),
        TextButton(
          onPressed: () => context.go('/screen/notifications-1'),
          child: const Text(
            'Remind Me Later',
            style: TextStyle(color: PelevoColors.green),
          ),
        ),
      ],
    );
  }

  Widget _mentions(BuildContext context) =>
      _inbox(context, AccountFeed.mentions);

  Widget _settings(BuildContext context) =>
      const NotificationPreferencesContent(
        view: NotificationPreferenceView.settings,
      );

  Widget _scheduled(BuildContext context) =>
      const NotificationPreferencesContent(
        view: NotificationPreferenceView.scheduled,
      );

  Widget _promotions(BuildContext context, AccountFeedPanelState state) {
    if (state.loading) return const CatalogStatusBody();
    if (state.error != null) {
      return CatalogStatusBody(
        error: state.error,
        retry: () {
          state.refresh();
        },
      );
    }
    if (state.items.isEmpty) {
      return const Text(
        'No promotion broadcasts yet.',
        style: TextStyle(color: PelevoColors.textMuted),
      );
    }
    return Column(
      children: [
        for (final item in state.items)
          Card(
            color: PelevoColors.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: PelevoColors.yellow.withValues(alpha: .2),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: PelevoColors.yellow,
                        ),
                      ),
                      const SizedBox(width: PelevoSpacing.sm),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PelevoSpacing.sm),
                  Text(
                    item.body,
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                  TextButton(
                    onPressed: () => context.go('/screen/home-feed'),
                    child: const Text(
                      'Explore Now',
                      style: TextStyle(color: PelevoColors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _markAsRead(BuildContext context) =>
      _inbox(context, AccountFeed.all, selection: true);

  Widget _clearAll(BuildContext context, AccountFeedPanelState state) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PelevoColors.red.withValues(alpha: .18),
          border: Border.all(color: PelevoColors.red, width: 2),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 56,
          color: PelevoColors.red,
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Clear All Notifications?',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'This will remove every current notification from your inbox. They remain available in notification history.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xxl),
      PelevoButton(
        label: 'Clear All',
        color: PelevoColors.red,
        onPressed:
            state.busy || state.loading
                ? null
                : () async {
                  if (await state.mutate(
                        (repo) => repo.clear(),
                        'Notifications cleared',
                      ) &&
                      context.mounted) {
                    context.go('/screen/notifications-1');
                  }
                },
      ),
      TextButton(
        onPressed: () => context.go('/screen/notifications-1'),
        child: const Text('Cancel'),
      ),
    ],
  );

  Widget _history(BuildContext context) => _inbox(context, AccountFeed.history);

  Widget _notifTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String time,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: PelevoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PelevoColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PelevoSpacing.sm),
          Text(
            time,
            style: const TextStyle(color: PelevoColors.textDim, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
