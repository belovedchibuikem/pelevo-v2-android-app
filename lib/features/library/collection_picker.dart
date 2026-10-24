import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

class _CreateCollectionRequest {
  const _CreateCollectionRequest();
}

/// Lets the listener drop an episode or podcast into one of their collections.
Future<bool> pickCollectionForItem({
  required BuildContext context,
  required WidgetRef ref,
  required String type,
  required String collectableId,
  required String label,
}) async {
  final token = CancelToken();
  List<LibraryCollection> collections;
  try {
    collections = await ref.read(libraryRepositoryProvider).collections(token);
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
              'Add to Collection',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.create_new_folder_outlined,
                color: PelevoColors.green,
              ),
              title: const Text('Create new collection'),
              onTap: () => Navigator.pop(
                sheetContext,
                const _CreateCollectionRequest(),
              ),
            ),
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'You do not have a collection yet. Create one to save this.',
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(collection.name),
                      subtitle: Text(collection.countLabel),
                      onTap: () => Navigator.pop(sheetContext, collection),
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

  LibraryCollection? target;
  if (picked is _CreateCollectionRequest) {
    target = await _createCollection(context, ref);
  } else if (picked is LibraryCollection) {
    target = picked;
  }
  if (target == null || !context.mounted) return false;

  try {
    await _addItem(
      ref,
      collection: target,
      type: type,
      collectableId: collectableId,
    );
  } catch (error) {
    final failure = catalogFailure(error);
    if (failure.code == 'CANCELLED') return false;
    if (context.mounted) context.showPelevoMessage(failure.message);
    return false;
  }
  if (!context.mounted) return false;
  context.showPelevoMessage('Added $label to ${target.name}');
  return true;
}

/// Adds saved episodes and followed podcasts into an existing collection.
Future<bool> showCollectionLibraryPicker({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryCollection collection,
}) async {
  final token = CancelToken();
  List<LibraryEpisode> episodes;
  List<LibraryShow> shows;
  try {
    final repo = ref.read(libraryRepositoryProvider);
    episodes = await repo.saved(token);
    shows = await repo.shows(token);
  } catch (error) {
    final failure = catalogFailure(error);
    if (failure.code == 'CANCELLED') return false;
    if (context.mounted) context.showPelevoMessage(failure.message);
    return false;
  }
  if (!context.mounted) return false;
  final added = await showPelevoSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _CollectionLibrarySheet(
      collection: collection,
      episodes: episodes,
      shows: shows,
    ),
  );
  return added == true;
}

class _CollectionLibrarySheet extends ConsumerStatefulWidget {
  const _CollectionLibrarySheet({
    required this.collection,
    required this.episodes,
    required this.shows,
  });

  final LibraryCollection collection;
  final List<LibraryEpisode> episodes;
  final List<LibraryShow> shows;

  @override
  ConsumerState<_CollectionLibrarySheet> createState() =>
      _CollectionLibrarySheetState();
}

class _CollectionLibrarySheetState
    extends ConsumerState<_CollectionLibrarySheet> {
  late int _version = widget.collection.version < 1 ? 1 : widget.collection.version;
  late final Set<String> _present = {
    for (final item in widget.collection.items) '${item.type}:${item.id}',
  };
  bool _busy = false;
  bool _changed = false;

  Future<void> _add(String type, String id, String label) async {
    if (_busy || _present.contains('$type:$id')) return;
    setState(() => _busy = true);
    try {
      final updated = await _addItem(
        ref,
        collection: widget.collection.copyWith(version: _version),
        type: type,
        collectableId: id,
      );
      if (!mounted) return;
      setState(() {
        _version = updated.version;
        _present.add('$type:$id');
        _changed = true;
      });
      context.showPelevoMessage('Added $label');
    } catch (error) {
      if (mounted) context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodes = widget.episodes.where(
      (item) => !_present.contains('episode:${item.id}'),
    );
    final shows = widget.shows.where(
      (item) => !_present.contains('show:${item.id}'),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add to ${widget.collection.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (episodes.isEmpty && shows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Save an episode or follow a podcast, then add it here.',
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  ),
                if (episodes.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Saved episodes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                for (final episode in episodes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(episode.title),
                    subtitle: Text(episode.subtitle),
                    trailing: const Icon(Icons.add_rounded),
                    enabled: !_busy,
                    onTap: () => _add('episode', episode.id, episode.title),
                  ),
                if (shows.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      'Podcasts you follow',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                for (final show in shows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(show.title),
                    subtitle: Text(show.author ?? ''),
                    trailing: const Icon(Icons.add_rounded),
                    enabled: !_busy,
                    onTap: () => _add('show', show.id, show.title),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PelevoButton(
            label: 'Done',
            color: PelevoColors.green,
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ],
      ),
    );
  }
}

Future<LibraryCollection?> _createCollection(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create collection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Collection name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            nameController.text.trim().isNotEmpty,
          ),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final name = nameController.text.trim();
  final description = descriptionController.text.trim();
  nameController.dispose();
  descriptionController.dispose();
  if (confirmed != true || name.isEmpty || !context.mounted) return null;
  try {
    final created = await ref.read(libraryRepositoryProvider).createCollection(
      name,
      description: description,
    );
    ref.invalidate(libraryCollectionsProvider);
    ref.invalidate(libraryOverviewProvider);
    return created;
  } catch (error) {
    if (context.mounted) {
      context.showPelevoMessage(catalogFailure(error).message);
    }
    return null;
  }
}

Future<LibraryCollection> _addItem(
  WidgetRef ref, {
  required LibraryCollection collection,
  required String type,
  required String collectableId,
}) async {
  final repo = ref.read(libraryRepositoryProvider);
  Future<LibraryCollection> post(int version) {
    return repo.addCollectionItem(
      id: collection.id,
      type: type,
      collectableId: collectableId,
      version: version < 1 ? 1 : version,
    );
  }

  LibraryCollection updated;
  try {
    updated = await post(collection.version);
  } on ApiFailure catch (error) {
    if (error.code != 'VERSION_CONFLICT') rethrow;
    final fresh = await repo.collection(collection.id, CancelToken());
    updated = await post(fresh.version);
  }
  ref.invalidate(libraryCollectionsProvider);
  ref.invalidate(libraryCollectionProvider);
  ref.invalidate(libraryOverviewProvider);
  return updated;
}

extension on LibraryCollection {
  LibraryCollection copyWith({int? version}) => LibraryCollection(
    id: id,
    name: name,
    description: description,
    artworkUrl: artworkUrl,
    isPublic: isPublic,
    isOwner: isOwner,
    version: version ?? this.version,
    itemCount: itemCount,
    items: items,
  );
}
