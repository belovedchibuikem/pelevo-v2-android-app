import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/search/directory/directory_models.dart';
import 'package:pelevo/features/search/directory/directory_repository.dart';
import 'package:pelevo/features/search/search_data.dart';

/// Directory matches under a Pelevo search. Adding a show stores it and
/// keeps later episodes syncing from the publisher feed.
class DirectoryResultsSection extends ConsumerStatefulWidget {
  const DirectoryResultsSection({
    required this.query,
    required this.catalogShows,
    this.heading = 'More podcasts',
    this.emptyCatalog,
    super.key,
  });

  final String query;
  final List<SearchShow> catalogShows;
  final String heading;
  final Widget? emptyCatalog;

  @override
  ConsumerState<DirectoryResultsSection> createState() =>
      _DirectoryResultsSectionState();
}

class _DirectoryResultsSectionState
    extends ConsumerState<DirectoryResultsSection> {
  String? _busyId;

  Future<void> _openOrAdd(DirectoryCandidate candidate) async {
    final existing = matchingCatalogShowId(
      candidate,
      [
        for (final show in widget.catalogShows)
          (id: show.id, title: show.title, author: show.author),
      ],
    );
    if (existing != null) {
      openCatalogShow(context, existing);
      context.push('/screen/podcast-details');
      return;
    }
    if (_busyId != null) return;
    setState(() => _busyId = candidate.id);
    try {
      final subscription = await ref
          .read(directoryRepositoryProvider)
          .subscribe(candidate);
      if (!mounted) return;
      openCatalogShow(context, subscription.showId);
      context.push('/screen/podcast-details');
      final title = candidate.title;
      context.showPelevoMessage(
        subscription.storedLocally
            ? '$title added on this device. New episodes refresh from its feed.'
            : subscription.alreadyInCatalog
            ? '$title is already on Pelevo. New episodes keep syncing.'
            : '$title added. New episodes will keep syncing.',
      );
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(searchFailure(error).message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query.trim();
    if (query.length < 3 && !query.contains('://')) {
      return widget.emptyCatalog ?? const SizedBox.shrink();
    }
    final page = ref.watch(directorySearchProvider(query));
    return page.when(
      skipLoadingOnReload: true,
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: PelevoSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          if (widget.emptyCatalog != null) widget.emptyCatalog!,
        ],
      ),
      error: (error, _) {
        if (searchFailure(error).code == 'CANCELLED') {
          return widget.emptyCatalog ?? const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(searchFailure(error).message),
            TextButton(
              onPressed: () => ref.invalidate(directorySearchProvider(query)),
              child: const Text('Retry'),
            ),
            if (widget.emptyCatalog != null) widget.emptyCatalog!,
          ],
        );
      },
      data: (result) {
        if (result.candidates.isEmpty) {
          if (result.unavailableMessage == null) {
            return widget.emptyCatalog ?? const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PelevoSectionHeader(title: 'Podcast feed'),
              Text(
                result.unavailableMessage!,
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              if (widget.emptyCatalog != null) ...[
                const SizedBox(height: PelevoSpacing.lg),
                widget.emptyCatalog!,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PelevoSectionHeader(title: widget.heading),
            Text(
              'Add a show to keep new episodes syncing.',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            for (final candidate in result.candidates)
              _row(context, candidate),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, DirectoryCandidate candidate) {
    final existing = matchingCatalogShowId(
      candidate,
      [
        for (final show in widget.catalogShows)
          (id: show.id, title: show.title, author: show.author),
      ],
    );
    final busy = _busyId == candidate.id;
    final subtitle = [
      if (candidate.author != null && candidate.author!.isNotEmpty)
        candidate.author!,
      candidate.sourceLabel,
      if (existing != null) 'Already on Pelevo',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _DirectoryArtwork(
        label: candidate.title,
        artworkUrl: candidate.artworkUrl,
      ),
      title: Text(candidate.title),
      subtitle: Text(subtitle),
      trailing:
          busy
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : TextButton(
                onPressed: () => _openOrAdd(candidate),
                child: Text(existing == null ? 'Add' : 'Open'),
              ),
      onTap: busy ? null : () => _openOrAdd(candidate),
    );
  }
}

class _DirectoryArtwork extends StatelessWidget {
  const _DirectoryArtwork({required this.label, this.artworkUrl});

  final String label;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.small),
      child:
          url == null || url.isEmpty
              ? PelevoArtwork(label: label, size: 58, color: PelevoColors.blue)
              : PelevoNetworkArt(
                url: url,
                width: 58,
                height: 58,
                fallback: PelevoArtwork(
                  label: label,
                  size: 58,
                  color: PelevoColors.blue,
                ),
              ),
    );
  }
}
