import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

/// Drag-to-reorder Up Next list. Dropping an episode persists play order.
class QueueReorderList extends ConsumerWidget {
  const QueueReorderList({
    super.key,
    this.header,
    this.footer,
    this.emptyLabel = 'Your queue is empty.',
    this.onEpisodeTap,
  });

  final Widget? header;
  final Widget? footer;
  final String emptyLabel;
  final void Function(CatalogQueueItem item)? onEpisodeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(catalogQueueProvider);
    if (queueAsync.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          const CatalogStatusBody(),
        ],
      );
    }
    if (queueAsync.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          CatalogStatusBody(
            error: queueAsync.error,
            retry: () => ref.invalidate(catalogQueueProvider),
          ),
        ],
      );
    }

    final items = queueAsync.requireValue.items;
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          Text(
            emptyLabel,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          if (footer != null) footer!,
        ],
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      header: header,
      footer: footer,
      itemCount: items.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Material(
              elevation: 4 * animation.value,
              color: context.pelevo.surfaceHigh,
              borderRadius: BorderRadius.circular(PelevoRadii.medium),
              child: child,
            );
          },
        );
      },
      onReorder: (oldIndex, newIndex) {
        final reordered = reorderCatalogQueueItems(items, oldIndex, newIndex);
        unawaited(
          ref.read(catalogQueueProvider.notifier).commitOrder(reordered).catchError((
            Object error,
          ) {
            if (!context.mounted) return;
            context.showPelevoMessage(catalogFailure(error).message);
          }),
        );
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          key: ValueKey(item.queueItemId),
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: ReorderableDelayedDragStartListener(
                  index: index,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CatalogArtwork(
                      url: item.episode.artworkUrl,
                      width: 52,
                      height: 52,
                    ),
                    title: Text(item.episode.title),
                    subtitle: Text(
                      [
                        if (index == 0) 'Plays next',
                        item.episode.showTitle ?? '',
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                    onTap: onEpisodeTap == null
                        ? null
                        : () => onEpisodeTap!(item),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(PelevoSpacing.sm),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
