import 'package:flutter/material.dart';
import 'package:pelevo/features/authentication/social_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_link_text.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/device_sync/device_sync_expanded_screens.dart';
import 'package:pelevo/features/lock_screen/lock_screen_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_store.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';
import 'package:pelevo/features/premium/storefront_price.dart';
import 'package:pelevo/features/store/regional_prices.dart';
import 'package:pelevo/features/profile/legal_links.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/share_cards/share_card_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _PremiumView {
  home,
  plans,
  compare,
  account,
  payment,
  confirmed,
  features,
  subscription,
  changePlan,
  billing,
  restore,
  exclusive,
}

const _premiumInventory =
    <({String id, String title, String state, _PremiumView view})>[
      (
        id: 'premium-intro',
        title: 'Pelevo Plus',
        state: 'Premium overview',
        view: _PremiumView.home,
      ),
      (
        id: 'premium-plans',
        title: 'Choose Your Plan',
        state: 'Monthly or yearly',
        view: _PremiumView.plans,
      ),
      (
        id: 'premium-compare',
        title: 'Compare Plans',
        state: 'Free versus Plus',
        view: _PremiumView.compare,
      ),
      (
        id: 'premium-account',
        title: 'Create Account',
        state: 'Premium registration',
        view: _PremiumView.account,
      ),
      (
        id: 'premium-payment',
        title: 'Payment Method',
        state: 'Secure payment',
        view: _PremiumView.payment,
      ),
      (
        id: 'premium-confirmed',
        title: 'Confirm Subscription',
        state: 'Purchase successful',
        view: _PremiumView.confirmed,
      ),
      (
        id: 'premium-features',
        title: 'Premium Features',
        state: 'Unlocked benefits',
        view: _PremiumView.features,
      ),
      (
        id: 'premium-subscription',
        title: 'Manage Subscription',
        state: 'Active monthly plan',
        view: _PremiumView.subscription,
      ),
      (
        id: 'premium-change-plan',
        title: 'Change Plan',
        state: 'Upgrade or downgrade',
        view: _PremiumView.changePlan,
      ),
      (
        id: 'premium-billing',
        title: 'Billing History',
        state: 'Invoices and payments',
        view: _PremiumView.billing,
      ),
      (
        id: 'premium-restore',
        title: 'Restore Purchase',
        state: 'Recover subscription',
        view: _PremiumView.restore,
      ),
      (
        id: 'premium-exclusive',
        title: 'Exclusive Content',
        state: 'Plus-only listening',
        view: _PremiumView.exclusive,
      ),
    ];

final List<PelevoScreenSpec> _premiumScreens = List.unmodifiable(
  _premiumInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Pelevo Premium',
      title: item.title,
      state: item.state,
      builder: (_) => _PremiumScreen(view: item.view, title: item.title),
    ),
  ),
);

/// Complete supplied-board groups 12, 23, 24, and 40.
final List<PelevoScreenSpec> premiumSystemScreens = List.unmodifiable([
  ..._premiumScreens,
  ...shareCardScreens,
  ...lockScreenNotificationScreens,
  ...deviceSyncExpandedScreens,
]);

class _PremiumScreen extends ConsumerStatefulWidget {
  const _PremiumScreen({required this.view, required this.title});

  final _PremiumView view;
  final String title;

