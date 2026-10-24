import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/claim_data.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<PelevoScreenSpec> creatorStudioScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'relationship-podcast',
    section: 'Creator Studio',
    title: 'Podcast Page',
    state: 'Unclaimed / claimed',
    builder: _buildRelationshipPodcast,
  ),
  const PelevoScreenSpec(
    id: 'claim-podcast',
    section: 'Creator Studio',
    title: 'Claim Your Podcast',
    builder: _buildClaimPodcast,
  ),
  const PelevoScreenSpec(
    id: 'creator-studio',
    section: 'Creator Studio',
    title: 'Creator Studio',
    builder: _buildCreatorStudio,
  ),
  const PelevoScreenSpec(
    id: 'creator-dashboard',
    section: 'Creator Studio',
    title: 'Creator Dashboard',
    builder: _buildCreatorDashboard,
  ),
]);

Widget _buildRelationshipPodcast(BuildContext context) =>
    const RelationshipPodcastScreen();
Widget _buildClaimPodcast(BuildContext context) => const ClaimPodcastScreen();
Widget _buildCreatorStudio(BuildContext context) => const CreatorStudioScreen();
Widget _buildCreatorDashboard(BuildContext context) =>
    const CreatorDashboardScreen();

class PodcastCreatorService extends ChangeNotifier {
  PodcastCreatorService._();

  static final instance = PodcastCreatorService._();

  static const _claimedKey = 'podcast_creator_claimed';

  SharedPreferences? _preferences;
  bool _claimed = false;
  bool get claimed => _claimed;

  Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    _claimed = preferences.getBool(_claimedKey) ?? false;
  }

  void claim() {
    if (_claimed) return;
    _claimed = true;
    _preferences?.setBool(_claimedKey, true);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _claimed = false;
    notifyListeners();
  }
}

class RelationshipPodcastScreen extends ConsumerStatefulWidget {
  const RelationshipPodcastScreen({super.key});

  @override
  ConsumerState<RelationshipPodcastScreen> createState() =>
      _RelationshipPodcastScreenState();
}

