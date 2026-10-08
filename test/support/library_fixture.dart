import 'package:pelevo/features/library/library_data.dart';
import 'catalog_fixture.dart';

const libraryPlaylistId = 'library-playlist-1';
const libraryCollectionId = 'library-collection-1';
const libraryDownloadId = 'library-download-1';

class CatalogHarnessPlaylistId extends SelectedPlaylistIdNotifier {
  @override
  String? build() => libraryPlaylistId;
}

class CatalogHarnessCollectionId extends SelectedCollectionIdNotifier {
  @override
  String? build() => libraryCollectionId;
}

Map<String, dynamic> libraryEpisodeFixture({
  String id = catalogEpisodeId,
  String showId = catalogShowId,
  String title = 'Ep. 124 - The Shift Life',
  String showTitle = 'The Honest Bunch',
  int duration = 2700,
  int? position,
  bool? completed,
  String? savedAt,
}) => {
  'id': id,
  'show_id': showId,
  'title': title,
  'show_title': showTitle,
  'artwork_url': null,
  'duration_seconds': duration,
  if (position != null) 'position_seconds': position,
  if (completed != null) 'completed': completed,
  if (savedAt != null) 'saved_at': savedAt,
};

Map<String, dynamic> libraryPlaylistFixture({
  String id = libraryPlaylistId,
  String name = 'Mindset & Growth',
  int itemCount = 1,
  bool detailed = false,
  bool isPublic = true,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'is_public': isPublic,
  'is_owner': true,
  'artwork_url': null,
  'version': 1,
  'item_count': itemCount,
  if (detailed) 'items': [libraryEpisodeFixture()],
};

Map<String, dynamic> libraryCollectionFixture({
  String id = libraryCollectionId,
  String name = 'Sunday Reset',
  int itemCount = 1,
  bool detailed = false,
}) => {
  'id': id,
  'name': name,
  'version': 1,
  'item_count': itemCount,
  if (detailed)
    'items': [
      {
        ...libraryEpisodeFixture(),
        'collectable_type': 'episode',
      },
    ],
};

Map<String, dynamic> libraryShowRowFixture({
  String id = catalogShowId,
  String title = 'The Honest Bunch',
  bool notificationsEnabled = true,
}) => {
  'id': id,
  'title': title,
  'author': 'With Toke & Friends',
  'artwork_url': null,
  'notifications_enabled': notificationsEnabled,
  'followed_at': '2026-09-09T12:00:00Z',
};

Map<String, dynamic> libraryOverviewFixture() => {
  'saved_count': 1,
  'liked_count': 1,
  'shows_count': 1,
  'downloads_count': 1,
  'recent_count': 1,
  'playlists': [libraryPlaylistFixture()],
  'collections': [libraryCollectionFixture()],
};

Map<String, dynamic> librarySettingsFixture({
  bool hideCompleted = false,
  String sort = 'recent',
  int version = 1,
}) => {
  'hide_completed': hideCompleted,
  'sort': sort,
  'version': version,
};

Map<String, dynamic> libraryDownloadFixture({
  String downloadId = libraryDownloadId,
  String episodeId = catalogEpisodeId,
  String title = 'Ep. 124 - The Shift Life',
}) => {
  'download_id': downloadId,
  'id': episodeId,
  'show_id': catalogShowId,
  'title': title,
  'show_title': 'The Honest Bunch',
  'artwork_url': null,
  'authorized_until': '2026-09-10T12:00:00Z',
};

Map<String, dynamic> downloadSettingsFixture({
  bool wifiOnly = true,
  bool autoDeleteCompleted = false,
  int maxStorageMb = 2048,
  int version = 1,
}) => {
  'wifi_only': wifiOnly,
  'auto_delete_completed': autoDeleteCompleted,
  'max_storage_mb': maxStorageMb,
  'version': version,
};

Map<String, dynamic> storageUsageFixture({
  int backupBytes = 0,
  int offlineItems = 1,
}) => {
  'backup_bytes': backupBytes,
  'offline_items': offlineItems,
};
