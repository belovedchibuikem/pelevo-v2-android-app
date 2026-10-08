Map<String, dynamic> giftWalletFixture({int balance = 100}) => {
  'unit': 'PCN',
  'balance': balance,
};

Map<String, dynamic> giftPackFixture({
  String id = 'pack-1200',
  String store = 'apple',
  String productId = 'pelevo_coins_1200',
  int coins = 1200,
}) => {
  'id': id,
  'store': store,
  'product_id': productId,
  'coins': coins,
  'unit': 'PCN',
};

Map<String, dynamic> giftTypeFixture({
  String id = 'gift-applause',
  String slug = 'applause',
  String name = 'Applause',
  int coins = 100,
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'coins': coins,
  'version': 1,
};

Map<String, dynamic> giftActivityFixture({
  String id = 'entry-1',
  String eventType = 'iap.verified',
  int amount = 1200,
}) => {
  'id': id,
  'event_type': eventType,
  'amount': amount,
  'unit': 'PCN',
  'created_at': '2026-09-10T00:00:00Z',
};

Map<String, dynamic> giftReceiptFixture({
  String id = 'gift-1',
  String name = 'Applause',
  int coins = 100,
  String creator = 'Studio Owner',
  int remaining = 50,
}) => {
  'id': id,
  'gift_type_id': 'gift-applause',
  'gift_type_name': name,
  'coins': coins,
  'creator_profile_id': 'creator-1',
  'creator_display_name': creator,
  'creator_handle': 'studio_owner',
  'message': 'Thank you',
  'remaining_balance': remaining,
  'created_at': '2026-09-10T00:00:00Z',
};

List<Map<String, dynamic>> giftCatalogFixture() => [
  giftTypeFixture(),
  giftTypeFixture(id: 'gift-love', slug: 'love', name: 'Love', coins: 500),
  giftTypeFixture(id: 'gift-star', slug: 'star', name: 'Star', coins: 1000),
  giftTypeFixture(
    id: 'gift-champion',
    slug: 'champion',
    name: 'Champion',
    coins: 5000,
  ),
];

List<Map<String, dynamic>> giftPacksFixture() => [
  giftPackFixture(id: 'pack-500', productId: 'pelevo_coins_500', coins: 500),
  giftPackFixture(),
];
