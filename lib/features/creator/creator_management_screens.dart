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
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> creatorManagementScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'creator-studios',
    section: 'Creator Studio',
    title: 'Your Studios',
    builder: _buildStudios,
  ),
  const PelevoScreenSpec(
    id: 'creator-add-studio',
    section: 'Creator Studio',
    title: 'Add Studio',
    builder: _buildAddStudio,
  ),
  const PelevoScreenSpec(
    id: 'creator-payout-schedule',
    section: 'Creator Monetization',
    title: 'Payout Schedule',
    builder: _buildPayoutSchedule,
  ),
]);

Widget _buildStudios(BuildContext context) => const CreatorStudiosScreen();
Widget _buildAddStudio(BuildContext context) => const CreatorAddStudioScreen();
Widget _buildPayoutSchedule(BuildContext context) =>
    const CreatorPayoutScheduleScreen();

class CreatorStudiosScreen extends ConsumerWidget {
  const CreatorStudiosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(studioWorkspaceProvider);
    final selectedId = ref.watch(selectedStudioShowIdProvider);
    return _ManagementPage(
      title: 'Your Studios',
      backRoute: '/screen/creator-studio',
      action: IconButton(
        tooltip: 'Add studio',
        onPressed: () => context.push('/screen/creator-add-studio'),
        icon: const Icon(Icons.add_rounded),
      ),
      child: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final active = value.showFor(selectedId);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manage the podcasts connected to your creator profile.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              const SizedBox(height: 18),
              if (value.shows.isEmpty)
                Text(
                  'No claimed shows are available yet.',
                  style: TextStyle(color: context.pelevo.textMuted),
                )
              else
                for (var i = 0; i < value.shows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _StudioCard(
                    title: value.shows[i].title,
                    subtitle: _showSubtitle(value.shows[i]),
                    artworkUrl: value.shows[i].artworkUrl,
                    accent: const [
                      PelevoColors.green,
                      PelevoColors.purple,
                      PelevoColors.yellow,
                    ][i % 3],
                    selected: value.shows[i].id == active?.id,
                    onTap: () {
                      ref
                          .read(selectedStudioShowIdProvider.notifier)
                          .select(value.shows[i].id);
                      context.go('/screen/creator-dashboard');
                    },
                  ),
                ],
              const SizedBox(height: 18),
              PelevoButton(
                label: 'Add Another Podcast',
                color: PelevoColors.green,
                icon: Icons.add_rounded,
                onPressed: () => context.push('/screen/creator-add-studio'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _showSubtitle(StudioShow show) {
    final episodes = show.episodeCount;
    final followers = show.followerCount;
    final parts = [
      if (episodes != null) '$episodes ${episodes == 1 ? 'episode' : 'episodes'}',
      if (followers != null)
        '$followers ${followers == 1 ? 'follower' : 'followers'}',
    ];
    if (parts.isEmpty) {
      return show.author ?? '';
    }
    return parts.join(' · ');
  }
}

class CreatorAddStudioScreen extends ConsumerStatefulWidget {
  const CreatorAddStudioScreen({super.key});

  @override
  ConsumerState<CreatorAddStudioScreen> createState() =>
      _CreatorAddStudioScreenState();
}

class _CreatorAddStudioScreenState
    extends ConsumerState<CreatorAddStudioScreen> {
  int _source = 0;
  var _searching = false;
  String? _error;
  List<ClaimShow> _results = const [];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
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
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _error = 'No matching shows were found.';
        }
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
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

  void _select(ClaimShow show) {
    ref.read(claimDraftProvider.notifier).selectShow(show);
    context.push('/screen/claim-method');
  }

  @override
  Widget build(BuildContext context) => _ManagementPage(
    title: 'Add Studio',
    backRoute: '/screen/creator-studios',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ManagementPanel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Color(0x332FA44F),
                child: Icon(
                  Icons.podcasts_rounded,
                  color: PelevoColors.green,
                  size: 38,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Connect another podcast',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                'Add a show by RSS feed or search the Pelevo catalog.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.pelevo.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.rss_feed_rounded),
              label: Text('RSS Feed'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.search_rounded),
              label: Text('Search Pelevo'),
            ),
          ],
          selected: {_source},
          onSelectionChanged: (value) => setState(() => _source = value.first),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                _source == 0
                    ? 'Paste your podcast RSS URL'
                    : 'Search by podcast name',
            prefixIcon: Icon(
              _source == 0 ? Icons.link_rounded : Icons.search_rounded,
            ),
          ),
          onSubmitted: (_) {
            if (!_searching) {
              _search();
            }
          },
        ),
        const SizedBox(height: 14),
        _ManagementPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: PelevoColors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You’ll verify ownership before management, analytics, and monetization tools are enabled.',
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: PelevoColors.red)),
        ],
        for (final show in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _StudioCover(size: 42, artworkUrl: show.artworkUrl),
            title: Text(show.title),
            subtitle: Text(show.author ?? ''),
            onTap: () => _select(show),
          ),
        const SizedBox(height: 22),
        PelevoButton(
          label: _source == 0 ? 'Find Podcast' : 'Search Podcasts',
          color: PelevoColors.green,
          onPressed: _searching ? null : _search,
        ),
      ],
    ),
  );
}

