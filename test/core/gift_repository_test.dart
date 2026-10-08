import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/gifts/gift_data.dart';
import '../support/api_adapter.dart';
import '../support/gift_fixture.dart';

void main() {
  test('wallet packs catalog activity and receipt parse public fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse(switch (request.path) {
        '/gifts/wallet' => giftWalletFixture(),
        '/gifts/packs' => [
          giftPackFixture(),
          giftPackFixture(
            id: 'pack-google',
            store: 'google',
            productId: 'pelevo_coins_1200',
          ),
        ],
        '/gifts/catalog' => giftCatalogFixture(),
        '/gifts/wallet/activity' => [giftActivityFixture()],
        '/gifts/gift-1' => giftReceiptFixture(),
        _ => throw StateError(request.path),
      });
    });
    final repository = GiftRepository(dio);

    final wallet = await repository.wallet();
    expect(wallet.balance, 100);
    expect(wallet.unit, 'PCN');

    final packs = await repository.packs();
    expect(packs, hasLength(1));
    expect(packs.single.coins, 1200);
    expect(packs.single.productId, 'pelevo_coins_1200');

    final catalog = await repository.catalog();
    expect(catalog.map((item) => item.name), ['Applause', 'Love', 'Star', 'Champion']);

    final activity = await repository.activity();
    expect(activity.single.eventType, 'iap.verified');
    expect(activity.single.amount, 1200);

    final receipt = await repository.receipt('gift-1');
    expect(receipt.giftTypeName, 'Applause');
    expect(receipt.creatorDisplayName, 'Studio Owner');
    expect(receipt.remainingBalance, 50);
    expect(seen.path, '/gifts/gift-1');
  });

  test('gift models reject invented money and missing identities', () {
    expect(() => GiftWallet.fromApi({'balance': 1250}), throwsA(isA<ApiFailure>()));
    expect(
      () => GiftWallet.fromApi({'unit': 'NGN', 'balance': 100}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => GiftPack.fromApi({
        'id': 'pack-1',
        'store': 'apple',
        'product_id': 'pelevo_coins_1200',
        'coins': 1200,
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => GiftReceipt.fromApi({
        'gift_type_name': 'Applause',
        'coins': 100,
        'creator_display_name': 'Creator',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });
}
