import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/gifts/gift_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/reels/reel_create_service.dart';
import 'package:pelevo/features/reels/reel_ad_service.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reel_player.dart';
import 'package:pelevo/features/reels/creator_public_screens.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

bool _inReelPauseZone(Offset position, Size size) {
  final zone = Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width * 0.5,
    height: size.height * 0.4,
  );
  return zone.contains(position);
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final TabController _tabs;
  final _pageControllers = <ReelsFeedKind, PageController>{
    ReelsFeedKind.forYou: PageController(),
    ReelsFeedKind.following: PageController(),
    ReelsFeedKind.trending: PageController(),
  };

  final _liked = <String, bool>{};
  final _saved = <String, bool>{};
  final _following = <String, bool>{};
  final _likeDelta = <String, int>{};
  final _saveDelta = <String, int>{};
  final _hidden = <String>{};
  final _expanded = <String>{};
  final _busy = <String>{};
  final _seenStories = <String>{};
  String? _playingId;
  var _paused = false;
  var _muted = false;
  var _feedTabIndex = 0;
  String? _heartId;
  Offset? _tapOrigin;
  String _query = '';
  final _progress = <String, (Duration, Duration)>{};
  final _heartbeats = ReelHeartbeatGate();
  final _adAfterReel = <ReelsFeedKind, Map<String, ReelAdDue>>{};
  String? _activeAdImpressionId;
  var _appForeground = true;
  String? _focusReelId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onFeedTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      pelevoRouteObserver.subscribe(this, route);
    }
    final requested =
        GoRouterState.of(context).uri.queryParameters['reelId']?.trim();
    if (requested != null &&
        requested.isNotEmpty &&
        requested != _focusReelId) {
      _focusReelId = requested;
      _playingId = null;
      _paused = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tabs.index != 0) _tabs.index = 0;
        final controller = _pageControllers[ReelsFeedKind.forYou]!;
        if (controller.hasClients) controller.jumpToPage(0);
      });
    }
  }

  /// Puts the reel opened from elsewhere (e.g. a Home short card) first in For You.
  List<PublishedReel> _withFocusedReel(
    ReelsFeedKind tab,
    List<PublishedReel> rows,
  ) {
    final focusId = _focusReelId;
    if (tab != ReelsFeedKind.forYou || focusId == null) return rows;
    final focused =
        ref.watch(reelByIdProvider(focusId)).asData?.value ??
        rows.where((reel) => reel.id == focusId).firstOrNull;
    if (focused == null) return rows;
    return [focused, ...rows.where((reel) => reel.id != focusId)];
  }

  @override
  void dispose() {
    pelevoRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    ReelPlayback.halt();
    unawaited(ReelVideoCache.instance.disposeAll());
    _tabs.removeListener(_onFeedTabChanged);
    _tabs.dispose();
    for (final controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didPushNext() => _haltPlayback();

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() => _paused = false);
    _syncWakeLock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _haltPlayback();
    }
  }

  void _haltPlayback() {
    _paused = true;
    ReelPlayback.halt();
    if (mounted) setState(() {});
  }

  void _onFeedTabChanged() {
    if (!mounted) return;
    if (_tabs.index != _feedTabIndex) {
      _feedTabIndex = _tabs.index;
      _activeAdImpressionId = null;
      _haltPlayback();
    }
    if (_tabs.indexIsChanging) return;
    final nextId = _pageReelId(_activeTab);
    setState(() {
      _paused = false;
      if (nextId != null) _playingId = nextId;
    });
    _syncWakeLock();
  }

  String? _pageReelId(ReelsFeedKind tab) {
    final source = ref.read(reelsFeedProvider(tab)).asData?.value;
    if (source == null) return null;
    final focusId = _focusReelId;
    final focused =
        tab == ReelsFeedKind.forYou && focusId != null
            ? ref.read(reelByIdProvider(focusId)).asData?.value
            : null;
    final rows =
        focused == null
            ? source
            : [focused, ...source.where((reel) => reel.id != focused.id)];
    final feed = _visible(rows);
    if (feed.isEmpty) return null;
    final controller = _pageControllers[tab];
    var page = 0;
    if (controller != null && controller.hasClients) {
      page = controller.page?.round() ?? controller.initialPage;
    }
    final items = _feedItems(tab, feed);
    if (items.isEmpty) return null;
    final item = items[page.clamp(0, items.length - 1)];
    return item is PublishedReel ? item.id : null;
  }

  bool get _proListening => pelevoPlusRemovesAds(
    ref.read(premiumAccountProvider).asData?.value,
  );

  List<Object> _feedItems(ReelsFeedKind tab, List<PublishedReel> reels) {
    if (_proListening) return reels;
    final ads = _adAfterReel[tab] ?? const <String, ReelAdDue>{};
    return [
      for (final reel in reels) ...[
        reel,
        if (ads[reel.id] case final due?) due,
      ],
    ];
  }

  void _removeUnavailableAd(ReelsFeedKind tab, String impressionId) {
    final ads = _adAfterReel[tab];
    if (ads == null || !mounted) return;
    setState(() {
      ads.removeWhere((_, due) => due.impressionId == impressionId);
      if (_activeAdImpressionId == impressionId) {
        _activeAdImpressionId = null;
      }
    });
  }

  void _syncWakeLock() {
    unawaited(ReelWakeLock.setEnabled(!_paused && _playingId != null));
  }

  Future<T?> _withPausedPlayback<T>(Future<T?> Function() action) async {
    _haltPlayback();
    try {
      return await action();
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ModalRoute.of(context)?.isCurrent ?? false) {
            setState(() => _paused = false);
            _syncWakeLock();
          }
        });
      }
    }
  }

  void _warmFeed(List<PublishedReel> feed, int index) {
    if (feed.isEmpty) return;
    final start = index.clamp(0, feed.length - 1);
    ReelVideoCache.instance.preload(
      feed.skip(start).map((reel) => reel.mediaUrl),
    );
    final keep = <String>{};
    for (
      var i = (start - 1).clamp(0, feed.length - 1);
      i < feed.length && i <= start + 5;
      i++
    ) {
      final url = feed[i].mediaUrl;
      if (url != null && url.isNotEmpty) keep.add(url);
    }
    unawaited(ReelVideoCache.instance.evictExcept(keep));
  }

  ReelsFeedKind get _activeTab => ReelsFeedKind.values[_tabs.index];

  bool get _canCreate {
    final preview = kDebugMode && ref.watch(catalogPreviewProvider);
    final creatorAccess = ref.watch(
      authSessionProvider.select((session) => session.creatorAccess),
    );
    return preview ? PodcastCreatorService.instance.claimed : creatorAccess;
  }

  List<PublishedReel> _visible(List<PublishedReel> source) {
    final filtered =
        source.where((reel) => !_hidden.contains(reel.id)).toList();
    if (_query.trim().isEmpty) return filtered;
    final q = _query.trim().toLowerCase();
    return filtered
        .where(
          (reel) =>
              reel.creatorName.toLowerCase().contains(q) ||
              reel.captionText.toLowerCase().contains(q) ||
              reel.handleLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  PublishedReel _present(
    PublishedReel reel, [
    Map<String, int>? commentDeltas,
  ]) {
    final liked = _liked[reel.id] ?? reel.liked;
    final saved = _saved[reel.id] ?? reel.saved;
    final Map<String, int> deltas =
        commentDeltas == null
            ? Map<String, int>.from(ref.read(commentCountDeltaProvider))
            : commentDeltas;
    final commentDelta = deltas[CommentTarget.reel(reel.id).key] ?? 0;
    return reel.copyWith(
      liked: liked,
      saved: saved,
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

  Future<void> _openCreator(String creatorProfileId) {
    setState(() => _seenStories.add(creatorProfileId));
    return _withPausedPlayback(
      () => openCreatorReelStories(context, creatorProfileId: creatorProfileId),
    );
  }

  Future<void> _openCreatorProfile(String creatorProfileId) {
    return _withPausedPlayback(
      () => openPublicCreatorProfile(context, creatorProfileId),
    );
  }

  Future<void> _showCreateReel() async {
    await _withPausedPlayback(() async {
      if (!_canCreate) {
        final shouldClaim = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  color: PelevoColors.green,
                  size: 38,
                ),
                title: const Text('Creator access required'),
                content: const Text(
                  'Only verified podcast creators can create Reels. Claim and verify your podcast to unlock Reel creation.',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Not Now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: PelevoColors.green,
                    ),
                    child: const Text('Claim Podcast'),
                  ),
                ],
              ),
        );
        if (shouldClaim == true && mounted) {
          context.push('/screen/claim-podcast');
        }
        return;
      }

      await showPelevoSheet<void>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.pelevo.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Reel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record a short clip, upload from your library, or continue a draft.',
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                    const SizedBox(height: 16),
                    _SheetAction(
                      icon: Icons.videocam_rounded,
                      title: 'Record',
                      subtitle: 'Capture a new Pelevo Reel',
                      onTap: () {
                        Navigator.pop(context);
                        this.context.push('/screen/reels-record');
                      },
                    ),
                    _SheetAction(
                      icon: Icons.upload_rounded,
                      title: 'Upload',
                      subtitle: 'Choose a video from your device',
                      onTap: () {
                        Navigator.pop(context);
                        this.context.push('/screen/reels-upload');
                      },
                    ),
                    _SheetAction(
                      icon: Icons.drafts_outlined,
                      title: 'Drafts',
                      subtitle: 'Finish an unfinished reel',
                      onTap: () {
                        Navigator.pop(context);
                        ReelCreateService.instance.ensureLoaded();
                        this.context.push('/screen/reels-drafts');
                      },
                    ),
                  ],
                ),
              ),
            ),
      );
    });
  }

  Future<void> _showComments(PublishedReel reel) => _withPausedPlayback(
    () => showPelevoCommentSheet(
      context,
      target: CommentTarget.reel(reel.id),
      title: 'Comments',
    ),
  );

  Future<void> _showGift(PublishedReel reel) => _withPausedPlayback(
    () => showPelevoGiftFlow(
      context,
      creator: reel.creatorName,
      contentTitle: reel.captionText,
      creatorProfileId: reel.creatorProfileId,
    ),
  );

  Future<void> _copyReelLink(PublishedReel reel) async {
    final url = catalogShareReelLink(reel.id);
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      context.showPelevoMessage('Link copied');
    } catch (_) {
      if (mounted) {
        context.showPelevoMessage('Copying to the clipboard is not available.');
      }
    }
  }

  Future<void> _shareReel(PublishedReel reel) {
    final url = catalogShareReelLink(reel.id);
    final title =
        reel.titleText.isNotEmpty
            ? reel.titleText
            : (reel.captionText.isNotEmpty ? reel.captionText : 'Pelevo reel');
    return _withPausedPlayback(() async {
      try {
        await pelevoShareEpisodeLink(context: context, url: url, title: title);
      } catch (_) {
        await _copyReelLink(reel);
      }
    });
  }

  void _onReelProgress(
    PublishedReel reel,
    Duration position,
    Duration duration,
  ) {
    final previous = _progress[reel.id];
    if (previous == null ||
        previous.$1.inMilliseconds ~/ 250 != position.inMilliseconds ~/ 250) {
      if (mounted) {
        setState(() => _progress[reel.id] = (position, duration));
      } else {
        _progress[reel.id] = (position, duration);
      }
    }
    if (_playingId != reel.id || _paused || _muted || !_appForeground) return;
    final watched = position.inMilliseconds;
    final completed =
        duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 250);
    if (!_heartbeats.allow(reel.id, watched, completed: completed)) return;
    unawaited(() async {
      try {
        final result = await ref
            .read(reelRepositoryProvider)
            .heartbeat(
              reel.id,
              sessionId: _heartbeats.sessions[reel.id]!,
              feedSessionId: _heartbeats.feedSessionId,
              sequence: _heartbeats.nextSequence(reel.id),
              playbackPositionMs: watched,
              completed: completed,
              appForeground: _appForeground,
              audible: !_muted,
              adEligible: !_proListening,
            );
        final due = result.adDue;
        if (due != null && mounted && !_proListening) {
          setState(() {
            (_adAfterReel[_activeTab] ??= <String, ReelAdDue>{})[reel.id] = due;
          });
        }
      } catch (_) {
      } finally {
        _heartbeats.done(reel.id);
      }
    }());
  }

  Future<void> _toggleLike(PublishedReel reel) async {
    if (_busy.contains('like-${reel.id}')) return;
    final next = !reel.liked;
    setState(() => _busy.add('like-${reel.id}'));
    try {
      await ref.read(reelRepositoryProvider).like(reel.id, liked: next);
      if (!mounted) return;
      setState(() {
        _liked[reel.id] = next;
        _likeDelta[reel.id] = (_likeDelta[reel.id] ?? 0) + (next ? 1 : -1);
        if (next) {
          _heartId = reel.id;
          Future<void>.delayed(const Duration(milliseconds: 650), () {
            if (mounted && _heartId == reel.id) {
              setState(() => _heartId = null);
            }
          });
        }
      });
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy.remove('like-${reel.id}'));
    }
  }

  Future<void> _toggleSave(PublishedReel reel) async {
    if (_busy.contains('save-${reel.id}')) return;
    final next = !reel.saved;
    setState(() => _busy.add('save-${reel.id}'));
    try {
      await ref.read(reelRepositoryProvider).save(reel.id, saved: next);
      if (!mounted) return;
      setState(() {
        _saved[reel.id] = next;
        _saveDelta[reel.id] = (_saveDelta[reel.id] ?? 0) + (next ? 1 : -1);
      });
      ref.invalidate(savedReelsProvider);
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy.remove('save-${reel.id}'));
    }
  }

  Future<void> _toggleFollow(PublishedReel reel) async {
    if (_busy.contains('follow-${reel.id}')) return;
    final next = !reel.following;
    setState(() => _busy.add('follow-${reel.id}'));
    try {
      await ref
          .read(reelRepositoryProvider)
          .followCreator(reel.creatorProfileId, follow: next);
      if (!mounted) return;
      setState(() => _following[reel.id] = next);
      ref.invalidate(reelsFeedProvider(ReelsFeedKind.following));
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy.remove('follow-${reel.id}'));
    }
  }

  Future<void> _showMore(PublishedReel reel) async {
    await _withPausedPlayback(
      () => showPelevoSheet<void>(
        context: context,
        builder:
            (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetAction(
                    icon: Icons.link_rounded,
                    title: 'Copy link',
                    subtitle: 'Share ${reel.creatorName}\'s reel',
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_copyReelLink(reel));
                    },
                  ),
                  _SheetAction(
                    icon: Icons.visibility_off_outlined,
                    title: 'Not interested',
                    subtitle: 'See fewer reels like this',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await ref
                            .read(reelRepositoryProvider)
                            .notInterested(reel.id);
                        if (!this.context.mounted) return;
                        setState(() => _hidden.add(reel.id));
                      } on Object catch (error) {
                        if (this.context.mounted) {
                          this.context.showPelevoMessage(
                            reelFailure(error).message,
                          );
                        }
                      }
                    },
                  ),
                  _SheetAction(
                    icon: Icons.flag_outlined,
                    title: 'Report',
                    subtitle: 'Flag this reel for review',
                    onTap: () {
                      Navigator.pop(context);
                      _showReport(reel);
                    },
                  ),
                  _SheetAction(
                    icon: Icons.podcasts_rounded,
                    title: 'Open related podcast',
                    subtitle: 'Continue listening in Pelevo',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final show = await ref
                            .read(reelRepositoryProvider)
                            .relatedShow(reel.id);
                        if (!this.context.mounted) return;
                        this.context.showPelevoMessage(show.title);
                        this.context.push('/screen/podcast-details');
                      } on Object catch (error) {
                        if (this.context.mounted) {
                          this.context.showPelevoMessage(
                            reelFailure(error).message,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _showReport(PublishedReel reel) async {
    String reason = 'Spam';
    await showPelevoSheet<void>(
      context: context,
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: StatefulBuilder(
              builder:
                  (context, setSheet) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Report ${reel.creatorName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final option in reportReasonCodes.keys)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: option,
                          groupValue: reason,
                          title: Text(option),
                          onChanged:
                              (value) =>
                                  setSheet(() => reason = value ?? reason),
                        ),
                      PelevoButton(
                        label: 'Submit report',
                        color: PelevoColors.purple,
                        onPressed: () async {
                          final code = reportReasonCodes[reason];
                          if (code == null) return;
                          Navigator.pop(sheetContext);
                          try {
                            await ref
                                .read(reelRepositoryProvider)
                                .report(
                                  reelId: reel.id,
                                  reason: code,
                                  details:
                                      reason == 'Spoiler' ? 'Spoiler' : null,
                                );
                            if (!this.context.mounted) return;
                            this.context.showPelevoMessage('Report submitted');
                          } on Object catch (error) {
                            if (this.context.mounted) {
                              this.context.showPelevoMessage(
                                reelFailure(error).message,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
            ),
          ),
    );
  }

  Future<void> _showLinkedEpisode(PublishedReel reel) async {
    _haltPlayback();
    final episodeId = reel.episodeId;
    if (episodeId == null || episodeId.isEmpty) {
      context.showPelevoMessage('This reel is not linked to an episode yet.');
      return;
    }
    openCatalogEpisodeDetails(
      context,
      episodeId: episodeId,
      showId: reel.showId,
    );
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController(text: _query);
    await _withPausedPlayback(
      () => showPelevoSheet<void>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search reels, creators, topics',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (value) {
                      Navigator.pop(context);
                      setState(() => _query = value.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  PelevoButton(
                    label: 'Search Reels',
                    color: PelevoColors.purple,
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _query = controller.text.trim());
                    },
                  ),
                  if (_query.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _query = '');
                      },
                      child: const Text('Clear filter'),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reelsFeedProvider(ReelsFeedKind.forYou));
    ref.watch(reelsFeedProvider(ReelsFeedKind.following));
    ref.watch(reelsFeedProvider(ReelsFeedKind.trending));
    ref.watch(commentCountDeltaProvider);
    ref.watch(premiumAccountProvider);

    return ListenableBuilder(
      listenable: PodcastCreatorService.instance,
      builder: (context, _) {
        return PelevoPage(
          scrollable: false,
          padding: EdgeInsets.zero,
          safeArea: false,
          extendBody: true,
          showMiniPlayer: false,
          bottomNavigationBar: PelevoBottomNavigation(
            index: 4,
            onDestinationSelected: context.openPelevoTab,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TabBarView(
                controller: _tabs,
                children: [
                  for (final tab in ReelsFeedKind.values) _buildFeed(tab),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 2, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  for (final entry
                                      in ReelsFeedKind.values.indexed)
                                    Expanded(
                                      child: _FeedTab(
                                        label: switch (entry.$2) {
                                          ReelsFeedKind.forYou => 'For You',
                                          ReelsFeedKind.following =>
                                            'Following',
                                          ReelsFeedKind.trending => 'Trending',
                                        },
                                        selected: _tabs.index == entry.$1,
                                        onTap: () {
                                          if (_tabs.index != entry.$1) {
                                            _haltPlayback();
                                          }
                                          _tabs.animateTo(entry.$1);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Search reels',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _showSearch,
                              icon: const Icon(Icons.search_rounded, size: 22),
                            ),
                            IconButton(
                              tooltip: _muted ? 'Unmute reels' : 'Mute reels',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() => _muted = !_muted),
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                size: 22,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Create Reel',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _showCreateReel,
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filtered by “$_query”',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _query = ''),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeed(ReelsFeedKind tab) {
    final async = ref.watch(reelsFeedProvider(tab));
    final commentDeltas = ref.watch(commentCountDeltaProvider);
    final focusId = _focusReelId;
    if (tab == ReelsFeedKind.forYou &&
        focusId != null &&
        ref.watch(reelByIdProvider(focusId)).isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(PelevoSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(reelFailure(error).message, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => ref.invalidate(reelsFeedProvider(tab)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      data: (rows) {
        final feed =
            _visible(
              _withFocusedReel(tab, rows),
            ).map((reel) => _present(reel, commentDeltas)).toList();
        final items = _feedItems(tab, feed);
        if (tab == _activeTab &&
            feed.isNotEmpty &&
            _playingId == null &&
            !_paused) {
          final firstId = feed.first.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || tab != _activeTab || _playingId != null) return;
            setState(() => _playingId = firstId);
            _warmFeed(feed, 0);
            _syncWakeLock();
          });
        }
        if (feed.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(PelevoSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_filter_outlined,
                    size: 52,
                    color: PelevoColors.purple,
                  ),
                  SizedBox(height: PelevoSpacing.md),
                  Text(
                    'No reels found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: PelevoSpacing.sm),
                  Text(
                    'Try another creator, topic, or clear your filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return PageView.builder(
          controller: _pageControllers[tab],
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: true,
          itemCount: items.length,
          onPageChanged: (index) {
            if (tab != _activeTab) return;
            final item = items[index];
            setState(() {
              _playingId = item is PublishedReel ? item.id : null;
              _activeAdImpressionId =
                  item is ReelAdDue ? item.impressionId : null;
              _paused = item is! PublishedReel;
              _heartId = null;
            });
            if (item is PublishedReel) {
              _warmFeed(feed, feed.indexWhere((reel) => reel.id == item.id));
            } else {
              ReelPlayback.halt();
            }
            _syncWakeLock();
          },
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is ReelAdDue) {
              return ref
                  .read(reelAdPageFactoryProvider)
                  .build(
                    key: ValueKey('reel-ad-${item.impressionId}'),
                    due: item,
                    feedSessionId: _heartbeats.feedSessionId,
                    isActive: _activeAdImpressionId == item.impressionId,
                    onUnavailable:
                        () => _removeUnavailableAd(tab, item.impressionId),
                  );
            }
            final reel = item as PublishedReel;
            final liked = reel.liked;
            final saved = reel.saved;
            final following = reel.following;
            final expanded = _expanded.contains(reel.id);
            final isCurrent =
                tab == _activeTab &&
                (_playingId == reel.id || (_playingId == null && index == 0));
            final playing = isCurrent && !_paused;
            final caption = reel.captionText;
            final overlayBottom =
                MediaQuery.paddingOf(context).bottom +
                kBottomNavigationBarHeight +
                12;

            return Stack(
              fit: StackFit.expand,
              children: [
                PelevoReelVideo(
                  coverUrl: reel.imageUrl,
                  mediaUrl: reel.mediaUrl,
                  playing: playing,
                  muted: _muted,
                  showProgress: false,
                  onProgress:
                      (position, duration) =>
                          _onReelProgress(reel, position, duration),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black26,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Listener(
                    key:
                        isCurrent
                            ? const ValueKey('active-reel-surface')
                            : ValueKey('reel-surface-${reel.id}'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      _tapOrigin = event.position;
                    },
                    onPointerUp: (event) {
                      final origin = _tapOrigin;
                      _tapOrigin = null;
                      if (origin == null) return;
                      if ((event.position - origin).distance > 14) return;
                      if (!_inReelPauseZone(
                        event.position,
                        MediaQuery.sizeOf(context),
                      )) {
                        return;
                      }
                      setState(() {
                        _playingId = reel.id;
                        _paused = isCurrent ? !_paused : false;
                      });
                      _syncWakeLock();
                    },
                    onPointerCancel: (_) => _tapOrigin = null,
                    child: GestureDetector(
                      onDoubleTap: () => _toggleLike(reel),
                      onLongPressStart: (_) {
                        setState(() {
                          _playingId = reel.id;
                          _paused = true;
                        });
                      },
                      onLongPressEnd: (_) {
                        setState(() => _paused = false);
                        _syncWakeLock();
                      },
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                ),
                if (_paused && tab == _activeTab && _playingId == reel.id)
                  const IgnorePointer(
                    child: Center(
                      child: Tooltip(
                        message: 'Play reel',
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 84,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 18, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_heartId == reel.id)
                  const IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 88,
                        color: PelevoColors.red,
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 72,
                  bottom: overlayBottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reel.hasLinkedEpisode)
                        _LinkedEpisodeCard(
                          reel: reel,
                          onOpen: () => _showLinkedEpisode(reel),
                        ),
                      if (reel.hasLinkedEpisode) const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _openCreator(reel.creatorProfileId),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: context.pelevo.surfaceHigh,
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
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: InkWell(
                              onTap:
                                  () => _openCreatorProfile(
                                    reel.creatorProfileId,
                                  ),
                              child: Text(
                                reel.creatorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _toggleFollow(reel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PelevoColors.purple,
                              side: const BorderSide(
                                color: PelevoColors.purple,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(following ? 'Following' : 'Follow'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reel.viewsLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reel.titleText.isNotEmpty &&
                          !reel.hasLinkedEpisode) ...[
                        const SizedBox(height: 8),
                        Text(
                          reel.titleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 16,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                      ],
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (expanded) {
                                _expanded.remove(reel.id);
                              } else {
                                _expanded.add(reel.id);
                              }
                            });
                          },
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      expanded || caption.length <= 140
                                          ? caption
                                          : '${caption.substring(0, 140)}... ',
                                ),
                                if (!expanded && caption.length > 140)
                                  const TextSpan(
                                    text: 'more',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: expanded ? 8 : 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.35,
                              fontSize: 14,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: overlayBottom,
                  child: Column(
                    children: [
                      _Action(
                        icon:
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                        label: '${reel.likesCount}',
                        tooltip: 'Like',
                        color: liked ? PelevoColors.red : Colors.white,
                        onTap: () => _toggleLike(reel),
                      ),
                      _Action(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${reel.commentsCount}',
                        tooltip: 'Comments',
                        onTap: () => _showComments(reel),
                      ),
                      _Action(
                        icon: Icons.send_outlined,
                        label: 'Share',
                        tooltip: 'Share',
                        onTap: () => _shareReel(reel),
                      ),
                      _Action(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Gift',
                        tooltip: 'Gift',
                        color: PelevoColors.purple,
                        onTap: () => _showGift(reel),
                      ),
                      _Action(
                        icon:
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                        label: '${reel.savesCount}',
                        tooltip: 'Save',
                        onTap: () => _toggleSave(reel),
                      ),
                      IconButton(
                        tooltip: 'More options',
                        onPressed: () => _showMore(reel),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      kBottomNavigationBarHeight,
                  child: ReelScrubber(
                    progress: () {
                      final tick = _progress[reel.id];
                      final duration =
                          tick?.$2.inMilliseconds ?? reel.durationMs ?? 0;
                      if (duration <= 0) return 0.0;
                      return ((tick?.$1.inMilliseconds ?? 0) / duration).clamp(
                        0.0,
                        1.0,
                      );
                    }(),
                    duration: Duration(
                      milliseconds:
                          _progress[reel.id]?.$2.inMilliseconds ??
                          reel.durationMs ??
                          0,
                    ),
                    enabled: reel.mediaUrl != null && reel.mediaUrl!.isNotEmpty,
                    onSeek: (position) {
                      final url = reel.mediaUrl;
                      if (url == null || url.isEmpty) return;
                      unawaited(ReelVideoCache.instance.seek(url, position));
                      setState(
                        () =>
                            _progress[reel.id] = (
                              position,
                              _progress[reel.id]?.$2 ??
                                  Duration(milliseconds: reel.durationMs ?? 0),
                            ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LinkedEpisodeCard extends StatelessWidget {
  const _LinkedEpisodeCard({required this.reel, required this.onOpen});

  final PublishedReel reel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final quote = reel.titleText;
    final artwork = reel.showArtworkUrl;
    final duration = reel.linkedDurationLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: PelevoColors.purple,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Linked to Podcast Episode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (quote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '“$quote”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              height: 1.15,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'Listen to the full conversation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(PelevoRadii.large),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.pelevo.surfaceHigh.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PelevoRadii.small),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child:
                          artwork != null &&
                                  (artwork.startsWith('http://') ||
                                      artwork.startsWith('https://'))
                              ? CachedNetworkImage(
                                imageUrl: artwork,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, _, _) => const _LinkedArtworkFallback(),
                              )
                              : const _LinkedArtworkFallback(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reel.linkedShowLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reel.linkedChipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.pelevo.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: _LinkedWaveform(),
                                ),
                              ),
                            ),
                            if (duration.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                duration,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: PelevoColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PelevoRadii.large),
              ),
            ),
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: const Text(
              'Listen Now',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkedArtworkFallback extends StatelessWidget {
  const _LinkedArtworkFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.pelevo.surface,
    child: Center(
      child: Icon(Icons.mic_rounded, color: PelevoColors.purple, size: 22),
    ),
  );
}

class _LinkedWaveform extends StatelessWidget {
  const _LinkedWaveform();

  static const _bars = [
    5,
    9,
    14,
    8,
    16,
    11,
    18,
    7,
    13,
    10,
    16,
    6,
    12,
    15,
    8,
    11,
    17,
    9,
    14,
    7,
    12,
    16,
    8,
    10,
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Row(
      children: [
        for (final height in _bars) ...[
          Container(
            width: 2,
            height: height.toDouble(),
            decoration: BoxDecoration(
              color: PelevoColors.purple.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 1.5),
        ],
      ],
    ),
  );
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: selected ? Colors.white : Colors.white70,
          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Tooltip(
      message: tooltip,
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
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
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
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: PelevoColors.purple.withValues(alpha: .15),
      child: Icon(icon, color: PelevoColors.purple),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: context.pelevo.textMuted),
    ),
    onTap: onTap,
  );
}

void openSavedReels(BuildContext context, {String? reelId}) {
  final uri = Uri(
    path: '/screen/saved-reels',
    queryParameters: {
      if (reelId != null && reelId.isNotEmpty) 'reelId': reelId,
    },
  );
  context.push(uri.toString());
}

class SavedReelsScreen extends ConsumerStatefulWidget {
  const SavedReelsScreen({super.key});

  @override
  ConsumerState<SavedReelsScreen> createState() => _SavedReelsScreenState();
}

class _SavedReelsScreenState extends ConsumerState<SavedReelsScreen>
    with WidgetsBindingObserver, RouteAware {
  PageController? _pages;
  var _index = 0;
  var _paused = false;
  var _muted = false;
  String? _playingId;
  final _liked = <String, bool>{};
  final _saved = <String, bool>{};
  final _likeDelta = <String, int>{};
  final _saveDelta = <String, int>{};
  Offset? _tapOrigin;
  final _progress = <String, (Duration, Duration)>{};
  final _heartbeats = ReelHeartbeatGate();
  var _appForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

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
  void didPushNext() => _halt();

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() => _paused = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) _halt();
  }

  void _halt() {
    _paused = true;
    ReelPlayback.halt();
    if (mounted) setState(() {});
  }

  PublishedReel _present(PublishedReel reel) {
    return reel.copyWith(
      liked: _liked[reel.id] ?? reel.liked,
      saved: _saved[reel.id] ?? reel.saved,
      likesCount: (reel.likesCount + (_likeDelta[reel.id] ?? 0)).clamp(
        0,
        1 << 30,
      ),
      savesCount: (reel.savesCount + (_saveDelta[reel.id] ?? 0)).clamp(
        0,
        1 << 30,
      ),
    );
  }

  void _openLinked(PublishedReel reel) {
    _halt();
    final episodeId = reel.episodeId;
    if (episodeId == null || episodeId.isEmpty) {
      context.showPelevoMessage('This reel is not linked to an episode yet.');
      return;
    }
    openCatalogEpisodeDetails(
      context,
      episodeId: episodeId,
      showId: reel.showId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(savedReelsProvider);
    return PelevoPage(
      scrollable: false,
      padding: EdgeInsets.zero,
      safeArea: false,
      extendBody: true,
      showMiniPlayer: false,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(PelevoSpacing.xl),
                child: Text(reelFailure(error).message),
              ),
            ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No saved reels yet.\nBookmark a reel to watch it here.',
                textAlign: TextAlign.center,
              ),
            );
          }
          final startId =
              GoRouterState.of(context).uri.queryParameters['reelId'];
          if (_pages == null) {
            final start =
                startId == null
                    ? 0
                    : items
                        .indexWhere((reel) => reel.id == startId)
                        .clamp(0, items.length - 1);
            _index = start < 0 ? 0 : start;
            _playingId = items[_index].id;
            _pages = PageController(initialPage: _index);
            ReelVideoCache.instance.preload(
              items.skip(_index).map((reel) => reel.mediaUrl),
            );
          }
          final overlayBottom = MediaQuery.paddingOf(context).bottom + 24;
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true,
                itemCount: items.length,
                onPageChanged: (index) {
                  setState(() {
                    _index = index;
                    _playingId = items[index].id;
                    _paused = false;
                  });
                  ReelVideoCache.instance.preload(
                    items.skip(index).map((reel) => reel.mediaUrl),
                  );
                },
                itemBuilder: (context, index) {
                  final reel = _present(items[index]);
                  final playing = _playingId == reel.id && !_paused;
                  final caption = reel.captionText;
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _tapOrigin = event.position,
                    onPointerUp: (event) {
                      final origin = _tapOrigin;
                      _tapOrigin = null;
                      if (origin == null) return;
                      if ((event.position - origin).distance > 14) return;
                      if (!_inReelPauseZone(
                        event.position,
                        MediaQuery.sizeOf(context),
                      )) {
                        return;
                      }
                      setState(() => _paused = !_paused);
                      if (_paused) ReelPlayback.halt();
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PelevoReelVideo(
                          coverUrl: reel.imageUrl,
                          mediaUrl: reel.mediaUrl,
                          playing: playing,
                          muted: _muted,
                          showProgress: false,
                          onProgress: (position, duration) {
                            final previous = _progress[reel.id];
                            if (previous == null ||
                                previous.$1.inMilliseconds ~/ 250 !=
                                    position.inMilliseconds ~/ 250) {
                              setState(
                                () => _progress[reel.id] = (position, duration),
                              );
                            }
                            if (_playingId != reel.id ||
                                _paused ||
                                _muted ||
                                !_appForeground) {
                              return;
                            }
                            final watched = position.inMilliseconds;
                            final completed =
                                duration > Duration.zero &&
                                position >=
                                    duration -
                                        const Duration(milliseconds: 250);
                            if (!_heartbeats.allow(
                              reel.id,
                              watched,
                              completed: completed,
                            )) {
                              return;
                            }
                            unawaited(() async {
                              try {
                                await ref
                                    .read(reelRepositoryProvider)
                                    .heartbeat(
                                      reel.id,
                                      sessionId: _heartbeats.sessions[reel.id]!,
                                      feedSessionId: _heartbeats.feedSessionId,
                                      sequence: _heartbeats.nextSequence(
                                        reel.id,
                                      ),
                                      playbackPositionMs: watched,
                                      completed: completed,
                                      appForeground: _appForeground,
                                      audible: !_muted,
                                      adEligible: false,
                                    );
                              } catch (_) {
                              } finally {
                                _heartbeats.done(reel.id);
                              }
                            }());
                          },
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black26,
                                Colors.transparent,
                                Colors.black87,
                              ],
                              stops: [0, .45, 1],
                            ),
                          ),
                        ),
                        if (_paused)
                          const IgnorePointer(
                            child: Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 84,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 72,
                          bottom: overlayBottom,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reel.hasLinkedEpisode)
                                _LinkedEpisodeCard(
                                  reel: reel,
                                  onOpen: () => _openLinked(reel),
                                ),
                              if (reel.hasLinkedEpisode)
                                const SizedBox(height: 8),
                              Text(
                                reel.creatorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reel.viewsLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (reel.titleText.isNotEmpty &&
                                  !reel.hasLinkedEpisode) ...[
                                const SizedBox(height: 8),
                                Text(
                                  reel.titleText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                              if (caption.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  caption,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    height: 1.35,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: overlayBottom,
                          child: Column(
                            children: [
                              IconButton(
                                tooltip: _muted ? 'Unmute reels' : 'Mute reels',
                                onPressed:
                                    () => setState(() => _muted = !_muted),
                                icon: Icon(
                                  _muted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              _Action(
                                icon:
                                    reel.liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                label: '${reel.likesCount}',
                                tooltip: 'Like',
                                color:
                                    reel.liked
                                        ? PelevoColors.red
                                        : Colors.white,
                                onTap: () async {
                                  final next = !reel.liked;
                                  await ref
                                      .read(reelRepositoryProvider)
                                      .like(reel.id, liked: next);
                                  if (!mounted) return;
                                  setState(() {
                                    _liked[reel.id] = next;
                                    _likeDelta[reel.id] =
                                        (_likeDelta[reel.id] ?? 0) +
                                        (next ? 1 : -1);
                                  });
                                },
                              ),
                              _Action(
                                icon: Icons.bookmark_rounded,
                                label: '${reel.savesCount}',
                                tooltip: 'Unsave',
                                onTap: () async {
                                  await ref
                                      .read(reelRepositoryProvider)
                                      .save(reel.id, saved: false);
                                  ref.invalidate(savedReelsProvider);
                                  if (!mounted) return;
                                  setState(() => _saved[reel.id] = false);
                                },
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: MediaQuery.paddingOf(context).bottom,
                          child: ReelScrubber(
                            progress: () {
                              final tick = _progress[reel.id];
                              final duration =
                                  tick?.$2.inMilliseconds ??
                                  reel.durationMs ??
                                  0;
                              if (duration <= 0) return 0.0;
                              return ((tick?.$1.inMilliseconds ?? 0) / duration)
                                  .clamp(0.0, 1.0);
                            }(),
                            duration: Duration(
                              milliseconds:
                                  _progress[reel.id]?.$2.inMilliseconds ??
                                  reel.durationMs ??
                                  0,
                            ),
                            enabled:
                                reel.mediaUrl != null &&
                                reel.mediaUrl!.isNotEmpty,
                            onSeek: (position) {
                              final url = reel.mediaUrl;
                              if (url == null || url.isEmpty) return;
                              unawaited(
                                ReelVideoCache.instance.seek(url, position),
                              );
                              setState(
                                () =>
                                    _progress[reel.id] = (
                                      position,
                                      _progress[reel.id]?.$2 ??
                                          Duration(
                                            milliseconds: reel.durationMs ?? 0,
                                          ),
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pelevoBack(),
                    icon: const Icon(Icons.arrow_back_rounded),
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
