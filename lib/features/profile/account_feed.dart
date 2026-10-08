import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';

enum AccountFeed { following, all, unread, mentions, history, newEpisode, broadcast }

extension AccountFeedView on AccountFeed {
  String get viewName => switch (this) {
    AccountFeed.following => 'following',
    AccountFeed.all => 'all',
    AccountFeed.unread => 'unread',
    AccountFeed.mentions => 'mentions',
    AccountFeed.history => 'history',
    AccountFeed.newEpisode => 'new_episode',
    AccountFeed.broadcast => 'broadcast',
  };
}

const _invalidFeed = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'The server list could not be read. Please retry.',
);

class AccountFeedItem {
  const AccountFeedItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.artwork,
    this.type,
    this.episodeId,
    this.showId,
    this.reelId,
  });
  final String id, title, body;
  final DateTime createdAt;
  final bool read;
  final String? artwork;
  final String? type;
  final String? episodeId;
  final String? showId;
  final String? reelId;

  bool get hasDestination =>
      (episodeId != null && episodeId!.isNotEmpty) ||
      (showId != null && showId!.isNotEmpty) ||
      (reelId != null && reelId!.isNotEmpty);

  factory AccountFeedItem.parse(Map<String, dynamic> data, bool following) {
    final date = data[following ? 'followed_at' : 'created_at'];
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['title'] is! String ||
        date is! String ||
        DateTime.tryParse(date) == null ||
        (!following && data['body'] is! String) ||
        (!following &&
            (data['type'] is! String || (data['type'] as String).isEmpty)) ||
        (following && data['author'] != null && data['author'] is! String) ||
        (data['artwork_url'] != null && data['artwork_url'] is! String) ||
        (!following &&
            data['read_at'] != null &&
            (data['read_at'] is! String ||
                DateTime.tryParse(data['read_at']) == null))) {
      throw _invalidFeed;
    }
    final payload = _notificationPayload(data);
    return AccountFeedItem(
      id: data['id'],
      title: data['title'],
      body: following ? (data['author'] as String? ?? '') : data['body'],
      createdAt: DateTime.parse(date),
      read: data['read_at'] != null,
      artwork: data['artwork_url'] as String?,
      type: following ? null : data['type'] as String,
      episodeId: payload['episode_id'],
      showId: payload['show_id'],
      reelId: payload['reel_id'],
    );
  }
}

String? _payloadText(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return '$value';
  return null;
}

Map<String, dynamic> _nestedNotificationData(Object? raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

Map<String, String?> _notificationPayload(Map<String, dynamic> data) {
  final nested = _nestedNotificationData(data['data']);
  return {
    'episode_id':
        _payloadText(nested['episode_id']) ?? _payloadText(data['episode_id']),
    'show_id': _payloadText(nested['show_id']) ?? _payloadText(data['show_id']),
    'reel_id':
        _payloadText(nested['reel_id']) ?? _payloadText(data['reel_id']),
  };
}

class AccountFeedPage {
  const AccountFeedPage(this.items, this.cursor, this.unread);
  final List<AccountFeedItem> items;
  final String? cursor;
  final int? unread;
}

class AccountFeedRepository {
  AccountFeedRepository(this.dio);
  final Dio dio;
  Future<AccountFeedPage> page(
    AccountFeed feed, {
    String? cursor,
    CancelToken? cancel,
  }) async {
    final following = feed == AccountFeed.following;
    final response =
        (await dio.get<Map<String, dynamic>>(
          following ? '/me/following' : '/notifications',
          queryParameters: {
            'limit': 20,
            if (!following) 'view': feed.viewName,
            if (cursor != null) 'cursor': cursor,
          },
          cancelToken: cancel,
        )).data;
    if (response?['ok'] != true) {
      requireApiData(response);
    }
    final list = response?['data'];
    final meta = response?['meta'];
    if (list is! List ||
        meta is! Map ||
        meta['has_more'] is! bool ||
        (meta['has_more'] == true &&
            (meta['cursor'] is! String ||
                (meta['cursor'] as String).isEmpty)) ||
        (!following &&
            (meta['unread_count'] is! int ||
                (meta['unread_count'] as int) < 0))) {
      throw _invalidFeed;
    }
    final items =
        list.map((item) {
          if (item is! Map<String, dynamic>) {
            throw _invalidFeed;
          }
          return AccountFeedItem.parse(item, following);
        }).toList();
    return AccountFeedPage(
      items,
      meta['has_more'] == true ? meta['cursor'] as String : null,
      following ? null : meta['unread_count'] as int,
    );
  }

  Future<void> unfollow(String id) async {
    final data = requireApiData(
      (await dio.delete<Map<String, dynamic>>(
        '/shows/${Uri.encodeComponent(id)}/follow',
      )).data,
    );
    if (data['following'] != false) {
      throw _invalidFeed;
    }
  }

  Future<void> read(String id) async {
    final data = requireApiData(
      (await dio.put<Map<String, dynamic>>(
        '/notifications/${Uri.encodeComponent(id)}/read',
      )).data,
    );
    if (data['read'] != true) {
      throw _invalidFeed;
    }
  }

  Future<void> bulk(Set<String> ids, String action) async {
    final data = requireApiData(
      (await dio.post<Map<String, dynamic>>(
        '/notifications/bulk',
        data: {'ids': ids.toList(), 'action': action},
      )).data,
    );
    final returned = data['ids'];
    if (data['action'] != action ||
        returned is! List ||
        returned.length != ids.length ||
        returned.toSet().length != ids.length ||
        !ids.containsAll(returned)) {
      throw _invalidFeed;
    }
  }

  Future<void> clear() async {
    final data = requireApiData(
      (await dio.post<Map<String, dynamic>>(
        '/notifications/clear',
        data: {'confirmed': true},
      )).data,
    );
    if (data['cleared'] != true || data['count'] is! int) {
      throw _invalidFeed;
    }
  }
}

final accountFeedRepositoryProvider = Provider(
  (ref) => AccountFeedRepository(ref.watch(dioProvider)),
);

class AccountFeedPanel extends ConsumerWidget {
  const AccountFeedPanel({
    super.key,
    required this.feed,
    required this.builder,
  });
  final AccountFeed feed;
  final Widget Function(AccountFeedPanelState state) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authSessionProvider.select((s) => s.userId));
    if (owner == null) {
      return const Text('Sign in to view this list.');
    }
    return _AccountFeedBody(
      key: ValueKey('$owner:${feed.name}'),
      feed: feed,
      owner: owner,
      builder: builder,
    );
  }
}

