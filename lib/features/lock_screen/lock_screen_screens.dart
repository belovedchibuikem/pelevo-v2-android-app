import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/ai/ai_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/lock_screen/lock_screen_data.dart';
import 'package:pelevo/features/notifications/local_notifications.dart';
import 'package:pelevo/features/notifications/notification_preferences.dart';
import 'package:pelevo/features/notifications/push_registration.dart';
import 'package:pelevo/features/player/pelevo_audio_handler.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/profile/account_feed.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

String _lockClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _lockDate(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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
  final local = value.toLocal();
  return '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}';
}

String _lockStamp(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year} ${_lockClock(local)}';
}

enum _LockView {
  newEpisode,
  continueListening,
  downloadComplete,
  showEpisode,
  playlistUpdated,
  recommendation,
  expiring,
  liveAlert,
  settings,
  preview,
  style,
  controls,
  privacy,
  quietHours,
  sound,
  dnd,
  history,
  snooze,
  rules,
  widget,
  focus,
  analytics,
  advanced,
  about,
}

const _inventory = <({String id, String title, String state, _LockView view})>[
  (
    id: 'lock-new-episode',
    title: 'New Episode Alert',
    state: 'Episode released',
    view: _LockView.newEpisode,
  ),
  (
    id: 'lock-continue-listening',
    title: 'Continue Listening',
    state: 'Playback reminder',
    view: _LockView.continueListening,
  ),
  (
    id: 'lock-download-complete',
    title: 'Download Complete',
    state: 'Ready offline',
    view: _LockView.downloadComplete,
  ),
  (
    id: 'lock-show-episode',
    title: 'New Episode in Show',
    state: 'Followed show',
    view: _LockView.showEpisode,
  ),
  (
    id: 'lock-playlist-updated',
    title: 'Playlist Updated',
    state: 'Playlist changed',
    view: _LockView.playlistUpdated,
  ),
  (
    id: 'lock-recommendation',
    title: 'Recommendation',
    state: 'Suggested listening',
    view: _LockView.recommendation,
  ),
  (
    id: 'lock-episode-expiring',
    title: 'Episode Expiring',
    state: 'Download expires soon',
    view: _LockView.expiring,
  ),
  (
    id: 'lock-live-alert',
    title: 'Live Podcast Alert',
    state: 'Live show started',
    view: _LockView.liveAlert,
  ),
  (
    id: 'lock-settings',
    title: 'Lock Screen Notifications',
    state: 'Category settings',
    view: _LockView.settings,
  ),
  (
    id: 'lock-preview',
    title: 'Notification Preview',
    state: 'Preview appearance',
    view: _LockView.preview,
  ),
  (
    id: 'lock-style',
    title: 'Notification Style',
    state: 'Compact or detailed',
    view: _LockView.style,
  ),
  (
    id: 'lock-controls',
    title: 'Media Controls',
    state: 'Playback controls',
    view: _LockView.controls,
  ),
  (
    id: 'lock-privacy',
    title: 'Privacy Options',
    state: 'Lock-screen privacy',
    view: _LockView.privacy,
  ),
  (
    id: 'lock-quiet-hours',
    title: 'Quiet Hours',
    state: 'Scheduled silence',
    view: _LockView.quietHours,
  ),
  (
    id: 'lock-sound-vibration',
    title: 'Sound & Vibration',
    state: 'Alert feedback',
    view: _LockView.sound,
  ),
  (
    id: 'lock-do-not-disturb',
    title: 'Do Not Disturb',
    state: 'Focus behavior',
    view: _LockView.dnd,
  ),
  (
    id: 'lock-history',
    title: 'Notification History',
    state: 'Recent alerts',
    view: _LockView.history,
  ),
  (
    id: 'lock-snooze',
    title: 'Snooze Notifications',
    state: 'Temporary silence',
    view: _LockView.snooze,
  ),
  (
    id: 'lock-custom-rules',
    title: 'Custom Rules',
    state: 'Conditional delivery',
    view: _LockView.rules,
  ),
  (
    id: 'lock-widget',
    title: 'Lock Screen Widget',
    state: 'Widget controls',
    view: _LockView.widget,
  ),
  (
    id: 'lock-focus',
    title: 'Focus Mode Integration',
    state: 'Focus modes',
    view: _LockView.focus,
  ),
  (
    id: 'lock-analytics',
    title: 'Notification Analytics',
    state: 'Alert performance',
    view: _LockView.analytics,
  ),
  (
    id: 'lock-advanced',
    title: 'Advanced Settings',
    state: 'System behavior',
    view: _LockView.advanced,
  ),
  (
    id: 'lock-about',
    title: 'About & Help',
    state: 'Support information',
    view: _LockView.about,
  ),
];

final List<PelevoScreenSpec> lockScreenNotificationScreens = List.unmodifiable(
  _inventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Lock Screen Notifications',
      title: item.title,
      state: item.state,
      builder: (_) => _LockScreen(view: item.view, title: item.title),
    ),
  ),
);