class _RelationshipPodcastScreenState
    extends ConsumerState<RelationshipPodcastScreen> {
  List<ClaimEpisode> _episodes = const [];
  Object? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(claimDraftProvider).show == null) {
        context.go('/screen/claim-podcast');
        return;
      }
      _hydrate();
    });
  }

  Future<void> _hydrate() async {
    final selected = ref.read(claimDraftProvider).show;
    if (selected == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(claimRepositoryProvider);
      final show = await repository.fetchShow(selected.id);
      ref.read(claimDraftProvider.notifier).selectShow(show);
      final episodes = await repository.episodes(show.id);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(claimDraftProvider);
    final show = draft.show;
    final claimed = show?.claimedByViewer ?? false;
    return PelevoPage(
      padding: EdgeInsets.zero,
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed:
                          () =>
                              context.canPop()
                                  ? context.pop()
                                  : context.go('/screen/profile'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Podcast options',
                      onPressed:
                          () => context.showPelevoMessage('Podcast options'),
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PelevoSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PodcastCover(
                          size: 112,
                          artworkUrl: show?.artworkUrl,
                        ),
                        const SizedBox(width: PelevoSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      show?.title.isNotEmpty == true
                                          ? show!.title
                                          : 'Select a podcast to claim',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineMedium,
                                    ),
                                  ),
                                  if (claimed)
                                    const Icon(
                                      Icons.verified,
                                      color: PelevoColors.green,
                                      size: 18,
                                    ),
                                ],
                              ),
                              if (show?.author case final author?
                                  when author.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  author,
                                  style: TextStyle(
                                    color: context.pelevo.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PelevoSpacing.md),
                    if (show != null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  () => context.showPelevoMessage(
                                    'Follow is not available on this screen yet.',
                                  ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: const Text('Follow'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed:
                                () => context.showPelevoMessage(
                                  'Show alerts are not available on this screen yet.',
                                ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(50, 46),
                            ),
                            child: const Icon(Icons.notifications_none_rounded),
                          ),
                        ],
                      ),
                    if (show?.description case final description?
                        when description.isNotEmpty) ...[
                      const SizedBox(height: PelevoSpacing.md),
                      Text(
                        description,
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                    if (show?.episodeCount != null) ...[
                      const SizedBox(height: PelevoSpacing.md),
                      _PodcastStats(episodes: show!.episodeCount!),
                    ],
                    const SizedBox(height: PelevoSpacing.md),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      TextButton(
                        onPressed: _hydrate,
                        child: const Text('Retry'),
                      )
                    else if (claimed)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: PelevoColors.green,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Verified Creator',
                              style: TextStyle(
                                color: PelevoColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _ClaimCard(
                        onTap: () => context.push('/screen/claim-podcast'),
                      ),
                    const SizedBox(height: PelevoSpacing.lg),
                    PelevoSectionHeader(
                      title: 'Latest Episode',
                      onSeeAll:
                          () => context.push(
                            claimed
                                ? '/screen/creator-episodes'
                                : '/screen/podcast-episodes',
                          ),
                    ),
                    if (_episodes.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No episodes are available for this show yet.',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      )
                    else
                      for (final episode in _episodes)
                        _EpisodeTile(
                          title: episode.title,
                          date: episode.publishedAt ?? '',
                          artworkUrl: episode.artworkUrl ?? show?.artworkUrl,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClaimPodcastScreen extends ConsumerStatefulWidget {
  const ClaimPodcastScreen({super.key});

  @override
  ConsumerState<ClaimPodcastScreen> createState() => _ClaimPodcastScreenState();
}

class _ClaimPodcastScreenState extends ConsumerState<ClaimPodcastScreen> {
  final _query = TextEditingController();
  var _searching = false;
  String? _error;
  List<ClaimShow> _results = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Enter at least two characters to search.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(claimRepositoryProvider).searchShows(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _error = 'No matching shows were found.';
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'Shows could not be searched. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(claimDraftProvider).show;
    return PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed:
            () =>
                context.canPop()
                    ? context.pop()
                    : context.go('/screen/profile'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('Claim your podcast'),
      centerTitle: true,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PelevoSpacing.md),
            Center(
              child: Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF2EC742), Color(0xFF0B501F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PelevoColors.green.withValues(alpha: .25),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 62,
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'Take control of your podcast on Pelevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.xl),
            if (ref.watch(myClaimsProvider).value case final claims?
                when claims.isNotEmpty) ...[
              InkWell(
                onTap: () => context.push('/screen/claim-status'),
                borderRadius: PelevoRadii.card,
                child: _Panel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_rounded,
                        color: PelevoColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My claim requests',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${claims.where((claim) => claim.isInReview || claim.needsAction).length} in progress · ${claims.where((claim) => claim.isVerified).length} approved',
                              style: TextStyle(
                                color: context.pelevo.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PelevoSpacing.md),
            ],
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Podcast selected',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search for your podcast',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _searching ? null : _search,
                      child: Text(_searching ? 'Searching…' : 'Search'),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: PelevoColors.red,
                        fontSize: 12,
                      ),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PodcastCover(
                          size: 58,
                          artworkUrl: selected.artworkUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                selected.author ?? '',
                                style: TextStyle(
                                  color: context.pelevo.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  for (final show in _results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _PodcastCover(
                        size: 42,
                        artworkUrl: show.artworkUrl,
                      ),
                      title: Text(show.title),
                      subtitle: Text(show.author ?? ''),
                      onTap:
                          () => ref
                              .read(claimDraftProvider.notifier)
                              .selectShow(show),
                    ),
                  const Divider(height: 28),
                  const Text(
                    'What you’ll get',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final benefit in const [
                    'Edit podcast information',
                    'Podcast & episode analytics',
                    'Understand your listeners',
                    'Create Reels linked to your episodes',
                    'Interact with your audience',
                    'Access creator monetization',
                    'Verified creator badge',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF64D83F),
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          Expanded(child: Text(benefit)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            FilledButton(
              onPressed:
                  selected == null
                      ? null
                      : () => context.push('/screen/claim-method'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF54C923),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PelevoRadii.small),
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class CreatorStudioScreen extends ConsumerWidget {
  const CreatorStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(studioWorkspaceProvider);
    final session = ref.watch(authSessionProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Creator Studio'),
        centerTitle: true,
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: workspace.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => _StudioError(
                  error: error,
                  onRetry: () => ref.invalidate(studioWorkspaceProvider),
                  onClaim: () => context.go('/screen/claim-podcast'),
                ),
            data: (value) {
              final show = value.showFor(ref.watch(selectedStudioShowIdProvider));
              final account = ref.watch(profileProvider).asData?.value;
              final name = account?.name ?? session.displayName;
              final sessionHandle = session.user?['handle'];
              final handle = account != null
                  ? account.handle
                  : sessionHandle is String
                  ? sessionHandle
                  : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your all-in-one hub to grow your podcast\nand build your audience',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  const SizedBox(height: PelevoSpacing.lg),
                  Center(
                    child: ProfileAvatar(
                      url: ref.watch(profileProvider).asData?.value.avatarUrl,
                      size: 94,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (handle is String && handle.isNotEmpty)
                    Text(
                      '@$handle',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  const SizedBox(height: 6),
                  const Center(child: _PurpleBadge('Verified Creator')),
                  const SizedBox(height: PelevoSpacing.xl),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Studios',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => context.push('/screen/creator-add-studio'),
                        child: const Text(
                          'Add New',
                          style: TextStyle(
                            color: PelevoColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (show == null)
                    _Panel(
                      child: Text(
                        'No claimed shows are available yet.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => context.push('/screen/creator-dashboard'),
                      borderRadius: PelevoRadii.card,
                      child: _Panel(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _PodcastCover(
                                  size: 66,
                                  artworkUrl: show.artworkUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        show.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        show.episodeCount == null
                                            ? (show.author ?? '')
                                            : '${show.episodeCount} ${show.episodeCount == 1 ? 'Episode' : 'Episodes'}',
                                        style: TextStyle(
                                          color: context.pelevo.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            if (show.followerCount != null ||
                                show.episodeCount != null) ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  if (show.followerCount != null)
                                    _StudioStat(
                                      '${show.followerCount}',
                                      'Followers',
                                    ),
                                  if (show.episodeCount != null)
                                    _StudioStat(
                                      '${show.episodeCount}',
                                      'Episodes',
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 9),
                  TextButton(
                    onPressed: () => context.push('/screen/creator-studios'),
                    child: Text(
                      'View all studios (${value.shows.length})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PelevoColors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: PelevoSpacing.xl),
                  const Text(
                    'What you can do',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _CreatorAction(
                    Icons.pending_actions_rounded,
                    PelevoColors.green,
                    'My claim requests',
                    'Check pending, expired and approved podcast claims',
                    () => context.push('/screen/claim-status'),
                  ),
                  _CreatorAction(
                    Icons.analytics_outlined,
                    PelevoColors.green,
                    'Track your growth',
                    'Detailed analytics about your audience',
                    () => context.push('/screen/creator-dashboard'),
                  ),
                  _CreatorAction(
                    Icons.forum_outlined,
                    PelevoColors.purple,
                    'Connect with your audience',
                    'Engage, respond and build community',
                    () => context.push('/screen/creator-audience'),
                  ),
                  _CreatorAction(
                    Icons.movie_creation_outlined,
                    PelevoColors.yellow,
                    'Create & share',
                    'Make reels and promote your episodes',
                    () => context.push('/screen/creator-create-reel'),
                  ),
                  _CreatorAction(
                    Icons.monetization_on_outlined,
                    PelevoColors.purple,
                    'Monetize your content',
                    'Earn from gifts, tips and more',
                    () => context.push('/screen/creator-monetization'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _publishedDate(String? publishedAt) {
  if (publishedAt == null || publishedAt.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(publishedAt);
  if (parsed == null) {
    return publishedAt;
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

class _StudioError extends StatelessWidget {
  const _StudioError({
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

class CreatorDashboardScreen extends ConsumerStatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  ConsumerState<CreatorDashboardScreen> createState() =>
      _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends ConsumerState<CreatorDashboardScreen> {
  int _tab = 0;
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(studioWorkspaceProvider);
    return PelevoPage(
    appBar: AppBar(
      title: const Text('Creator Studio'),
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
        child: workspace.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => _StudioError(
                error: error,
                onRetry: () => ref.invalidate(studioWorkspaceProvider),
                onClaim: () => context.go('/screen/claim-podcast'),
              ),
          data: (value) {
            final show = value.showFor(ref.watch(selectedStudioShowIdProvider));
            return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.push('/screen/creator-studios'),
              borderRadius: PelevoRadii.card,
              child: _Panel(
                child: Row(
                  children: [
                    _PodcastCover(
                      size: 58,
                      artworkUrl: show?.artworkUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            show?.title ??
                                'No claimed show yet',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: PelevoColors.green,
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Verified Creator',
                                style: TextStyle(
                                  color: PelevoColors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: InkWell(
                        onTap: () {
                          if (i == 1) {
                            context.go('/screen/creator-episodes');
                          } else if (i == 2) {
                            context.go('/screen/creator-reels');
                          } else if (i == 3) {
                            context.go('/screen/creator-audience');
                          } else if (i == 4) {
                            context.go('/screen/creator-monetization');
                          } else {
                            setState(() => _tab = i);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                                  _tab == i
                                      ? PelevoColors.green
                                      : context.pelevo.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: PelevoSpacing.md),
            if (_tab == 0)
              _overview(context, value, show)
            else
              _placeholder(context),
          ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _overview(
    BuildContext context,
    StudioWorkspace workspace,
    StudioShow? show,
  ) {
    final followers = show?.followerCount ?? workspace.audience.showFollowers;
    final episodes = [
      for (final episode in workspace.episodes)
        if (show == null || episode.showId == null || episode.showId == show.id)
          episode,
    ];
    return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('This Week')),
          ButtonSegment(value: 1, label: Text('This Month')),
          ButtonSegment(value: 2, label: Text('This Year')),
        ],
        selected: {_period},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() => _period = value.first),
      ),
      const SizedBox(height: PelevoSpacing.md),
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              'Listeners',
              '${workspace.audience.listeners30d}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              'Followers',
              '$followers',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              'Show followers',
              '$followers',
            ),
          ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoSectionHeader(
        title: 'Recent Episode Performance',
        onSeeAll: () => context.push('/screen/creator-episodes'),
      ),
      if (episodes.isEmpty)
        Text(
          'No episodes are available yet.',
          style: TextStyle(color: context.pelevo.textMuted),
        )
      else
        for (final episode in episodes)
          _EpisodeTile(
            title: episode.title,
            date: _publishedDate(episode.publishedAt),
            artworkUrl: episode.artworkUrl,
          ),
      const SizedBox(height: PelevoSpacing.md),
      Row(
        children: [
          Expanded(
            child: _QuickCreatorButton(
              icon: Icons.add_box_outlined,
              label: 'Create Reel',
              onTap: () => context.push('/screen/creator-create-reel'),
            ),
          ),
          Expanded(
            child: _QuickCreatorButton(
              icon: Icons.analytics_outlined,
              label: 'Analytics',
              onTap: () => context.push('/screen/creator-audience'),
            ),
          ),
          Expanded(
            child: _QuickCreatorButton(
              icon: Icons.podcasts_rounded,
              label: 'Go Live',
              color: PelevoColors.red,
              badge: 'Soon',
              onTap: () => context.showPelevoMessage('Go Live is coming soon.'),
            ),
          ),
        ],
      ),
    ],
    );
  }

  Widget _placeholder(BuildContext context) => _Panel(
    child: SizedBox(
      height: 360,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            const [
              Icons.analytics_outlined,
              Icons.mic_none_rounded,
              Icons.movie_creation_outlined,
              Icons.groups_outlined,
              Icons.monetization_on_outlined,
            ][_tab],
            size: 54,
            color: PelevoColors.green,
          ),
          const SizedBox(height: 14),
          Text(
            const [
              'Overview',
              'Episodes',
              'Reels',
              'Audience',
              'Monetization',
            ][_tab],
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Creator tools and insights for your podcast.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _PodcastCover extends StatelessWidget {
  const _PodcastCover({required this.size, this.artworkUrl});
  final double size;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFF111016),
      alignment: Alignment.center,
      child: Icon(Icons.podcasts_rounded, color: context.pelevo.textMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
      child:
          artworkUrl != null && artworkUrl!.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: artworkUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => fallback,
              )
              : fallback,
    );
  }
}

class _PodcastStats extends StatelessWidget {
  const _PodcastStats({required this.episodes});
  final int episodes;
  @override
  Widget build(BuildContext context) => _Panel(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [_StudioStat('$episodes', 'Episodes')],
    ),
  );
}

class _StudioStat extends StatelessWidget {
  const _StudioStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(
        label,
        style: TextStyle(color: context.pelevo.textMuted, fontSize: 11),
      ),
    ],
  );
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: PelevoColors.green.withValues(alpha: .08),
      borderRadius: PelevoRadii.card,
      border: Border.all(color: PelevoColors.green),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: PelevoColors.green),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you the creator of this podcast?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Claim this podcast to manage your show, view analytics and grow your audience.',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: PelevoColors.green),
          child: const Text('Claim This Podcast'),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(PelevoSpacing.md),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: child,
  );
}

class _PurpleBadge extends StatelessWidget {
  const _PurpleBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: PelevoColors.purple.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PelevoColors.purple),
    ),
    child: Text(
      label,
      style: const TextStyle(color: PelevoColors.purple, fontSize: 11),
    ),
  );
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.title,
    required this.date,
    this.artworkUrl,
  });
  final String title;
  final String date;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 58,
      height: 58,
      color: context.pelevo.surfaceHigh,
      child: const Icon(Icons.mic_rounded),
    );
    return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(PelevoRadii.small),
      child:
          artworkUrl != null && artworkUrl!.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: artworkUrl!,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => fallback,
              )
              : fallback,
    ),
    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(date),
    trailing: const Icon(Icons.play_circle_outline_rounded),
    onTap: () => context.push('/screen/player-now-playing'),
    );
  }
}

class _CreatorAction extends StatelessWidget {
  const _CreatorAction(
    this.icon,
    this.color,
    this.title,
    this.subtitle,
    this.onTap,
  );
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .14),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.pelevo.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _QuickCreatorButton extends StatelessWidget {
  const _QuickCreatorButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = PelevoColors.green,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10)),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: PelevoColors.yellow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
