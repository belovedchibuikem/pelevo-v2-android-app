import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/earn/earn_catalog_data.dart';
import 'package:pelevo/features/earn/earn_wallet_data.dart';
import 'package:pelevo/features/profile/invite_data.dart';
import '../support/api_adapter.dart';
import '../support/earn_fixture.dart';

void main() {
  test('catalog parses public show and episode fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      return jsonResponse(switch (request.path) {
        '/earn/shows' => earnShowsFixture(),
        '/earn/episodes' => earnEpisodesFixture(),
        _ => throw StateError(request.path),
      });
    });
    final catalog = await EarnCatalogRepository(dio).catalog();
    expect(catalog.shows.first.title, 'The Honest Bunch');
    expect(catalog.shows.first.episodeCount, 2);
    expect(
      catalog.episodes.singleWhere((item) => item.id == 'earn-mindset-1').title,
      'Train Your Mind Daily',
    );
    expect(
      EarnShow.fromApi({...earnShowFixture(), 'rss_url': 'secret'}).title,
      'The Honest Bunch',
    );
  });

  test('session start heartbeat and complete stay on public fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse(
        switch (request.path) {
          '/earn/episodes/earn-mindset-1/sessions' => earnSessionFixture(),
          '/earn/sessions/session-1/heartbeat' => {'accepted': true},
          '/earn/sessions/session-1/complete' => earnAwardFixture(),
          _ => throw StateError(request.path),
        },
        status:
            request.path.endsWith('/complete') ||
                    request.path.endsWith('/sessions')
                ? 201
                : 200,
      );
    });
    final repository = EarnCatalogRepository(dio);
    final started = await repository.start('earn-mindset-1');
    expect(started.nonce.length, 64);
    expect(started.expectedAward, 2);
    final heartbeat = await repository.heartbeat(
      sessionId: started.id,
      position: 20,
      sequence: 1,
      elapsedSeconds: 20,
      mediaDurationSeconds: 1080,
      nonce: started.nonce,
      integrityToken: 'token',
    );
    expect(heartbeat.award, isNull);
    expect(seen.path, '/earn/sessions/session-1/heartbeat');
    expect((seen.data as Map<String, dynamic>)['media_duration_seconds'], 1080);
    final award = await repository.complete(
      sessionId: started.id,
      idempotencyKey: 'earn-once',
    );
    expect(award.coins, 2);
    expect('${seen.headers['Idempotency-Key']}', contains('earn-once'));
  });

  test(
    'payout methods and withdrawals reject private fields and reuse idempotency',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
      addTearDown(() => dio.close(force: true));
      late RequestOptions seen;
      dio.httpClientAdapter = ApiAdapter((request) {
        seen = request;
        if (request.path == '/payout-methods' && request.method == 'POST') {
          return jsonResponse(earnPayoutMethodFixture(), status: 201);
        }
        if (request.path == '/payout-methods') {
          return jsonResponse([earnPayoutMethodFixture()]);
        }
        return jsonResponse(earnWithdrawalFixture(), status: 201);
      });
      final repository = EarnWalletRepository(dio);
      final methods = await repository.payoutMethods(CancelToken());
      expect(methods.single.verified, isTrue);
      expect(methods.single.destinationLabel, '•••• 6789');
      final created = await repository.createPayoutMethod(
        provider: 'flutterwave',
        kind: 'bank',
        destination: {'account_number': '0123456789', 'bank_code': '058'},
      );
      expect(created.provider, 'flutterwave');
      final receipt = await repository.submitWithdrawal(
        payoutMethodId: created.id,
        coins: BigInt.from(1250),
        idempotencyKey: 'withdraw-once',
      );
      expect(receipt.coins, BigInt.from(1250));
      expect(receipt.state, 'queued');
      expect('${seen.headers['Idempotency-Key']}', contains('withdraw-once'));
      expect(
        () => EarnPayoutMethod.parse({
          'id': 'method-1',
          'provider': 'flutterwave',
          'destination_encrypted': 'secret',
        }),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test('invite requires owner and does not invent a code', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      return jsonResponse(
        inviteFixture(code: request.method == 'POST' ? 'ROTATEDCODE' : null),
        status: request.method == 'POST' ? 201 : 200,
      );
    });
    final repository = InviteRepository(dio);
    final empty = await repository.current('test-user', CancelToken());
    expect(empty.code, isNull);
    expect(empty.shareLink, isEmpty);
    final created = await repository.create('test-user', CancelToken());
    expect(created.code, 'ROTATEDCODE');
    expect(created.shareLink, 'pelevo://invite/ROTATEDCODE');
    expect(
      () => UserInvite.fromApi(inviteFixture(owner: 'other'), 'test-user'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
