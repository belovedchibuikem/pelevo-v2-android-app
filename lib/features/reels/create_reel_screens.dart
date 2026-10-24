import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/creator/creator_content_screens.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import 'package:pelevo/features/reels/reel_create_service.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reel_limits.dart';
import 'package:pelevo/features/reels/reel_upload.dart';
import 'package:pelevo/features/reels/reel_upload_progress.dart';
import 'package:video_player/video_player.dart';

bool get _isFlutterTest {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

/// Full-screen create hub (catalog + deep link). Bottom sheet uses the same actions.
class CreateReelHubScreen extends StatelessWidget {
  const CreateReelHubScreen({super.key});

  @override
  Widget build(BuildContext context) => PelevoPage(
    scrollable: false,
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/reels'),
        icon: const Icon(Icons.close_rounded),
      ),
      title: const Text('Create Reel'),
    ),
    child: ListView(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.xxl),
      children: [
            Text(
              'Record a short clip, upload from your library, or continue a draft.',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            _CreateActionTile(
              icon: Icons.videocam_rounded,
              title: 'Record',
              subtitle: 'Capture a new Pelevo Reel',
              onTap: () => context.push('/screen/reels-record'),
            ),
            _CreateActionTile(
              icon: Icons.upload_rounded,
              title: 'Upload',
              subtitle: 'Choose a video from your device',
              onTap: () => context.push('/screen/reels-upload'),
            ),
            _CreateActionTile(
              icon: Icons.drafts_outlined,
              title: 'Drafts',
              subtitle: 'Finish an unfinished reel',
              onTap: () => context.push('/screen/reels-drafts'),
            ),
      ],
    ),
  );
}

class ReelRecordScreen extends StatefulWidget {
  const ReelRecordScreen({super.key, this.autoLaunch = true});

  final bool autoLaunch;

  @override
  State<ReelRecordScreen> createState() => _ReelRecordScreenState();
}

class _ReelRecordScreenState extends State<ReelRecordScreen> {
  bool _launching = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (widget.autoLaunch && !_isFlutterTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
    }
  }

  Future<void> _openCamera() async {
    if (_launching) return;
    setState(() {
      _launching = true;
      _status = 'Opening camera…';
    });
    final draft = await ReelCreateService.instance.captureFromCamera();
    if (!mounted) return;
    setState(() => _launching = false);
    if (draft != null) {
      context.pushReplacement('/screen/reels-editor');
      return;
    }
    final error = ReelCreateService.instance.lastError;
    setState(() {
      _status = error == 'Recording cancelled.'
          ? 'Recording cancelled. Tap below to try again.'
          : (error ?? 'Camera unavailable. Tap below to try again.');
    });
    if (error != null && error != 'Recording cancelled.') {
      context.showPelevoMessage(error);
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/reels'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Record Reel'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 48),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PelevoColors.purple.withValues(alpha: 0.18),
                border: Border.all(color: PelevoColors.purple, width: 2),
              ),
              child: Icon(
                _launching ? Icons.hourglass_top_rounded : Icons.videocam_rounded,
                size: 64,
                color: PelevoColors.purple,
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'Capture a new Pelevo Reel',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Text(
              _status ??
                  'Up to $reelMaxDurationLabel. Longer videos are trimmed to the first $reelMaxDurationLabel. Camera and microphone access are required.',
              style: TextStyle(color: context.pelevo.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            PelevoButton(
              label: _launching ? 'Opening camera…' : 'Open Camera',
              color: PelevoColors.purple,
              onPressed: _launching ? null : _openCamera,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            TextButton(
              onPressed: _launching
                  ? null
                  : () => context.push('/screen/reels-upload'),
              child: const Text('Upload instead'),
            ),
            const SizedBox(height: PelevoSpacing.lg),
          ],
        ),
      ),
    ),
  );
}

class ReelUploadScreen extends StatefulWidget {
  const ReelUploadScreen({super.key, this.autoLaunch = true});

  final bool autoLaunch;

  @override
  State<ReelUploadScreen> createState() => _ReelUploadScreenState();
}

