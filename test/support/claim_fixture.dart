Map<String, dynamic> claimShowFixture({
  String id = 'show-1',
  String title = 'Owned Show',
  bool claimedByViewer = false,
}) => {
  'id': id,
  'title': title,
  'author': 'Ada',
  'artwork_url': null,
  'description': 'A real catalog show.',
  'language': 'en',
  'country_code': null,
  'explicit': null,
  'episodes_count': 2,
  'follower_count': 0,
  'rating_average': null,
  'rating_count': 0,
  'following': false,
  'notifications_enabled': false,
  'claimed_by_viewer': claimedByViewer,
  'categories': const <Map<String, dynamic>>[],
};

Map<String, dynamic> claimStartFixture({
  String method = 'email',
  String claimId = 'claim-1',
}) => {
  'claim_id': claimId,
  'state': 'pending',
  'masked_destination': method == 'email' ? 'o****@example.com' : null,
  'challenge': method == 'description' ? 'PELEVO-VERIFY-TESTTOKEN12' : null,
  'expires_at': '2026-09-24T00:00:00Z',
  'challenge_expires_at': '2026-09-10T01:15:00Z',
};

Map<String, dynamic> claimStatusFixture({
  String state = 'pending',
  String method = 'email',
}) => {
  'id': 'claim-1',
  'show_id': 'show-1',
  'method': method,
  'state': state,
  'destination_masked': method == 'email' ? 'o****@example.com' : null,
  'attempts': 0,
  'max_attempts': 5,
  'challenge_expires_at': '2026-09-10T01:15:00Z',
};
