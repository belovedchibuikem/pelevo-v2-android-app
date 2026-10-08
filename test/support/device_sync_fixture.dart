Map<String, dynamic> syncDeviceFixture({
  String id = 'device-1',
  String name = 'iPhone 15 Pro',
  String platform = 'ios',
  String trustState = 'paired',
}) => {
  'id': id,
  'name': name,
  'platform': platform,
  'trust_state': trustState,
  'last_seen_at': '2026-09-10T09:41:00Z',
  'last_active_at': '2026-09-10T09:41:00Z',
  'revoked_at': null,
  'created_at': '2026-09-01T00:00:00Z',
};

Map<String, dynamic> pairingCodeFixture({
  String code = 'ABCD1234',
  int expiresIn = 600,
}) => {
  'code': code,
  'expires_in': expiresIn,
};

Map<String, dynamic> syncChangeFixture({
  String id = 'sync-change-1',
  String resourceType = 'playlist',
  String resourceId = 'playlist-1',
  String operation = 'update',
  int version = 1,
}) => {
  'id': id,
  'resource_type': resourceType,
  'resource_id': resourceId,
  'operation': operation,
  'version': version,
};

Map<String, dynamic> syncConflictFixture({
  String id = 'sync-conflict-1',
  String resourceType = 'playlist',
}) => {
  'id': id,
  'created_at': '2026-09-10T09:00:00Z',
  'state': 'open',
  'resource_type': resourceType,
};