class _ReelUploadScreenState extends State<ReelUploadScreen> {
  bool _launching = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (widget.autoLaunch && !_isFlutterTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openGallery());
    }
  }

  Future<void> _openGallery() async {
    if (_launching) return;
    setState(() {
      _launching = true;
      _status = 'Opening gallery…';
    });
    final draft = await ReelCreateService.instance.pickFromGallery();
    if (!mounted) return;
    setState(() => _launching = false);
    if (draft != null) {
      context.pushReplacement('/screen/reels-editor');
      return;
    }
    final error = ReelCreateService.instance.lastError;
    setState(() {
      _status = error == 'Upload cancelled.'
          ? 'No video selected. Tap below to choose again.'
          : (error ?? 'Gallery unavailable. Tap below to try again.');
    });
    if (error != null && error != 'Upload cancelled.') {
      context.showPelevoMessage(error);
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/reels'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Upload Reel'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 48),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PelevoColors.purple.withValues(alpha: 0.18),
                border: Border.all(color: PelevoColors.purple, width: 2),
              ),
              child: Icon(
                _launching ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                size: 64,
                color: PelevoColors.purple,
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'Choose a video from your device',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Text(
              _status ??
                  'Select a clip from your library. Videos longer than $reelMaxDurationLabel are trimmed to the first $reelMaxDurationLabel.',
              style: TextStyle(color: context.pelevo.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            PelevoButton(
              label: _launching ? 'Opening gallery…' : 'Choose Video',
              color: PelevoColors.purple,
              onPressed: _launching ? null : _openGallery,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            TextButton(
              onPressed: _launching
                  ? null
                  : () => context.push('/screen/reels-record'),
              child: const Text('Record instead'),
            ),
            const SizedBox(height: PelevoSpacing.lg),
          ],
        ),
      ),
    ),
  );
}

class ReelDraftsScreen extends ConsumerStatefulWidget {
  const ReelDraftsScreen({super.key});

  @override
  ConsumerState<ReelDraftsScreen> createState() => _ReelDraftsScreenState();
}

