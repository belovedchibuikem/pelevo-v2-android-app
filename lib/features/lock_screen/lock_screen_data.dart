import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/account_feed.dart';

const _invalidLockRules = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Lock-screen privacy rules could not be read. Please retry.',
);

bool _flag(Object? value) {
  if (value is bool) return value;
  if (value == 0 || value == 1) return value == 1;
  throw _invalidLockRules;
}

class NotificationLockRules {
  const NotificationLockRules({
    required this.showTitle,
    required this.showBody,
    required this.sensitiveHidden,
  });

  factory NotificationLockRules.parse(Map<String, dynamic> data) {
    if (data.containsKey('user_id')) throw _invalidLockRules;
    return NotificationLockRules(
      showTitle: _flag(data['show_title']),
      showBody: _flag(data['show_body']),
      sensitiveHidden: _flag(data['sensitive_hidden']),
    );
  }

  final bool showTitle, showBody, sensitiveHidden;

  int get privacyIndex {
    if (!showTitle && !showBody) return 0;
    if (showTitle && !showBody) return 1;
    return 2;
  }

  factory NotificationLockRules.fromPrivacyIndex(int index) => switch (index) {
    0 => const NotificationLockRules(
      showTitle: false,
      showBody: false,
      sensitiveHidden: true,
    ),
    1 => const NotificationLockRules(
      showTitle: true,
      showBody: false,
      sensitiveHidden: true,
    ),
    _ => const NotificationLockRules(
      showTitle: true,
      showBody: true,
      sensitiveHidden: false,
    ),
  };

  Map<String, dynamic> toJson() => {
    'show_title': showTitle,
    'show_body': showBody,
    'sensitive_hidden': sensitiveHidden,
  };
}

class NotificationLockRulesRepository {
  NotificationLockRulesRepository(this.dio);
  final Dio dio;

  Future<NotificationLockRules> load(CancelToken token) async =>
      NotificationLockRules.parse(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/notification-lock-rules',
            cancelToken: token,
          )).data,
        ),
      );

  Future<NotificationLockRules> save(NotificationLockRules rules) async =>
      NotificationLockRules.parse(
        requireApiData(
          (await dio.put<Map<String, dynamic>>(
            '/notification-lock-rules',
            data: rules.toJson(),
          )).data,
        ),
      );
}

final notificationLockRulesRepositoryProvider = Provider(
  (ref) => NotificationLockRulesRepository(ref.watch(dioProvider)),
);

final notificationLockRulesProvider =
    FutureProvider.autoDispose<NotificationLockRules>((ref) async {
      final owner = ref.watch(authSessionProvider.select((s) => s.userId));
      if (owner == null) {
        throw const ApiFailure(
          code: 'UNAUTHENTICATED',
          message: 'Sign in to view lock-screen privacy rules.',
        );
      }
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref.read(notificationLockRulesRepositoryProvider).load(token);
    }, retry: (_, _) => null);

final lockNewEpisodePreviewProvider =
    FutureProvider.autoDispose<AccountFeedItem?>((ref) async {
      final owner = ref.watch(authSessionProvider.select((s) => s.userId));
      if (owner == null) return null;
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final page = await ref
          .read(accountFeedRepositoryProvider)
          .page(AccountFeed.newEpisode, cancel: token);
      return page.items.isEmpty ? null : page.items.first;
    }, retry: (_, _) => null);

class PublicLiveSession {
  const PublicLiveSession({required this.id, required this.title, required this.state});
  final String id, title, state;
}

final publicLiveSessionsProvider =
    FutureProvider.autoDispose<List<PublicLiveSession>>((ref) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final body =
          (await ref.watch(dioProvider).get<Map<String, dynamic>>(
            '/live',
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true || body['data'] is! List) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Live sessions could not be read.',
        );
      }
      return [
        for (final row in body['data'] as List)
          if (row is Map<String, dynamic> &&
              row['id'] is String &&
              row['title'] is String &&
              row['state'] is String)
            PublicLiveSession(
              id: row['id'] as String,
              title: row['title'] as String,
              state: row['state'] as String,
            ),
      ];
    }, retry: (_, _) => null);
