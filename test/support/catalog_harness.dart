import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'api_adapter.dart';
import 'profile_fixture.dart';
import 'cms_fixture.dart';
import 'account_feed_fixture.dart';
import 'claim_fixture.dart';
import 'home_fixture.dart';
import 'studio_fixture.dart';
import 'gift_fixture.dart';
import 'comment_fixture.dart';
import 'reel_fixture.dart';
import 'preferences_fixture.dart';
import 'notification_preferences_fixture.dart';
import 'earn_fixture.dart';
import 'search_fixture.dart';
import 'browse_fixture.dart';
import 'catalog_fixture.dart';
import 'library_fixture.dart';
import 'ai_fixture.dart';
import 'device_sync_fixture.dart';
import 'premium_fixture.dart';
import 'share_card_fixture.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/profile/preferences_data.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Visual/navigation fixtures belong only in test code, never in an app cache.
final navigationFeed = HomeFeed(
  schemaVersion: 2,
  rails: [
    for (final row in const [
      (
        'continue_listening',
        'Continue Listening',
        'Pick up where you left off',
      ),
      ('made_for_you', 'Made For You', 'Personalized episode picks'),
      ('quick_listen', 'Quick Listen', 'Short episodes that fit your time'),
      (
        'because_you_listened',
        'Because You Listened',
        'More from topics you already enjoy',
      ),
      ('trending', 'Trending on Pelevo', 'What listeners are playing now'),
      (
        'new_from_following',
        'New from shows you follow',
        'Fresh episodes from your subscriptions',
      ),
      (
        'african_voices',
        'African Voices',
        'Shows published across the continent',
      ),
      (
        'try_something_new',
        'Try Something New',
        'Topics outside your listening history',
      ),
      ('explore_by_topic', 'Explore by Topic', 'Browse the Pelevo catalog'),
    ])
      HomeRail(
        id: row.$1,
        key: row.$1,
        type: 'episodes',
        title: row.$2,
        subtitle: row.$3,
        items: const [
          HomeItem(id: 'test-episode', type: 'episode', title: 'Test episode'),
        ],
      ),
  ],
);

