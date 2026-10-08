// Test-only wire response; never shipped with the app.
Map<String, dynamic> profileFixture({
  String id = 'test-user',
  String name = 'Test listener',
}) => {
  'id': id,
  'name': name,
  'email': 'listener@example.invalid',
  'handle': 'listener',
  'phone': null,
  'country_code': 'NG',
  'profile': {
    'bio': 'A listener biography',
    'avatar_url': null,
    'locale': 'en',
    'timezone': 'Africa/Lagos',
  },
  'capabilities': {'creator_access': false},
  'stats': {'following': 4, 'followers': 2, 'podcasts': 0, 'playlists': 3},
  'unread_notifications': 0,
};

Map<String, dynamic> connectedAccountFixture({
  String id = 'acct-google',
  String provider = 'google',
  String? email = 'google@example.invalid',
}) => {
  'id': id,
  'provider': provider,
  'email': email,
  'created_at': '2026-09-10T09:00:00Z',
};
