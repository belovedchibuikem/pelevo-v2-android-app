import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_environment.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

void openCatalogShow(BuildContext context, String showId) {
  final container = ProviderScope.containerOf(context);
  container.read(selectedShowIdProvider.notifier).select(showId);
  container.read(catalogEpisodeQueryProvider.notifier).clear();
}

void openCatalogEpisode(
  BuildContext context, {
  required String episodeId,
  String? showId,
}) {
  final container = ProviderScope.containerOf(context);
  container.read(selectedEpisodeIdProvider.notifier).select(episodeId);
  if (showId != null && showId.isNotEmpty) {
    container.read(selectedShowIdProvider.notifier).select(showId);
  }
}

void openCatalogEpisodeDetails(
  BuildContext context, {
  required String episodeId,
  String? showId,
}) {
  openCatalogEpisode(context, episodeId: episodeId, showId: showId);
  context.push('/screen/episode-details');
}

void playCatalogEpisode(
  BuildContext context, {
  required String episodeId,
  String? showId,
  int? positionSeconds,
  bool restart = false,
  bool keepQueue = false,
}) {
  final container = ProviderScope.containerOf(context);
  if (!keepQueue &&
      container.read(playbackQueueSourceProvider) ==
          PlaybackQueueSource.playlist) {
    container
        .read(playbackQueueSourceProvider.notifier)
        .set(PlaybackQueueSource.standalone);
    unawaited(_replaceQueueQuietly(container, const []));
  }
  container.read(playbackPlayIntentProvider.notifier).arm();
  container
      .read(playbackResumeHintProvider.notifier)
      .setSeconds(
        restart
            ? 0
            : (positionSeconds != null && positionSeconds > 0
                ? positionSeconds
                : null),
      );
  openCatalogEpisode(context, episodeId: episodeId, showId: showId);
  context.push('/screen/player-now-playing');
}

void playCatalogEpisodeQueue(
  BuildContext context, {
  required List<String> episodeIds,
  Map<String, String?> showIds = const {},
  bool shuffle = false,
}) {
  if (episodeIds.isEmpty) return;
  final ordered = [...episodeIds];
  if (shuffle) ordered.shuffle();
  final container = ProviderScope.containerOf(context);
  container
      .read(playbackQueueSourceProvider.notifier)
      .set(PlaybackQueueSource.playlist);
  final first = ordered.first;
  playCatalogEpisode(
    context,
    episodeId: first,
    showId: showIds[first],
    keepQueue: true,
  );
  unawaited(_replaceQueueQuietly(container, ordered.skip(1).toList()));
}

void openLibraryPlaylist(BuildContext context, String playlistId) {
  final container = ProviderScope.containerOf(context);
  container.read(selectedPlaylistIdProvider.notifier).select(playlistId);
  context.push('/screen/library-3?id=${Uri.encodeComponent(playlistId)}');
}

Future<void> _replaceQueueQuietly(
  ProviderContainer container,
  List<String> episodeIds,
) async {
  try {
    await container
        .read(catalogRepositoryProvider)
        .replaceQueueRetry(episodeIds);
    container.invalidate(catalogQueueProvider);
  } catch (_) {}
}

void openCatalogHomeItem(BuildContext context, HomeItem item) {
  if (item.type == 'show') {
    openCatalogShow(context, item.id);
    return;
  }
  if (item.type == 'reel' ||
      item.type == 'mood' ||
      item.type == 'category' ||
      item.type == 'browse') {
    return;
  }
  openCatalogEpisode(context, episodeId: item.id, showId: item.showId);
}

/// Opens show or episode details (does not start playback).
void openCatalogHomeDestination(BuildContext context, HomeItem item) {
  openCatalogHomeItem(context, item);
  if (item.type == 'mood' || item.type == 'category' || item.type == 'browse') {
    return;
  }
  context.push(homeItemRoute(item));
}

