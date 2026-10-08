import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/home/home_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> commentScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'episode-comments',
    section: 'Comments',
    title: 'Episode Comments',
    builder: _buildEpisodeComments,
  ),
  const PelevoScreenSpec(
    id: 'episode-comments-empty',
    section: 'Comments',
    title: 'Episode Comments Empty',
    builder: _buildEpisodeCommentsEmpty,
  ),
  const PelevoScreenSpec(
    id: 'episode-comment-replies',
    section: 'Comments',
    title: 'Comment Replies',
    builder: _buildEpisodeReplies,
  ),
  const PelevoScreenSpec(
    id: 'reel-comments',
    section: 'Comments',
    title: 'Reel Comments',
    builder: _buildReelComments,
  ),
  const PelevoScreenSpec(
    id: 'comment-report',
    section: 'Comments',
    title: 'Report Comment',
    builder: _buildReport,
  ),
]);

Widget _buildEpisodeComments(BuildContext context) => const CommentThreadPage(
  type: CommentTargetType.episode,
  title: 'Episode Comments',
);

Widget _buildEpisodeCommentsEmpty(BuildContext context) =>
    const CommentThreadPage(
      type: CommentTargetType.episode,
      title: 'Episode Comments',
      subtitle: 'Be the first to start this conversation',
      emptyCatalog: true,
    );

Widget _buildEpisodeReplies(BuildContext context) => const CommentRepliesPage();

Widget _buildReelComments(BuildContext context) => const CommentThreadPage(
  type: CommentTargetType.reel,
  title: 'Reel Comments',
);

Widget _buildReport(BuildContext context) => const CommentReportScreen();

Future<void> showPelevoCommentSheet(
  BuildContext context, {
  required CommentTarget target,
  required String title,
}) => showPelevoSheet<void>(
  context: context,
  isScrollControlled: true,
  heightFactor: .78,
  builder:
      (context) =>
          CommentThreadPanel(target: target, title: title, asSheet: true),
);

class CommentThreadPage extends ConsumerWidget {
  const CommentThreadPage({
    required this.type,
    required this.title,
    this.subtitle,
    this.emptyCatalog = false,
    super.key,
  });

  final CommentTargetType type;
  final String title;
  final String? subtitle;
  final bool emptyCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCommentTargetProvider);
    final home = ref.watch(homeDiscoverProvider).asData?.value;
    CommentTarget? target;
    var resolvedSubtitle = subtitle;
    if (!emptyCatalog) {
      if (selected != null && selected.type == type) {
        target = selected;
      } else if (type == CommentTargetType.episode) {
        final item =
            home == null || home.newEpisodes.isEmpty
                ? null
                : home.newEpisodes.first;
        if (item != null) {
          target = CommentTarget.episode(item.id);
          resolvedSubtitle ??=
              item.showTitle == null || item.showTitle!.isEmpty
                  ? item.title
                  : '${item.title} · ${item.showTitle}';
        }
      }
    }
    return PelevoPage(
      scrollable: false,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go(
                        type == CommentTargetType.reel
                            ? '/screen/reels'
                            : '/screen/episode-details',
                      ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(title),
        centerTitle: true,
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: type == CommentTargetType.reel ? 4 : 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (resolvedSubtitle != null && resolvedSubtitle.isNotEmpty)
                Text(
                  resolvedSubtitle,
                  style: const TextStyle(color: PelevoColors.textMuted),
                ),
              const SizedBox(height: 10),
              Expanded(child: CommentThreadPanel(target: target)),
            ],
          ),
        ),
      ),
    );
  }
}

class CommentRepliesPage extends ConsumerWidget {
  const CommentRepliesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentId = ref.watch(selectedCommentIdProvider);
    final target = ref.watch(selectedCommentTargetProvider);
    return PelevoPage(
      scrollable: false,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/screen/episode-comments'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Replies'),
        centerTitle: true,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child:
              parentId == null || target == null
                  ? const Center(
                    child: Text('This comment is no longer available.'),
                  )
                  : CommentThreadPanel(
                    target: target,
                    focusedParentId: parentId,
                  ),
        ),
      ),
    );
  }
}

class CommentThreadPanel extends ConsumerStatefulWidget {
  const CommentThreadPanel({
    this.target,
    this.title,
    this.asSheet = false,
    this.creatorTools,
    this.focusedParentId,
    this.initialReplyTo,
    super.key,
  });

  final CommentTarget? target;
  final String? title;
  final bool asSheet;
  final bool? creatorTools;
  final String? focusedParentId;
  final PelevoComment? initialReplyTo;

  @override
  ConsumerState<CommentThreadPanel> createState() => _CommentThreadPanelState();
}

class _CommentThreadPanelState extends ConsumerState<CommentThreadPanel> {
  final _controller = TextEditingController();
  CommentSort _sort = CommentSort.newest;
  PelevoComment? _replyTo;
  bool _posting = false;

