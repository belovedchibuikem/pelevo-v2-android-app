import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> creatorAudienceScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'creator-audience',
    section: 'Creator Studio',
    title: 'Audience Overview',
    builder: _buildAudience,
  ),
  const PelevoScreenSpec(
    id: 'creator-audience-followers',
    section: 'Creator Studio',
    title: 'Audience Followers',
    builder: _buildFollowers,
  ),
  const PelevoScreenSpec(
    id: 'creator-audience-supporters',
    section: 'Creator Studio',
    title: 'Top Supporters',
    builder: _buildSupporters,
  ),
  const PelevoScreenSpec(
    id: 'creator-new-episode',
    section: 'Creator Studio',
    title: 'Create Episode',
    builder: _buildNewEpisode,
  ),
  const PelevoScreenSpec(
    id: 'creator-go-live',
    section: 'Creator Studio',
    title: 'Go Live',
    builder: _buildGoLive,
  ),
  const PelevoScreenSpec(
    id: 'creator-tax-information',
    section: 'Creator Monetization',
    title: 'Tax Information',
    builder: _buildTaxInformation,
  ),
  const PelevoScreenSpec(
    id: 'creator-payout-currency',
    section: 'Creator Monetization',
    title: 'Payout Currency',
    builder: _buildCurrency,
  ),
]);

Widget _buildAudience(BuildContext context) => const CreatorAudienceScreen();
Widget _buildFollowers(BuildContext context) =>
    const CreatorAudienceFollowersScreen();
Widget _buildSupporters(BuildContext context) =>
    const CreatorAudienceSupportersScreen();
Widget _buildNewEpisode(BuildContext context) =>
    const CreatorNewEpisodeScreen();
Widget _buildGoLive(BuildContext context) => const CreatorGoLiveScreen();
Widget _buildTaxInformation(BuildContext context) =>
    const CreatorTaxInformationScreen();
Widget _buildCurrency(BuildContext context) =>
    const CreatorPayoutCurrencyScreen();

class CreatorAudienceScreen extends ConsumerStatefulWidget {
  const CreatorAudienceScreen({super.key});

  @override
  ConsumerState<CreatorAudienceScreen> createState() =>
      _CreatorAudienceScreenState();
}