class _AccountFeedBody extends ConsumerStatefulWidget {
  const _AccountFeedBody({
    super.key,
    required this.feed,
    required this.owner,
    required this.builder,
  });
  final AccountFeed feed;
  final String owner;
  final Widget Function(AccountFeedPanelState state) builder;
  @override
  ConsumerState<_AccountFeedBody> createState() => AccountFeedPanelState();
}

class AccountFeedPanelState extends ConsumerState<_AccountFeedBody> {
  List<AccountFeedItem> items = [];
  String? cursor;
  int? unread;
  bool loading = true, busy = false;
  bool _hasLoaded = false, _failedAppend = false;
  Object? error;
  final _cancel = CancelToken();
  final _cursors = <String>{};
  @override
  void initState() {
    super.initState();
    _load(false);
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  bool get _valid =>
      mounted && ref.read(authSessionProvider).userId == widget.owner;

  Future<void> refresh() async {
    if (loading || busy) return;
    await _load(false);
  }

  Future<void> more() async {
    if (loading || busy || cursor == null) return;
    await _load(true);
  }

  Future<void> _load(bool append) async {
    _failedAppend = append;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await ref
          .read(accountFeedRepositoryProvider)
          .page(widget.feed, cursor: append ? cursor : null, cancel: _cancel);
      if (!_valid) return;
      if (append &&
          page.cursor != null &&
          (_cursors.contains(page.cursor) || page.cursor == cursor)) {
        throw _invalidFeed;
      }
      setState(() {
        if (!append) {
          _cursors.clear();
        }
        if (cursor != null && append) {
          _cursors.add(cursor!);
        }
        items =
            {
              for (final item in [
                ...(append ? items : <AccountFeedItem>[]),
                ...page.items,
              ])
                item.id: item,
            }.values.toList();
        cursor = page.cursor;
        unread = page.unread;
        _hasLoaded = true;
      });
    } on Object catch (failure) {
      if (_valid) {
        setState(() => error = failure);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<bool> mutate(
    Future<void> Function(AccountFeedRepository repository) action,
    String message,
  ) async {
    if (busy || loading || !_valid) return false;
    setState(() {
      busy = true;
      error = null;
      _failedAppend = false;
    });
    try {
      await action(ref.read(accountFeedRepositoryProvider));
      if (!mounted || !_valid) return false;
      ref.invalidate(profileProvider);
      context.showPelevoMessage(message);
      await _load(false);
      return true;
    } on Object catch (failure) {
      if (_valid) {
        setState(() => error = failure);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading || busy) const LinearProgressIndicator(),
      if (error != null)
        ProfileLoadState(
          error: error,
          retry: () => _failedAppend ? more() : refresh(),
        ),
      if (_hasLoaded) widget.builder(this),
      if (cursor != null)
        OutlinedButton(
          onPressed: loading || busy ? null : more,
          child: const Text('Load more'),
        ),
      TextButton(
        onPressed: loading || busy ? null : refresh,
        child: const Text('Refresh'),
      ),
    ],
  );
}
