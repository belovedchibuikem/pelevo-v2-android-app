import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/notifications/firebase_push.dart';
import 'package:pelevo/features/notifications/local_notifications.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:pelevo/features/profile/account_feed.dart';

export 'package:pelevo/features/notifications/push_token_repository.dart';

/// Enables OS notifications, registers the FCM token, and mirrors unread inbox
/// items onto the lock-visible notification shade.
class LockNotificationBootstrap {
  LockNotificationBootstrap(this._ref);
  final Ref _ref;

  Future<String> enable() async {
    final owner = _ref.read(authSessionProvider).userId;
    if (owner == null) {
      return 'Sign in to register lock-screen alerts.';
    }

    final firebaseMessage =
        await _ref.read(pelevoFirebasePushProvider).bootstrap();

    try {
      final page = await _ref
          .read(accountFeedRepositoryProvider)
          .page(AccountFeed.unread);
      var shown = 0;
      for (final item in page.items.take(5)) {
        await PelevoLocalNotifications.showAlert(
          id: item.id.hashCode & 0x7fffffff,
          title: item.title,
          body: item.body,
          payload: PelevoNotificationRouter.encodePayload({
            if (item.type != null) 'type': item.type,
            if (item.episodeId != null) 'episode_id': item.episodeId,
            if (item.showId != null) 'show_id': item.showId,
          }),
        );
        shown += 1;
      }
      final mirror =
          shown == 0
              ? 'No unread in-app alerts to mirror yet.'
              : 'Posted $shown unread alert(s) to the system shade.';
      return '$firebaseMessage $mirror';
    } on Object catch (error) {
      return '$firebaseMessage ${profileish(error)}';
    }
  }

  String profileish(Object error) =>
      error is ApiFailure ? error.message : 'Could not mirror inbox alerts.';
}

final lockNotificationBootstrapProvider = Provider(
  (ref) => LockNotificationBootstrap(ref),
);
