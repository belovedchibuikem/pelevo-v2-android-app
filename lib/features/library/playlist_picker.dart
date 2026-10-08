import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

class _CreatePlaylistRequest {
  const _CreatePlaylistRequest();
}

/// Shared playlist picker used by queue, podcast, episode, and player flows.
Future<bool> pickPlaylistForEpisode({
  required BuildContext context,
  required WidgetRef ref,
  required String episodeId,
  String? successRoute,
}) async {
  final token = CancelToken();
  List<LibraryPlaylist> playlists;
  try {
    // Fetch through the repository. `libraryPlaylistsProvider` is autoDispose,
    // so reading `.future` with no watcher cancels the request immediately.
    playlists = await ref.read(libraryRepositoryProvider).playlists(token);
  } catch (error) {
    final failure = catalogFailure(error);
    if (failure.code == 'CANCELLED') return false;
    if (context.mounted) context.showPelevoMessage(failure.message);
    return false;
  }
  if (!context.mounted) return false;

  final picked = await showPelevoSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to Playlist',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.playlist_add_rounded, color: PelevoColors.green),
              title: const Text('Create new playlist'),
              onTap: () => Navigator.pop(sheetContext, const _CreatePlaylistRequest()),
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'You do not have a playlist yet. Create one to save this episode.',
                  style: TextStyle(color: PelevoColors.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(playlist.name),
                      subtitle: Text(playlist.countLabel),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheetContext, playlist),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

  if (!context.mounted || picked == null) return false;

  LibraryPlaylist? target;
  if (picked is _CreatePlaylistRequest) {
    target = await _createPlaylist(context, ref);
  } else if (picked is LibraryPlaylist) {
    target = picked;
  }
  if (target == null || !context.mounted) return false;

  try {
    await _addEpisode(ref, episodeId: episodeId, playlist: target);
  } catch (error) {
    final failure = catalogFailure(error);
    if (failure.code == 'CANCELLED') return false;
    if (context.mounted) context.showPelevoMessage(failure.message);
    return false;
  }
  if (!context.mounted) return false;
  context.showPelevoMessage('Added to ${target.name}');
  if (successRoute != null) context.pelevoOpen(successRoute);
  return true;
}

Future<LibraryPlaylist?> _createPlaylist(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Playlist name'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(dialogContext, true);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim().isNotEmpty),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final name = controller.text.trim();
  controller.dispose();
  if (confirmed != true || name.isEmpty || !context.mounted) return null;
  try {
    final playlist = await ref.read(libraryRepositoryProvider).createPlaylist(name: name);
    ref.invalidate(libraryPlaylistsProvider);
    return playlist;
  } catch (error) {
    if (context.mounted) context.showPelevoMessage(catalogFailure(error).message);
    return null;
  }
}

Future<void> _addEpisode(
  WidgetRef ref, {
  required String episodeId,
  required LibraryPlaylist playlist,
}) async {
  final repo = ref.read(libraryRepositoryProvider);
  Future<void> post(int version) {
    return repo.addPlaylistItem(
      playlistId: playlist.id,
      episodeId: episodeId,
      version: version < 1 ? 1 : version,
    );
  }

  try {
    await post(playlist.version);
  } on ApiFailure catch (error) {
    if (error.code != 'VERSION_CONFLICT') rethrow;
    final fresh = await repo.playlist(playlist.id, CancelToken());
    await post(fresh.version);
  }
  ref.invalidate(libraryPlaylistsProvider);
  ref.invalidate(libraryPlaylistProvider);
}
