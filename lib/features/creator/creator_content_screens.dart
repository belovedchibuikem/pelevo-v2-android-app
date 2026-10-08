import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import 'package:pelevo/features/reels/reel_create_service.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reel_limits.dart';
import 'package:pelevo/features/reels/reel_upload.dart';
import 'package:pelevo/features/reels/reel_upload_progress.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> creatorContentScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'creator-episodes',
    section: 'Creator Studio',
    title: 'Creator Episodes',
    builder: _buildEpisodes,
  ),
  const PelevoScreenSpec(
    id: 'creator-episode-details',
    section: 'Creator Studio',
    title: 'Creator Episode Details',
    builder: _buildEpisodeDetails,
  ),
  const PelevoScreenSpec(
    id: 'creator-reels',
    section: 'Creator Studio',
    title: 'Creator Reels',
    builder: _buildReels,
  ),
  const PelevoScreenSpec(
    id: 'creator-reel-details',
    section: 'Creator Studio',
    title: 'Creator Reel Details',
    builder: _buildReelDetails,
  ),
  const PelevoScreenSpec(
    id: 'creator-create-reel',
    section: 'Creator Studio',
    title: 'Create New Reel',
    builder: _buildCreateReel,
  ),
]);

Widget _buildEpisodes(BuildContext context) => const CreatorEpisodesScreen();
Widget _buildEpisodeDetails(BuildContext context) =>
    const CreatorEpisodeDetailsScreen();
Widget _buildReels(BuildContext context) => const CreatorReelsScreen();
Widget _buildReelDetails(BuildContext context) =>
    const CreatorReelDetailsScreen();
Widget _buildCreateReel(BuildContext context) =>
    const CreatorCreateReelScreen();

Future<void> _deleteStudioReel({
  required BuildContext context,
  required WidgetRef ref,
  required String reelId,
  bool popOnSuccess = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Delete reel?'),
          content: const Text(
            'This permanently removes the reel from Pelevo. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: PelevoColors.red),
              ),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref.read(reelRepositoryProvider).deleteReel(reelId);
    ref.invalidate(studioReelsProvider);
    ref.invalidate(studioReelDetailProvider);
    if (!context.mounted) {
      return;
    }
    context.showPelevoMessage('Reel deleted');
    if (popOnSuccess) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/screen/creator-reels');
      }
    }
  } on Object catch (error) {
    if (context.mounted) {
      context.showPelevoMessage(reelFailure(error).message);
    }
  }
}

Future<void> _openStudioReelMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String reelId,
  bool popOnSuccess = false,
}) async {
  final action = await showPelevoSheet<String>(
    context: context,
    builder:
        (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: PelevoColors.red,
                ),
                title: const Text('Delete reel'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ),
  );
  if (action != 'delete' || !context.mounted) {
    return;
  }
  await _deleteStudioReel(
    context: context,
    ref: ref,
    reelId: reelId,
    popOnSuccess: popOnSuccess,
  );
}

class CreatorEpisodesScreen extends ConsumerWidget {
  const CreatorEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(studioEpisodesProvider);
    return _CreatorPage(
      selectedTab: 1,
      child: episodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioEpisodesProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (page) {
          final show = selectedStudioShow(ref);
          return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    show == null ? 'Episodes' : show.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Search creator episodes',
                  onPressed:
                      () => context.showPelevoMessage(
                        'Search creator episodes is not available yet.',
                      ),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (page.items.isEmpty)
              const Text(
                'No episodes are available yet.',
                style: TextStyle(color: PelevoColors.textMuted),
              )
            else
              for (final episode in page.items)
                _CreatorMediaTile(
                  title: episode.title,
                  subtitle: episode.subtitle,
                  artworkUrl: episode.artworkUrl,
                  status: episode.statusLabel.isEmpty
                      ? null
                      : episode.statusLabel,
                  onTap: () {
                    ref
                        .read(selectedStudioEpisodeIdProvider.notifier)
                        .select(episode.id);
                    context.push('/screen/creator-episode-details');
                  },
                ),
          ],
        );
        },
      ),
    );
  }
}

class CreatorReelsScreen extends ConsumerStatefulWidget {
  const CreatorReelsScreen({super.key});

  @override
  ConsumerState<CreatorReelsScreen> createState() => _CreatorReelsScreenState();
}

class _CreatorReelsScreenState extends ConsumerState<CreatorReelsScreen> {
  StudioReelFilter _filter = StudioReelFilter.all;