  bool get _creatorTools =>
      widget.creatorTools ??
      ref.watch(authSessionProvider).creatorAccess;

  CommentThreadArgs? get _args {
    final target = widget.target;
    if (target == null) return null;
    return CommentThreadArgs(
      target: target,
      sort: _sort,
    );
  }

  @override
  void initState() {
    super.initState();
    _replyTo = widget.initialReplyTo;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final args = _args;
    final text = _controller.text.trim();
    if (args == null || text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ref.read(commentsProvider(args).notifier).post(
        text,
        parentId: _replyTo?.id ?? widget.focusedParentId,
      );
      final reply = _replyTo != null || widget.focusedParentId != null;
      _controller.clear();
      setState(
        () => _replyTo = widget.focusedParentId != null ? _replyTo : null,
      );
      if (mounted) {
        context.showPelevoMessage(reply ? 'Reply posted' : 'Comment posted');
      }
    } catch (error) {
      if (mounted) context.showPelevoMessage(commentFailure(error).message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final commentsAsync =
        args == null ? null : ref.watch(commentsProvider(args));
    final comments = commentsAsync?.asData?.value ?? const <PelevoComment>[];
    final parents =
        widget.focusedParentId == null
            ? comments.where((comment) => comment.parentId == null).toList()
            : comments
                .where((comment) => comment.id == widget.focusedParentId)
                .toList();
    return Padding(
      padding:
          widget.asSheet
              ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
              : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.asSheet) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PelevoColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title ?? 'Comments'} · ${comments.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close comments',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<CommentSort>(
              segments: const [
                ButtonSegment(value: CommentSort.newest, label: Text('New')),
                ButtonSegment(value: CommentSort.top, label: Text('Top')),
                ButtonSegment(
                  value: CommentSort.creator,
                  label: Text('Creator'),
                ),
              ],
              selected: {_sort},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged:
                  (value) => setState(() => _sort = value.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                args == null
                    ? const _EmptyComments()
                    : commentsAsync!.when(
                      skipLoadingOnRefresh: false,
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error:
                          (error, _) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(commentFailure(error).message),
                              TextButton(
                                onPressed:
                                    () => ref.invalidate(
                                      commentsProvider(args),
                                    ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                      data: (_) {
                        if (parents.isEmpty) return const _EmptyComments();
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: parents.length,
                          itemBuilder: (context, index) {
                            final parent = parents[index];
                            final replies =
                                comments
                                    .where(
                                      (comment) =>
                                          comment.parentId == parent.id,
                                    )
                                    .toList();
                            return Column(
                              children: [
                                CommentTile(
                                  comment: parent,
                                  creatorTools: _creatorTools,
                                  args: args,
                                  onReply:
                                      () => setState(() => _replyTo = parent),
                                ),
                                for (final reply in replies)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: CommentTile(
                                      comment: reply,
                                      creatorTools: _creatorTools,
                                      compact: true,
                                      args: args,
                                      onReply:
                                          () =>
                                              setState(() => _replyTo = parent),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
          ),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: PelevoColors.surfaceHigh,
                borderRadius: PelevoRadii.card,
                child: ListTile(
                  dense: true,
                  title: Text(
                    'Replying to ${_replyTo!.handleLabel.isEmpty ? _replyTo!.authorName : _replyTo!.handleLabel}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: CommentService.maxLength,
                  minLines: 1,
                  maxLines: 3,
                  enabled: args != null && !_posting,
                  decoration: InputDecoration(
                    hintText:
                        _replyTo == null ? 'Add a comment…' : 'Write a reply…',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton(
                tooltip: _replyTo == null ? 'Send comment' : 'Send reply',
                onPressed: args == null || _posting ? null : _submit,
                icon: Icon(
                  Icons.send_rounded,
                  color: PelevoColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommentTile extends ConsumerWidget {
  const CommentTile({
    required this.comment,
    required this.onReply,
    required this.args,
    this.creatorTools = false,
    this.compact = false,
    super.key,
  });

  final PelevoComment comment;
  final VoidCallback onReply;
  final CommentThreadArgs args;
  final bool creatorTools;
  final bool compact;

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    await showPelevoSheet<void>(
      context: context,
      builder:
          (sheet) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (comment.canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit comment'),
                    onTap: () {
                      Navigator.pop(sheet);
                      _edit(context, ref);
                    },
                  ),
                if (comment.isMine)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Delete'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      try {
                        await ref
                            .read(commentsProvider(args).notifier)
                            .delete(comment.id);
                        if (context.mounted) {
                          context.showPelevoMessage('Comment deleted');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          context.showPelevoMessage(
                            commentFailure(error).message,
                          );
                        }
                      }
                    },
                  ),
                if (creatorTools && comment.parentId == null)
                  ListTile(
                    leading: const Icon(Icons.push_pin_outlined),
                    title: Text(comment.pinned ? 'Unpin' : 'Pin comment'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      try {
                        await ref
                            .read(commentsProvider(args).notifier)
                            .togglePin(comment);
                      } catch (error) {
                        if (context.mounted) {
                          context.showPelevoMessage(
                            commentFailure(error).message,
                          );
                        }
                      }
                    },
                  ),
                if (creatorTools)
                  ListTile(
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Hide comment'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      try {
                        await ref
                            .read(commentsProvider(args).notifier)
                            .hide(comment);
                        if (context.mounted) {
                          context.showPelevoMessage('Comment hidden');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          context.showPelevoMessage(
                            commentFailure(error).message,
                          );
                        }
                      }
                    },
                  ),
                if (!comment.isMine)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Report'),
                    onTap: () {
                      Navigator.pop(sheet);
                      ref
                          .read(reportingCommentProvider.notifier)
                          .select(comment);
                      context.push('/screen/comment-report');
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: comment.body);
    final next = await showDialog<String>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: const Text('Edit comment'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              maxLength: CommentService.maxLength,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: PelevoColors.purple,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (next == null || !context.mounted) return;
    try {
      await ref.read(commentsProvider(args).notifier).edit(comment.id, next);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(commentFailure(error).message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 10 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: compact ? 14 : 18,
          backgroundColor:
              comment.isCreator
                  ? PelevoColors.green.withValues(alpha: .2)
                  : PelevoColors.surfaceHigh,
          child: Text(comment.initials, style: const TextStyle(fontSize: 12)),
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
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (comment.isCreator) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PelevoColors.green.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Creator',
                        style: TextStyle(
                          color: PelevoColors.green,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                  if (comment.pinned) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 12,
                      color: PelevoColors.yellow,
                    ),
                  ],
                  if (comment.hidden) ...[
                    const SizedBox(width: 5),
                    const Text(
                      'Hidden',
                      style: TextStyle(
                        color: PelevoColors.textDim,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    comment.relativeTime,
                    style: const TextStyle(
                      color: PelevoColors.textDim,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Comment actions',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openActions(context, ref),
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  ),
                ],
              ),
              Text(comment.body),
              const SizedBox(height: 6),
              Row(
                children: [
                  InkWell(
                    onTap: onReply,
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        color: PelevoColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () async {
                      try {
                        await ref
                            .read(commentsProvider(args).notifier)
                            .toggleLike(comment);
                      } catch (error) {
                        if (context.mounted) {
                          context.showPelevoMessage(
                            commentFailure(error).message,
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          comment.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color:
                              comment.likedByMe
                                  ? PelevoColors.red
                                  : PelevoColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CommentReportScreen extends ConsumerStatefulWidget {
  const CommentReportScreen({super.key});

  @override
  ConsumerState<CommentReportScreen> createState() =>
      _CommentReportScreenState();
}

class _CommentReportScreenState extends ConsumerState<CommentReportScreen> {
  String _reason = 'Spam';
  bool _submitting = false;

  Future<void> _submit() async {
    final comment = ref.read(reportingCommentProvider);
    if (comment == null) {
      context.showPelevoMessage('No comment is selected to report.');
      return;
    }
    final code = reportReasonCodes[_reason];
    if (code == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(commentRepositoryProvider).report(
        commentId: comment.id,
        reason: code,
        details: _reason == 'Spoiler' ? 'Spoiler' : null,
      );
      if (!mounted) return;
      context.showPelevoMessage('Report submitted');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/screen/episode-comments');
      }
    } catch (error) {
      if (mounted) context.showPelevoMessage(commentFailure(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = ref.watch(reportingCommentProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/screen/episode-comments'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Report Comment'),
        centerTitle: true,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                comment == null
                    ? 'Choose why you are reporting this comment.'
                    : 'Reporting ${comment.handleLabel.isEmpty ? comment.authorName : comment.handleLabel}',
                style: const TextStyle(color: PelevoColors.textMuted),
              ),
              const SizedBox(height: 16),
              for (final reason in const [
                'Spam',
                'Harassment',
                'Spoiler',
                'Hate or abuse',
                'Other',
              ])
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: reason,
                  groupValue: _reason,
                  activeColor: PelevoColors.purple,
                  title: Text(reason),
                  onChanged:
                      (value) => setState(() => _reason = value ?? _reason),
                ),
              const SizedBox(height: 16),
              PelevoButton(
                label: _submitting ? 'Submitting…' : 'Submit Report',
                color: PelevoColors.purple,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 42,
          color: PelevoColors.textDim,
        ),
        SizedBox(height: 10),
        Text('Be the first to comment'),
        Text(
          'Share what this made you think or feel.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    ),
  );
}
