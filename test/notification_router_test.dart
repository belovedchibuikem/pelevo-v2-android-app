import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/notifications/notification_router.dart';

void main() {
  setUp(PelevoNotificationRouter.reset);

  test('builds episode and show destinations from payload data', () {
    expect(
      PelevoNotificationRouter.locationFor({
        'episode_id': 'ep-1',
        'show_id': 'show-1',
        'type': 'new_episode',
      }),
      '/episodes/ep-1?showId=show-1',
    );
    expect(
      PelevoNotificationRouter.locationFor({'episode_id': 'ep-1'}),
      '/episodes/ep-1',
    );
    expect(
      PelevoNotificationRouter.locationFor({'show_id': 'show-1'}),
      '/shows/show-1',
    );
    expect(
      PelevoNotificationRouter.locationFor({'reel_id': 'reel-9'}),
      '/reels/reel-9',
    );
    expect(
      PelevoNotificationRouter.locationFor({
        'type': 'earn_award',
        'coins': '2',
        'episode_id': 'ep-1',
      }),
      '/screen/earn-wallet',
    );
  });

  test('payload taps stay pending so splash can open the episode', () {
    final opened = <String>[];
    PelevoNotificationRouter.openPayload(
      '{"episode_id":"ep-9","show_id":"show-2"}',
    );
    expect(
      PelevoNotificationRouter.consumePending(),
      '/episodes/ep-9?showId=show-2',
    );

    PelevoNotificationRouter.bindGo(opened.add);
    PelevoNotificationRouter.openPayload(
      PelevoNotificationRouter.encodePayload({
        'episode_id': 'ep-9',
        'show_id': 'show-2',
      }),
    );
    expect(opened, ['/episodes/ep-9?showId=show-2']);
    expect(
      PelevoNotificationRouter.consumePending(),
      '/episodes/ep-9?showId=show-2',
    );
  });
}
