Map<String, dynamic> earnWalletFixture({
  String owner = 'test-user',
  String balance = '3000',
  String minimum = '1250',
  bool withdrawalsEnabled = true,
}) => {
  'user_id': owner,
  'unit': 'ECN',
  'balance': balance,
  'minimum_withdrawal': minimum,
  'withdrawals_enabled': withdrawalsEnabled,
};

Map<String, dynamic> earnShowFixture({
  String id = 'show-honest',
  String title = 'The Honest Bunch',
  String author = 'With Toke & Friends',
  int episodes = 2,
}) => {
  'id': id,
  'title': title,
  'author': author,
  'artwork_url': null,
  'episodes_count': episodes,
};

Map<String, dynamic> earnEpisodeFixture({
  String id = 'earn-honest-123',
  String showId = 'show-honest',
  String showTitle = 'The Honest Bunch',
  String showAuthor = 'With Toke & Friends',
  String title = 'Ep. 123 - Soft Life Talk',
  int duration = 2280,
  String? audioUrl = 'https://cdn.example.invalid/earn.mp3',
  String? lockedUntil,
}) => {
  'id': id,
  'show_id': showId,
  'show_title': showTitle,
  'show_author': showAuthor,
  'title': title,
  'artwork_url': null,
  'duration_seconds': duration,
  'audio_url': audioUrl,
  'locked_until': lockedUntil,
  'locked': lockedUntil != null,
  'coins': duration < 600 ? 1 : (duration < 1200 ? 2 : 3),
};

List<Map<String, dynamic>> earnShowsFixture() => [
  earnShowFixture(),
  earnShowFixture(
    id: 'show-mindset',
    title: 'The Mindset',
    author: 'Jay Shetty',
    episodes: 1,
  ),
];

List<Map<String, dynamic>> earnEpisodesFixture() => [
  earnEpisodeFixture(),
  earnEpisodeFixture(
    id: 'earn-mindset-1',
    showId: 'show-mindset',
    showTitle: 'The Mindset',
    showAuthor: 'Jay Shetty',
    title: 'Train Your Mind Daily',
    duration: 1080,
  ),
];

Map<String, dynamic> earnSessionFixture({
  String id = 'session-1',
  String episodeId = 'earn-mindset-1',
  int award = 2,
}) => {
  'id': id,
  'episode_id': episodeId,
  'expected_award': award,
  'nonce': 'n' * 64,
  'nonce_expires_at': '2026-09-10T12:00:00Z',
  'lock_hours': 72,
};

Map<String, dynamic> earnAwardFixture({
  String id = 'award-1',
  String episodeId = 'earn-mindset-1',
  int coins = 2,
}) => {
  'id': id,
  'episode_id': episodeId,
  'coins': coins,
  'locked_until': '2026-09-13T09:00:00Z',
};

Map<String, dynamic> earnPayoutMethodFixture({
  String id = 'method-1',
  String provider = 'flutterwave',
  String kind = 'bank',
  String label = 'Guaranty Trust Bank',
  String lastFour = '6789',
  String? verifiedAt = '2026-09-10T09:00:00Z',
}) => {
  'id': id,
  'provider': provider,
  'kind': kind,
  'label': label,
  'destination_last_four': lastFour,
  'verified_at': verifiedAt,
};

Map<String, dynamic> earnWithdrawalFixture({
  String id = 'wd-1',
  String coins = '1250',
  String state = 'queued',
}) => {
  'id': id,
  'coins': coins,
  'state': state,
  'created_at': '2026-09-10T09:00:00Z',
};

Map<String, dynamic> inviteFixture({
  String owner = 'test-user',
  String? code = 'PELEVOTEST1',
}) => {
  'user_id': owner,
  'code': code,
  'expires_at': code == null ? null : '2026-10-10T09:00:00Z',
  'redemptions': 0,
  'max_redemptions': 100,
};