  void _openDetails(StudioReel reel) {
    ref.read(selectedStudioReelIdProvider.notifier).select(reel.id);
    context.push('/screen/creator-reel-details');
  }

  @override
  Widget build(BuildContext context) {
    final reels = ref.watch(studioReelsProvider(_filter));
    return _CreatorPage(
      selectedTab: 2,
      child: reels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioReelsProvider(_filter)),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (page) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Your Reels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (page.items.isEmpty) {
                      context.showPelevoMessage(
                        'No reels are available yet.',
                      );
                      return;
                    }
                    _openDetails(page.items.first);
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(color: PelevoColors.green),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => context.push('/screen/creator-create-reel'),
              borderRadius: PelevoRadii.card,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PelevoColors.green.withValues(alpha: .08),
                  borderRadius: PelevoRadii.card,
                  border: Border.all(color: PelevoColors.green),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: PelevoColors.green,
                      child: Icon(Icons.add_box_outlined),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Reel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Turn your best moments into reels and grow your audience.',
                            style: TextStyle(
                              color: PelevoColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: PelevoColors.green,
                      child: Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final filter in StudioReelFilter.values)
                  ChoiceChip(
                    label: Text(switch (filter) {
                      StudioReelFilter.all => 'All',
                      StudioReelFilter.linked => 'Linked to Episodes',
                      StudioReelFilter.drafts => 'Drafts',
                    }),
                    selected: _filter == filter,
                    selectedColor: PelevoColors.green.withValues(alpha: .25),
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (page.items.isEmpty)
              _filter == StudioReelFilter.drafts
                  ? const _EmptyDrafts()
                  : const Text(
                    'No reels are available yet.',
                    style: TextStyle(color: PelevoColors.textMuted),
                  )
            else
              for (final reel in page.items)
                _CreatorMediaTile(
                  title: reel.title,
                  subtitle: reel.subtitle,
                  artworkUrl: reel.artworkUrl,
                  status:
                      reel.statusLabel.isEmpty ? null : reel.statusLabel,
                  reelCover: true,
                  onTap: () => _openDetails(reel),
                  onMore:
                      () => _openStudioReelMenu(
                        context: context,
                        ref: ref,
                        reelId: reel.id,
                      ),
                ),
          ],
        ),
      ),
    );
  }
}

class CreatorEpisodeDetailsScreen extends ConsumerWidget {
  const CreatorEpisodeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(studioEpisodeDetailProvider);
    return episode.when(
      loading:
          () => const PelevoPage(
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => PelevoPage(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed:
                    () =>
                        context.canPop()
                            ? context.pop()
                            : context.go('/screen/creator-episodes'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              title: const Text('Episode Details'),
              centerTitle: true,
            ),
            child: _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioEpisodeDetailProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
          ),
      data:
          (value) => _DetailCommentsScreen(
            title: 'Episode Details',
            asset: '',
            artworkUrl: value.artworkUrl,
            headline: value.title,
            metadata: value.subtitle,
            status: value.statusLabel,
            target: CommentTarget.episode(value.id),
          ),
    );
  }
}

class CreatorReelDetailsScreen extends ConsumerWidget {
  const CreatorReelDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reel = ref.watch(studioReelDetailProvider);
    return reel.when(
      loading:
          () => const PelevoPage(
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => PelevoPage(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed:
                    () =>
                        context.canPop()
                            ? context.pop()
                            : context.go('/screen/creator-reels'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              title: const Text('Reel Details'),
              centerTitle: true,
            ),
            child: _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioReelDetailProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
          ),
      data: (value) {
        final metadata = [
          if (value.subtitle.isNotEmpty) value.subtitle,
          if (value.statusLabel.isNotEmpty) value.statusLabel,
        ].join('\n');
        return _DetailCommentsScreen(
          title: 'Reel Details',
          asset: '',
          artworkUrl: value.artworkUrl,
          headline: value.title,
          metadata: metadata,
          status: value.statusLabel,
          target: CommentTarget.reel(value.id),
          reelCover: true,
          onMore:
              () => _openStudioReelMenu(
                context: context,
                ref: ref,
                reelId: value.id,
                popOnSuccess: true,
              ),
        );
      },
    );
  }
}

class _DetailCommentsScreen extends StatefulWidget {
  const _DetailCommentsScreen({
    required this.title,
    required this.asset,
    required this.headline,
    required this.metadata,
    required this.target,
    this.artworkUrl,
    this.status,
    this.reelCover = false,
    this.onMore,
  });
  final String title;
  final String asset;
  final String? artworkUrl;
  final String headline;
  final String metadata;
  final String? status;
  final CommentTarget target;
  final bool reelCover;
  final VoidCallback? onMore;

