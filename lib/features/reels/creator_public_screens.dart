import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_link_text.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/gifts/gift_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reel_player.dart';

String? creatorIdFromRoute(BuildContext context, String? selected) {
  final params = GoRouterState.of(context).uri.queryParameters;
  for (final key in const ['creatorId', 'id']) {
    final value = params[key]?.trim() ?? '';
    if (value.isNotEmpty &&
        value != 'creator-profile' &&
        value != 'creator-stories') {
      return value;
    }
  }
  final fallback = selected?.trim();
  return (fallback == null || fallback.isEmpty) ? null : fallback;
}

Future<void> openPublicCreatorProfile(
  BuildContext context,
  String creatorProfileId,
) async {
  final id = creatorProfileId.trim();
  if (id.isEmpty) return;
  ProviderScope.containerOf(
    context,
  ).read(selectedCreatorProfileIdProvider.notifier).select(id);
  await context.push('/screen/creator-profile?id=$id');
}

Future<void> sharePublicCreatorProfile(
  BuildContext context,
  PublicCreatorProfile profile,
) async {
  final handle = profile.handleLabel;
  final title =
      handle.isEmpty ? profile.displayName : '${profile.displayName} ($handle)';
  final url = catalogShareCreatorLink(profile.id);
  try {
    final result = await pelevoShare(
      context: context,
      text: '$title on Pelevo\n$url',
      title: title,
      subject: title,
    );
    if (result.status == ShareResultStatus.unavailable) {
      await _copyCreatorLink(context, url);
    }
  } on Object {
    await _copyCreatorLink(context, url);
  }
}

Future<void> _copyCreatorLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    context.showPelevoMessage('Profile link copied');
  }
}

Future<void> openCreatorReelStories(
  BuildContext context, {
  required String creatorProfileId,
  String? reelId,
}) async {
  final container = ProviderScope.containerOf(context);
  container
      .read(selectedCreatorProfileIdProvider.notifier)
      .select(creatorProfileId);
  container.read(selectedCreatorReelIdProvider.notifier).select(reelId);
  await context.push(
    Uri(
      path: '/screen/creator-stories',
      queryParameters: {
        'id': creatorProfileId,
        if (reelId != null && reelId.isNotEmpty) 'reelId': reelId,
      },
    ).toString(),
  );
}

class PublicCreatorProfileScreen extends ConsumerStatefulWidget {
  const PublicCreatorProfileScreen({super.key});

  @override
  ConsumerState<PublicCreatorProfileScreen> createState() =>
      _PublicCreatorProfileScreenState();
}