class _ReelDraftsScreenState extends ConsumerState<ReelDraftsScreen> {
  @override
  void initState() {
    super.initState();
    ReelCreateService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(reelDraftsProvider);
    return ListenableBuilder(
      listenable: ReelCreateService.instance,
      builder: (context, _) {
        final local = ReelCreateService.instance.drafts;
        return PelevoPage(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.go('/screen/reels'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Drafts'),
            actions: [
              IconButton(
                tooltip: 'Record new',
                onPressed: () => context.push('/screen/reels-record'),
                icon: const Icon(Icons.videocam_rounded),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: server.when(
                loading:
                    () =>
                        local.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : _localList(local),
                error:
                    (error, _) => Column(
                      children: [
                        for (final draft in local) _localTile(draft),
                        Padding(
                          padding: const EdgeInsets.all(PelevoSpacing.md),
                          child: Column(
                            children: [
                              Text(
                                reelFailure(error).message,
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed:
                                    () => ref.invalidate(reelDraftsProvider),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                data: (drafts) {
                  final localIds = local.map((item) => item.id).toSet();
                  final remote =
                      drafts
                          .where((item) => !localIds.contains(item.id))
                          .toList();
                  if (local.isEmpty && remote.isEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 72),
                        Icon(
                          Icons.drafts_outlined,
                          size: 56,
                          color: context.pelevo.textMuted,
                        ),
                        const SizedBox(height: PelevoSpacing.md),
                        Text(
                          'No drafts yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: PelevoSpacing.sm),
                        Text(
                          'Record or upload a reel, then save it as a draft to finish later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                        const SizedBox(height: PelevoSpacing.lg),
                        PelevoButton(
                          label: 'Record Reel',
                          color: PelevoColors.purple,
                          onPressed: () => context.push('/screen/reels-record'),
                        ),
                      ],
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ...[
                        for (var index = 0; index < local.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: PelevoSpacing.sm,
                            ),
                            child: _localTile(local[index]),
                          ),
                      ],
                      for (final draft in remote)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: PelevoSpacing.sm,
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: context.pelevo.border),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: PelevoColors.purple.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.drafts_outlined,
                                color: PelevoColors.purple,
                              ),
                            ),
                            title: Text(draft.displayTitle),
                            subtitle: Text(
                              draft.updatedAt ?? 'Saved on Pelevo',
                              style: TextStyle(
                                color: context.pelevo.textMuted,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete draft',
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(reelRepositoryProvider)
                                      .deleteDraft(draft.id);
                                  ref.invalidate(reelDraftsProvider);
                                  if (context.mounted) {
                                    context.showPelevoMessage('Draft deleted');
                                  }
                                } on Object catch (error) {
                                  if (context.mounted) {
                                    context.showPelevoMessage(
                                      reelFailure(error).message,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                            onTap: () {
                              ref
                                  .read(editingReelDraftProvider.notifier)
                                  .select(draft);
                              ReelCreateService.instance.activeDraft = null;
                              context.push('/screen/reels-editor');
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _localList(List<ReelDraft> drafts) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: drafts.length,
    separatorBuilder: (_, __) => const SizedBox(height: PelevoSpacing.sm),
    itemBuilder: (context, index) => _localTile(drafts[index]),
  );

  Widget _localTile(ReelDraft draft) {
    final service = ReelCreateService.instance;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.pelevo.border),
      ),
      leading: CircleAvatar(
        backgroundColor: PelevoColors.purple.withValues(alpha: 0.2),
        child: Icon(
          draft.source == ReelCaptureSource.camera
              ? Icons.videocam_rounded
              : Icons.upload_rounded,
          color: PelevoColors.purple,
        ),
      ),
      title: Text(
        draft.caption.trim().isNotEmpty ? draft.caption.trim() : draft.name,
      ),
      subtitle: Text(
        _relative(draft.createdAt),
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      trailing: IconButton(
        tooltip: 'Delete draft',
        onPressed: () async {
          await service.deleteDraft(draft.id);
          if (mounted) {
            context.showPelevoMessage('Draft deleted');
          }
        },
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      onTap: () {
        service.openDraft(draft);
        ref.read(editingReelDraftProvider.notifier).select(null);
        context.push('/screen/reels-editor');
      },
    );
  }

  String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class ReelEditorScreen extends ConsumerStatefulWidget {
  const ReelEditorScreen({super.key});

  @override
  ConsumerState<ReelEditorScreen> createState() => _ReelEditorScreenState();
}

class _ReelEditorScreenState extends ConsumerState<ReelEditorScreen> {
  final _caption = TextEditingController();
  final _name = TextEditingController();
  VideoPlayerController? _player;
  String _tag = 'Mindset';
  bool _saving = false;
  String _uploadStage = '';
  double? _uploadProgress;
  String? _serverDraftId;
  String? _coverPath;
  StudioEpisode? _linkedEpisode;

  static const _tags = [
    'Mindset',
    'Business',
    'Faith',
    'Health',
    'Comedy',
    'News',
  ];

  @override
  void initState() {
    super.initState();
    final draft = ReelCreateService.instance.activeDraft;
    final server = ref.read(editingReelDraftProvider);
    if (draft != null) {
      _caption.text = draft.caption;
      _name.text = draft.name;
      _tag = draft.tag;
      _initPlayer(draft.path);
    } else if (server != null) {
      _serverDraftId = server.id;
      _caption.text = server.caption ?? '';
      _name.text = server.title ?? '';
    }
  }

  Future<void> _initPlayer(String path) async {
    try {
      final controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _player = controller);
    } catch (_) {
      if (mounted) {
        setState(() => _player = null);
      }
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _name.dispose();
    _player?.dispose();
    super.dispose();
  }

  ReelDraft? get _draft => ReelCreateService.instance.activeDraft;

  ReelDraft _compose() {
    final base = _draft!;
    return base.copyWith(
      caption: _caption.text.trim(),
      name: _name.text.trim().isEmpty ? base.name : _name.text.trim(),
      tag: _tag,
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      if (_draft != null) {
        await ReelCreateService.instance.saveDraft(_compose());
      }
      final saved = await ref.read(reelRepositoryProvider).saveDraft(
        id: _serverDraftId,
        title: _name.text.trim(),
        caption: _caption.text.trim(),
      );
      _serverDraftId = saved.id;
      ref.read(editingReelDraftProvider.notifier).select(saved);
      ref.invalidate(reelDraftsProvider);
      if (!mounted) return;
      context.showPelevoMessage('Draft saved');
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    final local = _draft;
    if (local == null) {
      context.showPelevoMessage(
        'Record or upload a video before publishing. Caption-only drafts cannot be published without media.',
      );
      return;
    }
    if (kIsWeb) {
      context.showPelevoMessage('Reel publish requires a mobile or desktop file upload.');
      return;
    }
    setState(() {
      _saving = true;
      _uploadStage = '';
      _uploadProgress = null;
    });
    try {
      final composed = _compose();
      await ReelCreateService.instance.saveDraft(composed);
      final result = await ref.read(reelUploadRepositoryProvider).publishFile(
        file: File(composed.path),
        title: composed.name.trim().isEmpty ? null : composed.name.trim(),
        caption: composed.caption,
        draftId: _serverDraftId,
        episodeId: _linkedEpisode?.id,
        showId: _linkedEpisode?.showId,
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
          await ref.read(reelUploadRepositoryProvider).uploadCover(
            reelId: result.id,
            file: File(cover),
          );
        } on Object {
          if (mounted) {
            context.showPelevoMessage('Reel uploaded. Cover could not be saved.');
          }
        }
      }
      await ReelCreateService.instance.publishActive();
      if (_serverDraftId != null) {
        try {
          await ref.read(reelRepositoryProvider).deleteDraft(_serverDraftId!);
        } on Object {
          // Local publish already succeeded.
        }
      }
      ref.invalidate(reelDraftsProvider);
      ref.invalidate(reelsFeedProvider(ReelsFeedKind.forYou));
      if (!mounted) return;
      context.showPelevoMessage(
        result.truncated
            ? (result.truncatedMessage ?? reelTruncatedMessage)
            : result.state == 'processing'
            ? 'Your reel is publishing now and will appear in For You as soon as processing finishes.'
            : 'Reel published.',
      );
      context.go('/screen/reels');
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDraft = _draft != null || _serverDraftId != null;
    if (!hasDraft) {
      return PelevoPage(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/screen/reels'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Edit Reel'),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No reel selected',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              const SizedBox(height: PelevoSpacing.md),
              PelevoButton(
                label: 'Record a Reel',
                color: PelevoColors.purple,
                onPressed: () => context.go('/screen/reels-record'),
              ),
            ],
          ),
        ),
      );
    }

    ref.watch(studioEpisodesProvider);
    return PelevoPage(
      scrollable: false,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/reels'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Edit Reel'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveDraft,
            child: Text(_saving ? 'Saving…' : 'Save draft'),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            children: [
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: context.pelevo.surfaceHigh,
                    child: _player != null && _player!.value.isInitialized
                        ? GestureDetector(
                            onTap: () {
                              final player = _player!;
                              if (player.value.isPlaying) {
                                player.pause();
                              } else {
                                player.play();
                              }
                              setState(() {});
                            },
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _player!.value.size.width,
                                height: _player!.value.size.height,
                                child: VideoPlayer(_player!),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.movie_creation_outlined,
                                  size: 48,
                                  color: context.pelevo.textMuted,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Preview unavailable',
                                  style: TextStyle(
                                    color: context.pelevo.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              ReelDetailsFields(
                titleController: _name,
                descriptionController: _caption,
                enabled: !_saving,
              ),
              const SizedBox(height: PelevoSpacing.md),
              Text(
                'Tag',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    ChoiceChip(
                      label: Text(tag),
                      selected: _tag == tag,
                      onSelected: (_) => setState(() => _tag = tag),
                    ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: Text(
                  _linkedEpisode?.title ?? 'Link an episode (optional)',
                ),
                subtitle: Text(
                  _linkedEpisode == null
                      ? 'Choose a claimed episode'
                      : _linkedEpisode!.showTitle ?? '',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _saving
                    ? null
                    : () async {
                        final page = ref.read(studioEpisodesProvider).asData?.value;
                        if (page == null) {
                          ref.invalidate(studioEpisodesProvider);
                          context.showPelevoMessage('Loading your episodes…');
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
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  _coverPath == null ? 'Add cover (optional)' : 'Cover selected',
                ),
                subtitle: const Text('Choose a still image for the reel'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _saving
                    ? null
                    : () async {
                        final path =
                            await ReelCreateService.instance.pickCoverImage();
                        if (path != null && mounted) {
                          setState(() => _coverPath = path);
                        }
                      },
              ),
              const SizedBox(height: PelevoSpacing.lg),
              if (_saving && _uploadStage.isNotEmpty) ...[
                ReelUploadProgressBar(
                  stage: _uploadStage,
                  progress: _uploadProgress,
                ),
                const SizedBox(height: PelevoSpacing.md),
              ],
              PelevoButton(
                label: _saving ? 'Uploading…' : 'Publish Reel',
                color: PelevoColors.purple,
                onPressed: _saving ? null : _publish,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push('/screen/reels-drafts'),
                child: const Text('View all drafts'),
              ),
              const SizedBox(height: PelevoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateActionTile extends StatelessWidget {
  const _CreateActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    leading: CircleAvatar(
      backgroundColor: PelevoColors.purple.withValues(alpha: 0.2),
      child: Icon(icon, color: PelevoColors.purple),
    ),
    title: Text(title),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: context.pelevo.textMuted),
    ),
    onTap: onTap,
  );
}
