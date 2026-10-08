import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import '../support/api_adapter.dart';
import '../support/reel_fixture.dart';

void main() {
  test('feed, drafts and monetization parse presented fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/reels/for-you') {
        return jsonResponse([publishedReelFixture(liked: true, likesCount: 2)]);
      }
      if (request.path == '/reels/drafts') {
        if (request.method == 'POST') {
          return jsonResponse(
            reelDraftFixture(caption: '${request.data['caption']}'),
            status: 201,
          );
        }
        return jsonResponse([reelDraftFixture()]);
      }
      if (request.path == '/reels/monetization') {
        return jsonResponse(
          reelMonetizationFixture(followers: 12, qualifiedViews: 40),
        );
      }
      if (request.path == '/reels/monetization/opt-in') {
        return jsonResponse(
          reelMonetizationFixture(
            eligible: true,
            optedIn: true,
            followers: 120,
            qualifiedViews: 2000,
          ),
        );
      }
      if (request.path == '/reels/reel-1/like') {
        return jsonResponse({'liked': true});
      }
      if (request.path == '/reels/reel-1/related-show') {
        return jsonResponse(reelRelatedShowFixture());
      }
      throw StateError(request.path);
    });
    final repository = ReelRepository(dio);

    final feed = await repository.feed(ReelsFeedKind.forYou);
    expect(feed.single.creatorName, 'Ada Creator');
    expect(feed.single.likesCount, 2);
    expect(feed.single.liked, isTrue);
    expect(feed.single.episodeTitle, 'Fresh episode');

    final drafts = await repository.drafts();
    expect(drafts.single.displayTitle, 'Draft reel');

    final saved = await repository.saveDraft(caption: 'New caption');
    expect(saved.caption, 'New caption');
    expect(seen.method, 'POST');

    final money = await repository.monetization();
    expect(money.followers, 12);
    expect(money.minFollowers, 100);
    expect(money.optedIn, isFalse);

    final opted = await repository.optIn();
    expect(opted.optedIn, isTrue);

    await repository.like('reel-1', liked: true);
    final related = await repository.relatedShow('reel-1');
    expect(related.title, 'Owned Show');
  });

  test('creator public profile and reels parse', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      if (request.path == '/creators/creator-1') {
        return jsonResponse({
          'id': 'creator-1',
          'display_name': 'Ada Creator',
          'handle': 'ada_creator',
          'bio': 'African stories on the go.',
          'avatar_url': null,
          'verified': true,
          'is_self': false,
          'following': false,
          'stats': {'followers': 12, 'following': 3, 'reels': 1, 'podcasts': 1},
          'shows': [
            {
              'id': 'show-1',
              'title': 'Ada Daily',
              'author': 'Ada',
              'artwork_url': null,
            },
          ],
        });
      }
      if (request.path == '/creators/creator-1/reels') {
        return jsonResponse([publishedReelFixture()]);
      }
      throw StateError(request.path);
    });
    final repository = ReelRepository(dio);
    final profile = await repository.creatorProfile('creator-1');
    expect(profile.displayName, 'Ada Creator');
    expect(profile.verified, isTrue);
    expect(profile.reelsCount, 1);
    expect(profile.shows.single.title, 'Ada Daily');
    final reels = await repository.creatorReels('creator-1');
    expect(reels.single.creatorName, 'Ada Creator');
  });

  test('published reel presentation rejects missing creator name', () {
    expect(
      () => PublishedReel.fromApi({
        'id': 'reel-1',
        'creator_profile_id': 'creator-1',
        'likes_count': 0,
        'comments_count': 0,
        'saves_count': 0,
        'liked': false,
        'saved': false,
        'following': false,
      }),
      throwsA(isA<ApiFailure>()),
    );
  });

  test(
    'reel heartbeat gate sends at most once per interval and while in flight',
    () {
      final gate = ReelHeartbeatGate();
      expect(gate.allow('reel-1', 0), isTrue);
      expect(gate.allow('reel-1', 2000), isFalse);
      gate.done('reel-1');
      expect(gate.allow('reel-1', 2000), isFalse);
      expect(gate.allow('reel-1', ReelHeartbeatGate.intervalMs), isTrue);
      gate.done('reel-1');
      expect(
        gate.allow(
          'reel-1',
          ReelHeartbeatGate.intervalMs + 500,
          completed: true,
        ),
        isTrue,
      );
      gate.done('reel-1');
      expect(
        gate.allow(
          'reel-1',
          ReelHeartbeatGate.intervalMs + 750,
          completed: true,
        ),
        isFalse,
      );
    },
  );

  test('heartbeat sends playback evidence and parses ad slot', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    final seen = <RequestOptions>[];
    dio.httpClientAdapter = ApiAdapter((request) {
      seen.add(request);
      if (request.path == '/reels/reel-1/view-heartbeat') {
        return jsonResponse({
          'server_watched_ms': 30000,
          'is_valid_view': true,
          'ad_due': {
            'ad_impression_id': 'imp-1',
            'expires_at': '2026-09-30T12:10:00Z',
            'ad_unit_key': 'reels_native_android',
            'format': 'native_advanced',
          },
        });
      }
      if (request.path == '/reels/ad-impressions/imp-1/watched') {
        return jsonResponse({'status': 'watched'});
      }
      if (request.path == '/reels/ad-impressions/imp-1/bounce') {
        return jsonResponse({'status': 'bounced'});
      }
      throw StateError(request.path);
    });
    final repository = ReelRepository(dio);

    final result = await repository.heartbeat(
      'reel-1',
      sessionId: 'view-1',
      feedSessionId: 'feed-1',
      sequence: 3,
      playbackPositionMs: 24000,
      completed: false,
      appForeground: true,
      audible: true,
      adEligible: true,
    );
    expect(seen.single.data, {
      'session_id': 'view-1',
      'feed_session_id': 'feed-1',
      'sequence': 3,
      'playback_position_ms': 24000,
      'completed': false,
      'app_foreground': true,
      'audible': true,
      'ad_eligible': true,
    });
    expect(result.serverWatchedMs, 30000);
    expect(result.isValidView, isTrue);
    expect(result.adDue?.impressionId, 'imp-1');
    expect(result.adDue?.adUnitKey, 'reels_native_android');

    await repository.confirmAdImpression(
      result.adDue!,
      feedSessionId: 'feed-1',
      clientEventId: 'evt-1',
    );
    expect(seen.last.data, {
      'feed_session_id': 'feed-1',
      'client_event_id': 'evt-1',
    });

    await repository.bounceAdImpression(
      result.adDue!,
      feedSessionId: 'feed-1',
      reason: 'load_failed',
    );
    expect(seen.last.data, {
      'feed_session_id': 'feed-1',
      'reason': 'load_failed',
    });
  });

  test('heartbeat without ad slot returns null ad', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => jsonResponse({
        'server_watched_ms': 8000,
        'is_valid_view': false,
        'ad_due': null,
      }),
    );

    final result = await ReelRepository(dio).heartbeat(
      'reel-1',
      sessionId: 'view-1',
      feedSessionId: 'feed-1',
      sequence: 1,
      playbackPositionMs: 8000,
      completed: false,
      appForeground: true,
      audible: true,
      adEligible: true,
    );
    expect(result.isValidView, isFalse);
    expect(result.adDue, isNull);
  });

  test('heartbeat gate numbers sequences per reel', () {
    final gate = ReelHeartbeatGate();
    expect(gate.feedSessionId, isNotEmpty);
    expect(gate.nextSequence('reel-1'), 1);
    expect(gate.nextSequence('reel-1'), 2);
    expect(gate.nextSequence('reel-2'), 1);
  });
}
