// Test-only wire contract. Never imported by runtime code.
Map<String, dynamic> preferencesFixture({
  int version = 0,
  String userId = 'test-user',
}) => {
  'user_id': userId,
  'version': version,
  'explicit_content': false,
  'autoplay': true,
  'download_wifi_only': true,
  'data_saver': false,
  'audio_quality': 'high',
  'email_product': false,
  'email_episodes': false,
  'email_marketing': false,
};
