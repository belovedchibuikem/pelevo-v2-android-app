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
      return account.entitlement?.grantsPlus == true;
    } on Object {
      return null;
    }
  }
}

/// Top banner for the 1-month Plus trial. It never covers the screen with a
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
    if (_hasActivePlus) {
      unawaited(_suppressForSubscriber());
      return;
    }
    if (_deferred && !_presented && !_closed && _routeAllows()) {
      _deferred = false;
      unawaited(_reveal());
      return;
    }
    unawaited(_consider());
  }

  bool get _hasActivePlus => pelevoPlusIsActive(
    account: ref.read(premiumAccountProvider).asData?.value,
    confirmedPurchase: ref.read(premiumAccountSeedProvider),
  );

  Future<void> _suppressForSubscriber() async {
    if (!_presented && !_deferred) {
      _closed = true;
      return;
    }
    if (_presented) {
      await _motion.reverse();
    }
    if (!mounted) return;
    setState(() {
      _presented = false;
      _closed = true;
      _deferred = false;
    });
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
    if (_hasActivePlus) {
      _closed = true;
      return;
    }
    final session = ref.read(authSessionProvider);
    final userId = session.userId;
    if (!session.authenticated || userId == null || !_routeAllows()) return;
    if (_checkedUser == userId) return;
    _checking = true;
    try {
      final show = await ref
          .read(premiumTrialCoordinatorProvider)
          .shouldPresent(userId);
      if (!mounted || _closed || _hasActivePlus) return;
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
    if (userId == null || _presented || _closed || _hasActivePlus) return;
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
    ref.listen(premiumAccountSeedProvider, (previous, next) {
      if (!pelevoPlusRemovesAds(next)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_suppressForSubscriber());
      });
    });
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
    ref.listen(premiumAccountProvider, (previous, next) {
      final active = pelevoPlusIsActive(
        account: next.asData?.value,
        confirmedPurchase: ref.read(premiumAccountSeedProvider),
      );
      if (!active) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_suppressForSubscriber());
      });
    });
    return Align(
      alignment: Alignment.topCenter,
      child: _presented
          ? SlideTransition(
              position:
                  Tween<Offset>(
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
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: const Color(0xFFF4E3D3),
          elevation: 6,
          shadowColor: Colors.black54,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(36, top + 12, 36, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      PremiumTrialOffer.promoHeadline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PelevoColors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      PremiumTrialOffer.promoSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onClaim,
                      style: FilledButton.styleFrom(
                        backgroundColor: PelevoColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: const Text(PremiumTrialOffer.claimCta),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: top,
                right: 2,
                child: Semantics(
                  button: true,
                  label: 'Dismiss',
                  child: InkWell(
                    onTap: onDismiss,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        color: Color(0xFF1A1A1A),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