class CatalogHarness extends StatelessWidget {
  const CatalogHarness({super.key, this.signedIn = false});
  final bool signedIn;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      catalogPreviewProvider.overrideWithValue(true),
      selectedShowIdProvider.overrideWith(CatalogHarnessShowId.new),
      selectedEpisodeIdProvider.overrideWith(CatalogHarnessEpisodeId.new),
      selectedPlaylistIdProvider.overrideWith(CatalogHarnessPlaylistId.new),
      selectedCollectionIdProvider.overrideWith(CatalogHarnessCollectionId.new),
      initialAuthSessionProvider.overrideWithValue(
        const AuthSession(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          deviceId: 'test-device',
          user: {'id': 'test-user', 'name': 'Test user'},
        ),
      ),
      preferencesProvider.overrideWith(
        (ref) async => AccountPreferences.fromApi(preferencesFixture()),
      ),
      packageInfoProvider.overrideWithValue(
        PackageInfo(
          appName: 'Pelevo',
          packageName: 'test.pelevo',
          version: '2.3.4',
          buildNumber: '19',
        ),
      ),
      homeFeedProvider.overrideWith((ref) => Stream.value(navigationFeed)),
      homeDiscoverProvider.overrideWith(
        (ref) async => HomeDiscoverPage.fromApi(homeDiscoverFixture()),
      ),
      homeChartsProvider.overrideWith(
        (ref) async => HomeChartsPage.fromApi(homeChartsFixture()),
      ),
      homePlaylistsProvider.overrideWith(
        (ref) async => HomePlaylistsPage.fromApi(homePlaylistsFixture()),
      ),
      homeRailProvider.overrideWith((ref, request) async {
        return navigationFeed.rails.firstWhere(
          (rail) => rail.key == request.key,
          orElse:
              () => HomeRail(
                id: request.key,
                key: request.key,
                type: 'episodes',
                title: request.key,
                items: const [],
              ),
        );
      }),
      authSessionStoreProvider.overrideWithValue(
        const AuthSessionStore(FlutterSecureStorage()),
      ),
      dioProvider.overrideWith((ref) {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
        dio.httpClientAdapter = ApiAdapter((request) {
          if (request.path.startsWith('/cms/')) {
            return jsonResponse(cmsFixture(request.path.split('/').last));
          }
          if (request.path == '/live') {
            return jsonResponse(<Map<String, dynamic>>[]);
          }
          if (request.path == '/me/push-tokens') {
            if (request.method == 'POST') {
              return jsonResponse({
                'registered': true,
                'provider': 'fcm',
                'device_id': 'device-1',
              }, status: 201);
            }
            return jsonResponse({'revoked': true});
          }
          if (request.path == '/me') return jsonResponse(profileFixture());
          if (request.path == '/notification-lock-rules') {
            return jsonResponse({
              'show_title': true,
              'show_body': false,
              'sensitive_hidden': true,
            });
          }
          if (request.path == '/notification-preferences') {
            if (request.method == 'PATCH') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              final version = data['version'];
              return jsonResponse(
                notificationPreferencesFixture(
                  version: version is int ? version + 1 : 1,
                ),
              );
            }
            return jsonResponse(notificationPreferencesFixture());
          }
          if (request.path == '/notifications/clear' &&
              request.method == 'POST') {
            return jsonResponse({'cleared': true, 'count': 0});
          }
          if (request.path == '/notifications') {
            final view = '${request.queryParameters['view'] ?? 'all'}';
            if (view == 'new_episode') {
              return feedResponse([
                notificationFixture(
                  'new-episode',
                  type: 'new_episode',
                  title: 'New episode from The Honest Bunch',
                  body: 'A published episode is available.',
                ),
              ]);
            }
            if (view == 'broadcast') {
              return feedResponse([
                notificationFixture(
                  'broadcast',
                  type: 'broadcast',
                  title: 'Server broadcast navigation',
                  body: 'Stored broadcast navigation',
                ),
              ]);
            }
            return feedResponse([
              notificationFixture('navigation', read: true),
            ]);
          }
          if (request.path == '/me/following') {
            return feedResponse([followedShowFixture('navigation')]);
          }
          if (request.path == '/earn/access') {
            return jsonResponse({'allowed': true, 'country': 'US'});
          }
          if (request.path == '/earn/wallet') {
            return jsonResponse(earnWalletFixture());
          }
          if (request.path == '/earn/shows') {
            return jsonResponse(earnShowsFixture());
          }
          if (request.path == '/earn/episodes') {
            return jsonResponse(earnEpisodesFixture());
          }
          if (RegExp(
            r'^/earn/episodes/[^/]+/sessions$',
          ).hasMatch(request.path)) {
            return jsonResponse(
              earnSessionFixture(episodeId: request.path.split('/')[3]),
              status: 201,
            );
          }
          if (RegExp(
            r'^/earn/sessions/[^/]+/heartbeat$',
          ).hasMatch(request.path)) {
            return jsonResponse({'accepted': true});
          }
          if (RegExp(
            r'^/earn/sessions/[^/]+/complete$',
          ).hasMatch(request.path)) {
            return jsonResponse(earnAwardFixture(), status: 201);
          }
          if (request.path == '/me/invite') {
            return jsonResponse(
              inviteFixture(),
              status: request.method == 'POST' ? 201 : 200,
            );
          }
          if (request.path == '/me/connected-accounts') {
            if (request.method == 'POST') {
              return errorResponse(
                status: 401,
                code: 'SOCIAL_TOKEN_INVALID',
                message: 'The provider token could not be verified.',
              );
            }
            return jsonResponse(
              <Map<String, dynamic>>[],
              meta: {'user_id': 'test-user'},
            );
          }
          if (RegExp(
            r'^/me/connected-accounts/[^/]+$',
          ).hasMatch(request.path)) {
            return jsonResponse({'disconnected': true});
          }
          if (request.path == '/withdrawals') {
            if (request.method == 'POST') {
              return jsonResponse(earnWithdrawalFixture(), status: 201);
            }
            return jsonResponse(
              <Map<String, dynamic>>[],
              meta: {'user_id': 'test-user', 'cursor': null, 'has_more': false},
            );
          }
          if (request.path == '/home/discover') {
            return jsonResponse(homeDiscoverFixture());
          }
          if (request.path == '/home/charts') {
            return jsonResponse(homeChartsFixture());
          }
          if (request.path == '/home/playlists') {
            return jsonResponse(homePlaylistsFixture());
          }
          if (request.path.startsWith('/home/rails/')) {
            final key = request.path.split('/').last;
            final matches = navigationFeed.rails.where(
              (item) => item.key == key,
            );
            if (matches.isEmpty) {
              return jsonResponse(null, status: 404);
            }
            return jsonResponse(homeRailFixture(matches.first));
          }
          if (request.path == '/studio') {
            return jsonResponse(studioProfileFixture());
          }
          if (request.path == '/studio/shows') {
            return jsonResponse([studioShowFixture()]);
          }
          if (request.path == '/studio/episodes') {
            if (request.method == 'POST') {
              return jsonResponse(studioEpisodeDraftFixture(), status: 201);
            }
            return jsonResponse([studioEpisodeFixture()]);
          }
          if (RegExp(r'^/studio/episodes/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(studioEpisodeFixture());
          }
          if (request.path == '/studio/reels') {
            return jsonResponse([studioReelFixture()]);
          }
          if (RegExp(r'^/studio/reels/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(studioReelFixture());
          }
          if (request.path == '/studio/audience') {
            return jsonResponse(studioAudienceFixture());
          }
          if (request.path == '/studio/audience/followers') {
            return jsonResponse([studioFollowerFixture()]);
          }
          if (request.path == '/studio/audience/supporters') {
            return jsonResponse(
              [studioSupporterFixture()],
              meta: {
                'supporters_count': 1,
                'coins_received': 100,
                'has_more': false,
              },
            );
          }
          if (request.path == '/studio/monetization') {
            return jsonResponse(studioMonetizationFixture());
          }
          if (request.path == '/studio/payout-settings') {
            return jsonResponse(studioPayoutSettingsFixture());
          }
          if (request.path == '/studio/live') {
            return jsonResponse(
              studioLiveFixture(state: 'scheduled'),
              status: 201,
            );
          }
          if (RegExp(r'^/studio/live/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(studioLiveFixture());
          }
          if (request.path == '/payout-methods') {
            if (request.method == 'POST') {
              final provider =
                  request.data is Map
                      ? '${request.data['provider']}'
                      : 'flutterwave';
              return jsonResponse(
                provider == 'paypal'
                    ? earnPayoutMethodFixture(
                      provider: 'paypal',
                      kind: 'paypal',
                      label: 'PayPal',
                      lastFour: '.com',
                    )
                    : earnPayoutMethodFixture(),
                status: 201,
              );
            }
            return jsonResponse(<Map<String, dynamic>>[]);
          }
          if (request.path == '/studio/transactions') {
            return jsonResponse([studioTransactionFixture()]);
          }
          if (RegExp(r'^/studio/transactions/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(studioTransactionFixture());
          }
          if (request.path == '/studios') {
            return jsonResponse(studioTeamFixture());
          }
          if (request.path == '/reels/for-you') {
            return jsonResponse([publishedReelFixture()]);
          }
          if (request.path == '/reels/following') {
            return jsonResponse([
              publishedReelFixture(
                id: 'reel-follow',
                caption: 'Following reel caption.',
                following: true,
              ),
            ]);
          }
          if (request.path == '/reels/trending') {
            return jsonResponse([
              publishedReelFixture(
                id: 'reel-trend',
                caption: 'Trending reel caption.',
              ),
            ]);
          }
          if (request.path == '/reels/saved') {
            return jsonResponse([
              publishedReelFixture(
                id: 'reel-saved',
                caption: 'Saved reel caption.',
              ),
            ]);
          }
          if (request.path == '/reels/monetization') {
            return jsonResponse(reelMonetizationFixture());
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
          if (RegExp(r'^/reels/[^/]+/related-show$').hasMatch(request.path)) {
            return jsonResponse(reelRelatedShowFixture());
          }
          if (RegExp(r'^/reels/[^/]+/like$').hasMatch(request.path)) {
            return jsonResponse({
              'liked': request.method == 'POST',
              'saved': false,
              'not_interested': false,
            });
          }
          if (RegExp(r'^/reels/[^/]+/save$').hasMatch(request.path)) {
            return jsonResponse({
              'liked': false,
              'saved': request.method == 'POST',
              'not_interested': false,
            });
          }
          if (RegExp(r'^/reels/[^/]+/not-interested$').hasMatch(request.path)) {
            return jsonResponse({
              'liked': false,
              'saved': false,
              'not_interested': true,
            });
          }
          if (RegExp(r'^/creators/[^/]+/follow$').hasMatch(request.path)) {
            return jsonResponse({
              'following': request.method == 'POST',
            }, status: request.method == 'POST' ? 201 : 200);
          }
          if (request.path == '/reels/drafts') {
            if (request.method == 'POST') {
              return jsonResponse(reelDraftFixture(), status: 201);
            }
            return jsonResponse(<Map<String, dynamic>>[]);
          }
          if (RegExp(r'^/reels/drafts/[^/]+$').hasMatch(request.path)) {
            if (request.method == 'DELETE') {
              return jsonResponse({'deleted': true});
            }
            return jsonResponse(
              reelDraftFixture(id: request.path.split('/').last),
            );
          }
          if (request.path == '/gifts/wallet') {
            return jsonResponse(giftWalletFixture());
          }
          if (request.path == '/gifts/wallet/activity') {
            return jsonResponse([giftActivityFixture()]);
          }
          if (request.path == '/gifts/packs') {
            return jsonResponse(giftPacksFixture());
          }
          if (request.path == '/gifts/catalog') {
            return jsonResponse(giftCatalogFixture());
          }
          if (request.path == '/gifts/send') {
            return errorResponse(
              status: 503,
              code: 'SERVICE_DEGRADED',
              message: 'Gifts are awaiting finance sign-off.',
            );
          }
          if (RegExp(r'^/gifts/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(
              giftReceiptFixture(id: request.path.split('/').last),
            );
          }
          if (request.path == '/iap/verify') {
            return errorResponse(
              status: 503,
              code: 'SERVICE_DEGRADED',
              message: 'Financial purchases are awaiting finance sign-off.',
            );
          }
          if (request.path == '/comments') {
            if (request.method == 'POST') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                commentFixture(
                  id: 'posted-1',
                  body: '${data['body'] ?? ''}',
                  authorName: 'Test user',
                  authorHandle: 'test_user',
                  isMine: true,
                  parentId: data['parent_id'] as String?,
                ),
                status: 201,
              );
            }
            final type = '${request.queryParameters['commentable_type']}';
            return jsonResponse(
              type == 'reel' ? reelCommentsFixture() : episodeCommentsFixture(),
            );
          }
          if (request.path == '/reports') {
            return jsonResponse({
              'id': 'report-1',
              'state': 'open',
            }, status: 201);
          }
          if (request.path == '/browse' ||
              request.path == '/browse/categories') {
            return jsonResponse(browseCategoriesFixture());
          }
          if (request.path == '/browse/music') {
            return jsonResponse(
              browseCategoryPageFixture(
                id: '2',
                name: 'Music',
                slug: 'music',
                shows: [
                  browseShowFixture(id: 'show-music', title: 'Lagos Mix'),
                ],
              ),
            );
          }
          if (RegExp(r'^/browse/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(browseCategoryPageFixture());
          }
          if (request.path == '/search/recent') {
            if (request.method == 'DELETE') {
              return jsonResponse({'cleared': true});
            }
            if (request.method == 'POST') {
              return jsonResponse({'saved': true}, status: 201);
            }
            return jsonResponse([recentSearchFixture()]);
          }
          if (request.path == '/search/voice') {
            final transcript =
                request.data is Map ? '${request.data['transcript']}' : '';
            return jsonResponse(searchPageFixture(query: transcript));
          }
          if (request.path == '/search') {
            final query = '${request.queryParameters['q'] ?? ''}';
            if (query.contains('unknown')) {
              return jsonResponse(
                searchPageFixture(
                  query: query,
                  shows: const [],
                  episodes: const [],
                  playlists: const [],
                ),
              );
            }
            return jsonResponse({
              ...searchPageFixture(query: query.isEmpty ? 'Owned' : query),
              'shows': [claimShowFixture()],
            });
          }
          if (request.path == '/directory/search') {
            return jsonResponse({
              'query': '${request.queryParameters['q'] ?? ''}',
              'candidates': const <Map<String, dynamic>>[],
            });
          }
          if (RegExp(r'^/shows/[^/]+/follow$').hasMatch(request.path)) {
            return jsonResponse({'following': request.method != 'DELETE'});
          }
          if (RegExp(r'^/shows/[^/]+/claims$').hasMatch(request.path)) {
            final method =
                request.data is Map ? '${request.data['method']}' : 'email';
            return jsonResponse(claimStartFixture(method: method), status: 201);
          }
          if (RegExp(r'^/shows/[^/]+/related$').hasMatch(request.path)) {
            return jsonResponse([catalogRelatedShowFixture()]);
          }
          if (RegExp(r'^/shows/[^/]+/reviews$').hasMatch(request.path)) {
            if (request.method == 'POST') {
              return jsonResponse(catalogReviewFixture(), status: 201);
            }
            return jsonResponse([catalogReviewFixture()]);
          }
          if (RegExp(r'^/shows/[^/]+/notifications$').hasMatch(request.path)) {
            return jsonResponse({
              'notifications_enabled':
                  request.data is Map ? request.data['enabled'] == true : false,
            });
          }
          if (RegExp(r'^/shows/[^/]+/episodes$').hasMatch(request.path)) {
            final showId = request.path.split('/')[2];
            if (showId == catalogShowId) {
              return jsonResponse(
                catalogEpisodesFixture(),
                meta: {
                  'cursor': null,
                  'has_more': false,
                  'episodes_syncing': false,
                },
              );
            }
            return jsonResponse(
              [
                {
                  'id': 'ep-1',
                  'show_id': showId,
                  'title': 'Fresh episode',
                  'description': null,
                  'artwork_url': null,
                  'duration_seconds': 600,
                  'published_at': '2026-09-09T00:00:00Z',
                  'show_title': 'Show',
                  'show_author': 'Host',
                },
              ],
              meta: {
                'cursor': null,
                'has_more': false,
                'episodes_syncing': false,
              },
            );
          }
          if (RegExp(r'^/shows/[^/]+$').hasMatch(request.path)) {
            final showId = request.path.split('/')[2];
            if (showId == catalogShowId) {
              return jsonResponse(catalogShowFixture());
            }
            return jsonResponse(claimShowFixture(id: showId));
          }
          if (RegExp(r'^/episodes/[^/]+/chapters$').hasMatch(request.path)) {
            return jsonResponse(catalogChaptersFixture());
          }
          if (RegExp(r'^/episodes/[^/]+/transcript$').hasMatch(request.path)) {
            return jsonResponse(catalogTranscriptFixture());
          }
          if (RegExp(r'^/episodes/[^/]+/notes$').hasMatch(request.path)) {
            if (request.method == 'PUT') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                catalogNoteFixture(
                  body: '${data['body'] ?? ''}',
                  version: ((data['version'] as num?)?.toInt() ?? 0) + 1,
                ),
              );
            }
            return jsonResponse(catalogNoteFixture());
          }
          if (RegExp(r'^/episodes/[^/]+/queue$').hasMatch(request.path)) {
            return jsonResponse({'version': 2}, status: 201);
          }
          if (RegExp(r'^/episodes/[^/]+/downloads$').hasMatch(request.path)) {
            return jsonResponse({
              'episode_id': request.path.split('/')[2],
              'url': 'https://cdn.example.invalid/shift-life.mp3',
              'expires_at': '2026-09-10T12:00:00Z',
              'authorization': 'test-download',
            });
          }
          if (RegExp(r'^/episodes/[^/]+$').hasMatch(request.path)) {
            final id = request.path.split('/')[2];
            if (id == catalogEpisodeId || id.startsWith('catalog-')) {
              return jsonResponse(
                catalogEpisodeFixture(id: id, detailed: true),
              );
            }
            return jsonResponse(
              catalogEpisodeFixture(
                id: id,
                showId: 'show-1',
                title: 'Fresh episode',
                showTitle: 'Owned Show',
                detailed: true,
              ),
            );
          }
          if (RegExp(r'^/playback/[^/]+$').hasMatch(request.path)) {
            final id = request.path.split('/')[2];
            if (request.method == 'PUT') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                catalogPlaybackFixture(
                  episodeId: id,
                  position: (data['position_seconds'] as num?)?.toInt() ?? 765,
                  completed: data['completed'] == true,
                  version: ((data['version'] as num?)?.toInt() ?? 0) + 1,
                ),
              );
            }
            return jsonResponse(catalogPlaybackFixture(episodeId: id));
          }
          if (request.path == '/player/session') {
            if (request.method == 'PATCH') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                catalogPlayerSessionFixture(
                  episodeId: data['episode_id'] as String?,
                  playing: data['playing'] == true,
                  rate: (data['playback_rate'] as num?)?.toDouble() ?? 1,
                  version: ((data['version'] as num?)?.toInt() ?? 0) + 1,
                ),
              );
            }
            return jsonResponse(catalogPlayerSessionFixture());
          }
          if (request.path == '/queue') {
            if (request.method == 'PUT') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              final ids = data['episode_ids'];
              return jsonResponse({
                'version': ((data['version'] as num?)?.toInt() ?? 0) + 1,
                'count': ids is List ? ids.length : 0,
              });
            }
            if (request.method == 'DELETE') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse({
                'version': ((data['version'] as num?)?.toInt() ?? 0) + 1,
                'count': 0,
              });
            }
            return jsonResponse(catalogQueueFixture());
          }
          if (request.path == '/queue/reorder') {
            final data =
                request.data is Map
                    ? Map<String, dynamic>.from(request.data as Map)
                    : const <String, dynamic>{};
            final ids = data['episode_ids'];
            return jsonResponse({
              'version': ((data['version'] as num?)?.toInt() ?? 0) + 1,
              'count': ids is List ? ids.length : 0,
            });
          }
          if (RegExp(r'^/queue/items/[^/]+$').hasMatch(request.path)) {
            final data =
                request.data is Map
                    ? Map<String, dynamic>.from(request.data as Map)
                    : const <String, dynamic>{};
            return jsonResponse({
              'version': ((data['version'] as num?)?.toInt() ?? 0) + 1,
            });
          }
          if (request.path == '/stats/me') {
            return jsonResponse(catalogStatsFixture());
          }
          if (request.path == '/library') {
            return jsonResponse(libraryOverviewFixture());
          }
          if (request.path == '/library/saved' ||
              request.path == '/library/liked') {
            return jsonResponse([
              libraryEpisodeFixture(savedAt: '2026-09-09T12:00:00Z'),
            ]);
          }
          if (request.path == '/library/shows') {
            return jsonResponse([libraryShowRowFixture()]);
          }
          if (request.path == '/library/recent') {
            return jsonResponse([catalogRecentEpisodeFixture()]);
          }
          if (request.path == '/library/settings') {
            if (request.method == 'PATCH') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                librarySettingsFixture(
                  hideCompleted: data['hide_completed'] == true,
                  sort: '${data['sort'] ?? 'recent'}',
                  version: ((data['version'] as num?)?.toInt() ?? 0) + 1,
                ),
              );
            }
            return jsonResponse(librarySettingsFixture());
          }
          if (request.path == '/playlists') {
            if (request.method == 'POST') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                libraryPlaylistFixture(
                  id: 'library-playlist-created',
                  name: '${data['name'] ?? 'Playlist'}',
                  itemCount: 0,
                ),
                status: 201,
              );
            }
            return jsonResponse([libraryPlaylistFixture()]);
          }
          if (RegExp(r'^/playlists/[^/]+$').hasMatch(request.path)) {
            final id = request.path.split('/').last;
            if (request.method == 'DELETE') {
              return jsonResponse({'deleted': true});
            }
            if (request.method == 'PUT') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                libraryPlaylistFixture(
                  id: id,
                  name: '${data['name'] ?? 'Mindset & Growth'}',
                  detailed: true,
                ),
              );
            }
            return jsonResponse(libraryPlaylistFixture(id: id, detailed: true));
          }
          if (request.path == '/collections') {
            if (request.method == 'POST') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                libraryCollectionFixture(
                  id: 'library-collection-created',
                  name: '${data['name'] ?? 'Collection'}',
                  itemCount: 0,
                ),
                status: 201,
              );
            }
            return jsonResponse([libraryCollectionFixture()]);
          }
          if (RegExp(r'^/collections/[^/]+$').hasMatch(request.path)) {
            final id = request.path.split('/').last;
            if (request.method == 'DELETE') {
              return jsonResponse({'deleted': true});
            }
            return jsonResponse(
              libraryCollectionFixture(id: id, detailed: true),
            );
          }
          if (request.path == '/downloads/settings') {
            if (request.method == 'PATCH') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                downloadSettingsFixture(
                  wifiOnly: data['wifi_only'] == true,
                  autoDeleteCompleted: data['auto_delete_completed'] == true,
                  maxStorageMb:
                      (data['max_storage_mb'] as num?)?.toInt() ?? 2048,
                  version: ((data['version'] as num?)?.toInt() ?? 0) + 1,
                ),
              );
            }
            return jsonResponse(downloadSettingsFixture());
          }
          if (request.path == '/downloads') {
            return jsonResponse([libraryDownloadFixture()]);
          }
          if (RegExp(r'^/downloads/[^/]+$').hasMatch(request.path) &&
              request.method == 'DELETE') {
            return jsonResponse({'deleted': true});
          }
          if (request.path == '/storage') {
            return jsonResponse(storageUsageFixture());
          }
          if (request.path == '/storage/cache' && request.method == 'DELETE') {
            return jsonResponse({'cleared': true});
          }
          if (request.path == '/devices') {
            return jsonResponse([syncDeviceFixture()]);
          }
          if (request.path == '/devices/pairing-code' &&
              request.method == 'POST') {
            return jsonResponse(pairingCodeFixture(), status: 201);
          }
          if (request.path == '/devices/pair' && request.method == 'POST') {
            return jsonResponse({'paired': true}, status: 201);
          }
          if (request.path == '/devices/sign-out-all' &&
              request.method == 'POST') {
            return jsonResponse({'signed_out': true});
          }
          if (RegExp(r'^/devices/[^/]+$').hasMatch(request.path) &&
              request.method == 'DELETE') {
            return jsonResponse({'revoked': true});
          }
          if (request.path == '/sync/pull') {
            return jsonResponse([syncChangeFixture()]);
          }
          if (request.path == '/sync/conflicts') {
            if (request.method == 'GET') {
              return jsonResponse([syncConflictFixture()]);
            }
          }
          if (RegExp(r'^/sync/conflicts/[^/]+$').hasMatch(request.path) &&
              request.method == 'PUT') {
            return jsonResponse({'resolved': true});
          }
          if (request.path == '/backups' && request.method == 'POST') {
            return jsonResponse({
              'id': 'backup-1',
              'state': 'ready',
              'size_bytes': 12,
            }, status: 201);
          }
          if (RegExp(r'^/backups/[^/]+/restore$').hasMatch(request.path) &&
              request.method == 'POST') {
            return jsonResponse({'restored': true});
          }
          if (request.path == '/premium/plans') {
            return jsonResponse([premiumPlanFixture()]);
          }
          if (request.path == '/premium/me') {
            return jsonResponse(premiumAccountFixture());
          }
          if (request.path == '/premium/invoices') {
            return jsonResponse([premiumInvoiceFixture()]);
          }
          if (request.path == '/premium/exclusive') {
            return jsonResponse([premiumExclusiveFixture()]);
          }
          if ((request.path == '/premium/checkout' ||
                  request.path == '/premium/change-plan') &&
              request.method == 'POST') {
            return jsonResponse(premiumCheckoutFixture(), status: 201);
          }
          if (request.path == '/premium/restore' && request.method == 'POST') {
            return jsonResponse(premiumInvoiceFixture());
          }
          if (request.path == '/home/recommendations') {
            return jsonResponse(aiRecommendationsFixture());
          }
          if (request.path == '/ai/ask' && request.method == 'POST') {
            return jsonResponse(aiAskFixture());
          }
          if (request.path == '/ai/lineup') {
            return jsonResponse(aiLineupFixture());
          }
          if (request.path == '/ai/jobs' && request.method == 'POST') {
            final data =
                request.data is Map
                    ? Map<String, dynamic>.from(request.data as Map)
                    : const <String, dynamic>{};
            return jsonResponse(
              aiJobFixture(type: '${data['type'] ?? 'summary'}'),
              status: 202,
            );
          }
          if (RegExp(r'^/ai/jobs/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(
              aiJobFixture(
                id: request.path.split('/').last,
                state: 'completed',
                outputText: 'Queued jobs return text when complete.',
              ),
            );
          }
          if (request.path == '/share-card-templates') {
            return jsonResponse([shareCardTemplateFixture()]);
          }
          if (request.path == '/share-cards') {
            if (request.method == 'POST') {
              final data =
                  request.data is Map
                      ? Map<String, dynamic>.from(request.data as Map)
                      : const <String, dynamic>{};
              final payload =
                  data['payload'] is Map
                      ? Map<String, dynamic>.from(data['payload'] as Map)
                      : const <String, dynamic>{};
              return jsonResponse(
                shareCardFixture(
                  subjectType: '${data['subject_type'] ?? 'episode'}',
                  subjectId: '${data['subject_id'] ?? catalogEpisodeId}',
                  state: data['scheduled_at'] == null ? 'ready' : 'scheduled',
                  scheduledAt: data['scheduled_at'] as String?,
                  variant: '${payload['variant'] ?? 'qr'}',
                  quote: '${payload['quote'] ?? 'Ep. 124 - The Shift Life'}',
                  layout: '${payload['layout'] ?? 'portrait'}',
                ),
                status: 201,
              );
            }
            return jsonResponse([shareCardFixture()]);
          }
          if (RegExp(r'^/share-cards/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(
              shareCardDetailFixture(id: request.path.split('/').last),
            );
          }
          if (RegExp(r'^/claims/[^/]+/verify$').hasMatch(request.path)) {
            return jsonResponse({'claim_id': 'claim-1', 'state': 'verified'});
          }
          if (RegExp(r'^/claims/[^/]+/challenge$').hasMatch(request.path)) {
            return jsonResponse({
              'claim_id': 'claim-1',
              'masked_destination': 'o****@example.com',
              'challenge_expires_at': '2026-09-10T01:15:00Z',
            }, status: 202);
          }
          if (RegExp(
            r'^/claims/[^/]+/description/confirm$',
          ).hasMatch(request.path)) {
            return jsonResponse({
              'claim_id': 'claim-1',
              'state': 'verifying',
            }, status: 202);
          }
          if (RegExp(r'^/claims/[^/]+$').hasMatch(request.path)) {
            return jsonResponse(claimStatusFixture(state: 'review'));
          }
          if (request.path == '/me/onboarding') {
            return jsonResponse({
              'user_id': 'test-user',
              'onboarded': true,
              'interests': ['News', 'Culture', 'Technology'],
              'locale': 'en',
            });
          }
          if (request.path == '/auth/register') {
            return jsonResponse({
              'verification_required': true,
              'email': 'listener@example.com',
            }, status: 201);
          }
          if (request.path == '/auth/login') {
            return jsonResponse({
              'access_token': 'test-access',
              'refresh_token': 'test-refresh',
              'device_id': 'test-device',
              'user': {'id': 'test-user', 'name': 'Test user'},
            });
          }
          return jsonResponse({'accepted': true});
        });
        ref.onDispose(() => dio.close(force: true));
        return dio;
      }),
    ],
    child: const PelevoApp(),
  );
}
