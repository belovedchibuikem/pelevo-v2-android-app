Map<String, dynamic> giftWalletFixture({int balance = 100}) => {
  'unit': 'PCN',
  'balance': balance,
};

Map<String, dynamic> giftPackFixture({
  String id = 'pack-500',
  String store = 'apple',
  String productId = 'coins_500',
  int coins = 500,
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
  int coins = 300,
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
  int amount = 500,
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
  int coins = 300,
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
  giftTypeFixture(id: 'gift-star', slug: 'star', name: 'Star', coins: 750),
  giftTypeFixture(
    id: 'gift-champion',
    slug: 'champion',
    name: 'Champion',
    coins: 1000,
  ),
  giftTypeFixture(id: 'gift-crown', slug: 'crown', name: 'Crown', coins: 1500),
  giftTypeFixture(
    id: 'gift-legend',
    slug: 'legend',
    name: 'Legend',
    coins: 2000,
  ),
];

List<Map<String, dynamic>> giftPacksFixture() => [
  giftPackFixture(id: 'pack-300', productId: 'coins_300', coins: 300),
  giftPackFixture(),
  giftPackFixture(id: 'pack-750', productId: 'coins_750', coins: 750),
  giftPackFixture(id: 'pack-1000', productId: 'coins_1000', coins: 1000),
  giftPackFixture(id: 'pack-1500', productId: 'coins_1500', coins: 1500),
  giftPackFixture(id: 'pack-2000', productId: 'coins_2000', coins: 2000),
];
