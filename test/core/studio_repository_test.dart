import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import '../support/api_adapter.dart';
import '../support/studio_fixture.dart';

void main() {
  test('workspace parses studio, list envelopes and audience only', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse(switch (request.path) {
        '/studio' => studioProfileFixture(),
        '/studio/shows' => [studioShowFixture()],
        '/studio/episodes' => [studioEpisodeFixture()],
        '/studio/audience' => studioAudienceFixture(),
        '/studios' => studioTeamFixture(),
        _ => throw StateError(request.path),
      });
    });

    final workspace = await StudioRepository(dio).workspace();
    expect(workspace.profile.displayName, 'Studio Owner');
    expect(workspace.primaryShow?.title, 'Owned Show');
    expect(workspace.primaryShow?.episodeCount, 2);
    expect(workspace.primaryShow?.followerCount, 4);
    expect(workspace.episodes.single.title, 'Fresh episode');
    expect(workspace.audience.listeners30d, 7);
    expect(workspace.audience.followers, 4);
    expect(workspace.audience.showFollowers, 3);
    expect(workspace.teamStudioCount, 1);
    expect(seen.path, '/studios');
  });

  test(
    'monetization, transactions, payouts and audience lists parse server fields only',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
      addTearDown(() => dio.close(force: true));
      late RequestOptions seen;
      dio.httpClientAdapter = ApiAdapter((request) {
        seen = request;
        return jsonResponse(
          switch (request.path) {
            '/studio/monetization' => studioMonetizationFixture(),
            '/studio/transactions' => [studioTransactionFixture()],
            '/studio/transactions/txn-1' => studioTransactionFixture(),
            '/studio/payout-settings' => studioPayoutSettingsFixture(),
            '/payout-methods' => [studioPayoutMethodFixture()],
            '/studio/audience/followers' => [studioFollowerFixture()],
            '/studio/audience/supporters' => [studioSupporterFixture()],
            _ => throw StateError(request.path),
          },
          meta:
              request.path == '/studio/audience/supporters'
                  ? {'supporters_count': 1, 'coins_received': 100}
                  : const {},
        );
      });
      final repository = StudioRepository(dio);

      final money = await repository.monetization();
      expect(money.giftsReceived, 1);
      expect(money.payoutsCount, 0);
      expect(money.primaryBalance?.balance, 90);
      expect(money.gifts.balance, 300);
      expect(money.gifts.moneyLabel, '\$0.38 USD');
      expect(money.taxProfiles.single.countryCode, 'NG');

      final page = await repository.transactions(
        filter: StudioTransactionFilter.gifts,
      );
      expect(page.items.single.title, 'Gift from Listener Ada');
      expect(page.items.single.amountLabel, '+90 PCN');
      expect(seen.queryParameters['kind'], 'gifts');

      final detail = await repository.transaction('txn-1');
      expect(detail.message, 'Thank you');
      expect(seen.path, '/studio/transactions/txn-1');

      final payout = await repository.payoutWorkspace();
      expect(payout.config.currency, 'NGN');
      expect(payout.selectedMethod?.label, 'Access Bank');
      expect(payout.taxProfile?.countryCode, 'NG');

      final followers = await repository.followers();
      expect(followers.items.single.name, 'Listener Ada');
      expect(followers.items.single.handleLabel, '@ada_listener');

      final supporters = await repository.supporters();
      expect(supporters.items.single.subtitle, '100 coins · 1 gifts');
      expect(supporters.coinsReceived, 100);
    },
  );

  test(
    'payout method post sends provider destination without inventing success',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
      addTearDown(() => dio.close(force: true));
      late RequestOptions seen;
      dio.httpClientAdapter = ApiAdapter((request) {
        seen = request;
        return jsonResponse(studioPayoutMethodFixture(), status: 201);
      });

      final method = await StudioRepository(dio).createPayoutMethod(
        provider: 'flutterwave',
        kind: 'bank',
        destination: {'account_number': '0123456789', 'bank_code': '044'},
      );
      expect(method.id, 'method-1');
      expect(seen.path, '/payout-methods');
      expect(seen.method, 'POST');
      expect(seen.data, {
        'provider': 'flutterwave',
        'kind': 'bank',
        'destination': {'account_number': '0123456789', 'bank_code': '044'},
      });
    },
  );

  test('workspace rejects invented profile and list shapes', () {
    expect(
      () => StudioProfile.fromApi({'accepted': true}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioAudience.fromApi({'followers': 1}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioMonetization.fromApi({'gifts_received': 1}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioTransaction.fromJson({
        'title': 'Gift from BlessedP',
        'amount': '+ ₦5,000.00',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioShow.fromJson({'title': 'The Relationship Podcast'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioEpisode.fromJson({'title': 'Ep 42: The conversation'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => StudioReel.fromJson({'caption': 'I can’t believe she said this!'}),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('reels list and detail parse server fields only', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/studio/reels/reel-1') {
        return jsonResponse(studioReelFixture());
      }
      if (request.path == '/studio/reels') {
        return jsonResponse([studioReelFixture()]);
      }
      throw StateError(request.path);
    });
    final repository = StudioRepository(dio);

    final page = await repository.reels(filter: StudioReelFilter.linked);
    expect(page.items.single.title, 'Studio reel');
    expect(page.items.single.linked, isTrue);
    expect(page.items.single.subtitle, 'Linked to Fresh episode · 2026-09-09');
    expect(page.items.single.statusLabel, 'Published');
    expect(seen.queryParameters['linked'], 1);

    final drafts = await repository.reels(filter: StudioReelFilter.drafts);
    expect(drafts.items.single.id, 'reel-1');
    expect(seen.queryParameters['state'], 'draft');

    final detail = await repository.reel('reel-1');
    expect(detail.episodeTitle, 'Fresh episode');
    expect(seen.path, '/studio/reels/reel-1');
  });

  test('episodes list and detail parse server fields only', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/studio/episodes/ep-1') {
        return jsonResponse(studioEpisodeFixture());
      }
      if (request.path == '/studio/episodes') {
        return jsonResponse([studioEpisodeFixture()]);
      }
      throw StateError(request.path);
    });
    final repository = StudioRepository(dio);

    final page = await repository.episodes();
    expect(page.items.single.title, 'Fresh episode');
    expect(page.items.single.durationSeconds, 1256);
    expect(page.items.single.availability, 'available');
    expect(page.items.single.subtitle, '2026-09-09 · 20:56');
    expect(page.items.single.statusLabel, 'Published');
    expect(seen.queryParameters['limit'], 50);

    final detail = await repository.episode('ep-1');
    expect(detail.id, 'ep-1');
    expect(detail.showTitle, 'Owned Show');
    expect(seen.path, '/studio/episodes/ep-1');
  });

  test('reel draft posts caption and claimed episode id', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse(
        studioReelDraftFixture(caption: 'Draft reel'),
        status: 201,
      );
    });

    final draft = await StudioRepository(
      dio,
    ).saveReelDraft(caption: 'Draft reel', episodeId: 'ep-1', showId: 'show-1');
    expect(draft.id, 'draft-1');
    expect(draft.state, 'draft');
    expect(seen.path, '/reels/drafts');
    expect(seen.method, 'POST');
    expect(seen.data, {
      'caption': 'Draft reel',
      'episode_id': 'ep-1',
      'show_id': 'show-1',
    });
  });

  test('missing verified claim stays CLAIM_REQUIRED', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter(
      (_) => errorResponse(
        status: 403,
        code: 'CLAIM_REQUIRED',
        message: 'A verified show claim is required.',
      ),
    );

    await expectLater(
      StudioRepository(dio).workspace(),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.code,
          'code',
          'CLAIM_REQUIRED',
        ),
      ),
    );
  });

  test(
    'episode draft, live start and payout slices post server fields only',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
      addTearDown(() => dio.close(force: true));
      final seen = <RequestOptions>[];
      dio.httpClientAdapter = ApiAdapter((request) {
        seen.add(request);
        if (request.path == '/studio/episodes') {
          return jsonResponse(studioEpisodeDraftFixture(), status: 201);
        }
        if (request.path == '/studio/live') {
          return jsonResponse(
            studioLiveFixture(state: 'scheduled'),
            status: 201,
          );
        }
        if (request.path == '/studio/live/live-1') {
          return jsonResponse(studioLiveFixture());
        }
        if (request.path == '/studio/payout-settings') {
          if (request.method == 'PUT') {
            return jsonResponse(studioPayoutSettingsFixture());
          }
          return jsonResponse(studioPayoutSettingsFixture());
        }
        if (request.path == '/payout-methods') {
          return jsonResponse([studioPayoutMethodFixture()]);
        }
        if (request.path == '/studio/monetization') {
          return jsonResponse(studioMonetizationFixture());
        }
        throw StateError('${request.method} ${request.path}');
      });
      final repository = StudioRepository(dio);

      final draft = await repository.createEpisodeDraft(
        showId: 'show-1',
        title: 'Studio draft',
        description: 'Draft notes',
      );
      expect(draft.availability, 'draft');
      expect(draft.statusLabel, 'Draft');
      expect(seen.first.path, '/studio/episodes');
      expect(seen.first.data['title'], 'Studio draft');

      final live = await repository.startLive(
        title: 'Studio live',
        showId: 'show-1',
      );
      expect(live.state, 'live');
      expect(seen[1].path, '/studio/live');
      expect(seen[1].data['title'], 'Studio live');
      expect(seen[2].path, '/studio/live/live-1');
      expect(seen[2].method, 'PATCH');

      final payout = await repository.updatePayoutSettings(
        currency: 'USD',
        schedule: 'weekly',
        minimumAmount: 5000,
      );
      expect(payout.config.currency, 'NGN');
      expect(seen[3].method, 'PUT');
      expect(seen[3].data, {
        'currency': 'USD',
        'schedule': 'weekly',
        'minimum_amount': 5000,
      });
    },
  );
}