class _CreatorAudienceScreenState extends ConsumerState<CreatorAudienceScreen> {
  int _period = 1;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(studioWorkspaceProvider);
    final period = StudioAudiencePeriod.values[_period];
    final showId = selectedStudioShow(ref)?.id;
    final insightsQuery = (period: period, showId: showId);
    final insightsAsync = ref.watch(
      studioAudienceInsightsProvider(insightsQuery),
    );
    final insights = insightsAsync.asData?.value;
    final insightsLoading = insightsAsync.isLoading && insights == null;
    return _AudienceShell(
      child: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () {
                ref.invalidate(studioWorkspaceProvider);
                ref.invalidate(studioAudienceInsightsProvider(insightsQuery));
              },
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final audience = value.audience;
          final topListeners =
              insights?.topListeners.take(5).toList() ??
              const <StudioTopListener>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Audience',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Understand who listens and what keeps them engaged.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('7D')),
                    ButtonSegment(value: 1, label: Text('30D')),
                    ButtonSegment(value: 2, label: Text('1Y')),
                  ],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged:
                      (next) => setState(() => _period = next.first),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AudienceMetric(
                      icon: Icons.groups_2_outlined,
                      label: 'Followers',
                      value: '${insights?.followers ?? audience.followers}',
                      onTap:
                          () => context.push(
                            '/screen/creator-audience-followers',
                          ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AudienceMetric(
                      icon: Icons.person_add_alt_rounded,
                      label: period.listenersLabel,
                      value:
                          insights != null
                              ? '${insights.listeners}'
                              : period == StudioAudiencePeriod.month
                              ? '${audience.listeners30d}'
                              : '—',
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AudienceMetric(
                      icon: Icons.podcasts_rounded,
                      label: 'Show followers',
                      value:
                          '${insights?.showFollowers ?? audience.showFollowers}',
                    ),
                  ),
                ],
              ),
              if (insights != null) ...[
                const SizedBox(height: 9),
                _AudiencePanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SmallStat('${insights.plays}', 'Episodes played'),
                      _SmallStat('${insights.completions}', 'Completed'),
                      _SmallStat('+${insights.newFollowers}', 'New followers'),
                    ],
                  ),
                ),
              ],
              if (insightsAsync.hasError && insights == null) ...[
                const SizedBox(height: 12),
                _AudiencePanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Audience insights could not load.',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => ref.invalidate(
                              studioAudienceInsightsProvider(insightsQuery),
                            ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _GrowthCard(insights: insights, loading: insightsLoading),
              const SizedBox(height: 12),
              _DemographicsCard(insights: insights, loading: insightsLoading),
              const SizedBox(height: 12),
              _LocationCard(insights: insights, loading: insightsLoading),
              const SizedBox(height: 12),
              _ListeningTimesCard(insights: insights, loading: insightsLoading),
              const SizedBox(height: 12),
              _AudiencePanel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Most Engaged Listeners',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => context.push(
                                '/screen/creator-audience-supporters',
                              ),
                          child: const Text(
                            'Supporters',
                            style: TextStyle(color: PelevoColors.green),
                          ),
                        ),
                      ],
                    ),
                    if (insightsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (topListeners.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No listeners in this period yet.',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      )
                    else
                      for (final listener in topListeners)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: PelevoColors.green.withValues(
                              alpha: .18,
                            ),
                            child: Text(
                              listener.name.isEmpty
                                  ? '?'
                                  : listener.name.characters.first
                                      .toUpperCase(),
                            ),
                          ),
                          title: Text(listener.name),
                          subtitle: Text(listener.subtitle),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorAudienceFollowersScreen extends ConsumerStatefulWidget {
  const CreatorAudienceFollowersScreen({super.key});

  @override
  ConsumerState<CreatorAudienceFollowersScreen> createState() =>
      _CreatorAudienceFollowersScreenState();
}

class _CreatorAudienceFollowersScreenState
    extends ConsumerState<CreatorAudienceFollowersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final followers = ref.watch(studioFollowersProvider);
    final workspace = ref.watch(studioWorkspaceProvider);
    return _AudienceDetailPage(
      title: 'Audience Followers',
      child: followers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioFollowersProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (page) {
          final query = _query.trim().toLowerCase();
          final filtered =
              query.isEmpty
                  ? page.items
                  : page.items
                      .where(
                        (item) =>
                            item.name.toLowerCase().contains(query) ||
                            item.handleLabel.toLowerCase().contains(query),
                      )
                      .toList();
          final total = workspace.asData?.value.audience.followers;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AudiencePanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SmallStat(
                      '${total ?? page.items.length}',
                      'Total followers',
                    ),
                    _SmallStat('${page.items.length}', 'Loaded'),
                    const _SmallStat('â€”', 'Engaged'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search listeners',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${filtered.length} listeners',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No followers yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                )
              else
                for (final listener in filtered)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.pelevo.surfaceHigh,
                      child: Text(listener.name.characters.first),
                    ),
                    title: Text(listener.name),
                    subtitle: Text(
                      [
                        if (listener.handleLabel.isNotEmpty)
                          listener.handleLabel,
                        if (listener.createdLabel.isNotEmpty)
                          listener.createdLabel,
                      ].join(' Â· '),
                    ),
                    onTap:
                        () =>
                            context.push('/screen/creator-audience-supporters'),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorAudienceSupportersScreen extends ConsumerWidget {
  const CreatorAudienceSupportersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supporters = ref.watch(studioSupportersProvider);
    return _AudienceDetailPage(
      title: 'Top Supporters',
      child: supporters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioSupportersProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data:
            (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AudiencePanel(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: PelevoColors.yellow,
                        size: 42,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your community showed up',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${page.coinsReceived} coins received from ${page.supportersCount} supporters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (page.items.isEmpty)
                  Text(
                    'No supporters yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  )
                else
                  for (var i = 0; i < page.items.length; i++)
                    Card(
                      color: context.pelevo.surface,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              i < 3
                                  ? [
                                    PelevoColors.yellow,
                                    context.pelevo.textMuted,
                                    PelevoColors.orange,
                                  ][i]
                                  : context.pelevo.surfaceHigh,
                          child: Text('${i + 1}'),
                        ),
                        title: Text(page.items[i].name),
                        subtitle: Text(page.items[i].subtitle),
                        trailing: IconButton(
                          tooltip: 'Thank supporter',
                          onPressed:
                              () => context.showPelevoMessage(
                                'Thank-you messages are not available yet.',
                              ),
                          icon: const Icon(
                            Icons.favorite_outline_rounded,
                            color: PelevoColors.green,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
      ),
    );
  }
}

class CreatorNewEpisodeScreen extends ConsumerStatefulWidget {
  const CreatorNewEpisodeScreen({super.key});

  @override
  ConsumerState<CreatorNewEpisodeScreen> createState() =>
      _CreatorNewEpisodeScreenState();
}

class _CreatorNewEpisodeScreenState
    extends ConsumerState<CreatorNewEpisodeScreen> {
  bool _explicit = false;
  bool _schedule = false;
  bool _saving = false;
  String? _error;
  String? _audioPath;
  String? _audioName;
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null || file.path!.isEmpty) {
      setState(() => _error = 'Could not read the selected audio file.');
      return;
    }
    setState(() {
      _audioPath = file.path;
      _audioName = file.name;
      _error = null;
    });
  }

  Future<void> _saveDraft(StudioShow? show) async {
    final title = _title.text.trim();
    if (show == null) {
      setState(() => _error = 'A claimed show is required to save a draft.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Give your episode a clear title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = await ref
          .read(studioRepositoryProvider)
          .createEpisodeDraft(
            showId: show.id,
            title: title,
            description: _description.text.trim(),
          );
      if (_audioPath != null && _audioName != null) {
        await ref
            .read(studioRepositoryProvider)
            .uploadEpisodeAudio(
              episodeId: draft.id,
              filePath: _audioPath!,
              fileName: _audioName!,
            );
      }
      if (!mounted) {
        return;
      }
      ref.invalidate(studioEpisodesProvider);
      ref.invalidate(studioWorkspaceProvider);
      context.showPelevoMessage('Draft saved');
      context.go('/screen/creator-episodes');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'The episode draft could not be saved. Please try again.';
      });
    }
  }

  Future<void> _publish(StudioShow? show) async {
    final title = _title.text.trim();
    if (show == null) {
      setState(() => _error = 'A claimed show is required to publish.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Give your episode a clear title.');
      return;
    }
    if (_audioPath == null || _audioName == null) {
      setState(() => _error = 'Episode audio is required to publish.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = await ref
          .read(studioRepositoryProvider)
          .createEpisodeDraft(
            showId: show.id,
            title: title,
            description: _description.text.trim(),
          );
      await ref
          .read(studioRepositoryProvider)
          .uploadEpisodeAudio(
            episodeId: draft.id,
            filePath: _audioPath!,
            fileName: _audioName!,
          );
      await ref
          .read(studioRepositoryProvider)
          .publishEpisode(
            episodeId: draft.id,
            scheduledAt:
                _schedule
                    ? DateTime.now().toUtc().add(const Duration(hours: 24))
                    : null,
          );
      if (!mounted) return;
      ref.invalidate(studioEpisodesProvider);
      ref.invalidate(studioWorkspaceProvider);
      context.showPelevoMessage(
        _schedule
            ? 'Episode scheduled for tomorrow (UTC).'
            : 'Episode published.',
      );
      context.go('/screen/creator-episodes');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'The episode could not be published. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(studioWorkspaceProvider);
    final show = selectedStudioShow(ref);
    return _AudienceDetailPage(
      title: 'New Episode',
      backRoute: '/screen/creator-episodes',
      child: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data:
            (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Episode artwork & audio',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      onTap:
                          () => context.showPelevoMessage(
                            'Episode artwork is not available yet.',
                          ),
                      child: Container(
                        width: 106,
                        height: 106,
                        decoration: BoxDecoration(
                          color: context.pelevo.surface,
                          borderRadius: PelevoRadii.card,
                          border: Border.all(color: context.pelevo.border),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            SizedBox(height: 5),
                            Text('Add cover', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _saving ? null : _pickAudio,
                        child: Container(
                          height: 106,
                          decoration: BoxDecoration(
                            color: PelevoColors.green.withValues(alpha: .08),
                            borderRadius: PelevoRadii.card,
                            border: Border.all(color: PelevoColors.green),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.upload_file_rounded,
                                color: PelevoColors.green,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _audioName == null
                                    ? 'Upload episode audio'
                                    : _audioName!,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'MP3, M4A or WAV · Max 500MB',
                                style: TextStyle(
                                  color: context.pelevo.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Episode title'),
                const SizedBox(height: 6),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'Give your episode a clear title',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: _description,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText: 'Tell listeners what this episode is about',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _explicit,
                  activeColor: PelevoColors.green,
                  title: const Text('Contains explicit content'),
                  subtitle: const Text('Show an explicit-content label'),
                  onChanged: (value) => setState(() => _explicit = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _schedule,
                  activeColor: PelevoColors.green,
                  title: const Text('Schedule for later'),
                  subtitle: Text(
                    _schedule
                        ? 'Will schedule ~24 hours from now (UTC).'
                        : 'Publish immediately',
                  ),
                  onChanged: (value) => setState(() => _schedule = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: PelevoColors.red),
                  ),
                ],
                const SizedBox(height: 18),
                PelevoButton(
                  label: _schedule ? 'Schedule Episode' : 'Publish Episode',
                  color: PelevoColors.green,
                  onPressed: _saving ? null : () => _publish(show),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _saveDraft(show),
                  child: const Text('Save as Draft'),
                ),
              ],
            ),
      ),
    );
  }
}

class CreatorGoLiveScreen extends ConsumerStatefulWidget {
  const CreatorGoLiveScreen({super.key});

  @override
  ConsumerState<CreatorGoLiveScreen> createState() =>
      _CreatorGoLiveScreenState();
}

class _CreatorGoLiveScreenState extends ConsumerState<CreatorGoLiveScreen> {
  bool _notify = true;
  bool _comments = true;
  bool _saving = false;
  String? _error;
  String? _showId;
  StudioLiveSession? _live;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _goLive(List<StudioShow> shows) async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a live title.');
      return;
    }
    final showId = _showId ?? (shows.isEmpty ? null : shows.first.id);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(studioRepositoryProvider)
          .startLive(
            title: title,
            showId: showId,
            notifyFollowers: _notify,
            commentsEnabled: _comments,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _live = session;
      });
      if (!session.muxReady) {
        context.showPelevoMessage(
          session.muxMessage ??
              'Live session started. Mux ingest is not ready yet.',
        );
      } else {
        context.showPelevoMessage(
          'You are live. Connect your encoder with the stream key below.',
        );
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'The live session could not be started. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(studioWorkspaceProvider);
    return _AudienceDetailPage(
      title: 'Go Live',
      backRoute: '/screen/creator-dashboard',
      child: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final shows = value.shows;
          final selectedId =
              _showId != null && shows.any((show) => show.id == _showId)
                  ? _showId
                  : (shows.isEmpty ? null : shows.first.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AudiencePanel(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0x332FA44F),
                      child: Icon(
                        Icons.podcasts_rounded,
                        size: 42,
                        color: PelevoColors.green,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Start a live conversation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Broadcast to your followers and engage in real time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Live title'),
              const SizedBox(height: 6),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  hintText: 'What will you talk about?',
                ),
              ),
              const SizedBox(height: 14),
              const Text('Topic'),
              const SizedBox(height: 6),
              if (shows.isEmpty)
                Text(
                  'A claimed show is required to go live.',
                  style: TextStyle(color: context.pelevo.textMuted),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedId,
                  items: [
                    for (final show in shows)
                      DropdownMenuItem(value: show.id, child: Text(show.title)),
                  ],
                  onChanged: (value) => setState(() => _showId = value),
                ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notify,
                title: const Text('Notify followers'),
                subtitle: const Text('Send an alert when you go live'),
                onChanged: (value) => setState(() => _notify = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _comments,
                title: const Text('Live comments'),
                subtitle: const Text('Allow listeners to participate'),
                onChanged: (value) => setState(() => _comments = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: PelevoColors.red)),
              ],
              const SizedBox(height: 18),
              PelevoButton(
                label: _saving ? 'Starting…' : 'Go Live Now',
                color: PelevoColors.red,
                icon: Icons.podcasts_rounded,
                onPressed:
                    _saving || shows.isEmpty ? null : () => _goLive(shows),
              ),
              if (_live != null) ...[
                const SizedBox(height: 18),
                Text(
                  _live!.muxReady
                      ? 'Live now — connect your encoder'
                      : 'Session created',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _live!.muxMessage ??
                      'Use OBS or Streamlabs with the RTMP URL and stream key below.',
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
                if (_live!.ingestUrl != null && _live!.ingestUrl!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ingest URL'),
                    subtitle: Text(_live!.ingestUrl!),
                    trailing: IconButton(
                      tooltip: 'Copy ingest URL',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _live!.ingestUrl!),
                        );
                        context.showPelevoMessage('Ingest URL copied');
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                if (_live!.streamKey != null && _live!.streamKey!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stream key'),
                    subtitle: const Text('Keep this private'),
                    trailing: IconButton(
                      tooltip: 'Copy stream key',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _live!.streamKey!),
                        );
                        context.showPelevoMessage('Stream key copied');
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                if (_live!.playbackUrl != null &&
                    _live!.playbackUrl!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Playback URL'),
                    subtitle: Text(_live!.playbackUrl!),
                    trailing: IconButton(
                      tooltip: 'Copy playback URL',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _live!.playbackUrl!),
                        );
                        context.showPelevoMessage('Playback URL copied');
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CreatorTaxInformationScreen extends ConsumerStatefulWidget {
  const CreatorTaxInformationScreen({super.key});

  @override
  ConsumerState<CreatorTaxInformationScreen> createState() =>
      _CreatorTaxInformationScreenState();
}

class _CreatorTaxInformationScreenState
    extends ConsumerState<CreatorTaxInformationScreen> {
  String _type = 'Individual';
  bool _saving = false;
  String? _error;
  final _country = TextEditingController();
  final _legalName = TextEditingController();
  final _taxId = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _country.dispose();
    _legalName.dispose();
    _taxId.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final country = _country.text.trim().toUpperCase();
    if (country.length != 2) {
      setState(() => _error = 'Enter a two-letter country code.');
      return;
    }
    if (_legalName.text.trim().isEmpty || _taxId.text.trim().isEmpty) {
      setState(
        () => _error = 'Legal name and tax identification number are required.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(studioRepositoryProvider)
          .updatePayoutSettings(
            countryCode: country,
            taxDetails: {
              'account_type': _type,
              'legal_name': _legalName.text.trim(),
              'tax_id': _taxId.text.trim(),
              if (_address.text.trim().isNotEmpty)
                'address': _address.text.trim(),
            },
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(studioPayoutWorkspaceProvider);
      context.showPelevoMessage('Tax information saved');
      context.go('/screen/creator-payout-settings');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'Tax information could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = ref.watch(studioPayoutWorkspaceProvider);
    return _AudienceDetailPage(
      title: 'Tax Information',
      backRoute: '/screen/creator-payout-settings',
      child: payout.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioPayoutWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data:
            (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AudiencePanel(
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: PelevoColors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your tax information is encrypted and used only for payout compliance.',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Account type'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Individual',
                      label: Text('Individual'),
                    ),
                    ButtonSegment(value: 'Business', label: Text('Business')),
                  ],
                  selected: {_type},
                  onSelectionChanged:
                      (value) => setState(() => _type = value.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _country,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Country code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _legalName,
                  decoration: const InputDecoration(hintText: 'Legal name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxId,
                  decoration: const InputDecoration(
                    hintText: 'Tax identification number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    hintText: 'Residential address',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: PelevoColors.red),
                  ),
                ],
                const SizedBox(height: 18),
                PelevoButton(
                  label: 'Save Tax Information',
                  color: PelevoColors.green,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
      ),
    );
  }
}

class CreatorPayoutCurrencyScreen extends ConsumerStatefulWidget {
  const CreatorPayoutCurrencyScreen({super.key});

  @override
  ConsumerState<CreatorPayoutCurrencyScreen> createState() =>
      _CreatorPayoutCurrencyScreenState();
}

class _CreatorPayoutCurrencyScreenState
    extends ConsumerState<CreatorPayoutCurrencyScreen> {
  String? _currency;
  bool _saving = false;
  String? _error;

  static const _currencies = [
    ('NGN', 'NGN', 'Nigerian Naira'),
    ('USD', 'USD', 'US Dollar'),
  ];

  Future<void> _save() async {
    final currency = _currency;
    if (currency == null || currency.isEmpty) {
      setState(() => _error = 'Choose a payout currency.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(studioRepositoryProvider)
          .updatePayoutSettings(currency: currency, adPayoutCurrency: currency);
      if (!mounted) {
        return;
      }
      ref.invalidate(studioPayoutWorkspaceProvider);
      context.showPelevoMessage('Payout currency updated');
      context.go('/screen/creator-payout-settings');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error =
            error is ApiFailure
                ? error.message
                : error is DioException
                ? apiFailureFromDio(error).message
                : 'Payout currency could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = ref.watch(studioPayoutWorkspaceProvider);
    return _AudienceDetailPage(
      title: 'Payout Currency',
      backRoute: '/screen/creator-payout-settings',
      child: payout.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioPayoutWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final saved = value.config.adPayoutCurrency ?? value.config.currency;
          final selected =
              _currency ?? (saved != null && saved.isNotEmpty ? saved : null);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose USD or Nigerian naira for future creator payouts. Existing balances stay in their current currency.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              const SizedBox(height: 14),
              for (final item in _currencies)
                RadioListTile<String>(
                  value: item.$1,
                  groupValue: selected,
                  activeColor: PelevoColors.green,
                  secondary: Text(
                    item.$2,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text('${item.$1} · ${item.$3}'),
                  onChanged: (value) => setState(() => _currency = value),
                ),
              if (selected != null &&
                  !_currencies.any((item) => item.$1 == selected))
                RadioListTile<String>(
                  value: selected,
                  groupValue: selected,
                  activeColor: PelevoColors.green,
                  title: Text(selected),
                  onChanged: (value) => setState(() => _currency = value),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: PelevoColors.red)),
              ],
              const SizedBox(height: 18),
              PelevoButton(
                label: 'Save Currency',
                color: PelevoColors.green,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
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
            needsClaim ? 'A verified show claim is required.' : failure.message,
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

class _AudienceShell extends StatelessWidget {
  const _AudienceShell({required this.child});
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
            const SizedBox(height: 10),
            const _AudienceTabs(),
            const Divider(height: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

class _AudienceDetailPage extends StatelessWidget {
  const _AudienceDetailPage({
    required this.title,
    required this.child,
    this.backRoute = '/screen/creator-audience',
  });
  final String title;
  final Widget child;
  final String backRoute;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed:
            () => context.canPop() ? context.pop() : context.go(backRoute),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(title),
      centerTitle: true,
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: 0,
      onDestinationSelected: context.openPelevoTab,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: child,
      ),
    ),
  );
}

class _PodcastHeader extends ConsumerWidget {
  const _PodcastHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = selectedStudioShow(ref);
    final artwork = show?.artworkUrl;
    final fallback = Container(
      width: 54,
      height: 54,
      color: const Color(0xFF111016),
      alignment: Alignment.center,
      child: Icon(Icons.podcasts_rounded, color: context.pelevo.textMuted),
    );
    final subtitle = [
      if (show?.episodeCount != null) '${show!.episodeCount} Episodes',
      if (show?.followerCount != null) '${show!.followerCount} followers',
    ].join(' Â· ');
    return InkWell(
      onTap: () => context.push('/screen/creator-studios'),
      borderRadius: PelevoRadii.card,
      child: _AudiencePanel(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child:
                  artwork != null && artwork.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: artwork,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => fallback,
                      )
                      : Image.asset(
                        'assets/creator/relationship_cover.png',
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
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
                          show?.title ?? 'No claimed show yet',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: PelevoColors.green,
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.pelevo.textMuted,
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

class _AudienceTabs extends StatelessWidget {
  const _AudienceTabs();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < 5; i++)
          InkWell(
            onTap:
                () => context.go(
                  const [
                    '/screen/creator-dashboard',
                    '/screen/creator-episodes',
                    '/screen/creator-reels',
                    '/screen/creator-audience',
                    '/screen/creator-monetization',
                  ][i],
                ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: i == 3 ? PelevoColors.green : Colors.transparent,
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
                  color: i == 3 ? PelevoColors.green : context.pelevo.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AudienceMetric extends StatelessWidget {
  const _AudienceMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: PelevoRadii.card,
    child: _AudiencePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PelevoColors.green, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.loading,
    required this.empty,
    required this.emptyText,
    required this.builder,
  });

  final String title;
  final bool loading;
  final bool empty;
  final String emptyText;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => _AudiencePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (empty)
          Text(
            emptyText,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
          )
        else
          builder(context),
      ],
    ),
  );
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.label,
    required this.share,
    required this.trailing,
    this.color = PelevoColors.green,
  });

  final String label;
  final double share;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                color: context.pelevo.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: context.pelevo.border,
          ),
        ),
      ],
    ),
  );
}

String _percent(double share) => '${(share * 100).round()}%';

String _flagFor(String? code) {
  if (code == null || code.length != 2) return '🌍';
  final upper = code.toUpperCase();
  return String.fromCharCodes([
    0x1F1E6 + upper.codeUnitAt(0) - 65,
    0x1F1E6 + upper.codeUnitAt(1) - 65,
  ]);
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.insights, required this.loading});

  final StudioAudienceInsights? insights;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final growth = insights?.growth ?? const <StudioGrowthPoint>[];
    final labels =
        growth.isEmpty
            ? const <String>[]
            : growth.length <= 5
            ? [for (final point in growth) point.label]
            : [
              for (final index in [
                0,
                (growth.length - 1) ~/ 2,
                growth.length - 1,
              ])
                growth[index].label,
            ];
    return _InsightCard(
      title: 'Audience Growth',
      loading: loading,
      empty: growth.isEmpty,
      emptyText: 'No audience activity in this period yet.',
      builder:
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _AudienceGrowthPainter(
                    growth,
                    gridColor: context.pelevo.border.withValues(alpha: .5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in labels)
                    Text(
                      label,
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Dot(color: PelevoColors.green),
                  SizedBox(width: 6),
                  Text(
                    'Total followers',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 16),
                  _Dot(color: PelevoColors.blue),
                  SizedBox(width: 6),
                  Text(
                    'Active listeners',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _AudienceGrowthPainter extends CustomPainter {
  const _AudienceGrowthPainter(this.growth, {required this.gridColor});

  final List<StudioGrowthPoint> growth;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        grid,
      );
    }
    if (growth.isEmpty) return;
    final peak = growth.fold<int>(
      1,
      (max, point) => [
        max,
        point.followers,
        point.listeners,
      ].reduce((a, b) => a > b ? a : b),
    );
    final slot = size.width / growth.length;
    final barWidth = (slot * .55).clamp(2.0, 18.0);
    final bars = Paint()..color = PelevoColors.blue.withValues(alpha: .65);
    for (var i = 0; i < growth.length; i++) {
      final height = (size.height - 4) * growth[i].listeners / peak;
      if (height <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            slot * i + (slot - barWidth) / 2,
            size.height - height,
            barWidth,
            height,
          ),
          const Radius.circular(2),
        ),
        bars,
      );
    }
    final line = Path();
    for (var i = 0; i < growth.length; i++) {
      final point = Offset(
        slot * i + slot / 2,
        size.height - (size.height - 4) * growth[i].followers / peak,
      );
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = PelevoColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AudienceGrowthPainter oldDelegate) =>
      !identical(oldDelegate.growth, growth) ||
      oldDelegate.gridColor != gridColor;
}

class _DemographicsCard extends StatelessWidget {
  const _DemographicsCard({required this.insights, required this.loading});

  final StudioAudienceInsights? insights;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final value = insights;
    final total = value?.listeners ?? 0;
    return _InsightCard(
      title: 'Listener Demographics',
      loading: loading,
      empty: value == null || total == 0,
      emptyText: 'No listeners in this period yet.',
      builder:
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShareBar(
                label: 'New listeners',
                share: value!.newListeners / total,
                trailing:
                    '${value.newListeners} · ${_percent(value.newListeners / total)}',
              ),
              _ShareBar(
                label: 'Returning listeners',
                share: value.returningListeners / total,
                trailing:
                    '${value.returningListeners} · ${_percent(value.returningListeners / total)}',
                color: PelevoColors.blue,
              ),
              if (value.platforms.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Listening platform',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                for (final platform in value.platforms)
                  _ShareBar(
                    label: platform.label,
                    share: platform.share,
                    trailing:
                        '${platform.listeners} · ${_percent(platform.share)}',
                    color: PelevoColors.purple,
                  ),
              ],
            ],
          ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.insights, required this.loading});

  final StudioAudienceInsights? insights;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final locations = insights?.locations ?? const <StudioShare>[];
    return _InsightCard(
      title: 'Top Locations',
      loading: loading,
      empty: locations.isEmpty,
      emptyText: 'No listener locations in this period yet.',
      builder:
          (context) => Column(
            children: [
              for (final location in locations)
                _ShareBar(
                  label: '${_flagFor(location.code)}  ${location.label}',
                  share: location.share,
                  trailing:
                      '${location.listeners} · ${_percent(location.share)}',
                ),
            ],
          ),
    );
  }
}

class _ListeningTimesCard extends StatelessWidget {
  const _ListeningTimesCard({required this.insights, required this.loading});

  final StudioAudienceInsights? insights;
  final bool loading;

  static const _dayparts = [
    ('Night', 0, 6),
    ('Morning', 6, 12),
    ('Afternoon', 12, 18),
    ('Evening', 18, 24),
  ];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final hours = insights?.listeningHours ?? const <int>[];
    final weekdays = insights?.listeningWeekdays ?? const <int>[];
    final total = hours.fold<int>(0, (sum, value) => sum + value);
    final weekdayPeak = weekdays.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return _InsightCard(
      title: 'When Your Audience Listens',
      loading: loading,
      empty: total == 0,
      emptyText: 'No listening activity in this period yet.',
      builder: (context) {
        final parts = [
          for (final (label, start, end) in _dayparts)
            (
              label,
              hours
                  .sublist(start, end.clamp(0, hours.length))
                  .fold<int>(0, (sum, value) => sum + value),
            ),
        ];
        final busiest = parts.reduce((a, b) => b.$2 > a.$2 ? b : a);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most listening happens in the ${busiest.$1.toLowerCase()} (listener local time).',
              style: TextStyle(
                color: context.pelevo.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            for (final (label, count) in parts)
              _ShareBar(
                label: label,
                share: count / total,
                trailing: _percent(count / total),
                color:
                    label == busiest.$1
                        ? PelevoColors.green
                        : PelevoColors.blue,
              ),
            if (weekdays.length == 7) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 48 * weekdays[i] / weekdayPeak,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: PelevoColors.green.withValues(
                                  alpha: .7,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weekdayLabels[i],
                              style: TextStyle(
                                color: context.pelevo.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      Text(
        label,
        style: TextStyle(color: context.pelevo.textMuted, fontSize: 10),
      ),
    ],
  );
}

class _AudiencePanel extends StatelessWidget {
  const _AudiencePanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: child,
  );
}