class _PublicCreatorProfileScreenState
    extends ConsumerState<PublicCreatorProfileScreen> {
  var _followingOverride = <String, bool>{};
  var _busy = false;

  String? get _creatorId =>
      creatorIdFromRoute(context, ref.watch(selectedCreatorProfileIdProvider));

  Future<void> _toggleFollow(PublicCreatorProfile profile) async {
    if (_busy || profile.isSelf) return;
    final next = !(_followingOverride[profile.id] ?? profile.following);
    setState(() => _busy = true);
    try {
      await ref
          .read(reelRepositoryProvider)
          .followCreator(profile.id, follow: next);
      if (!mounted) return;
      setState(() => _followingOverride[profile.id] = next);
      ref.invalidate(publicCreatorProfileProvider(profile.id));
      ref.invalidate(reelsFeedProvider(ReelsFeedKind.following));
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _creatorId;
    if (id == null || id.isEmpty) {
      return PelevoPage(
        scrollable: false,
        appBar: AppBar(
          leading: const PelevoBackButton(),
          title: const Text('Creator'),
        ),
        child: const Center(child: Text('Creator unavailable')),
      );
    }
    final profileAsync = ref.watch(publicCreatorProfileProvider(id));
    final reelsAsync = ref.watch(publicCreatorReelsProvider(id));
    return PelevoPage(
      scrollable: false,
      appBar: AppBar(
        leading: const PelevoBackButton(),
        title: const Text('Profile'),
      ),
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(PelevoSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      reelFailure(error).message,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed:
                          () =>
                              ref.invalidate(publicCreatorProfileProvider(id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        data: (profile) {
          final following = _followingOverride[profile.id] ?? profile.following;
          return ListView(
            children: [
              Row(
                children: [
                  ProfileAvatar(url: profile.avatarUrl, size: 84),
                  const SizedBox(width: PelevoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (profile.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: PelevoColors.green,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        if (profile.handleLabel.isNotEmpty)
                          Text(
                            profile.handleLabel,
                            style: const TextStyle(
                              color: PelevoColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((profile.bio ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: PelevoSpacing.md),
                PelevoLinkedText(profile.bio!.trim()),
              ],
              const SizedBox(height: PelevoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child:
                        profile.isSelf
                            ? OutlinedButton(
                              onPressed:
                                  () => context.push('/screen/profile-edit'),
                              child: const Text('Edit profile'),
                            )
                            : FilledButton(
                              onPressed: () => _toggleFollow(profile),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    following
                                        ? PelevoColors.surfaceHigh
                                        : PelevoColors.purple,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(following ? 'Following' : 'Follow'),
                            ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed:
                        () => showPelevoGiftFlow(
                          context,
                          creator: profile.displayName,
                          contentTitle: profile.displayName,
                          creatorProfileId: profile.id,
                        ),
                    child: const Text('Gift'),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder:
                        (buttonContext) => OutlinedButton(
                          onPressed:
                              () => sharePublicCreatorProfile(
                                buttonContext,
                                profile,
                              ),
                          child: const Text('Share'),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: PelevoColors.surface,
                  borderRadius: PelevoRadii.card,
                  border: Border.all(color: PelevoColors.border),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${profile.reelsCount}',
                          label: 'Reels',
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: PelevoColors.border,
                      ),
                      Expanded(
                        child: _Stat(
                          value: '${profile.followers}',
                          label: 'Followers',
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: PelevoColors.border,
                      ),
                      Expanded(
                        child: _Stat(
                          value: '${profile.podcastsCount}',
                          label: 'Podcasts',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (profile.shows.isNotEmpty) ...[
                const SizedBox(height: PelevoSpacing.lg),
                Text(
                  'Podcasts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PelevoSpacing.sm),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profile.shows.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final show = profile.shows[index];
                      return InkWell(
                        onTap: () {
                          openCatalogShow(context, show.id);
                          context.push('/screen/podcast-details');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 168,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child:
                                      show.artworkUrl == null ||
                                              show.artworkUrl!.isEmpty
                                          ? const ColoredBox(
                                            color: PelevoColors.surfaceHigh,
                                            child: Icon(Icons.podcasts_rounded),
                                          )
                                          : CachedNetworkImage(
                                            imageUrl: show.artworkUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  show.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: PelevoSpacing.lg),
              Text('Reels', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: PelevoSpacing.sm),
              reelsAsync.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                error:
                    (error, _) => TextButton(
                      onPressed:
                          () => ref.invalidate(publicCreatorReelsProvider(id)),
                      child: Text(reelFailure(error).message),
                    ),
                data: (reels) {
                  if (reels.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No published reels yet.',
                        style: TextStyle(color: PelevoColors.textMuted),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 4.0;
                      final width = constraints.maxWidth;
                      final cellW = (width - gap * 2) / 3;
                      final cellH = cellW * 16 / 9;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final reel in reels)
                            SizedBox(
                              width: cellW,
                              height: cellH,
                              child: InkWell(
                                onTap:
                                    () => openCreatorReelStories(
                                      context,
                                      creatorProfileId: id,
                                      reelId: reel.id,
                                    ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child:
                                      reel.imageUrl == null
                                          ? const ColoredBox(
                                            color: PelevoColors.surfaceHigh,
                                            child: Center(
                                              child: Icon(
                                                Icons.play_arrow_rounded,
                                              ),
                                            ),
                                          )
                                          : CachedNetworkImage(
                                            imageUrl: reel.imageUrl!,
                                            width: cellW,
                                            height: cellH,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (_, _, _) => const ColoredBox(
                                                  color:
                                                      PelevoColors.surfaceHigh,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.play_arrow_rounded,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(
        label,
        style: const TextStyle(color: PelevoColors.textMuted, fontSize: 12),
      ),
    ],
  );
}

class CreatorStoriesScreen extends ConsumerStatefulWidget {
  const CreatorStoriesScreen({super.key});

  @override
  ConsumerState<CreatorStoriesScreen> createState() =>
      _CreatorStoriesScreenState();
}

class _CreatorStoriesScreenState extends ConsumerState<CreatorStoriesScreen>
    with WidgetsBindingObserver, RouteAware {
  PageController? _pages;
  var _index = 0;
  var _paused = false;
  var _muted = false;
  var _progress = 0.0;
  final _liked = <String, bool>{};
  final _saved = <String, bool>{};
  final _following = <String, bool>{};
  final _likeDelta = <String, int>{};
  final _saveDelta = <String, int>{};
  String? _heartId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  String? get _creatorId =>
      creatorIdFromRoute(context, ref.watch(selectedCreatorProfileIdProvider));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      pelevoRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    pelevoRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    ReelPlayback.halt();
    _pages?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _paused = true;
    ReelPlayback.halt();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _paused = true;
      ReelPlayback.halt();
      if (mounted) setState(() {});
    }
  }

  PublishedReel _present(PublishedReel reel) {
    final commentDelta =
        ref.read(commentCountDeltaProvider)[CommentTarget.reel(reel.id).key] ??
        0;
    return reel.copyWith(
      liked: _liked[reel.id] ?? reel.liked,
      saved: _saved[reel.id] ?? reel.saved,
      following: _following[reel.id] ?? reel.following,
      likesCount: (reel.likesCount + (_likeDelta[reel.id] ?? 0)).clamp(
        0,
        1 << 30,
      ),
      savesCount: (reel.savesCount + (_saveDelta[reel.id] ?? 0)).clamp(
        0,
        1 << 30,
      ),
      commentsCount: (reel.commentsCount + commentDelta).clamp(0, 1 << 30),
    );
  }

  Future<void> _toggleLike(PublishedReel reel) async {
    final next = !reel.liked;
    try {
      await ref.read(reelRepositoryProvider).like(reel.id, liked: next);
      if (!mounted) return;
      setState(() {
        _liked[reel.id] = next;
        _likeDelta[reel.id] = (_likeDelta[reel.id] ?? 0) + (next ? 1 : -1);
        _heartId = next ? reel.id : _heartId;
      });
      if (next) {
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted && _heartId == reel.id) {
            setState(() => _heartId = null);
          }
        });
      }
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    }
  }

  Future<void> _toggleSave(PublishedReel reel) async {
    final next = !reel.saved;
    try {
      await ref.read(reelRepositoryProvider).save(reel.id, saved: next);
      if (!mounted) return;
      setState(() {
        _saved[reel.id] = next;
        _saveDelta[reel.id] = (_saveDelta[reel.id] ?? 0) + (next ? 1 : -1);
      });
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    }
  }

  Future<void> _toggleFollow(PublishedReel reel) async {
    final next = !reel.following;
    try {
      await ref
          .read(reelRepositoryProvider)
          .followCreator(reel.creatorProfileId, follow: next);
      if (!mounted) return;
      setState(() => _following[reel.id] = next);
      ref.invalidate(reelsFeedProvider(ReelsFeedKind.following));
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    }
  }

  void _go(int index, int count) {
    if (index < 0 || index >= count || _pages == null) return;
    _pages!.animateToPage(
      index,
      duration: PelevoMotion.normal,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _creatorId;
    if (id == null || id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Stories unavailable')));
    }
    final async = ref.watch(publicCreatorReelsProvider(id));
    ref.watch(commentCountDeltaProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(publicCreatorReelsProvider(id)),
                child: Text(reelFailure(error).message),
              ),
            ),
        data: (rows) {
          final feed = rows.map(_present).toList();
          if (feed.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No reels from this creator yet.'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
          final startId =
              GoRouterState.of(context).uri.queryParameters['reelId'] ??
              ref.read(selectedCreatorReelIdProvider);
          var start = 0;
          if (startId != null) {
            final found = feed.indexWhere((reel) => reel.id == startId);
            if (found >= 0) start = found;
          }
          if (_pages == null) {
            _index = start;
            _pages = PageController(initialPage: start);
            ReelVideoCache.instance.preload(
              feed.skip(start).map((reel) => reel.mediaUrl),
            );
            unawaited(ReelWakeLock.setEnabled(true));
          }
          if (_index >= feed.length) _index = 0;
          final current = feed[_index];
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true,
                itemCount: feed.length,
                onPageChanged: (index) {
                  setState(() {
                    _index = index;
                    _paused = false;
                    _progress = 0;
                  });
                  ReelVideoCache.instance.preload(
                    feed.skip(index).map((reel) => reel.mediaUrl),
                  );
                  unawaited(ReelWakeLock.setEnabled(true));
                },
                itemBuilder: (context, index) {
                  final reel = feed[index];
                  final playing = index == _index && !_paused;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      PelevoReelVideo(
                        coverUrl: reel.imageUrl,
                        mediaUrl: reel.mediaUrl,
                        playing: playing,
                        muted: _muted,
                        looping: false,
                        showProgress: false,
                        onProgress: (position, duration) {
                          if (index != _index || duration <= Duration.zero) {
                            return;
                          }
                          final next =
                              position.inMilliseconds / duration.inMilliseconds;
                          if ((next - _progress).abs() > 0.01) {
                            setState(() => _progress = next.clamp(0, 1));
                          }
                        },
                        onEnded: () {
                          if (index != _index) return;
                          if (_index + 1 < feed.length) {
                            _go(_index + 1, feed.length);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.black87,
                            ],
                            stops: [0, .4, 1],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) {
                            final width = MediaQuery.sizeOf(context).width;
                            final x = details.localPosition.dx;
                            if (x < width * 0.22) {
                              _go(_index - 1, feed.length);
                            } else if (x > width * 0.78) {
                              _go(_index + 1, feed.length);
                            } else {
                              setState(() => _paused = !_paused);
                              unawaited(ReelWakeLock.setEnabled(!_paused));
                            }
                          },
                          onDoubleTap: () => _toggleLike(reel),
                          onLongPressStart:
                              (_) => setState(() => _paused = true),
                          onLongPressEnd:
                              (_) => setState(() => _paused = false),
                        ),
                      ),
                      if (_paused)
                        const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 84,
                            color: Colors.white,
                          ),
                        ),
                      if (_heartId == reel.id)
                        const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 92,
                            color: PelevoColors.red,
                          ),
                        ),
                      Positioned(
                        left: 12,
                        right: 72,
                        bottom: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () async {
                                setState(() => _paused = true);
                                unawaited(ReelWakeLock.setEnabled(false));
                                await openPublicCreatorProfile(
                                  context,
                                  reel.creatorProfileId,
                                );
                                if (mounted) {
                                  setState(() => _paused = false);
                                  unawaited(ReelWakeLock.setEnabled(true));
                                }
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        reel.creatorImageUrl == null
                                            ? null
                                            : CachedNetworkImageProvider(
                                              reel.creatorImageUrl!,
                                            ),
                                    child:
                                        reel.creatorImageUrl == null
                                            ? Text(
                                              reel.creatorName.isEmpty
                                                  ? '?'
                                                  : reel.creatorName[0],
                                            )
                                            : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      reel.creatorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (reel.titleText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                reel.titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            if (reel.captionText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(reel.captionText, maxLines: 3),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 28,
                        child: Column(
                          children: [
                            _StoryAction(
                              icon:
                                  reel.liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                              label: '${reel.likesCount}',
                              color:
                                  reel.liked ? PelevoColors.red : Colors.white,
                              onTap: () => _toggleLike(reel),
                            ),
                            _StoryAction(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '${reel.commentsCount}',
                              onTap:
                                  () => showPelevoCommentSheet(
                                    context,
                                    target: CommentTarget.reel(reel.id),
                                    title: 'Comments',
                                  ),
                            ),
                            _StoryAction(
                              icon:
                                  reel.saved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                              label: '${reel.savesCount}',
                              onTap: () => _toggleSave(reel),
                            ),
                            _StoryAction(
                              icon: Icons.card_giftcard_rounded,
                              label: 'Gift',
                              color: PelevoColors.purple,
                              onTap:
                                  () => showPelevoGiftFlow(
                                    context,
                                    creator: reel.creatorName,
                                    contentTitle: reel.captionText,
                                    creatorProfileId: reel.creatorProfileId,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < feed.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  value:
                                      i < _index
                                          ? 1
                                          : i == _index
                                          ? _progress
                                          : 0,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                setState(() => _paused = true);
                                unawaited(ReelWakeLock.setEnabled(false));
                                await openPublicCreatorProfile(context, id);
                                if (mounted) {
                                  setState(() => _paused = false);
                                  unawaited(ReelWakeLock.setEnabled(true));
                                }
                              },
                              child: Text(
                                current.creatorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (!current.following)
                            TextButton(
                              onPressed: () => _toggleFollow(current),
                              child: const Text('Follow'),
                            ),
                          IconButton(
                            tooltip: _muted ? 'Unmute' : 'Mute',
                            onPressed: () => setState(() => _muted = !_muted),
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryAction extends StatelessWidget {
  const _StoryAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}
