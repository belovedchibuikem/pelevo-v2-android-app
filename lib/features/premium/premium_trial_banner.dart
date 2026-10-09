import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';

final premiumTrialCoordinatorProvider = Provider<PremiumTrialCoordinator>((
  ref,
) {
  return PremiumTrialCoordinator(
    store: PremiumTrialLocalStore(ref.watch(sharedPreferencesProvider)),
    remote: _PremiumTrialRepositoryRemote(ref.watch(premiumRepositoryProvider)),
  );
});

class _PremiumTrialRepositoryRemote implements PremiumTrialRemote {
  _PremiumTrialRepositoryRemote(this._repository);

  final PremiumRepository _repository;

  @override
  Future<PremiumTrialEvaluation> recordSession(String sessionId) =>
      _repository.recordTrialSession(sessionId);

  @override
  Future<void> markShown() => _repository.markTrialShown();

  @override
  Future<bool?> readPremiumActive() async {
    try {
      final account = await _repository.me(CancelToken());
      return account.entitlement?.active == true;
    } on Object {
      return null;
    }
  }
}

/// Top banner for the 3-month Plus trial. It never covers the screen with a
/// barrier, so playback and the rest of the UI stay usable.
class PremiumTrialBannerHost extends ConsumerStatefulWidget {
  const PremiumTrialBannerHost({required this.router, super.key});

  final GoRouter router;

  @override
  ConsumerState<PremiumTrialBannerHost> createState() =>
      _PremiumTrialBannerHostState();
}

class _PremiumTrialBannerHostState extends ConsumerState<PremiumTrialBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _presented = false;
  bool _closed = false;
  bool _checking = false;
  bool _deferred = false;
  String? _checkedUser;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: PelevoMotion.normal);
    widget.router.routerDelegate.addListener(_onRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRoute();
    });
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    _motion.dispose();
    super.dispose();
  }

  void _onRoute() {
    if (_deferred && !_presented && !_closed && _routeAllows()) {
      _deferred = false;
      unawaited(_reveal());
      return;
    }
    unawaited(_consider());
  }

  bool _routeAllows() {
    final path = widget.router.routeInformationProvider.value.uri.path;
    if (!path.startsWith('/screen/')) return false;
    final id = path.split('/').last;
    return id.isNotEmpty &&
        id != 'splash' &&
        !id.startsWith('onboarding-') &&
        !id.startsWith('auth-') &&
        !id.startsWith('premium-');
  }

  Future<void> _consider() async {
    if (_checking || _closed || _presented || _deferred) return;
    final session = ref.read(authSessionProvider);
    final userId = session.userId;
    if (!session.authenticated || userId == null || !_routeAllows()) return;
    if (_checkedUser == userId) return;
    _checking = true;
    try {
      final show = await ref
          .read(premiumTrialCoordinatorProvider)
          .shouldPresent(userId);
      if (!mounted || _closed) return;
      _checkedUser = userId;
      if (!show) return;
      if (!_routeAllows()) {
        _deferred = true;
        return;
      }
      await _reveal();
    } on Object {
      _checkedUser = userId;
    } finally {
      _checking = false;
    }
  }

  Future<void> _reveal() async {
    final userId = ref.read(authSessionProvider).userId;
    if (userId == null || _presented || _closed) return;
    setState(() => _presented = true);
    await _motion.forward(from: 0);
    try {
      await ref.read(premiumTrialCoordinatorProvider).markShown(userId);
    } on Object {
      // Local storage still records the impression inside the coordinator.
    }
  }

  Future<void> _close() async {
    if (!_presented) return;
    await _motion.reverse();
    if (!mounted) return;
    setState(() {
      _presented = false;
      _closed = true;
      _deferred = false;
    });
  }

  void _claim() {
    widget.router.go('/screen/premium-plans?offer=${PremiumTrialOffer.slug}');
    unawaited(_close());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      if (next.userId == previous?.userId) return;
      _checkedUser = null;
      _deferred = false;
      _closed = false;
      _presented = false;
      _motion.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRoute();
      });
    });
    return Align(
      alignment: Alignment.topCenter,
      child:
          _presented
              ? SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1.15),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _motion,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
                child: _TrialBanner(onClaim: _claim, onDismiss: _close),
              )
              : const SizedBox.shrink(),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.onClaim, required this.onDismiss});

  final VoidCallback onClaim;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      container: true,
      namesRoute: false,
      label: 'Premium trial offer',
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
        child: Material(
          color: const Color(0xFF241808),
          elevation: 8,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(PelevoRadii.large),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PelevoRadii.large),
              border: Border.all(
                color: PelevoColors.yellow.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: PelevoColors.yellow,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '3 months of Premium, free',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upgrade to Pelevo Plus. Listening keeps going.',
                          style: TextStyle(
                            color: PelevoColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onClaim,
                    style: FilledButton.styleFrom(
                      backgroundColor: PelevoColors.yellow,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Claim Offer'),
                  ),
                  Semantics(
                    button: true,
                    label: 'Dismiss',
                    child: InkWell(
                      onTap: onDismiss,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