  @override
  State<_DetailCommentsScreen> createState() => _DetailCommentsScreenState();
}

class _DetailCommentsScreenState extends State<_DetailCommentsScreen> {
  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed:
            () =>
                context.canPop()
                    ? context.pop()
                    : context.go('/screen/creator-dashboard'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(widget.title),
      centerTitle: true,
      actions: [
        if (widget.onMore != null)
          IconButton(
            tooltip: 'More options',
            onPressed: widget.onMore,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
      ],
    ),
    scrollable: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: PelevoRadii.card,
                  child: _MediaImage(
                    asset: widget.asset,
                    artworkUrl: widget.artworkUrl,
                    width: 112,
                    height: 112,
                    reelCover: widget.reelCover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.headline,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.metadata,
                        style: const TextStyle(
                          color: PelevoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (widget.status != null &&
                          widget.status!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '● ${widget.status}',
                          style: const TextStyle(
                            color: PelevoColors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Consumer(
              builder: (context, ref, _) {
                final args = CommentThreadArgs(
                  target: widget.target,
                  sort: CommentSort.newest,
                );
                final comments =
                    ref.watch(commentsProvider(args)).asData?.value ?? const [];
                return _Metric(
                  icon: Icons.chat_bubble_outline_rounded,
                  value: '${comments.length}',
                  label: 'Comments',
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CommentThreadPanel(
                target: widget.target,
                creatorTools: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CreatorCreateReelScreen extends ConsumerStatefulWidget {
  const CreatorCreateReelScreen({super.key});

  @override
  ConsumerState<CreatorCreateReelScreen> createState() =>
      _CreatorCreateReelScreenState();
}

class _CreatorCreateReelScreenState
    extends ConsumerState<CreatorCreateReelScreen> {
  int _source = 1;
  bool _public = true;
  bool _saving = false;
  String? _error;
  String? _videoPath;
  String? _coverPath;
  StudioEpisode? _linkedEpisode;
  String _uploadStage = '';
  double? _uploadProgress;
  final _title = TextEditingController();
  final _caption = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickEpisode() async {
    final page = ref.read(studioEpisodesProvider).asData?.value;
    if (page == null) {
      return;
    }
    final selected = await showStudioEpisodePicker(
      context,
      episodes: page.items,
      selectedId: _linkedEpisode?.id,
    );
    if (selected != null && mounted) {
      setState(() => _linkedEpisode = selected);
    }
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      context.showPelevoMessage('Reel upload requires a mobile or desktop build.');
      return;
    }
    final draft = await ReelCreateService.instance.pickFromGallery(
      maxDuration: reelMaxDuration,
    );
    if (!mounted) {
      return;
    }
    if (draft == null) {
      final error = ReelCreateService.instance.lastError;
      if (error != null && error != 'Upload cancelled.') {
        setState(() => _error = error);
      }
      return;
    }
    setState(() {
      _videoPath = draft.path;
      _error = null;
    });
  }

  Future<void> _pickCover() async {
    if (kIsWeb) {
      context.showPelevoMessage('Cover upload requires a mobile or desktop build.');
      return;
    }
    final path = await ReelCreateService.instance.pickCoverImage();
    if (!mounted) {
      return;
    }
    if (path == null) {
      return;
    }
    setState(() => _coverPath = path);
  }

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final title = _title.text.trim();
      final caption = _caption.text.trim();
      await ref.read(studioRepositoryProvider).saveReelDraft(
        title: title.isEmpty ? null : title,
        caption: caption.isEmpty ? null : caption,
        episodeId: _source == 0 ? _linkedEpisode?.id : null,
        showId: _source == 0 ? _linkedEpisode?.showId : null,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(studioReelsProvider);
      context.showPelevoMessage('Draft saved');
      context.go('/screen/creator-reels');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = _failureMessage(error, 'The reel draft could not be saved.');
      });
    }
  }

  Future<void> _createReel() async {
    if (_source == 0 && _linkedEpisode == null) {
      setState(() => _error = 'Choose an episode to link, then select a video.');
      return;
    }
    if (_videoPath == null) {
      setState(() => _error = 'Select a video up to $reelMaxDurationLabel.');
      return;
    }
    if (kIsWeb) {
      context.showPelevoMessage('Reel publish requires a mobile or desktop file upload.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _uploadStage = '';
      _uploadProgress = null;
    });
    try {
      final title = _title.text.trim();
      final caption = _caption.text.trim();
      if (!_public) {
        await ref.read(studioRepositoryProvider).saveReelDraft(
          title: title.isEmpty ? null : title,
          caption: caption.isEmpty ? null : caption,
          episodeId: _source == 0 ? _linkedEpisode?.id : null,
          showId: _source == 0 ? _linkedEpisode?.showId : null,
        );
        if (!mounted) {
          return;
        }
        ref.invalidate(studioReelsProvider);
        context.showPelevoMessage('Draft saved');
        context.go('/screen/creator-reels');
        return;
      }
      final upload = ref.read(reelUploadRepositoryProvider);
      final result = await upload.publishFile(
        file: File(_videoPath!),
        title: title.isEmpty ? null : title,
        caption: caption.isEmpty ? null : caption,
        episodeId: _source == 0 ? _linkedEpisode?.id : null,
        showId: _source == 0 ? _linkedEpisode?.showId : null,
        onProgress: (stage, progress) {
          if (!mounted) return;
          setState(() {
            _uploadStage = stage;
            _uploadProgress = progress;
          });
        },
      );
      final cover = _coverPath;
      if (cover != null) {
        try {
          await upload.uploadCover(reelId: result.id, file: File(cover));
        } on Object {
          if (mounted) {
            context.showPelevoMessage('Reel uploaded. Cover could not be saved.');
          }
        }
      }
      ref.invalidate(studioReelsProvider);
      if (!mounted) {
        return;
      }
      context.showPelevoMessage(
        result.truncated
            ? (result.truncatedMessage ?? reelTruncatedMessage)
            : result.state == 'processing'
            ? 'Your reel is publishing now and will appear in For You as soon as processing finishes.'
            : 'Reel published.',
      );
      context.go('/screen/creator-reels');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = _failureMessage(error, 'The reel could not be created.');
      });
    }
  }

  String _failureMessage(Object error, String fallback) {
    if (error is ApiFailure) {
      return error.message;
    }
    if (error is DioException) {
      return apiFailureFromDio(error).message;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final episodes = ref.watch(studioEpisodesProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/screen/creator-reels'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Create New Reel'),
        centerTitle: true,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: episodes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => _StudioLoadError(
                  error: error,
                  onRetry: () => ref.invalidate(studioEpisodesProvider),
                  onClaim: () => context.go('/screen/claim-podcast'),
                ),
            data: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepTitle(
                  number: '1.',
                  title: 'Select Source',
                  subtitle: 'Choose a video, and optionally link an episode.',
                ),
                const SizedBox(height: 10),
                _SourceCard(
                  icon: Icons.link_rounded,
                  title: 'From an Episode',
                  subtitle: 'Link a claimed episode, then add a video clip.',
                  selected: _source == 0,
                  onTap: () => setState(() => _source = 0),
                ),
                const SizedBox(height: 10),
                _SourceCard(
                  icon: Icons.upload_outlined,
                  title: 'Upload Video',
                  subtitle: 'Upload a video from your device. Longer than $reelMaxDurationLabel is trimmed.',
                  selected: _source == 1,
                  onTap: () {
                    setState(() => _source = 1);
                    if (_videoPath == null) {
                      _pickVideo();
                    }
                  },
                ),
                if (_source == 0) ...[
                  const SizedBox(height: 12),
                  if (page.items.isEmpty)
                    const Text(
                      'No episodes are available yet.',
                      style: TextStyle(color: PelevoColors.textMuted),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _MediaImage(
                          artworkUrl: _linkedEpisode?.artworkUrl,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      title: Text(
                        _linkedEpisode?.title ?? 'Select an episode',
                      ),
                      subtitle: Text(
                        _linkedEpisode == null
                            ? 'Choose a claimed episode to link'
                            : 'Linked · ${_linkedEpisode!.showTitle ?? ''}',
                      ),
                      trailing: const Icon(Icons.swap_horiz_rounded),
                      onTap: _pickEpisode,
                    ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: PelevoColors.green.withValues(alpha: .2),
                    child: Icon(
                      _videoPath == null
                          ? Icons.video_file_outlined
                          : Icons.check_rounded,
                      color: PelevoColors.green,
                    ),
                  ),
                  title: Text(
                    _videoPath == null ? 'Choose video' : 'Video selected',
                  ),
                  subtitle: Text(
                    _videoPath == null
                        ? 'Pick a clip. Longer than $reelMaxDurationLabel is trimmed to $reelMaxDurationLabel.'
                        : _videoPath!.split(RegExp(r'[\\/]')).last,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving ? null : _pickVideo,
                ),
                const SizedBox(height: 24),
                const _StepTitle(
                  number: '2.',
                  title: 'Add Details',
                  subtitle: 'Add a title, description, and optional cover.',
                ),
                const SizedBox(height: 10),
                ReelDetailsFields(
                  titleController: _title,
                  descriptionController: _caption,
                  enabled: !_saving,
                ),
                const Text(
                  'Cover',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _coverPath == null
                        ? const CircleAvatar(
                            child: Icon(Icons.image_outlined),
                          )
                        : Image.file(
                            File(_coverPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                  ),
                  title: Text(
                    _coverPath == null ? 'Add Cover' : 'Cover selected',
                    style: const TextStyle(color: PelevoColors.green),
                  ),
                  subtitle: const Text('Choose a cover for your reel'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving ? null : _pickCover,
                ),
                const SizedBox(height: 18),
                const _StepTitle(
                  number: '3.',
                  title: 'Visibility',
                  subtitle: 'Choose who can see your reel.',
                ),
                const SizedBox(height: 10),
                _SourceCard(
                  icon: Icons.public_rounded,
                  title: 'Public',
                  subtitle: 'Anyone on Pelevo can view this reel.',
                  selected: _public,
                  onTap: () => setState(() => _public = true),
                ),
                const SizedBox(height: 10),
                _SourceCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Draft',
                  subtitle: 'Save without publishing to the Reels feed.',
                  selected: !_public,
                  onTap: () => setState(() => _public = false),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: PelevoColors.red),
                  ),
                ],
                if (_saving && _uploadStage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ReelUploadProgressBar(
                    stage: _uploadStage,
                    progress: _uploadProgress,
                  ),
                ],
                const SizedBox(height: 20),
                PelevoButton(
                  label: _saving
                      ? (_uploadStage.isEmpty ? 'Working…' : 'Uploading…')
                      : _public
                          ? 'Create Reel'
                          : 'Save Draft',
                  color: const Color(0xFF55C51F),
                  onPressed: _saving ? null : _createReel,
                ),
                TextButton(
                  onPressed: _saving ? null : _saveDraft,
                  child: const Text(
                    'Save as Draft',
                    style: TextStyle(color: PelevoColors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<StudioEpisode?> showStudioEpisodePicker(
  BuildContext context, {
  required List<StudioEpisode> episodes,
  String? selectedId,
}) {
  return showPelevoSheet<StudioEpisode>(
    context: context,
    isScrollControlled: true,
    heightFactor: .72,
    builder:
        (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PelevoColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change linked episode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose the podcast episode this reel should open.',
                style: TextStyle(color: PelevoColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final episode in episodes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, episode),
                          borderRadius: PelevoRadii.card,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: PelevoColors.surface,
                              borderRadius: PelevoRadii.card,
                              border: Border.all(
                                color:
                                    episode.id == selectedId
                                        ? PelevoColors.green
                                        : PelevoColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _MediaImage(
                                    artworkUrl: episode.artworkUrl,
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        episode.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (episode.showTitle != null &&
                                              episode.showTitle!.isNotEmpty)
                                            episode.showTitle!,
                                          if (episode.subtitle.isNotEmpty)
                                            episode.subtitle,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: PelevoColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
  );
}

class _StudioLoadError extends StatelessWidget {
  const _StudioLoadError({
    required this.error,
    required this.onRetry,
    required this.onClaim,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final failure =
        error is ApiFailure
            ? error as ApiFailure
            : error is DioException
            ? apiFailureFromDio(error as DioException)
            : const ApiFailure(
              code: 'UNEXPECTED',
              message: 'Creator Studio could not be loaded. Please try again.',
            );
    final needsClaim =
        failure.code == 'CLAIM_REQUIRED' || failure.statusCode == 403;
    return Padding(
      padding: const EdgeInsets.all(PelevoSpacing.xl),
      child: Column(
        children: [
          Text(
            needsClaim
                ? 'A verified show claim is required.'
                : failure.message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PelevoSpacing.sm),
          TextButton(
            onPressed: needsClaim ? onClaim : onRetry,
            child: Text(needsClaim ? 'Claim a podcast' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({
    required this.width,
    required this.height,
    this.asset = '',
    this.artworkUrl,
    this.reelCover = false,
  });

  final String asset;
  final String? artworkUrl;
  final double width;
  final double height;
  final bool reelCover;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: PelevoColors.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(
        reelCover ? Icons.movie_rounded : Icons.podcasts_rounded,
      ),
    );
    if (artworkUrl != null && artworkUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: artworkUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
      );
    }
    if (asset.isEmpty) {
      return fallback;
    }
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _CreatorPage extends StatelessWidget {
  const _CreatorPage({required this.selectedTab, required this.child});
  final int selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/creator-studio'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('Creator Studio'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Creator notifications',
          onPressed: () => context.push('/screen/notifications-1'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: 0,
      onDestinationSelected: context.openPelevoTab,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PodcastHeader(),
            const SizedBox(height: 12),
            _StudioTabs(selected: selectedTab),
            const Divider(height: 1),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ),
  );
}

class _PodcastHeader extends ConsumerWidget {
  const _PodcastHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = selectedStudioShow(ref);
    final title = show?.title;
    final episodeCount = show?.episodeCount;
    return InkWell(
      onTap: () => context.push('/screen/creator-studios'),
      borderRadius: PelevoRadii.card,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PelevoColors.surface,
          borderRadius: PelevoRadii.card,
          border: Border.all(color: PelevoColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _MediaImage(
                asset: 'assets/creator/relationship_cover.png',
                artworkUrl: show?.artworkUrl,
                width: 54,
                height: 54,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title == null || title.isEmpty
                              ? 'No claimed show yet'
                              : title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (show != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: PelevoColors.green,
                        ),
                      ],
                    ],
                  ),
                  if (episodeCount != null)
                    Text(
                      '$episodeCount ${episodeCount == 1 ? 'Episode' : 'Episodes'}',
                      style: const TextStyle(
                        color: PelevoColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _StudioTabs extends StatelessWidget {
  const _StudioTabs({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < 5; i++)
          InkWell(
            onTap: () {
              switch (i) {
                case 0:
                  context.go('/screen/creator-dashboard');
                  return;
                case 1:
                  context.go('/screen/creator-episodes');
                  return;
                case 2:
                  context.go('/screen/creator-reels');
                  return;
                case 3:
                  context.go('/screen/creator-audience');
                  return;
                case 4:
                  context.go('/screen/creator-monetization');
                  return;
                default:
                  context.showPelevoMessage(
                    '${const ['Overview', 'Episodes', 'Reels', 'Audience', 'Monetization'][i]} tools',
                  );
              }
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        selected == i ? PelevoColors.green : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                const [
                  'Overview',
                  'Episodes',
                  'Reels',
                  'Audience',
                  'Monetization',
                ][i],
                style: TextStyle(
                  color:
                      selected == i
                          ? PelevoColors.green
                          : PelevoColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CreatorMediaTile extends StatelessWidget {
  const _CreatorMediaTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.artworkUrl,
    this.status,
    this.reelCover = false,
    this.onMore,
  });
  final String title;
  final String subtitle;
  final String? artworkUrl;
  final String? status;
  final bool reelCover;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Card(
    color: PelevoColors.surface,
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: PelevoRadii.card,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _MediaImage(
                artworkUrl: artworkUrl,
                width: 76,
                height: 76,
                reelCover: reelCover,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Content options',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      onMore ??
                      () => context.showPelevoMessage('Content options'),
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                ),
                if (status != null)
                  Text(
                    status!,
                    style: const TextStyle(
                      color: PelevoColors.green,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PelevoColors.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: PelevoColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 30),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: const TextStyle(
                color: PelevoColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });
  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$number $title',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      Text(
        subtitle,
        style: const TextStyle(color: PelevoColors.textMuted, fontSize: 11),
      ),
    ],
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: PelevoRadii.card,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PelevoColors.surface,
        borderRadius: PelevoRadii.card,
        border: Border.all(
          color: selected ? PelevoColors.green : PelevoColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                selected
                    ? PelevoColors.green.withValues(alpha: .2)
                    : PelevoColors.surfaceHigh,
            child: Icon(icon, color: selected ? PelevoColors.green : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PelevoColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: PelevoColors.green),
        ],
      ),
    ),
  );
}

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 50),
    child: Column(
      children: [
        Icon(Icons.drafts_outlined, size: 48, color: PelevoColors.textDim),
        SizedBox(height: 10),
        Text('No creator drafts yet'),
      ],
    ),
  );
}
