Map<String, dynamic> studioProfileFixture({
  String id = 'creator-1',
  String displayName = 'Studio Owner',
}) => {
  'id': id,
  'user_id': 'test-user',
  'display_name': displayName,
  'status': 'active',
};

Map<String, dynamic> studioShowFixture({
  String id = 'show-1',
  String title = 'Owned Show',
}) => {
  'id': id,
  'title': title,
  'author': 'Ada',
  'artwork_url': null,
  'episodes_count': 2,
  'follower_count': 4,
  'updated_at': '2026-09-09T00:00:00Z',
};

Map<String, dynamic> studioEpisodeFixture({
  String id = 'ep-1',
  String title = 'Fresh episode',
}) => {
  'id': id,
  'show_id': 'show-1',
  'title': title,
  'description': 'A published studio episode.',
  'show_title': 'Owned Show',
  'published_at': '2026-09-09T00:00:00Z',
  'artwork_url': null,
  'duration_seconds': 1256,
  'availability': 'available',
};

Map<String, dynamic> studioAudienceFixture({
  int followers = 4,
  int showFollowers = 3,
  int listeners30d = 7,
}) => {
  'followers': followers,
  'show_followers': showFollowers,
  'listeners_30d': listeners30d,
};

Map<String, dynamic> studioReelFixture({
  String id = 'reel-1',
  String caption = 'Studio reel',
  String state = 'published',
}) => {
  'id': id,
  'title': caption,
  'caption': caption,
  'state': state,
  'duration_ms': 12000,
  'published_at': '2026-09-09T00:00:00Z',
  'episode_id': 'ep-1',
  'show_id': 'show-1',
  'media_url': null,
  'episode_title': 'Fresh episode',
  'thumbnail_path': null,
  'linked': 1,
};

Map<String, dynamic> studioReelDraftFixture({
  String id = 'draft-1',
  String caption = 'Draft reel',
}) => {
  'id': id,
  'title': caption,
  'caption': caption,
  'state': 'draft',
  'episode_id': 'ep-1',
  'show_id': 'show-1',
};

List<Map<String, dynamic>> studioTeamFixture() => [
  {'id': 'studio-1', 'name': 'Team', 'role': 'owner'},
];

Map<String, dynamic> studioMonetizationFixture({
  int giftsReceived = 1,
  int payoutsCount = 0,
  int balance = 90,
}) => {
  'gifts_received': giftsReceived,
  'payouts_count': payoutsCount,
  'accounts': [
    {
      'id': 'acct-1',
      'owner_id': 'creator-1',
      'type': 'creator_balance',
      'unit': 'PCN',
      'balance': balance,
    },
  ],
  'ad_revenue_allocations': const <Map<String, dynamic>>[],
  'currency_conversions': const <Map<String, dynamic>>[],
  'tax_profiles': [
    {
      'id': 'tax-1',
      'creator_profile_id': 'creator-1',
      'country_code': 'NG',
      'state': 'pending',
    },
  ],
};

Map<String, dynamic> studioTransactionFixture({
  String id = 'txn-1',
  String reference = 'gift-studio-1',
  String eventType = 'gift.sent',
  int amount = 90,
  String counterpartName = 'Listener Ada',
}) => {
  'id': id,
  'reference': reference,
  'event_type': eventType,
  'created_at': '2026-09-09T10:24:00Z',
  'amount': amount,
  'unit': 'PCN',
  'counterpart_name': counterpartName,
  'counterpart_handle': 'ada_listener',
  'message': 'Thank you',
  'gift_type_name': 'Applause',
  'payout_state': null,
  'payout_label': null,
  'payout_last_four': null,
};

Map<String, dynamic> studioPayoutSettingsFixture() => {
  'settings': {
    'payout_method_id': 'method-1',
    'currency': 'NGN',
    'schedule': 'monthly',
    'minimum_amount': 10000,
    'compliance_state': 'pending',
  },
  'tax_profile': {'id': 'tax-1', 'country_code': 'NG', 'state': 'pending'},
};

Map<String, dynamic> studioPayoutMethodFixture({
  String id = 'method-1',
  String label = 'Access Bank',
}) => {
  'id': id,
  'provider': 'paystack',
  'kind': 'bank',
  'label': label,
  'destination_last_four': '1234',
  'verified_at': '2026-09-09T00:00:00Z',
};

Map<String, dynamic> studioFollowerFixture({
  String id = 'user-ada',
  String name = 'Listener Ada',
}) => {
  'id': id,
  'name': name,
  'handle': 'ada_listener',
  'created_at': '2026-09-09T00:00:00Z',
};

Map<String, dynamic> studioLiveFixture({
  String id = 'live-1',
  String title = 'Studio live',
  String state = 'live',
}) => {
  'id': id,
  'title': title,
  'show_id': 'show-1',
  'state': state,
  'scheduled_at': null,
  'started_at': '2026-09-10T08:00:00Z',
  'ended_at': null,
  'viewer_count': 0,
};

Map<String, dynamic> studioEpisodeDraftFixture({
  String id = 'draft-ep-1',
  String title = 'Studio draft',
}) => {
  'id': id,
  'show_id': 'show-1',
  'title': title,
  'description': 'Draft notes',
  'show_title': 'Owned Show',
  'published_at': null,
  'artwork_url': null,
  'duration_seconds': null,
  'availability': 'draft',
};

Map<String, dynamic> studioSupporterFixture({
  String id = 'user-ada',
  String name = 'Listener Ada',
  int giftsCount = 1,
  int coins = 100,
}) => {
  'id': id,
  'name': name,
  'handle': 'ada_listener',
  'gifts_count': giftsCount,
  'coins': coins,
};