const _unavailableCategories = {
  'Continue Listening',
  'Playlist Updates',
  'Recommendations',
  'Live Show Alerts',
  'Episode Expiring',
};

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.view, required this.title});

  final _LockView view;
  final String title;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  int _nav = 4;
  int _style = 1;
  int _privacy = 1;
  int _previewBackground = 0;
  int _widgetSize = 1;
  int _quietDay = 1;
  bool _sound = true;
  bool _vibrate = true;
  bool _faceId = false;
  bool _saving = false;
  Object? _error;
  final Map<String, bool> _options = {};

  bool get _isAlert => widget.view.index <= _LockView.liveAlert.index;

  String get _backRoute {
    if (_isAlert) return '/screen/lock-settings';
    if (widget.view == _LockView.settings) return '/screen/notifications-7';
    if (widget.view == _LockView.snooze ||
        widget.view == _LockView.rules ||
        widget.view == _LockView.widget ||
        widget.view == _LockView.focus ||
        widget.view == _LockView.analytics ||
        widget.view == _LockView.about) {
      return '/screen/lock-advanced';
    }
    return '/screen/lock-settings';
  }

  bool _option(String key, bool fallback) => _options[key] ?? fallback;

  void _setOption(String key, bool value) =>
      setState(() => _options[key] = value);

  String _unavailable(String feature) =>
      '$feature is not available on this account API yet.';

  Future<void> _savePreferences(
    NotificationPreferences previous,
    Map<String, dynamic> draft,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(notificationPreferencesRepositoryProvider)
          .save(previous, draft);
      if (!mounted) return;
      ref.invalidate(notificationPreferencesProvider);
      context.showPelevoMessage('Notification preferences saved');
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _pickTime(String? current) async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          current == null
              ? TimeOfDay.now()
              : TimeOfDay(
                hour: int.parse(current.substring(0, 2)),
                minute: int.parse(current.substring(3, 5)),
              ),
    );
    return time == null
        ? null
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go(_backRoute),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(widget.title),
    ),
    bottomNavigationBar:
        _isAlert
            ? null
            : PelevoBottomNavigation(
              index: _nav,
              onDestinationSelected: (value) {
                setState(() => _nav = value);
                context.openPelevoTab(value);
              },
            ),
    child:
        _isAlert
            ? _alert(context)
            : switch (widget.view) {
              _LockView.settings => _settings(context),
              _LockView.preview => _preview(context),
              _LockView.style => _notificationStyle(context),
              _LockView.controls => _controls(context),
              _LockView.privacy => _privacyOptions(context),
              _LockView.quietHours => _quietHours(context),
              _LockView.sound => _soundVibration(context),
              _LockView.dnd => _doNotDisturb(context),
              _LockView.history => _history(context),
              _LockView.snooze => _snooze(context),
              _LockView.rules => _rules(context),
              _LockView.widget => _widgetSettings(context),
              _LockView.focus => _focus(context),
              _LockView.analytics => _analytics(context),
              _LockView.advanced => _advanced(context),
              _LockView.about => _about(context),
              _ => const SizedBox.shrink(),
            },
  );

  Widget _alert(BuildContext context) {
    return switch (widget.view) {
      _LockView.newEpisode || _LockView.showEpisode => _asyncAlert(
        context,
        async: ref.watch(lockNewEpisodePreviewProvider).whenData(
          (item) => item == null ? const <AccountFeedItem>[] : [item],
        ),
        retry: () => ref.invalidate(lockNewEpisodePreviewProvider),
        builder: (items) {
          final item = items.isEmpty ? null : items.first;
          return _alertBody(
            context,
            headline:
                widget.view == _LockView.showEpisode
                    ? 'New Episode in Your Show'
                    : 'New Episode Out Now!',
            subtitle: item?.title ?? 'No new-episode alerts yet.',
            detail: item?.body,
            artworkUrl: item?.artwork,
            asset: 'assets/notifications/ep_cover.png',
            icon: Icons.podcasts_rounded,
            color: PelevoColors.red,
            onOpen:
                () => context.showPelevoMessage(
                  'This notification does not include an episode to play.',
                ),
          );
        },
      ),
      _LockView.continueListening => _asyncAlert(
        context,
        async: ref.watch(libraryRecentProvider),
        retry: () => ref.invalidate(libraryRecentProvider),
        builder: (items) {
          final item = items.isEmpty ? null : items.first;
          return _alertBody(
            context,
            headline: 'Continue Listening',
            subtitle:
                item == null
                    ? 'Nothing in recents.'
                    : [
                      item.title,
                      if ((item.showTitle ?? '').isNotEmpty) item.showTitle,
                    ].join(' · '),
            artworkUrl: item?.artworkUrl,
            asset: 'assets/podcast/episode_123.png',
            icon: Icons.play_arrow_rounded,
            color: PelevoColors.red,
            onOpen:
                item == null
                    ? () => context.showPelevoMessage(
                      'Nothing in recents to resume.',
                    )
                    : () {
                      openCatalogEpisode(
                        context,
                        episodeId: item.id,
                        showId: item.showId,
                      );
                      context.go('/screen/player-now-playing');
                    },
          );
        },
      ),
      _LockView.downloadComplete => _asyncAlert(
        context,
        async: ref.watch(libraryDownloadsProvider),
        retry: () => ref.invalidate(libraryDownloadsProvider),
        builder: (items) {
          final item = items.isEmpty ? null : items.first;
          return _alertBody(
            context,
            headline: 'Download Complete',
            subtitle:
                item == null
                    ? 'No authorized downloads yet.'
                    : '${item.title} is authorized on your account.',
            artworkUrl: item?.artworkUrl,
            asset: 'assets/podcast/episode_122.png',
            icon: Icons.download_done_rounded,
            color: PelevoColors.green,
            onOpen:
                item == null
                    ? () => context.showPelevoMessage(
                      'No authorized download to open.',
                    )
                    : () {
                      openCatalogEpisode(
                        context,
                        episodeId: item.episodeId,
                        showId: item.showId,
                      );
                      context.go('/screen/player-now-playing');
                    },
          );
        },
      ),
      _LockView.playlistUpdated => _alertBody(
        context,
        headline: 'Playlist Updated',
        subtitle: 'Playlist-update lock alerts are not available yet.',
        asset: 'assets/home/playlist_afrobeats.png',
        icon: Icons.playlist_play_rounded,
        color: PelevoColors.yellow,
        onOpen: () => context.go('/screen/library-3'),
      ),
      _LockView.recommendation => _asyncAlert(
        context,
        async: ref.watch(aiRecommendationsProvider),
        retry: () => ref.invalidate(aiRecommendationsProvider),
        builder: (items) {
          final item = items.isEmpty ? null : items.first;
          return _alertBody(
            context,
            headline: 'New Recommendation',
            subtitle: item?.title ?? 'No recommendations yet.',
            detail: item?.reason,
            asset: 'assets/home/morning_motivation.png',
            icon: Icons.auto_awesome_rounded,
            color: PelevoColors.green,
            onOpen:
                item == null
                    ? () => context.showPelevoMessage(
                      'No recommendation to open.',
                    )
                    : () => context.go('/screen/browse'),
          );
        },
      ),
      _LockView.expiring => _asyncAlert(
        context,
        async: ref.watch(libraryDownloadsProvider),
        retry: () => ref.invalidate(libraryDownloadsProvider),
        builder: (items) {
          final dated =
              items.where((item) => item.authorizedUntil != null).toList()
                ..sort(
                  (a, b) => a.authorizedUntil!.compareTo(b.authorizedUntil!),
                );
          final item = dated.isEmpty ? null : dated.first;
          return _alertBody(
            context,
            headline: 'Episode Expiring Soon',
            subtitle:
                item == null
                    ? 'No expiring authorizations.'
                    : '${item.title} authorized until ${_lockStamp(item.authorizedUntil!)}',
            artworkUrl: item?.artworkUrl,
            asset: 'assets/podcast/episode_120.png',
            icon: Icons.warning_amber_rounded,
            color: PelevoColors.red,
            onOpen:
                item == null
                    ? () => context.showPelevoMessage(
                      'No expiring authorization to open.',
                    )
                    : () => context.go('/screen/downloads-7'),
          );
        },
      ),
      _ => _asyncAlert(
        context,
        async: ref.watch(publicLiveSessionsProvider),
        retry: () => ref.invalidate(publicLiveSessionsProvider),
        builder: (items) {
          final live = items.where((item) => item.state == 'live').toList();
          final item = live.isEmpty ? null : live.first;
          return _alertBody(
            context,
            headline: 'Live Podcast Alert',
            subtitle: item?.title ?? 'No live sessions listed.',
            asset: 'assets/podcast/honest_bunch_cover.png',
            icon: Icons.live_tv_rounded,
            color: PelevoColors.red,
            onOpen:
                item == null
                    ? () => context.showPelevoMessage('No live session to open.')
                    : () => context.showPelevoMessage(
                      'Live session ${item.title} is listed as live.',
                    ),
          );
        },
      ),
    };
  }

  Widget _asyncAlert<T>(
    BuildContext context, {
    required AsyncValue<List<T>> async,
    required VoidCallback retry,
    required Widget Function(List<T> items) builder,
  }) {
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(error: async.error, retry: retry);
    }
    return builder(async.requireValue);
  }

  Widget _alertBody(
    BuildContext context, {
    required String headline,
    required String subtitle,
    String? detail,
    String? artworkUrl,
    required String asset,
    required IconData icon,
    required Color color,
    required VoidCallback onOpen,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _lockFrame(
        context,
        title: headline,
        subtitle: [subtitle, if (detail != null && detail.isNotEmpty) detail]
            .join('\n'),
        artworkUrl: artworkUrl,
        asset: asset,
        icon: icon,
        color: color,
        onTap: onOpen,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Open',
        icon: icon,
        color: color,
        onPressed: onOpen,
      ),
      TextButton(
        onPressed: () => context.go('/screen/lock-settings'),
        child: const Text('Notification Settings'),
      ),
    ],
  );

  Widget _settings(BuildContext context) {
    final async = ref.watch(notificationPreferencesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(notificationPreferencesProvider),
      );
    }
    final preferences = async.requireValue;
    final types = List<String>.from(
      preferences.options['types'] as List? ?? const [],
    );
    final push = preferences.data['push_enabled'] as bool;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(),
        Text(
          preferences.data['delivery_status'] == 'in_app_policy_enabled'
              ? 'Push preference is saved to your account. Enable Lock Screen Alerts below to register this device with FCM and mirror remote/live alerts onto the lock screen.'
              : 'These preferences are saved to your account. Enable OS notifications below for lock-visible local alerts.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        PelevoButton(
          label: 'Enable Lock Screen Alerts',
          color: PelevoColors.green,
          onPressed:
              _saving
                  ? null
                  : () async {
                    final message =
                        await ref
                            .read(lockNotificationBootstrapProvider)
                            .enable();
                    if (context.mounted) {
                      context.showPelevoMessage(message);
                    }
                  },
        ),
        if (_error != null)
          Text(
            profileFailure(_error!).message,
            style: const TextStyle(color: PelevoColors.red),
          ),
        _switch(
          'Enable Lock Screen Notifications',
          'Account push preference. OS lock delivery is not claimed.',
          Icons.notifications_active_outlined,
          push,
          _saving
              ? (_) {}
              : (value) {
                final draft = _prefsDraft(preferences);
                draft['push_enabled'] = value;
                _savePreferences(preferences, draft);
              },
        ),
        const _Section('Notification Types'),
        for (final label in const [
          'New Episodes',
          'Continue Listening',
          'Downloads',
          'Playlist Updates',
          'Recommendations',
          'Live Show Alerts',
          'Episode Expiring',
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle:
                _unavailableCategories.contains(label)
                    ? const Text('Not available yet')
                    : null,
            value:
                label == 'New Episodes'
                    ? preferences.data['new_episodes'] as bool ||
                        types.contains('new_episodes')
                    : label == 'Downloads'
                    ? types.contains('downloads')
                    : false,
            activeColor: PelevoColors.green,
            onChanged:
                _saving || !push || _unavailableCategories.contains(label)
                    ? (_unavailableCategories.contains(label)
                        ? (_) => context.showPelevoMessage(
                          _unavailable('$label lock alerts'),
                        )
                        : null)
                    : (value) {
                      final draft = _prefsDraft(preferences);
                      final next = List<String>.from(
                        draft['options']['types'] as List,
                      );
                      if (label == 'New Episodes') {
                        if (value) {
                          if (!next.contains('new_episodes')) {
                            next.add('new_episodes');
                          }
                        } else {
                          next.remove('new_episodes');
                        }
                        draft['new_episodes'] = value;
                      } else if (label == 'Downloads') {
                        if (value) {
                          if (!next.contains('downloads')) {
                            next.add('downloads');
                          }
                        } else {
                          next.remove('downloads');
                        }
                      }
                      draft['options']['types'] = next;
                      _savePreferences(preferences, draft);
                    },
          ),
        const _Section('Customize'),
        _menu(
          Icons.preview_outlined,
          'Notification Preview',
          '/screen/lock-preview',
        ),
        _menu(
          Icons.palette_outlined,
          'Notification Style',
          '/screen/lock-style',
        ),
        _menu(Icons.tune_rounded, 'Media Controls', '/screen/lock-controls'),
        _menu(
          Icons.shield_outlined,
          'Privacy Options',
          '/screen/lock-privacy',
        ),
        _menu(
          Icons.bedtime_outlined,
          'Quiet Hours',
          '/screen/lock-quiet-hours',
        ),
        _menu(
          Icons.vibration_rounded,
          'Sound & Vibration',
          '/screen/lock-sound-vibration',
        ),
        _menu(
          Icons.do_not_disturb_on_outlined,
          'Do Not Disturb',
          '/screen/lock-do-not-disturb',
        ),
        _menu(
          Icons.history_rounded,
          'Notification History',
          '/screen/lock-history',
        ),
        _menu(
          Icons.settings_suggest_outlined,
          'Advanced',
          '/screen/lock-advanced',
        ),
      ],
    );
  }

  Map<String, dynamic> _prefsDraft(NotificationPreferences preferences) {
    final options = {...preferences.options};
    for (final field in ['types', 'summary_days', 'summary_include']) {
      options[field] = List.of(options[field] as List);
    }
    return {
      for (final key in [
        'new_episodes',
        'push_enabled',
        'quiet_hours_start',
        'quiet_hours_end',
        'timezone',
      ])
        key: preferences.data[key],
      'options': options,
    };
  }

  Widget _preview(BuildContext context) {
    final feed = ref.watch(notificationPreferencesProvider);
    final downloads = ref.watch(libraryDownloadsProvider);
    String subtitle = 'No sample alert yet.';
    String? artwork;
    final newEpisodeAsync = ref.watch(aiRecommendationsProvider);
    // Prefer downloads title as sample content when feed is empty of episodes.
    if (downloads.hasValue && downloads.requireValue.isNotEmpty) {
      subtitle = downloads.requireValue.first.title;
      artwork = downloads.requireValue.first.artworkUrl;
    }
    return AccountFeedPanel(
      feed: AccountFeed.newEpisode,
      builder: (state) {
        if (!state.loading && state.items.isNotEmpty) {
          subtitle = state.items.first.title;
          artwork = state.items.first.artwork;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _lockFrame(
              context,
              title: 'New Episode Out Now!',
              subtitle: subtitle,
              artworkUrl: artwork,
              asset: 'assets/podcast/episode_124.png',
              icon: Icons.podcasts_rounded,
              color: PelevoColors.red,
              onTap: () {},
            ),
            const _Section('Preview Background'),
            _choiceChips(
              const ['Default', 'Blur', 'Color', 'None'],
              _previewBackground,
              (value) => setState(() => _previewBackground = value),
            ),
            const _Section('Text Size'),
            Slider(
              value: _widgetSize.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged:
                  (value) => setState(() => _widgetSize = value.round()),
            ),
            if (feed.hasError || newEpisodeAsync.hasError)
              const SizedBox.shrink(),
            PelevoButton(
              label: 'Save Preview',
              color: PelevoColors.green,
              onPressed: () {
                context.showPelevoMessage(
                  'Preview appearance is local chrome and is not saved to the server.',
                );
                context.go('/screen/lock-settings');
              },
            ),
          ],
        );
      },
    );
  }

  Widget _notificationStyle(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Style choices are local chrome. The OS lock-screen layout is not controlled by Pelevo yet.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      for (var i = 0; i < 3; i++)
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: i,
          groupValue: _style,
          activeColor: PelevoColors.green,
          secondary: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              const [
                Icons.view_agenda_outlined,
                Icons.featured_play_list_outlined,
                Icons.hide_source_rounded,
              ][i],
              color: PelevoColors.green,
            ),
          ),
          title: Text(const ['Compact', 'Detailed', 'Rich Media'][i]),
          subtitle: Text(
            const [
              'Show title and app icon only',
              'Show title, message and episode artwork',
              'Show large artwork with controls',
            ][i],
          ),
          onChanged: (value) => setState(() => _style = value!),
        ),
      _switch(
        'Show Expiry',
        'Display expiration on lock screen',
        Icons.timer_outlined,
        _option('Show Expiry', true),
        (value) => _setOption('Show Expiry', value),
      ),
      _switch(
        'Show Progress Bar',
        'Show download and playback progress',
        Icons.linear_scale_rounded,
        _option('Show Progress Bar', true),
        (value) => _setOption('Show Progress Bar', value),
      ),
      PelevoButton(
        label: 'Save Style',
        onPressed: () {
          context.showPelevoMessage(_unavailable('Lock-screen style'));
          context.go('/screen/lock-settings');
        },
      ),
    ],
  );

  Widget _controls(BuildContext context) {
    final handler = pelevoAudioHandler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _miniPlayer(context),
        const _Section('Controls'),
        for (final item in const [
          ('Show Play/Pause', Icons.play_circle_outline_rounded),
          ('Show Next/Previous', Icons.skip_next_rounded),
          ('Show Progress Bar', Icons.linear_scale_rounded),
          ('Show Episode Info', Icons.info_outline_rounded),
        ])
          _switch(
            item.$1,
            null,
            item.$2,
            _option(item.$1, true),
            (value) => _setOption(item.$1, value),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.replay_30_rounded, color: PelevoColors.green),
          ),
          title: const Text('Skip Interval'),
          subtitle: Text('${handler?.skipSeconds ?? 30} seconds'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            final current = handler?.skipSeconds ?? 30;
            final next = current >= 30 ? 10 : current + 10;
            handler?.skipSeconds = next;
            setState(() {});
          },
        ),
        PelevoButton(
          label: 'Save Controls',
          onPressed: () {
            context.showPelevoMessage(
              'Media-session skip interval is ${handler?.skipSeconds ?? 30}s on this device',
            );
            context.go('/screen/lock-settings');
          },
        ),
      ],
    );
  }

  Widget _privacyOptions(BuildContext context) {
    final async = ref.watch(notificationLockRulesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(notificationLockRulesProvider),
      );
    }
    final rules = async.requireValue;
    final selected =
        _options.containsKey('privacy_ready') ? _privacy : rules.privacyIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            profileFailure(_error!).message,
            style: const TextStyle(color: PelevoColors.red),
          ),
        for (var i = 0; i < 3; i++)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: i,
            groupValue: selected,
            activeColor: PelevoColors.green,
            title: Text(
              const ['Hide Content', 'Show Title Only', 'Show All Details'][i],
            ),
            subtitle: Text(
              const [
                'Hide all notification content when locked',
                'Show only episode title and app name',
                'Show full episode details and artwork',
              ][i],
            ),
            onChanged:
                _saving
                    ? null
                    : (value) => setState(() {
                      _privacy = value!;
                      _options['privacy_ready'] = true;
                    }),
          ),
        _switch(
          'Require Face ID to Show',
          'Biometric unlock is controlled by the OS, not this API.',
          Icons.face_retouching_natural,
          _faceId,
          (value) {
            setState(() => _faceId = value);
            context.showPelevoMessage(_unavailable('Face ID lock privacy'));
          },
        ),
        PelevoButton(
          label: 'Save Privacy',
          onPressed:
              _saving
                  ? null
                  : () async {
                    setState(() {
                      _saving = true;
                      _error = null;
                    });
                    try {
                      await ref
                          .read(notificationLockRulesRepositoryProvider)
                          .save(
                            NotificationLockRules.fromPrivacyIndex(selected),
                          );
                      if (!context.mounted) return;
                      ref.invalidate(notificationLockRulesProvider);
                      context.showPelevoMessage('Lock-screen privacy saved');
                      context.go('/screen/lock-settings');
                    } on Object catch (error) {
                      if (context.mounted) setState(() => _error = error);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
        ),
      ],
    );
  }

  Widget _quietHours(BuildContext context) {
    final async = ref.watch(notificationPreferencesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(notificationPreferencesProvider),
      );
    }
    final preferences = async.requireValue;
    final start = preferences.data['quiet_hours_start'] as String?;
    final end = preferences.data['quiet_hours_end'] as String?;
    final highPriority =
        preferences.options['high_priority_only'] as bool? ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(),
        Text(
          'Quiet hours use ${preferences.data['timezone']}. Day chips below are visual only; the API stores a start/end pair, not per-day quiet windows.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        if (_error != null)
          Text(
            profileFailure(_error!).message,
            style: const TextStyle(color: PelevoColors.red),
          ),
        _switch(
          'Quiet Hours',
          null,
          Icons.bedtime_outlined,
          start != null && end != null,
          _saving
              ? (_) {}
              : (value) async {
                final draft = _prefsDraft(preferences);
                if (!value) {
                  draft['quiet_hours_start'] = null;
                  draft['quiet_hours_end'] = null;
                  await _savePreferences(preferences, draft);
                  return;
                }
                final nextStart = await _pickTime(start);
                if (nextStart == null || !mounted) return;
                final nextEnd = await _pickTime(end);
                if (nextEnd == null || !mounted) return;
                draft['quiet_hours_start'] = nextStart;
                draft['quiet_hours_end'] = nextEnd;
                await _savePreferences(preferences, draft);
              },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('From'),
          trailing: Text(start ?? 'Not set'),
          onTap:
              _saving
                  ? null
                  : () async {
                    final next = await _pickTime(start);
                    if (next == null || !mounted) return;
                    final draft = _prefsDraft(preferences);
                    draft['quiet_hours_start'] = next;
                    draft['quiet_hours_end'] =
                        draft['quiet_hours_end'] ?? end ?? next;
                    await _savePreferences(preferences, draft);
                  },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('To'),
          trailing: Text(end ?? 'Not set'),
          onTap:
              _saving
                  ? null
                  : () async {
                    final next = await _pickTime(end);
                    if (next == null || !mounted) return;
                    final draft = _prefsDraft(preferences);
                    draft['quiet_hours_end'] = next;
                    draft['quiet_hours_start'] =
                        draft['quiet_hours_start'] ?? start ?? next;
                    await _savePreferences(preferences, draft);
                  },
        ),
        const _Section('Days'),
        _choiceChips(
          const ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
          _quietDay,
          (value) => setState(() => _quietDay = value),
        ),
        _switch(
          'Allow Important Alerts',
          'Maps to high-priority-only preference',
          Icons.priority_high_rounded,
          highPriority,
          _saving
              ? (_) {}
              : (value) {
                final draft = _prefsDraft(preferences);
                draft['options']['high_priority_only'] = value;
                _savePreferences(preferences, draft);
              },
        ),
        PelevoButton(
          label: 'Save Quiet Hours',
          onPressed: () => context.go('/screen/lock-settings'),
        ),
      ],
    );
  }

  Widget _soundVibration(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Pelevo creates Android notification channels. Exact sounds and vibration patterns are finalized in system settings.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      _switch(
        'Play Sound',
        'Used for local lock alerts',
        Icons.volume_up_outlined,
        _sound,
        (value) => setState(() => _sound = value),
      ),
      _menu(
        Icons.music_note_rounded,
        'Sound',
        null,
        subtitle: 'Open system notification settings',
      ),
      _switch(
        'Vibration',
        null,
        Icons.vibration_rounded,
        _vibrate,
        (value) => setState(() => _vibrate = value),
      ),
      PelevoButton(
        label: 'Open System Notification Settings',
        onPressed: () => PelevoLocalNotifications.openSystemNotificationSettings(),
      ),
      PelevoButton(
        label: 'Save Sound Settings',
        onPressed: () async {
          await PelevoLocalNotifications.showAlert(
            id: 42,
            title: 'Pelevo alert preview',
            body: 'Sound=${_sound ? 'on' : 'off'}, vibration=${_vibrate ? 'on' : 'off'}',
            playSound: _sound,
            vibrate: _vibrate,
          );
          if (context.mounted) {
            context.showPelevoMessage('Preview posted to the system shade');
            context.go('/screen/lock-settings');
          }
        },
      ),
    ],
  );

  Widget _doNotDisturb(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PelevoSpacing.lg),
      const Icon(Icons.bedtime_rounded, size: 72, color: Color(0xFF9C6ADE)),
      const SizedBox(height: PelevoSpacing.md),
      Text(
        'Respect your focus',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(
        'Do Not Disturb is controlled by the OS. Pelevo cannot change system DND from this screen.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const _Section('Allow Notifications'),
      for (final item in const ['From Favorites', 'Live Shows', 'Downloads'])
        _switch(
          item,
          null,
          Icons.check_circle_outline_rounded,
          _option(item, false),
          (value) => _setOption(item, value),
        ),
      _switch(
        'Normal Alerts',
        'Other alerts will be silenced',
        Icons.notifications_off_outlined,
        _option('Normal Alerts', false),
        (value) => _setOption('Normal Alerts', value),
      ),
      PelevoButton(
        label: 'Save Do Not Disturb',
        onPressed: () {
          context.showPelevoMessage(_unavailable('Do Not Disturb'));
          context.go('/screen/lock-settings');
        },
      ),
    ],
  );

  Widget _history(BuildContext context) => AccountFeedPanel(
    feed: AccountFeed.history,
    builder: (state) {
      if (state.loading && state.items.isEmpty) {
        return const CatalogStatusBody();
      }
      if (state.error != null && state.items.isEmpty) {
        return CatalogStatusBody(error: state.error, retry: state.refresh);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review stored inbox history. This is not an OS lock-screen log.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
          if (state.items.isEmpty)
            Text(
              'No notification history yet.',
              style: TextStyle(color: context.pelevo.textMuted),
            )
          else
            for (final item in state.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.notifications_outlined,
                    color: PelevoColors.green,
                  ),
                ),
                title: Text(item.title),
                subtitle: Text(
                  [
                    item.body,
                    _lockStamp(item.createdAt),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    () => context.showPelevoMessage(
                      'Inbox items do not include lock-screen deep links yet.',
                    ),
              ),
          const SizedBox(height: PelevoSpacing.xl),
          PelevoButton(
            label: 'Clear History',
            color: PelevoColors.red,
            onPressed:
                state.busy
                    ? null
                    : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (dialogContext) => AlertDialog(
                              title: const Text('Clear history?'),
                              content: const Text(
                                'This archives the current inbox after server confirmation.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(dialogContext, true),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref
                            .read(accountFeedRepositoryProvider)
                            .clear();
                        if (!context.mounted) return;
                        context.showPelevoMessage('History cleared');
                        await state.refresh();
                      } on Object catch (error) {
                        if (context.mounted) {
                          context.showPelevoMessage(
                            profileFailure(error).message,
                          );
                        }
                      }
                    },
          ),
        ],
      );
    },
  );

  Widget _snooze(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Schedule a local reminder that can appear on the lock screen.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (final item in const [
        ('Snooze for 15 minutes', Duration(minutes: 15)),
        ('Snooze for 1 hour', Duration(hours: 1)),
        ('Snooze until tonight', Duration(hours: 8)),
        ('Snooze until tomorrow', Duration(hours: 24)),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.snooze_rounded, color: PelevoColors.green),
          ),
          title: Text(item.$1),
          onTap: () async {
            await PelevoLocalNotifications.snooze(
              id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
              title: 'Pelevo reminder',
              body: 'Your snoozed listening reminder is ready.',
              delay: item.$2,
            );
            if (context.mounted) {
              context.showPelevoMessage('${item.$1} scheduled');
              context.go('/screen/lock-settings');
            }
          },
        ),
      TextButton(
        onPressed: () async {
          await PelevoLocalNotifications.cancelAll();
          if (context.mounted) {
            context.showPelevoMessage('Scheduled local reminders cleared');
          }
        },
        child: const Text('Turn off all for now'),
      ),
    ],
  );

  Widget _rules(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Conditional If/Then delivery rules are not offered. Privacy uses /notification-lock-rules.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      const TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'If',
          hintText: 'Not available',
          suffixIcon: Icon(Icons.expand_more_rounded),
        ),
      ),
      const SizedBox(height: PelevoSpacing.md),
      const TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Then',
          hintText: 'Not available',
          suffixIcon: Icon(Icons.expand_more_rounded),
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Add New Rule',
        icon: Icons.add_rounded,
        onPressed: () => context.showPelevoMessage(_unavailable('Custom rules')),
      ),
    ],
  );

  Widget _widgetSettings(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _miniPlayer(context),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Widget Size',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      _choiceChips(
        const ['Small', 'Medium', 'Large'],
        _widgetSize,
        (value) => setState(() => _widgetSize = value),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Add Widget',
        color: PelevoColors.green,
        onPressed: () => context.showPelevoMessage(_unavailable('Lock-screen widgets')),
      ),
    ],
  );

  Widget _focus(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Focus modes are owned by the OS. Pelevo cannot change them from this screen.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (final item in const [
        ('Work', 'Alert episodes by favorites', Icons.work_outline_rounded),
        ('Driving', 'Auto play + fewer alerts', Icons.directions_car_outlined),
        ('Sleep', 'Silence notifications', Icons.bedtime_outlined),
      ])
        _switch(
          item.$1,
          item.$2,
          item.$3,
          _option(item.$1, false),
          (value) => _setOption(item.$1, value),
        ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Manage Focus Modes',
        onPressed: () => context.showPelevoMessage(_unavailable('Focus modes')),
      ),
    ],
  );

  Widget _analytics(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _metricHero(
        context,
        '—',
        'Total Notifications',
        Icons.bar_chart_rounded,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        'Notification open, dismiss and snooze rates are not available from the API.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'View Details',
        onPressed: () => context.go('/screen/notifications-12'),
      ),
    ],
  );

  Widget _advanced(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Artwork and publisher detail toggles are local chrome until lock presentation APIs exist.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.md),
      for (final item in const [
        ('Show Episode Artwork', Icons.album_outlined),
        ('Show Publisher Name', Icons.person_outline_rounded),
        ('Show Episode Duration', Icons.schedule_rounded),
        ('Show Release Date', Icons.calendar_today_outlined),
      ])
        _switch(
          item.$1,
          null,
          item.$2,
          _option(item.$1, true),
          (value) => _setOption(item.$1, value),
        ),
      _switch(
        'Show Episode Description',
        null,
        Icons.subject_rounded,
        _option('Show Episode Description', false),
        (value) => _setOption('Show Episode Description', value),
      ),
      const _Section('More'),
      _menu(Icons.snooze_rounded, 'Snooze Notifications', '/screen/lock-snooze'),
      _menu(Icons.rule_rounded, 'Custom Rules', '/screen/lock-custom-rules'),
      _menu(
        Icons.widgets_outlined,
        'Lock Screen Widget',
        '/screen/lock-widget',
      ),
      _menu(
        Icons.center_focus_strong,
        'Focus Integration',
        '/screen/lock-focus',
      ),
      _menu(Icons.analytics_outlined, 'Analytics', '/screen/lock-analytics'),
      _menu(Icons.help_outline_rounded, 'About & Help', '/screen/lock-about'),
      const SizedBox(height: PelevoSpacing.lg),
      OutlinedButton(
        onPressed:
            () => context.showPelevoMessage(
              'There is no lock-defaults reset endpoint.',
            ),
        style: OutlinedButton.styleFrom(foregroundColor: PelevoColors.red),
        child: const Text('Reset to Defaults'),
      ),
    ],
  );

  Widget _about(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PelevoSpacing.xl),
      const Icon(
        Icons.notifications_active_rounded,
        size: 72,
        color: PelevoColors.red,
      ),
      const SizedBox(height: PelevoSpacing.md),
      Text(
        'Pelevo protects your privacy and gives you control.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      _menu(
        Icons.school_outlined,
        'Learn more',
        null,
        subtitle: 'How lock screen alerts work',
      ),
      _menu(
        Icons.policy_outlined,
        'Privacy Policy',
        '/legal/privacy',
        subtitle: 'Published privacy document',
      ),
      _menu(
        Icons.support_agent_rounded,
        'Help Center',
        '/screen/profile-help',
        subtitle: 'Get help and support',
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'App Permissions',
        onPressed: () => context.go('/screen/permissions-intro'),
      ),
    ],
  );

  Widget _lockFrame(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? artworkUrl,
    required String asset,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final now = DateTime.now();
    return Container(
      constraints: const BoxConstraints(minHeight: 390),
      padding: const EdgeInsets.all(PelevoSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .28), const Color(0xFF070807)],
        ),
        border: Border.all(color: context.pelevo.border),
      ),
      child: Column(
        children: [
          Text(
            _lockClock(now),
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300),
          ),
          Text(
            _lockDate(now),
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.xl),
          Material(
            color: context.pelevo.surfaceHigh.withValues(alpha: .92),
            borderRadius: PelevoRadii.card,
            child: InkWell(
              borderRadius: PelevoRadii.card,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(PelevoSpacing.sm),
                child: Row(
                  children: [
                    CatalogArtwork(
                      url: artworkUrl,
                      width: 58,
                      height: 58,
                      radius: 8,
                      assetPath: asset,
                    ),
                    const SizedBox(width: PelevoSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color, size: 17),
                              const SizedBox(width: PelevoSpacing.xs),
                              const Text('Pelevo', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.pelevo.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 120),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.flashlight_on_outlined),
              Text(
                'Swipe up to unlock',
                style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
              ),
              Icon(Icons.camera_alt_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPlayer(BuildContext context) {
    final async = ref.watch(libraryRecentProvider);
    final item =
        async.hasValue && async.requireValue.isNotEmpty
            ? async.requireValue.first
            : null;
    return Card(
      color: context.pelevo.surface,
      child: Padding(
        padding: const EdgeInsets.all(PelevoSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                CatalogArtwork(
                  url: item?.artworkUrl,
                  width: 48,
                  height: 48,
                  radius: 8,
                  assetPath: 'assets/podcast/episode_124.png',
                ),
                const SizedBox(width: PelevoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item?.title ?? 'Nothing playing',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        item?.showTitle ?? 'No recent episode',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed:
                      () => context.showPelevoMessage(
                        _unavailable('Media-session skip'),
                      ),
                  icon: const Icon(Icons.replay_10_rounded),
                ),
                IconButton(
                  onPressed:
                      item == null
                          ? () => context.showPelevoMessage(
                            'Nothing in recents to play.',
                          )
                          : () {
                            openCatalogEpisode(
                              context,
                              episodeId: item.id,
                              showId: item.showId,
                            );
                            context.go('/screen/player-now-playing');
                          },
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 42),
                ),
                IconButton(
                  onPressed:
                      () => context.showPelevoMessage(
                        _unavailable('Media-session skip'),
                      ),
                  icon: const Icon(Icons.forward_30_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(
    String title,
    String? subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: SizedBox(
      width: 42,
      height: 42,
      child: Icon(icon, color: PelevoColors.green, size: 22),
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: value,
    activeColor: PelevoColors.green,
    onChanged: onChanged,
  );

  Widget _menu(
    IconData icon,
    String title,
    String? route, {
    String? subtitle,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 42,
      height: 42,
      child: Icon(icon, color: PelevoColors.green, size: 22),
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap:
        route == null
            ? () async {
              if (title == 'Learn more') {
                context.showPelevoMessage(
                  'Lock-screen alert docs are not published in the mobile CMS yet.',
                );
                return;
              }
              if (title == 'Sound') {
                await PelevoLocalNotifications.openSystemNotificationSettings();
                return;
              }
              context.showPelevoMessage(_unavailable(title));
            }
            : () => context.go(route),
  );

  Widget _choiceChips(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => Wrap(
    spacing: PelevoSpacing.sm,
    children: [
      for (var i = 0; i < labels.length; i++)
        ChoiceChip(
          label: Text(labels[i]),
          selected: selected == i,
          onSelected: (_) => onSelected(i),
        ),
    ],
  );

  Widget _metricHero(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.lg),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: PelevoColors.green, size: 36),
        const SizedBox(width: PelevoSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: TextStyle(color: context.pelevo.textMuted)),
          ],
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.lg,
      bottom: PelevoSpacing.sm,
    ),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}