class CreatorPayoutScheduleScreen extends ConsumerStatefulWidget {
  const CreatorPayoutScheduleScreen({super.key});

  @override
  ConsumerState<CreatorPayoutScheduleScreen> createState() =>
      _CreatorPayoutScheduleScreenState();
}

class _CreatorPayoutScheduleScreenState
    extends ConsumerState<CreatorPayoutScheduleScreen> {
  int? _schedule;
  double? _threshold;
  bool _saving = false;
  String? _error;

  static const _schedules = ['weekly', 'monthly', 'manual'];

  int? _indexFor(String? value) {
    final index = _schedules.indexOf(value ?? '');
    return index < 0 ? null : index;
  }

  Future<void> _save(StudioPayoutWorkspace workspace) async {
    final schedule = _schedule;
    final threshold = _threshold ?? workspace.config.minimumAmount?.toDouble();
    if (schedule == null || schedule < 0 || schedule >= _schedules.length) {
      setState(() => _error = 'Choose a payout schedule.');
      return;
    }
    final amount = (threshold ?? 1000).round();
    if (amount < 1000) {
      setState(() => _error = 'Minimum payout is 1000.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(studioRepositoryProvider).updatePayoutSettings(
        schedule: _schedules[schedule],
        minimumAmount: amount,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(studioPayoutWorkspaceProvider);
      context.showPelevoMessage('Payout schedule updated');
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
                : 'Payout schedule could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = ref.watch(studioPayoutWorkspaceProvider);
    return _ManagementPage(
      title: 'Payout Schedule',
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
          final selected = _schedule ?? _indexFor(value.config.schedule);
          final unit = value.monetization.primaryBalance?.unit ?? 'PCN';
          final minAmount = (value.config.minimumAmount ?? 1000).toDouble();
          final threshold = (_threshold ?? minAmount).clamp(1000, 100000).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose when your creator earnings are transferred.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: selected,
                  activeColor: PelevoColors.green,
                  title: Text(
                    const ['Every 7 days', 'Monthly', 'Manual payouts'][i],
                  ),
                  subtitle: Text(
                    const [
                      'Recommended · fastest regular payout',
                      'Paid on the first business day each month',
                      'Request a payout whenever you are ready',
                    ][i],
                  ),
                  onChanged: (value) => setState(() => _schedule = value),
                ),
              const SizedBox(height: 16),
              _ManagementPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minimum payout threshold',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${threshold.round()} $unit',
                      style: const TextStyle(
                        color: PelevoColors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Slider(
                      value: threshold,
                      min: 1000,
                      max: 100000,
                      divisions: 99,
                      activeColor: PelevoColors.green,
                      label: '${threshold.round()} $unit',
                      onChanged: (value) => setState(() => _threshold = value),
                    ),
                    Text(
                      'Payouts are sent only when your available balance reaches this amount.',
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: PelevoColors.red),
                ),
              ],
              const SizedBox(height: 22),
              PelevoButton(
                label: 'Save Payout Schedule',
                color: PelevoColors.green,
                onPressed: _saving ? null : () => _save(value),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.artworkUrl,
    this.selected = false,
  });
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final String? artworkUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: PelevoRadii.card,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pelevo.surface,
        borderRadius: PelevoRadii.card,
        border: Border.all(
          color: selected ? PelevoColors.green : context.pelevo.border,
        ),
      ),
      child: Row(
        children: [
          _StudioCover(size: 60, artworkUrl: artworkUrl, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (selected)
                  const Text(
                    'Active studio',
                    style: TextStyle(color: PelevoColors.green, fontSize: 11),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _StudioCover extends StatelessWidget {
  const _StudioCover({required this.size, this.artworkUrl, this.accent});
  final double size;
  final String? artworkUrl;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [accent ?? PelevoColors.green, Colors.black],
        ),
      ),
      child: const Icon(Icons.mic_rounded),
    );
    if (artworkUrl == null || artworkUrl!.isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: artworkUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _ManagementPage extends StatelessWidget {
  const _ManagementPage({
    required this.title,
    required this.backRoute,
    required this.child,
    this.action,
  });
  final String title;
  final String backRoute;
  final Widget child;
  final Widget? action;

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
      actions: [if (action != null) action!],
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: 0,
      onDestinationSelected: context.openPelevoTab,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    ),
  );
}

class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: child,
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
