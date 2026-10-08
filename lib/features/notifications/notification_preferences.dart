import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';

const notificationTypeLabels = {
  'new_episodes': 'New Episodes',
  'downloads': 'Downloads',
  'reminders': 'Reminders',
  'mentions': 'Mentions',
  'promotions': 'Promotions',
  'achievements': 'Achievements',
};

enum NotificationPreferenceView { settings, filters, scheduled }

const _invalid = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Notification preferences could not be read. Please retry.',
);
bool _isTime(Object? value) =>
    value == null ||
    value is String && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

class NotificationPreferences {
  NotificationPreferences._(this.data);
  final Map<String, dynamic> data;
  String get owner => data['user_id'] as String;
  int get version => data['version'] as int;
  Map<String, dynamic> get options => data['options'] as Map<String, dynamic>;
  factory NotificationPreferences.parse(Map<String, dynamic> data) {
    final options = data['options'];
    if (data['user_id'] is! String ||
        (data['user_id'] as String).isEmpty ||
        data['version'] is! int ||
        data['version'] < 0 ||
        data['push_enabled'] is! bool ||
        data['new_episodes'] is! bool ||
        data['timezone'] is! String ||
        (data['timezone'] as String).isEmpty ||
        ![
          'preferences_only',
          'in_app_policy_enabled',
        ].contains(data['delivery_status']) ||
        options is! Map<String, dynamic> ||
        !_isTime(data['quiet_hours_start']) ||
        !_isTime(data['quiet_hours_end']) ||
        ((data['quiet_hours_start'] == null) !=
            (data['quiet_hours_end'] == null))) {
      throw _invalid;
    }
    for (final field in [
      'in_app_enabled',
      'email_enabled',
      'badge_enabled',
      'high_priority_only',
    ]) {
      if (options[field] is! bool) {
        throw _invalid;
      }
    }
    for (final field in ['types', 'summary_include']) {
      final list = options[field];
      if (list is! List ||
          list.any(
            (item) =>
                item is! String || !notificationTypeLabels.containsKey(item),
          ) ||
          list.toSet().length != list.length) {
        throw _invalid;
      }
    }
    final days = options['summary_days'];
    if (days is! List ||
        days.any((day) => day is! int || day < 0 || day > 6) ||
        days.toSet().length != days.length ||
        !_isTime(options['summary_time'])) {
      throw _invalid;
    }
    return NotificationPreferences._(data);
  }
}

class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this.dio);
  final Dio dio;
  Future<NotificationPreferences> load(CancelToken token) async =>
      NotificationPreferences.parse(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/notification-preferences',
            cancelToken: token,
          )).data,
        ),
      );
  Future<NotificationPreferences> save(
    NotificationPreferences previous,
    Map<String, dynamic> draft,
  ) async {
    final result = NotificationPreferences.parse(
      requireApiData(
        (await dio.patch<Map<String, dynamic>>(
          '/notification-preferences',
          data: {...draft, 'version': previous.version},
        )).data,
      ),
    );
    if (result.owner != previous.owner ||
        result.version != previous.version + 1) {
      throw _invalid;
    }
    return result;
  }
}

final notificationPreferencesRepositoryProvider = Provider(
  (ref) => NotificationPreferencesRepository(ref.watch(dioProvider)),
);
final notificationPreferencesProvider = FutureProvider.autoDispose((ref) async {
  final owner = ref.watch(authSessionProvider.select((s) => s.userId));
  if (owner == null) {
    throw const ApiFailure(
      code: 'UNAUTHENTICATED',
      message: 'Sign in to view notification preferences.',
    );
  }
  final token = CancelToken();
  ref.onDispose(token.cancel);
  final result = await ref
      .read(notificationPreferencesRepositoryProvider)
      .load(token);
  if (result.owner != owner) {
    throw _invalid;
  }
  return result;
}, retry: (_, _) => null);