/// Selects the episode and opens the full player (autoplay happens on that screen).
void playCatalogHomeItem(BuildContext context, HomeItem item) {
  if (item.type != 'episode') {
    openCatalogHomeDestination(context, item);
    return;
  }
  playCatalogEpisode(
    context,
    episodeId: item.id,
    showId: item.showId,
    positionSeconds: item.positionSeconds,
  );
}

Future<bool> enqueueCatalogEpisode(
  BuildContext context, {
  required String episodeId,
  bool playNext = false,
}) async {
  final container = ProviderScope.containerOf(context);
  try {
    await container
        .read(catalogRepositoryProvider)
        .enqueueEpisode(episodeId, playNext: playNext);
    container.invalidate(catalogQueueProvider);
    if (!context.mounted) return true;
    context.showPelevoMessage(playNext ? 'Will play next' : 'Added to queue');
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    final failure = catalogFailure(error);
    if (failure.code != 'CANCELLED') {
      context.showPelevoMessage(failure.message);
    }
    return false;
  }
}

String homeItemRoute(HomeItem item) => switch (item.type) {
  'show' => '/screen/podcast-details',
  'reel' => '/screen/reels',
  'mood' || 'category' || 'browse' => '/screen/browse',
  _ => '/screen/episode-details',
};

/// Drops broken provider artwork like `…/id?.jpg` that cannot be decoded.
String? sanitizeArtworkUrl(String? url) {
  if (url == null) return null;
  final value = url.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  if (value.contains('?.') ||
      RegExp(
        r'\?\.(jpe?g|png|webp|gif|avif)$',
        caseSensitive: false,
      ).hasMatch(value)) {
    return null;
  }
  final path = uri.path.toLowerCase();
  if (path.endsWith('?.jpg') ||
      path.endsWith('?.png') ||
      path.endsWith('?.webp')) {
    return null;
  }
  return value;
}

class CatalogStatusBody extends StatelessWidget {
  const CatalogStatusBody({super.key, this.error, this.retry});

  final Object? error;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        Text(catalogFailure(error!).message),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    );
  }
}

class CatalogArtwork extends StatelessWidget {
  const CatalogArtwork({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.assetPath,
    this.radius,
  });

  final String? url;
  final double width, height;
  final String? assetPath;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final safeUrl = sanitizeArtworkUrl(url);
    final fallback = Container(
      width: width,
      height: height,
      color: PelevoColors.surfaceHigh,
      alignment: Alignment.center,
      child: const Icon(Icons.podcasts_rounded, color: PelevoColors.textMuted),
    );
    final image =
        safeUrl == null
            ? (assetPath == null
                ? fallback
                : Image.asset(
                  assetPath!,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ))
            : PelevoNetworkArt(
              url: safeUrl,
              width: width,
              height: height,
              fallback: fallback,
            );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? PelevoRadii.medium),
      child: image,
    );
  }
}

String catalogShareShowLink(String showId) =>
    '${ApiEnvironment.publicWebBase}/shows/$showId';

String catalogShareEpisodeLink(String episodeId) =>
    '${ApiEnvironment.publicWebBase}/episodes/$episodeId';

String catalogShareReelLink(String reelId) =>
    '${ApiEnvironment.publicWebBase}/reels/$reelId';

String catalogShareCreatorLink(String creatorId) =>
    '${ApiEnvironment.publicWebBase}/creators/${Uri.encodeComponent(creatorId.trim())}';

List<CatalogReview> sortedCatalogReviews(
  List<CatalogReview> reviews,
  int filter,
) {
  final copy = [...reviews];
  if (filter == 2) {
    copy.sort((a, b) => b.rating.compareTo(a.rating));
  } else {
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return copy;
}

List<double> catalogRatingBars(List<CatalogReview> reviews) {
  if (reviews.isEmpty) return const [0, 0, 0, 0, 0];
  final counts = List<int>.filled(5, 0);
  for (final review in reviews) {
    counts[review.rating - 1] += 1;
  }
  return [for (final count in counts.reversed) count / reviews.length];
}