  @override
  ConsumerState<_PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<_PremiumScreen> {
  int _nav = 4;
  int _plan = 0;
  int _billingTab = 0;
  int _exclusiveTab = 0;
  bool _terms = true;
  bool _obscurePassword = true;
  bool _busy = false;
  bool _filledProfile = false;
  bool _trialOfferApplied = false;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool get _preview => ref.read(catalogPreviewProvider);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(premiumPlansProvider);
    ref.watch(premiumStoreCatalogProvider);
    ref.watch(premiumAccountProvider);
    ref.watch(premiumInvoicesProvider);
    ref.watch(premiumExclusiveProvider);
    ref.watch(profileProvider);
    return PelevoPage(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go(_backRoute),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(widget.title),
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: _nav,
        onDestinationSelected: (value) {
          setState(() => _nav = value);
          context.openPelevoTab(value);
        },
      ),
      child: switch (widget.view) {
        _PremiumView.home => _home(context),
        _PremiumView.plans => _plans(context),
        _PremiumView.compare => _compare(context),
        _PremiumView.account => _account(context),
        _PremiumView.payment => _paymentMethod(context),
        _PremiumView.confirmed => _confirmed(context),
        _PremiumView.features => _features(context),
        _PremiumView.subscription => _subscription(context),
        _PremiumView.changePlan => _changePlan(context),
        _PremiumView.billing => _billing(context),
        _PremiumView.restore => _restore(context),
        _PremiumView.exclusive => _exclusive(context),
      },
    );
  }

  String get _backRoute => switch (widget.view) {
    _PremiumView.home => '/screen/home-feed',
    _PremiumView.plans || _PremiumView.restore => '/screen/premium-intro',
    _PremiumView.compare => '/screen/premium-plans',
    _PremiumView.account => '/screen/premium-compare',
    _PremiumView.payment => '/screen/premium-account',
    _PremiumView.confirmed => '/screen/premium-payment',
    _PremiumView.features ||
    _PremiumView.subscription => '/screen/premium-intro',
    _PremiumView.changePlan ||
    _PremiumView.billing => '/screen/premium-subscription',
    _PremiumView.exclusive => '/screen/premium-features',
  };

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PremiumStoreException catch (error) {
      if (!context.mounted) return;
      context.showPelevoMessage(error.message);
    } catch (error) {
      if (!context.mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<PremiumPlan> get _plansList =>
      ref.watch(premiumPlansProvider).asData?.value ?? const [];

  String _localizedPlanPrice(PremiumPlan? plan) =>
      plan == null
          ? subscriptionPriceLine(null)
          : PremiumStore.instance.priceLabel(plan);

  StorefrontPrice? _quote(PremiumPlan? plan) =>
      plan == null ? null : PremiumStore.instance.quoteForPlan(plan);

  String _planBadge(PremiumPlan plan) {
    if (_isRenewalPaywall) return '';
    return storefrontPromoBadge(_quote(plan));
  }

  Future<void> _purchasePlus(PremiumPlan? plan) async {
    if (_preview) {
      context.go('/screen/premium-confirmed');
      return;
    }
    if (!ref.read(authSessionProvider).authenticated) {
      context.push('/screen/auth-sign-in');
      return;
    }
    if (plan == null) {
      context.showPelevoMessage('Select a Pelevo Plus plan first.');
      return;
    }
    ref.read(selectedPremiumPlanIdProvider.notifier).select(plan.id);
    setState(() => _busy = true);
    try {
      final purchase = await PremiumStore.instance.buy(
        plan,
        accountId: ref.read(authSessionProvider).userId,
      );
      try {
        await ref
            .read(premiumRepositoryProvider)
            .confirmStorePurchase(
              store: PremiumStore.instance.storeProvider,
              receipt: purchase.reference,
              planId: plan.id,
            );
      } on Object {
        if (!mounted) return;
        context.showPelevoMessage(
          'Purchase received. Pelevo Plus will unlock as soon as the store receipt is confirmed.',
        );
      }
      ref.invalidate(premiumAccountProvider);
      ref.invalidate(premiumInvoicesProvider);
      // Force a fresh entitlement so ads / upgrade cards dismiss immediately.
      try {
        await ref.read(premiumAccountProvider.future);
      } on Object {
        // Confirmation screen still explains pending receipt unlock.
      }
      if (!mounted) return;
      context.go('/screen/premium-confirmed');
    } on PremiumStoreException catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _trialOfferRequested {
    final offer = GoRouterState.of(context).uri.queryParameters['offer'];
    return PremiumTrialOffer.matchesSlug(offer);
  }

  bool get _isRenewalPaywall {
    final account = ref.watch(premiumAccountProvider).asData?.value;
    final entitlement = account?.entitlement;
    if (entitlement == null) return false;
    return !entitlement.grantsPlus;
  }

  void _selectTrialOffer(List<PremiumPlan> plans) {
    if (!_trialOfferRequested || _trialOfferApplied) return;
    var index = plans.indexWhere(
      (plan) => plan.isIntroTrial && plusIntervalIsYearly(plan.interval),
    );
    if (index < 0) {
      index = plans.indexWhere((plan) => plan.isIntroTrial);
    }
    if (index < 0) return;
    _trialOfferApplied = true;
    if (_plan == index &&
        ref.read(selectedPremiumPlanIdProvider) == plans[index].id) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _plan = index);
      ref.read(selectedPremiumPlanIdProvider.notifier).select(plans[index].id);
    });
  }

  PremiumPlan? get _selectedPlan {
    final selectedId = ref.watch(selectedPremiumPlanIdProvider);
    final plans = _plansList;
    for (final plan in plans) {
      if (plan.id == selectedId) return plan;
    }
    if (_plan >= 0 && _plan < plans.length) return plans[_plan];
    return plans.isEmpty ? null : plans.first;
  }

  Widget _home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _crownHero(context, 'Pelevo Plus', 'More Power. More Content. More You.'),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        'Take your listening to the next level with exclusive content and premium features.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (final item in const [
        (Icons.block_rounded, 'Ad-free listening'),
        (Icons.download_for_offline_rounded, 'Unlimited downloads'),
        (Icons.offline_bolt_rounded, 'Offline mode'),
        (Icons.workspace_premium_rounded, 'Exclusive & Originals'),
        (Icons.auto_awesome_rounded, 'Pelevo AI Hub'),
        (Icons.support_agent_rounded, 'Priority support'),
      ])
        _benefit(item.$1, item.$2),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Explore Plans',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed: () => context.go('/screen/premium-plans'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      PelevoButton(
        label: 'Restore Purchase',
        outlined: true,
        color: PelevoColors.yellow,
        foregroundColor: PelevoColors.yellow,
        onPressed: () => context.go('/screen/premium-restore'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      TextButton(
        onPressed: () => context.go('/screen/premium-subscription'),
        child: const Text('Manage Existing Subscription'),
      ),
    ],
  );

  Widget _plans(BuildContext context) {
    final async = ref.watch(premiumPlansProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(premiumPlansProvider),
      );
    }
    final plans = async.requireValue;
    _selectTrialOffer(plans);
    final claimingTrial =
        _selectedPlan?.isIntroTrial == true && !_isRenewalPaywall;
    final renewing = _isRenewalPaywall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (renewing) ...[
          const Text(
            PremiumTrialOffer.renewHeadline,
            style: TextStyle(
              color: PelevoColors.yellow,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PelevoSpacing.xs),
          Text(
            'Your previous Pelevo Plus period ended. Pick a plan to resubscribe at the standard store price.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
        ] else if (_trialOfferRequested && claimingTrial) ...[
          const Text(
            'Your 1-month free trial is selected.',
            style: TextStyle(
              color: PelevoColors.yellow,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PelevoSpacing.xs),
          Text(
            'Choose Monthly or Annual. Billing starts automatically when the 30 days end.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.md),
        ] else
          _introCallout(_selectedPlan),
        if (PremiumStore.instance.catalogQueried &&
            !PremiumStore.instance.hasStorePrices) ...[
          Text(
            PremiumStore.instance.catalogError ??
                'Google Play has not returned Plus prices yet. Confirm pelevo_plus_individual is Active, install from Play, and use a license-tester account.',
            style: TextStyle(color: PelevoColors.red, fontSize: 12),
          ),
          const SizedBox(height: PelevoSpacing.md),
        ],
        if (plans.isEmpty)
          Text(
            'No active Premium plans.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (var i = 0; i < plans.length; i++) ...[
            Text(
              plans[i].interval,
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            _planCard(
              context,
              i,
              plans[i].name,
              _localizedPlanPrice(plans[i]),
              _planBadge(plans[i]),
            ),
            const SizedBox(height: PelevoSpacing.md),
          ],
        TextButton(
          onPressed: () => context.go('/screen/premium-compare'),
          child: const Text('Compare all plan features'),
        ),
        PelevoButton(
          label: plansSubscribeLabel(
            claimingTrial: claimingTrial,
            preview: _preview,
            quote: _quote(_selectedPlan),
            renewing: renewing,
          ),
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed: () {
            if (_preview) {
              final plan = _selectedPlan;
              if (plan != null) {
                ref
                    .read(selectedPremiumPlanIdProvider.notifier)
                    .select(plan.id);
              }
              context.go('/screen/premium-compare');
              return;
            }
            _purchasePlus(_selectedPlan);
          },
        ),
        const SizedBox(height: PelevoSpacing.sm),
        if (!ref.watch(authSessionProvider).authenticated)
          TextButton(
            onPressed: () => context.push('/screen/auth-sign-in'),
            child: const Text('Already a member? Sign in'),
          ),
      ],
    );
  }

  Widget _compare(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'Features',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text('Free', textAlign: TextAlign.center)),
          Expanded(child: Text('Plus', textAlign: TextAlign.center)),
        ],
      ),
      const Divider(),
      for (final feature in const [
        ('Ad-free listening', 'No', 'Yes'),
        ('Downloads', '10 episodes', 'Unlimited'),
        ('Offline mode', 'No', 'Yes'),
        ('Exclusive & Originals', 'No', 'Yes'),
        ('Pelevo AI Hub', 'No', 'Yes'),
        ('Priority support', 'No', 'Yes'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PelevoSpacing.sm),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(feature.$1)),
              Expanded(
                child: Text(
                  feature.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  feature.$3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PelevoColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Choose Your Plan',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed: () {
          if (_preview) {
            context.go('/screen/premium-account');
            return;
          }
          _purchasePlus(_selectedPlan);
        },
      ),
    ],
  );

  Widget _account(BuildContext context) {
    final signedIn = ref.watch(authSessionProvider).authenticated;
    if (signedIn && !_preview) {
      final plan = _selectedPlan;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plan == null
                ? 'Subscribe to Pelevo Plus with your store account.'
                : plan.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PelevoSpacing.sm),
          Text(
            _localizedPlanPrice(plan),
            style: const TextStyle(
              color: PelevoColors.yellow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          _introCallout(plan),
          const SizedBox(height: PelevoSpacing.md),
          Text(
            'Payment is completed by Google Play or the App Store. Your Pelevo account stays signed in.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: PelevoSpacing.xl),
          PelevoButton(
            label: _busy ? 'Contacting the store…' : 'Subscribe',
            color: PelevoColors.yellow,
            foregroundColor: Colors.black,
            onPressed: _busy ? null : () => _purchasePlus(plan),
          ),
        ],
      );
    }
    final profile = ref.watch(profileProvider).asData?.value;
    if (profile != null && !_filledProfile) {
      _filledProfile = true;
      _name.text = profile.name;
      _email.text = profile.email;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create or sign in to start your Pelevo Plus membership.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (showsGoogleSignIn) ...[
          OutlinedButton.icon(
            onPressed: () {
              if (_preview) {
                context.go('/screen/premium-payment');
                return;
              }
              context.showPelevoMessage(
                'Google Sign-In is not available until a provider token can be posted.',
              );
            },
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: PelevoSpacing.sm),
        ],
        if (showsAppleSignIn) ...[
          OutlinedButton.icon(
            onPressed: () {
              if (_preview) {
                context.go('/screen/premium-payment');
                return;
              }
              context.showPelevoMessage(
                'Apple Sign-In is not available until a provider token can be posted.',
              );
            },
            icon: const Icon(Icons.apple_rounded),
            label: const Text('Continue with Apple'),
          ),
          const SizedBox(height: PelevoSpacing.sm),
        ],
        const SizedBox(height: PelevoSpacing.lg),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _terms,
          activeColor: PelevoColors.yellow,
          title: const PelevoPublicLegalNotice(
            lead: 'I agree to the',
            linkColor: PelevoColors.yellow,
          ),
          onChanged: (value) => setState(() => _terms = value ?? false),
        ),
        PelevoButton(
          label: 'Continue',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed:
              _terms
                  ? () {
                    if (_preview ||
                        !ref.read(authSessionProvider).authenticated) {
                      context.go('/screen/premium-payment');
                      return;
                    }
                    _purchasePlus(_selectedPlan);
                  }
                  : null,
        ),
      ],
    );
  }

  Widget _paymentMethod(BuildContext context) {
    final plan = _selectedPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_rounded, color: PelevoColors.green, size: 18),
            SizedBox(width: PelevoSpacing.xs),
            Text('Secure payment', style: TextStyle(color: PelevoColors.green)),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          'Pelevo Plus is purchased through $_storeBillingName. Payment stays with that store account.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const Divider(),
        _introCallout(plan),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: PelevoSpacing.md),
            Expanded(
              child: Text(
                plan == null ? 'Select a plan' : _localizedPlanPrice(plan),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Pay Securely',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed: _busy ? null : () => _pay(plan),
        ),
      ],
    );
  }

  Future<void> _pay(PremiumPlan? plan) async {
    await _purchasePlus(plan);
  }

  Widget _confirmed(BuildContext context) {
    final account = ref.watch(premiumAccountProvider).asData?.value;
    final invoices =
        ref.watch(premiumInvoicesProvider).asData?.value ?? const [];
    final active = _preview || pelevoPlusRemovesAds(account);
    final plan = _selectedPlan;
    String? receiptUrl;
    for (final item in invoices) {
      if (item.receiptUrl != null && item.receiptUrl!.isNotEmpty) {
        receiptUrl = item.receiptUrl;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PelevoSpacing.lg),
        _successIcon(Icons.check_rounded),
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          active ? 'You’re All Set!' : 'Checkout pending',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: PelevoSpacing.xs),
        Text(
          active
              ? 'Welcome to Pelevo Plus'
              : 'Payment has not granted entitlement yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.yellow),
        ),
        const SizedBox(height: PelevoSpacing.md),
        Text(
          active
              ? 'Your subscription is active and you now have access to all premium features.'
              : 'The $_storeName purchase is saved. Pelevo Plus unlocks when that receipt is confirmed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Card(
          color: context.pelevo.surface,
          child: Padding(
            padding: const EdgeInsets.all(PelevoSpacing.md),
            child: Column(
              children: [
                _SummaryRow('Plan', plan?.name ?? 'Not selected'),
                _SummaryRow(
                  'Amount',
                  plan == null ? '—' : _localizedPlanPrice(plan),
                ),
                _SummaryRow(
                  'Next Billing Date',
                  account?.subscription?.currentPeriodEnd ?? 'Not reported',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Start Exploring',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed: () => context.go('/screen/premium-features'),
        ),
        TextButton(
          onPressed: () {
            final url = receiptUrl;
            context.showPelevoMessage(
              url == null || url.isEmpty ? 'No receipt URL is available.' : url,
            );
          },
          child: const Text('View Receipt'),
        ),
      ],
    );
  }

  Widget _features(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'You have unlocked all premium features.',
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (final item in const [
        (
          Icons.block_rounded,
          PelevoColors.green,
          'Ad-free listening',
          'Play without ads.',
        ),
        (
          Icons.download_for_offline_rounded,
          PelevoColors.green,
          'Unlimited downloads',
          'Free accounts can save 10 episodes.',
        ),
        (
          Icons.offline_bolt_rounded,
          PelevoColors.blue,
          'Offline mode',
          'Listen to saved episodes without a connection.',
        ),
        (
          Icons.workspace_premium_rounded,
          PelevoColors.red,
          'Exclusive & Originals',
          'Shows and episodes that stay on Pro.',
        ),
        (
          Icons.auto_awesome_rounded,
          Color(0xFF9C27B0),
          'Pelevo AI Hub',
          'AI tools included with Pro.',
        ),
        (
          Icons.support_agent_rounded,
          PelevoColors.yellow,
          'Priority support',
          'Your requests are handled first.',
        ),
      ])
        _featureTile(item.$1, item.$2, item.$3, item.$4),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Explore Now',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed: () => context.go('/screen/premium-exclusive'),
      ),
    ],
  );

  Widget _subscription(BuildContext context) {
    final account = ref.watch(premiumAccountProvider);
    final plans = ref.watch(premiumPlansProvider);
    if (account.isLoading || plans.isLoading) return const CatalogStatusBody();
    if (account.hasError) {
      return CatalogStatusBody(
        error: account.error,
        retry: () => ref.invalidate(premiumAccountProvider),
      );
    }
    final me = account.requireValue;
    String? planName;
    for (final plan in plans.asData?.value ?? const <PremiumPlan>[]) {
      if (plan.id == (me.subscription?.planId ?? me.entitlement?.planId)) {
        planName = plan.name;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: context.pelevo.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: PelevoColors.yellow),
            borderRadius: PelevoRadii.card,
          ),
          child: ListTile(
            leading: const Icon(
              Icons.workspace_premium_rounded,
              color: PelevoColors.yellow,
              size: 34,
            ),
            title: Text(planName ?? 'Pelevo Plus'),
            subtitle: Text(
              [
                if (me.subscription != null)
                  _subscriptionProviderLabel(me.subscription!.provider),
                if (me.subscription != null &&
                    me.subscription!.billingLabel.isNotEmpty)
                  me.subscription!.billingLabel,
                if (me.subscription?.isInIntroOffer == true)
                  'Introductory offer',
                if (me.subscription?.currentPeriodEnd != null)
                  me.subscription!.currentPeriodEnd,
              ].join('\n'),
            ),
            trailing: Chip(label: Text(_membershipLabel(me.entitlement))),
          ),
        ),
        if (me.entitlement?.state == 'in_grace_period') ...[
          const SizedBox(height: PelevoSpacing.sm),
          Text(
            'A renewal payment is still retrying. Pelevo Plus stays available during this grace period.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ],
        if (me.subscription?.cancelAt != null &&
            me.entitlement?.grantsPlus == true) ...[
          const SizedBox(height: PelevoSpacing.sm),
          Text(
            'Auto-renew is off. Pelevo Plus stays available until the period you already paid for ends.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ],
        const UtilitySectionLabel('Manage'),
        _menuRow(
          Icons.receipt_long_outlined,
          'Subscription Details',
          () => context.showPelevoMessage(
            me.subscription?.state ?? 'No subscription is on file.',
          ),
        ),
        _menuRow(
          Icons.swap_horiz_rounded,
          'Change Plan',
          () => context.go('/screen/premium-change-plan'),
        ),
        _menuRow(
          Icons.credit_card_rounded,
          'Payment Method',
          () => context.go('/screen/premium-payment'),
        ),
        _menuRow(
          Icons.history_rounded,
          'Billing History',
          () => context.go('/screen/premium-billing'),
        ),
        _menuRow(
          Icons.cancel_outlined,
          'Cancel Subscription',
          () => _cancelInStore(me),
          color: PelevoColors.red,
        ),
        const SizedBox(height: PelevoSpacing.lg),
        OutlinedButton(
          onPressed: () => context.go('/screen/premium-features'),
          child: const Text('View Premium Features'),
        ),
      ],
    );
  }

  Widget _changePlan(BuildContext context) {
    final async = ref.watch(premiumPlansProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(premiumPlansProvider),
      );
    }
    final plans = async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose New Plan',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        for (var i = 0; i < plans.length; i++) ...[
          const SizedBox(height: PelevoSpacing.sm),
          _planCard(
            context,
            i,
            plans[i].name,
            _localizedPlanPrice(plans[i]),
            '',
          ),
        ],
        const SizedBox(height: PelevoSpacing.lg),
        Text(
          'Plan changes are completed in $_storeBillingName. Pelevo Plus updates after the store confirms the new plan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Continue',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed:
              _busy
                  ? null
                  : () {
                    if (_preview) {
                      context.go('/screen/premium-subscription');
                      return;
                    }
                    final plan = _selectedPlan;
                    if (plan == null) {
                      context.showPelevoMessage('Select a Premium plan first.');
                      return;
                    }
                    _purchasePlus(plan);
                  },
        ),
      ],
    );
  }

  Widget _billing(BuildContext context) {
    final async = ref.watch(premiumInvoicesProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(premiumInvoicesProvider),
      );
    }
    final invoices = async.requireValue;
    final visible = invoices
        .where((item) {
          if (_billingTab == 2) return item.state == 'refunded';
          if (_billingTab == 1) return item.state == 'paid';
          return true;
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(
          const ['All', 'Payments', 'Refunds'],
          _billingTab,
          (value) => setState(() => _billingTab = value),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (visible.isEmpty)
          Text(
            'No invoices yet.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.createdAt ?? item.id),
              subtitle: Text(item.state),
              trailing: Text(
                formatPremiumAmount(item.totalMinor, item.currency),
              ),
              onTap:
                  () => context.showPelevoMessage(
                    item.receiptUrl ?? 'No receipt URL is available.',
                  ),
            ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Download Invoice',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed: () {
            final url =
                invoices
                    .map((item) => item.receiptUrl)
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .firstOrNull;
            context.showPelevoMessage(url ?? 'No receipt URL is available.');
          },
        ),
      ],
    );
  }

  String? _storeProductId(PremiumAccount me) {
    final planId = me.subscription?.planId ?? me.entitlement?.planId;
    for (final plan in _plansList) {
      if (plan.id != planId) continue;
      return PremiumStore.instance.productIdFor(plan);
    }
    return null;
  }

  Future<void> _cancelInStore(PremiumAccount me) async {
    final provider =
        me.subscription?.provider ?? PremiumStore.instance.storeProvider;
    final uri = plusStoreSubscriptionUri(
      provider: provider,
      productId: _storeProductId(me),
    );
    var opened = false;
    if (uri != null) {
      try {
        opened = await openPelevoExternalLink(uri);
      } on Object {
        opened = false;
      }
    }
    if (!mounted || opened) return;
    final store = switch (provider) {
      'apple' => 'the App Store',
      'google' => 'Google Play',
      _ => 'the store that billed this membership',
    };
    context.showPelevoMessage(
      'Open $store to turn off auto-renew. Pelevo Plus stays available until the period you already paid for ends.',
    );
  }

  String _membershipLabel(PremiumEntitlement? entitlement) {
    final state = entitlement?.state;
    if (state == null || state.isEmpty) return 'Inactive';
    return switch (state) {
      'active' => 'Active',
      'in_grace_period' => 'Grace period',
      'expired' => 'Expired',
      'canceled' || 'cancelled' => 'Canceled',
      _ => state,
    };
  }

  String get _storeName =>
      PremiumStore.instance.storeProvider == 'apple'
          ? 'App Store'
          : 'Google Play';

  String get _storeBillingName =>
      PremiumStore.instance.storeProvider == 'apple'
          ? 'the App Store'
          : 'Google Play';

  String _subscriptionProviderLabel(String provider) => switch (provider) {
    'google' => 'Google Play',
    'apple' => 'App Store',
    _ => provider,
  };

  Widget _restore(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PelevoSpacing.xxl),
      _successIcon(Icons.restore_rounded, color: const Color(0xFF9C27B0)),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Restore Your Purchase',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        'Pelevo Plus is billed through $_storeBillingName. Restore looks up that subscription on this device and applies it to your Pelevo account.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: _busy ? 'Checking the store…' : 'Restore Purchase',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed:
            _busy
                ? null
                : () {
                  if (_preview) {
                    context.go('/screen/premium-subscription');
                    return;
                  }
                  _run(_restoreFromStore);
                },
      ),
    ],
  );

  Future<void> _restoreFromStore() async {
    final purchases = await PremiumStore.instance.restore(
      accountId: ref.read(authSessionProvider).userId,
    );
    if (!mounted) return;
    if (purchases.isEmpty) {
      context.showPelevoMessage(
        'No Pelevo Plus subscription was found for this $_storeName account.',
      );
      return;
    }
    final plans = await ref.read(premiumPlansProvider.future);
    var confirmed = 0;
    for (final purchase in purchases) {
      final plan = planForPlusProduct(plans, purchase.productId);
      if (plan == null) continue;
      await ref
          .read(premiumRepositoryProvider)
          .confirmStorePurchase(
            store: PremiumStore.instance.storeProvider,
            receipt: purchase.reference,
            planId: plan.id,
          );
      confirmed++;
    }
    ref.invalidate(premiumAccountProvider);
    ref.invalidate(premiumInvoicesProvider);
    if (!mounted) return;
    if (confirmed == 0) {
      context.showPelevoMessage(
        'The store purchase could not be matched to a Pelevo Plus plan.',
      );
      return;
    }
    context.go('/screen/premium-subscription');
  }

  Widget _exclusive(BuildContext context) {
    final async = ref.watch(premiumExclusiveProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Handpicked premium content just for you.',
          style: TextStyle(color: context.pelevo.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.md),
        _tabs(
          const ['Exclusives', 'Originals', 'Bonus'],
          _exclusiveTab,
          (value) => setState(() => _exclusiveTab = value),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (async.isLoading)
          const CatalogStatusBody()
        else if (async.hasError)
          CatalogStatusBody(
            error: async.error,
            retry: () => ref.invalidate(premiumExclusiveProvider),
          )
        else if (async.requireValue.isEmpty)
          Text(
            'No exclusive episodes are available.',
            style: TextStyle(color: context.pelevo.textMuted),
          )
        else
          for (final item in async.requireValue)
            Card(
              color: context.pelevo.surface,
              margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: ListTile(
                contentPadding: const EdgeInsets.all(PelevoSpacing.xs),
                leading: CatalogArtwork(
                  url: item.artworkUrl,
                  width: 58,
                  height: 58,
                  assetPath: 'assets/home/honest_bunch.png',
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(item.showTitle ?? ''),
                trailing: const Icon(Icons.play_circle_fill_rounded),
                onTap: () {
                  openCatalogEpisode(
                    context,
                    episodeId: item.id,
                    showId: item.showId,
                  );
                  context.go('/screen/player-now-playing');
                },
              ),
            ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Explore Exclusives',
          color: PelevoColors.yellow,
          foregroundColor: Colors.black,
          onPressed: () => context.go('/screen/browse'),
        ),
      ],
    );
  }

  Widget _crownHero(BuildContext context, String title, String subtitle) =>
      Container(
        padding: const EdgeInsets.all(PelevoSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: PelevoRadii.card,
          gradient: RadialGradient(
            colors: [Color(0xFF5A3D00), context.pelevo.background],
          ),
          border: Border.all(color: PelevoColors.yellow.withValues(alpha: .45)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 72,
              color: PelevoColors.yellow,
            ),
            const SizedBox(height: PelevoSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted),
            ),
          ],
        ),
      );

  Widget _introCallout(PremiumPlan? plan) {
    final notice = storefrontIntroNotice(_quote(plan));
    if (notice == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PelevoColors.yellow.withValues(alpha: 0.12),
          borderRadius: PelevoRadii.card,
          border: Border.all(color: PelevoColors.yellow),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PelevoSpacing.md),
          child: Text(
            notice,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PelevoColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    int value,
    String title,
    String price,
    String badge,
  ) => InkWell(
    borderRadius: BorderRadius.circular(PelevoRadii.medium),
    onTap: () {
      setState(() => _plan = value);
      final plans = _plansList;
      if (value >= 0 && value < plans.length) {
        ref
            .read(selectedPremiumPlanIdProvider.notifier)
            .select(plans[value].id);
      }
    },
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        color: context.pelevo.surface,
        border: Border.all(
          color: _plan == value ? PelevoColors.yellow : context.pelevo.border,
        ),
        borderRadius: PelevoRadii.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: PelevoColors.yellow,
            size: 34,
          ),
          const SizedBox(width: PelevoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(price, style: const TextStyle(color: PelevoColors.yellow)),
              ],
            ),
          ),
          Column(
            children: [
              Radio<int>(
                value: value,
                groupValue: _plan,
                activeColor: PelevoColors.yellow,
                onChanged: (next) {
                  if (next == null) return;
                  setState(() => _plan = next);
                  final plans = _plansList;
                  if (next >= 0 && next < plans.length) {
                    ref
                        .read(selectedPremiumPlanIdProvider.notifier)
                        .select(plans[next].id);
                  }
                },
              ),
              if (badge.isNotEmpty)
                Text(
                  badge,
                  style: const TextStyle(
                    color: PelevoColors.green,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PelevoSpacing.xs),
    child: Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: PelevoColors.green, size: 20),
        ),
        const SizedBox(width: PelevoSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _featureTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    onTap:
        title == 'Exclusive Content'
            ? () => context.go('/screen/premium-exclusive')
            : () => context.showPelevoMessage(title),
  );

  Widget _menuRow(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final ink = color ?? context.pelevo.text;
    return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: ink, size: 22),
    ),
    title: Text(title, style: TextStyle(color: ink)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
    );
  }

  Widget _tabs(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: PelevoSpacing.xs),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              selectedColor: PelevoColors.yellow,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );

  Widget _successIcon(IconData icon, {Color color = PelevoColors.green}) =>
      Center(
        child: Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .14),
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 58, color: color),
        ),
      );
}

class UtilitySectionLabel extends StatelessWidget {
  const UtilitySectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.xl,
      bottom: PelevoSpacing.xs,
    ),
    child: Text(
      label,
      style: TextStyle(
        color: context.pelevo.textMuted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PelevoSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.pelevo.textMuted)),
        const SizedBox(width: PelevoSpacing.md),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