class NotificationPreferencesContent extends ConsumerWidget {
  const NotificationPreferencesContent({super.key, required this.view});
  final NotificationPreferenceView view;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(notificationPreferencesProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading:
            () => ProfileLoadState(
              retry: () => ref.invalidate(notificationPreferencesProvider),
            ),
        error:
            (error, _) => ProfileLoadState(
              error: error,
              retry: () => ref.invalidate(notificationPreferencesProvider),
            ),
        data:
            (preferences) => _PreferenceEditor(
              key: ValueKey((preferences, view)),
              preferences: preferences,
              view: view,
            ),
      );
}

class _PreferenceEditor extends ConsumerStatefulWidget {
  const _PreferenceEditor({
    super.key,
    required this.preferences,
    required this.view,
  });
  final NotificationPreferences preferences;
  final NotificationPreferenceView view;
  @override
  ConsumerState<_PreferenceEditor> createState() => _PreferenceEditorState();
}

class _PreferenceEditorState extends ConsumerState<_PreferenceEditor> {
  late Map<String, dynamic> draft, options;
  bool saving = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    options = {...widget.preferences.options};
    for (final field in ['types', 'summary_days', 'summary_include']) {
      options[field] = List.of(options[field] as List);
    }
    draft = {
      for (final key in [
        'new_episodes',
        'push_enabled',
        'quiet_hours_start',
        'quiet_hours_end',
        'timezone',
      ])
        key: widget.preferences.data[key],
      'options': options,
    };
  }

  Future<void> save() async {
    if (saving ||
        ref.read(authSessionProvider).userId != widget.preferences.owner) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(notificationPreferencesRepositoryProvider)
          .save(widget.preferences, draft);
      if (!mounted ||
          ref.read(authSessionProvider).userId != widget.preferences.owner) {
        return;
      }
      context.showPelevoMessage('Notification preferences saved');
      ref.invalidate(notificationPreferencesProvider);
    } on Object catch (failure) {
      if (mounted) {
        setState(() => error = failure);
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget toggle(String title, Map<String, dynamic> target, String field, {String? subtitle}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: target[field] as bool,
        activeColor: PelevoColors.green,
        onChanged:
            saving
                ? null
                : (value) {
                  setState(() => target[field] = value);
                  if (widget.view == NotificationPreferenceView.settings) {
                    save();
                  }
                },
      );
  Future<String?> pick(String? current) async {
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

  Future<void> quiet(bool enabled) async {
    if (!enabled) {
      setState(() {
        draft['quiet_hours_start'] = null;
        draft['quiet_hours_end'] = null;
      });
      await save();
      return;
    }
    final start = await pick(draft['quiet_hours_start']);
    if (start == null || !mounted) return;
    final end = await pick(draft['quiet_hours_end']);
    if (end == null || !mounted) return;
    setState(() {
      draft['quiet_hours_start'] = start;
      draft['quiet_hours_end'] = end;
    });
    await save();
  }

  Widget timeTile(String title, Map<String, dynamic> target, String field) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        trailing: Text(target[field] as String? ?? 'Not set'),
        onTap:
            saving
                ? null
                : () async {
                  final time = await pick(target[field]);
                  if (time != null && mounted) {
                    setState(() => target[field] = time);
                    if (widget.view == NotificationPreferenceView.settings) {
                      await save();
                    }
                  }
                },
      );
  Widget types(String field, Iterable<String> keys) => Column(
    children: [
      for (final key in keys)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary:
              field != 'types'
                  ? null
                  : Icon(
                    switch (key) {
                      'new_episodes' => Icons.podcasts_rounded,
                      'downloads' => Icons.download_done_rounded,
                      'reminders' => Icons.notifications_active_rounded,
                      'mentions' => Icons.alternate_email_rounded,
                      'promotions' => Icons.card_giftcard_rounded,
                      _ => Icons.emoji_events_rounded,
                    },
                    color: switch (key) {
                      'new_episodes' || 'promotions' => PelevoColors.orange,
                      'downloads' => PelevoColors.green,
                      'mentions' => const Color(0xFF8B5CF6),
                      _ => PelevoColors.yellow,
                    },
                  ),
          title: Text(notificationTypeLabels[key]!),
          value: (options[field] as List).contains(key),
          activeColor: PelevoColors.green,
          onChanged:
              saving
                  ? null
                  : (value) => setState(() {
                    final values = options[field] as List;
                    value ? values.add(key) : values.remove(key);
                    if (field == 'types') {
                      draft['new_episodes'] = values.contains('new_episodes');
                    }
                  }),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (saving) const LinearProgressIndicator(),
      Text(
        widget.preferences.data['delivery_status'] == 'in_app_policy_enabled'
            ? 'In-app messages respect saved preferences. Quiet-hour delivery waits for the server queue. Email alerts follow the Email Notifications switch, including new episodes, live sessions, broadcasts, and your scheduled summary. Account, support, and payout emails still send. Device push still needs permission on this device.'
            : 'These preferences are saved to your account. Delivery integration is still pending; saving does not enable device push.',
      ),
      Text('Times use ${draft['timezone']}'),
      if (error != null) ...[
        Text(profileFailure(error!).message),
        TextButton(
          onPressed:
              saving
                  ? null
                  : () => ref.invalidate(notificationPreferencesProvider),
          child: const Text('Reload saved preferences'),
        ),
      ],
      if (widget.view == NotificationPreferenceView.settings) ...[
        Text('General', style: Theme.of(context).textTheme.titleLarge),
        toggle('Push Notifications', draft, 'push_enabled'),
        toggle('In-App Notifications', options, 'in_app_enabled'),
        toggle(
          'Email Notifications',
          options,
          'email_enabled',
          subtitle:
              'New episodes, live, broadcasts, and your scheduled summary. Security, support, and payout emails still send.',
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text('Quiet Hours', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Quiet Hours'),
          value: draft['quiet_hours_start'] != null,
          onChanged: saving ? null : quiet,
          activeColor: PelevoColors.green,
        ),
        timeTile('Start Time', draft, 'quiet_hours_start'),
        timeTile('End Time', draft, 'quiet_hours_end'),
        const SizedBox(height: PelevoSpacing.md),
        Text('Advanced', style: Theme.of(context).textTheme.titleLarge),
        toggle('Badge Count', options, 'badge_enabled'),
        for (final entry in [
          ('Notification Filters', 'notifications-2'),
          ('Scheduled Summary', 'notifications-8'),
          ('Notification History', 'notifications-12'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.$1),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: saving ? null : () => context.go('/screen/${entry.$2}'),
          ),
      ] else if (widget.view == NotificationPreferenceView.filters) ...[
        Text('Filter by Type', style: Theme.of(context).textTheme.titleLarge),
        types('types', notificationTypeLabels.keys),
        Text('Priority', style: Theme.of(context).textTheme.titleLarge),
        toggle('High Priority Only', options, 'high_priority_only'),
      ] else ...[
        const Text(
          'Summaries send only while Email Notifications is on, at the time and days you pick.',
        ),
        timeTile('Summary Time', options, 'summary_time'),
        const SizedBox(height: PelevoSpacing.md),
        Text('Days', style: Theme.of(context).textTheme.titleLarge),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 0; day < 7; day++)
              InkWell(
                onTap:
                    saving
                        ? null
                        : () => setState(() {
                          final days = options['summary_days'] as List;
                          days.contains(day) ? days.remove(day) : days.add(day);
                        }),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      (options['summary_days'] as List).contains(day)
                          ? PelevoColors.green
                          : PelevoColors.surfaceHigh,
                  child: Text(const ['S', 'M', 'T', 'W', 'T', 'F', 'S'][day]),
                ),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Text('Include', style: Theme.of(context).textTheme.titleLarge),
        types('summary_include', [
          'new_episodes',
          'downloads',
          'mentions',
          'promotions',
        ]),
      ],
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label:
            saving
                ? 'Saving…'
                : widget.view == NotificationPreferenceView.scheduled
                ? 'Save Schedule'
                : 'Save Preferences',
        color: PelevoColors.green,
        onPressed: saving ? null : save,
      ),
    ],
  );
}
