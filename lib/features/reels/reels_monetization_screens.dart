import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:pelevo/features/reels/reels_monetization_service.dart';

class ReelsMonetizationScreen extends ConsumerStatefulWidget {
  const ReelsMonetizationScreen({super.key, this.forceStage});

  /// Catalog / demo override. Live profile entry omits this.
  final ReelsMonetizationStage? forceStage;

  @override
  ConsumerState<ReelsMonetizationScreen> createState() =>
      _ReelsMonetizationScreenState();
}

class _ReelsMonetizationScreenState
    extends ConsumerState<ReelsMonetizationScreen> {
  ReelsMonetizationStage? _overrideStage;
  ReelMonetizationProfile? _opted;
  bool _optingIn = false;

  Future<void> _optIn() async {
    if (_optingIn) return;
    setState(() => _optingIn = true);
    try {
      final profile = await ref.read(reelRepositoryProvider).optIn();
      ref.invalidate(reelsMonetizationProvider);
      if (!mounted) return;
      setState(() {
        _opted = profile;
        _overrideStage = ReelsMonetizationStage.monetized;
      });
    } on Object catch (error) {
      if (mounted) context.showPelevoMessage(reelFailure(error).message);
    } finally {
      if (mounted) setState(() => _optingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reelsMonetizationProvider);
    return async.when(
      loading:
          () => PelevoPage(
            appBar: _monetizationAppBar(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) {
            final failure = reelFailure(error);
            final needsClaim =
                failure.code == 'CLAIM_REQUIRED' || failure.statusCode == 403;
            if (widget.forceStage != null) {
              return _stageView(
                widget.forceStage!,
                null,
              );
            }
            return PelevoPage(
              appBar: _monetizationAppBar(context),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(PelevoSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        needsClaim
                            ? 'A verified show claim is required.'
                            : failure.message,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed:
                            needsClaim
                                ? () => context.push('/screen/claim-podcast')
                                : () =>
                                    ref.invalidate(reelsMonetizationProvider),
                        child: Text(needsClaim ? 'Claim a podcast' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
      data: (profile) {
        final resolved = _opted ?? profile;
        final stage =
            _overrideStage ?? widget.forceStage ?? resolved.stage;
        return _stageView(stage, resolved);
      },
    );
  }

  Widget _stageView(
    ReelsMonetizationStage stage,
    ReelMonetizationProfile? profile,
  ) => switch (stage) {
    ReelsMonetizationStage.progressing => _ProgressingMonetizationView(
      profile: profile,
    ),
    ReelsMonetizationStage.eligible => _EligibleMonetizationView(
      profile: profile,
      optingIn: _optingIn,
      onOptIn: _optIn,
    ),
    ReelsMonetizationStage.monetized => _MonetizedDashboardView(
      profile: profile,
    ),
  };
}

PreferredSizeWidget _monetizationAppBar(BuildContext context) => AppBar(
  leading: IconButton(
    tooltip: 'Back',
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/screen/profile');
      }
    },
    icon: const Icon(Icons.arrow_back_rounded),
  ),
  title: const Text('Monetization'),
  actions: [
    IconButton(
      tooltip: 'About monetization',
      onPressed:
          () => showPelevoSheet<void>(
            context: context,
            builder:
                (context) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reels payouts vs Earn Wallet',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Earn Wallet: you request a payout after you hit the coin threshold.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Reels monetization: once active, payouts run from the creator program. Timing is shown when the server provides it.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ),
                ),
          ),
      icon: const Icon(Icons.info_outline_rounded),
    ),
  ],
);

class _ProgressingMonetizationView extends StatelessWidget {
  const _ProgressingMonetizationView({this.profile});

  final ReelMonetizationProfile? profile;

  @override
  Widget build(BuildContext context) {
    final followers = profile?.followers ?? 0;
    final views = profile?.qualifiedViews ?? 0;
    final minFollowers = profile?.minFollowers ?? 0;
    final minViews = profile?.minViews ?? 0;
    return PelevoPage(
      appBar: _monetizationAppBar(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monetize Your Reels',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Meet the creator requirements, opt in, and earn from your Pelevo Reels with automatic monthly payouts.',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _ClapperHero(size: 96),
                ],
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Text(
                'Eligibility Progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              _ProgressMetric(
                icon: Icons.person_add_alt_1_rounded,
                iconColor: PelevoColors.green,
                title: 'Followers',
                detail:
                    minFollowers == 0
                        ? 'Requirement is not available yet.'
                        : '$minFollowers required',
                progress: profile?.followersProgress ?? 0,
                barColor: PelevoColors.green,
                valueLabel: profile?.followersLabel ?? '$followers',
                complete: profile?.followersMet ?? false,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              _ProgressMetric(
                icon: Icons.visibility_outlined,
                iconColor: PelevoColors.purple,
                title: 'Reel Views',
                detail:
                    minViews == 0
                        ? 'Requirement is not available yet.'
                        : '$minViews required',
                progress: profile?.viewsProgress ?? 0,
                barColor: PelevoColors.purple,
                valueLabel: profile?.viewsLabel ?? '$views',
                complete: profile?.viewsMet ?? false,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              Container(
                padding: const EdgeInsets.all(PelevoSpacing.md),
                decoration: BoxDecoration(
                  color: context.pelevo.surface,
                  borderRadius: BorderRadius.circular(PelevoRadii.large),
                  border: Border.all(color: context.pelevo.border),
                ),
                child: Text(
                  minFollowers == 0 || minViews == 0
                      ? 'Eligibility thresholds are shown when the server provides them.'
                      : 'You need $minFollowers followers and $minViews reel views to be eligible for monetization.',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Text('Benefits', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: PelevoSpacing.sm),
              const _BenefitTile(
                icon: Icons.payments_outlined,
                color: PelevoColors.green,
                title: 'Earn Rewards',
                subtitle: 'Get paid for views, ads, and creator bonuses',
              ),
              const _BenefitTile(
                icon: Icons.trending_up_rounded,
                color: PelevoColors.purple,
                title: 'Grow Your Brand',
                subtitle: 'Unlock tools that help your reels reach more people',
              ),
              const _BenefitTile(
                icon: Icons.support_agent_rounded,
                color: PelevoColors.blue,
                title: 'Creator Support',
                subtitle: 'Priority help once your monetization is active',
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Text('How It Works', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: PelevoSpacing.sm),
              const _StepTile(step: 1, title: 'Meet the Requirements'),
              const _StepTile(step: 2, title: 'Opt In'),
              const _StepTile(step: 3, title: 'Create & Share'),
              const _StepTile(step: 4, title: 'Earn Automatically'),
              const SizedBox(height: PelevoSpacing.lg),
              Container(
                padding: const EdgeInsets.all(PelevoSpacing.md),
                decoration: BoxDecoration(
                  color: PelevoColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PelevoRadii.large),
                  border: Border.all(
                    color: PelevoColors.purple.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Unlike Earn Wallet, reels payouts are automatic once you are monetized. No manual withdrawal request.',
                  style: TextStyle(color: context.pelevo.textMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              PelevoButton(
                label: 'Almost eligible — keep growing',
                color: PelevoColors.purple,
                icon: Icons.lock_rounded,
                onPressed:
                    () => context.showPelevoMessage(
                      minFollowers == 0 || minViews == 0
                          ? 'Eligibility thresholds are not available yet.'
                          : 'Reach $minFollowers followers and $minViews reel views to unlock opt-in.',
                    ),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              TextButton(
                onPressed: () => context.push('/screen/reels'),
                child: const Text('Create more Reels'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EligibleMonetizationView extends StatelessWidget {
  const _EligibleMonetizationView({
    required this.onOptIn,
    required this.optingIn,
    this.profile,
  });

  final ReelMonetizationProfile? profile;
  final VoidCallback onOptIn;
  final bool optingIn;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: _monetizationAppBar(context),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "You're Eligible!",
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color: PelevoColors.green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: PelevoColors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You met the creator requirements. Opt in to start earning from your reels with automatic monthly payouts.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _ClapperHero(size: 72),
              ],
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: BoxDecoration(
                color: context.pelevo.surface,
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(
                  color: PelevoColors.green.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                children: [
                  _ProgressMetric(
                    icon: Icons.person_add_alt_1_rounded,
                    iconColor: PelevoColors.green,
                    title: 'Followers',
                    detail:
                        profile == null
                            ? 'Requirement is not available yet.'
                            : '${profile!.minFollowers} required',
                    progress: 1,
                    barColor: PelevoColors.green,
                    valueLabel: profile?.followersLabel ?? '',
                    complete: true,
                  ),
                  const SizedBox(height: PelevoSpacing.sm),
                  _ProgressMetric(
                    icon: Icons.visibility_outlined,
                    iconColor: PelevoColors.green,
                    title: 'Reel Views',
                    detail:
                        profile == null
                            ? 'Requirement is not available yet.'
                            : '${profile!.minViews} required',
                    progress: 1,
                    barColor: PelevoColors.green,
                    valueLabel: profile?.viewsLabel ?? '',
                    complete: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B21B6), Color(0xFF2E1065)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Monetizing Your Reels',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Opt in to the program. Payouts send automatically when the program pays out — no manual request.',
                              style: TextStyle(
                                color: context.pelevo.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: PelevoColors.purple),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PelevoSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: optingIn ? null : onOptIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PelevoColors.purple,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(optingIn ? 'Opting in…' : 'Opt In Now →'),
                    ),
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

class _MonetizedDashboardView extends StatelessWidget {
  const _MonetizedDashboardView({this.profile});

  final ReelMonetizationProfile? profile;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: _monetizationAppBar(context),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "You're Monetized!",
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color: PelevoColors.green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: PelevoColors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your reels are earning. Eligible balances pay out automatically each month.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    ],
                  ),
                ),
                const _ClapperHero(size: 72),
              ],
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: BoxDecoration(
                color: context.pelevo.surface,
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(color: context.pelevo.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monetization Status',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const _StatusPill(label: 'Active', green: true),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              () => context.showPelevoMessage(
                                'Payout schedule is not available yet.',
                              ),
                          style: FilledButton.styleFrom(
                            backgroundColor: PelevoColors.purple,
                          ),
                          child: const Text('View Payouts'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: PelevoColors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: PelevoColors.green),
                    ),
                    child: const Icon(
                      Icons.attach_money_rounded,
                      color: PelevoColors.green,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: BoxDecoration(
                color: context.pelevo.surface,
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(color: context.pelevo.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        'Performance Overview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.pelevo.surfaceHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.pelevo.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('This month', style: TextStyle(fontSize: 12)),
                            Icon(Icons.expand_more_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile == null ? '—' : '${profile!.qualifiedViews}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Qualified reel views',
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Earnings series is not available yet.',
                    style: TextStyle(color: PelevoColors.green),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          value:
                              profile == null
                                  ? '—'
                                  : '${profile!.qualifiedViews}',
                          label: 'Reel Views',
                        ),
                      ),
                      const Expanded(
                        child: _MiniStat(
                          value: '—',
                          label: 'Engagements',
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          value:
                              profile == null ? '—' : '${profile!.followers}',
                          label: 'Followers',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: BoxDecoration(
                color: context.pelevo.surface,
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(color: context.pelevo.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earnings Breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const _BreakdownRow(
                    label: 'Ad Revenue',
                    value: 'Not available',
                  ),
                  const _BreakdownRow(
                    label: 'Bonus & Incentives',
                    value: 'Not available',
                  ),
                  const _BreakdownRow(
                    label: 'Tips & Support',
                    value: 'Not available',
                  ),
                  Divider(color: context.pelevo.border),
                  const _BreakdownRow(
                    label: 'Total Earnings',
                    value: 'Not available',
                    emphasize: true,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        () => context.showPelevoMessage(
                          'Earnings history is not available yet.',
                        ),
                    child: const Text('View Earnings History →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'Monetization Tools',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            _ToolTile(
              icon: Icons.account_balance_rounded,
              title: 'Payout Information',
              subtitle: 'Payout destination is not available yet.',
              onTap:
                  () => context.showPelevoMessage(
                    'Reels payout destination is not available yet.',
                  ),
            ),
            _ToolTile(
              icon: Icons.receipt_long_outlined,
              title: 'Tax Information',
              subtitle: 'Manage tax forms for creator earnings',
              onTap:
                  () => context.push('/screen/creator-tax-information'),
            ),
            _ToolTile(
              icon: Icons.tune_rounded,
              title: 'Monetization Settings',
              subtitle: 'Notifications and creator preferences',
              onTap:
                  () => context.showPelevoMessage(
                    'Monetization settings are not available yet.',
                  ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            Text(
              'Helpful Resources',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            _ToolTile(
              icon: Icons.menu_book_outlined,
              title: 'How It Works',
              subtitle: 'Automatic reels payouts explained',
              onTap:
                  () => context.showPelevoMessage(
                    'Payout rules are shown when the server provides them.',
                  ),
            ),
            _ToolTile(
              icon: Icons.policy_outlined,
              title: 'Monetization Guidelines',
              subtitle: 'Creator policies and content rules',
              onTap: () => context.push('/screen/profile-help'),
            ),
            const SizedBox(height: PelevoSpacing.md),
            Container(
              padding: const EdgeInsets.all(PelevoSpacing.md),
              decoration: BoxDecoration(
                color: PelevoColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PelevoRadii.large),
                border: Border.all(
                  color: PelevoColors.green.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Reels payouts are automatic. Earn Wallet still requires you to request a withdrawal after reaching its coin threshold.',
                style: TextStyle(color: context.pelevo.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClapperHero extends StatelessWidget {
  const _ClapperHero({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: RadialGradient(
        colors: [
          PelevoColors.purple.withValues(alpha: 0.45),
          PelevoColors.purple.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.movie_filter_rounded,
          size: size * 0.55,
          color: PelevoColors.purple,
        ),
        Positioned(
          right: size * 0.12,
          bottom: size * 0.18,
          child: Icon(
            Icons.monetization_on_rounded,
            size: size * 0.22,
            color: PelevoColors.yellow,
          ),
        ),
      ],
    ),
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.progress,
    required this.barColor,
    required this.valueLabel,
    required this.complete,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final double progress;
  final Color barColor;
  final String valueLabel;
  final bool complete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: context.pelevo.surfaceHigh,
      borderRadius: BorderRadius.circular(PelevoRadii.large),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: iconColor.withValues(alpha: 0.18),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                valueLabel,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: complete ? PelevoColors.green : context.pelevo.text,
                ),
              ),
            ),
            if (complete) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                color: PelevoColors.green,
                size: 18,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: context.pelevo.border,
            color: barColor,
          ),
        ),
      ],
    ),
  );
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: context.pelevo.textMuted),
    ),
  );
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.title});

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: PelevoColors.purple.withValues(alpha: 0.2),
          child: Text(
            '$step',
            style: const TextStyle(
              color: PelevoColors.purple,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.green});

  final String label;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final color = green ? PelevoColors.green : PelevoColors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted, fontSize: 11),
      ),
    ],
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              color: emphasize ? PelevoColors.green : context.pelevo.text,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: emphasize ? PelevoColors.green : context.pelevo.text,
          ),
        ),
      ],
    ),
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
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
      backgroundColor: context.pelevo.surfaceHigh,
      child: Icon(icon, color: context.pelevo.textMuted, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
