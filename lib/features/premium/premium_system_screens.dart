import 'package:flutter/material.dart';
import 'package:pelevo/features/authentication/social_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/device_sync/device_sync_expanded_screens.dart';
import 'package:pelevo/features/lock_screen/lock_screen_screens.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_store.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';
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
  int _payment = 1;
  int _billingTab = 0;
  int _exclusiveTab = 0;
  int _restoreProvider = 0;
  bool _terms = true;
  bool _obscurePassword = true;
  bool _busy = false;
  bool _filledProfile = false;
  bool _trialOfferApplied = false;
  PremiumCheckout? _checkout;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _restoreReference = TextEditingController();

  bool get _preview => ref.read(catalogPreviewProvider);

  static const _providers = ['paystack', 'flutterwave'];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _restoreReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(premiumPlansProvider);
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
    } catch (error) {
      if (!context.mounted) return;
      context.showPelevoMessage(catalogFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<PremiumPlan> get _plansList =>
      ref.watch(premiumPlansProvider).asData?.value ?? const [];

  String get _countryCode => listenerCountryCode(
    profileCountry: ref.watch(profileProvider).asData?.value.countryCode,
    deviceCountry: View.of(context).platformDispatcher.locale.countryCode,
  );

  String _localizedPlanPrice(PremiumPlan plan) =>
      PremiumStore.instance.priceLabel(plan, _countryCode);

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
      final purchase = await PremiumStore.instance.buy(plan);
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
    return offer == PremiumTrialOffer.slug;
  }

  void _selectTrialOffer(List<PremiumPlan> plans) {
    if (!_trialOfferRequested || _trialOfferApplied) return;
    final index = plans.indexWhere((plan) => plan.isThreeMonthTrial);
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
      const Text(
        'Take your listening to the next level with exclusive content and premium features.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
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
    final claimingTrial = _selectedPlan?.isThreeMonthTrial == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_trialOfferRequested && claimingTrial) ...[
          const Text(
            'Your 3-month free trial is selected.',
            style: TextStyle(
              color: PelevoColors.yellow,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PelevoSpacing.md),
        ],
        if (plans.isEmpty)
          const Text(
            'No active Premium plans.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (var i = 0; i < plans.length; i++) ...[
            Text(
              plans[i].interval,
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            _planCard(
              context,
              i,
              plans[i].name,
              plans[i].isThreeMonthTrial
                  ? 'Free for 3 months, then ${_localizedPlanPrice(plans[i])}'
                  : _localizedPlanPrice(plans[i]),
              plans[i].isThreeMonthTrial ? '3 months free' : '',
            ),
            const SizedBox(height: PelevoSpacing.md),
          ],
        TextButton(
          onPressed: () => context.go('/screen/premium-compare'),
          child: const Text('Compare all plan features'),
        ),
        PelevoButton(
          label: claimingTrial ? 'Claim Offer' : 'Start Free Trial',
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
                  style: const TextStyle(
                    color: PelevoColors.textMuted,
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
            plan == null
                ? seededPlusPrice(_countryCode, yearly: false)
                : _localizedPlanPrice(plan),
            style: const TextStyle(
              color: PelevoColors.yellow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: PelevoSpacing.md),
          const Text(
            'Payment is completed by Google Play or the App Store. Your Pelevo account stays signed in.',
            style: TextStyle(color: PelevoColors.textMuted),
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
        const Text(
          'Create or sign in to start your Pelevo Plus membership.',
          style: TextStyle(color: PelevoColors.textMuted),
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
    final labels = const [
      'Card',
      'Paystack',
      'Flutterwave',
      'MTN MoMo',
      'Airtel Money',
    ];
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
        for (var i = 0; i < 5; i++)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: i,
            groupValue: _payment,
            activeColor: PelevoColors.yellow,
            secondary: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                const [
                  Icons.credit_card_rounded,
                  Icons.account_balance_wallet_outlined,
                  Icons.payments_outlined,
                  Icons.phone_android_rounded,
                  Icons.savings_outlined,
                ][i],
                color:
                    i == _payment
                        ? PelevoColors.yellow
                        : PelevoColors.textMuted,
              ),
            ),
            title: Text(labels[i]),
            subtitle: Text(
              i == 1 || i == 2
                  ? 'Pay securely with ${labels[i]}'
                  : 'Not offered by checkout',
            ),
            onChanged: (value) => setState(() => _payment = value!),
          ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(plan?.priceLabel ?? 'Select a plan'),
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
    final active = _preview || account?.entitlement?.active == true;
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
              : (_checkout?.checkoutUrl ??
                  'Complete provider checkout, then restore or wait for the webhook.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Card(
          color: PelevoColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(PelevoSpacing.md),
            child: Column(
              children: [
                _SummaryRow('Plan', plan?.name ?? 'Not selected'),
                _SummaryRow('Amount', plan?.priceLabel ?? '—'),
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
      const Text(
        'You have unlocked all premium features.',
        style: TextStyle(color: PelevoColors.textMuted),
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
    final active = me.entitlement?.active == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: PelevoColors.surface,
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
                if (me.subscription != null) me.subscription!.provider,
                if (me.subscription?.currentPeriodEnd != null)
                  me.subscription!.currentPeriodEnd,
              ].join('\n'),
            ),
            trailing: Chip(
              label: Text(
                active ? 'Active' : (me.entitlement?.state ?? 'Inactive'),
              ),
            ),
          ),
        ),
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
          () => context.showPelevoMessage(
            'Contact support to cancel your subscription',
          ),
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
        const Text(
          'Choose New Plan',
          style: TextStyle(color: PelevoColors.textMuted),
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
        const Text(
          'Plan changes start a provider checkout and do not grant entitlement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PelevoColors.textMuted),
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
                    _run(() async {
                      final checkout = await ref
                          .read(premiumRepositoryProvider)
                          .changePlan(
                            planId: plan.id,
                            provider: 'paystack',
                            idempotencyKey:
                                'premium-change-${DateTime.now().toUtc().microsecondsSinceEpoch}',
                          );
                      if (!context.mounted) return;
                      context.showPelevoMessage(
                        checkout.checkoutUrl ??
                            'Checkout is pending. The plan is not changed yet.',
                      );
                    });
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
          const Text(
            'No invoices yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.createdAt ?? item.id),
              subtitle: Text(item.state),
              trailing: Text(
                '${item.currency} ${(item.totalMinor / 100).toStringAsFixed(2)}',
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
      const Text(
        'Restore your previous Pelevo Plus subscription across all your devices.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      for (var i = 0; i < _providers.length; i++)
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: i,
          groupValue: _restoreProvider,
          title: Text(_providers[i]),
          onChanged: (value) => setState(() => _restoreProvider = value!),
        ),
      TextField(
        controller: _restoreReference,
        decoration: const InputDecoration(labelText: 'Payment reference'),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Restore Purchase',
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
                  final reference = _restoreReference.text.trim();
                  if (reference.isEmpty) {
                    context.showPelevoMessage('Enter the payment reference.');
                    return;
                  }
                  _run(() async {
                    await ref
                        .read(premiumRepositoryProvider)
                        .restore(
                          provider: _providers[_restoreProvider],
                          reference: reference,
                        );
                    ref.invalidate(premiumAccountProvider);
                    ref.invalidate(premiumInvoicesProvider);
                    if (!context.mounted) return;
                    context.go('/screen/premium-subscription');
                  });
                },
      ),
    ],
  );

  Widget _exclusive(BuildContext context) {
    final async = ref.watch(premiumExclusiveProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Handpicked premium content just for you.',
          style: TextStyle(color: PelevoColors.textMuted),
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
          const Text(
            'No exclusive episodes are available.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in async.requireValue)
            Card(
              color: PelevoColors.surface,
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
          gradient: const RadialGradient(
            colors: [Color(0xFF5A3D00), PelevoColors.background],
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
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
          ],
        ),
      );

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
        color: PelevoColors.surface,
        border: Border.all(
          color: _plan == value ? PelevoColors.yellow : PelevoColors.border,
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
    Color color = PelevoColors.text,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(title, style: TextStyle(color: color)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

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
      style: const TextStyle(
        color: PelevoColors.textMuted,
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
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
        ),
        Text(value),
      ],
    ),
  );
}
