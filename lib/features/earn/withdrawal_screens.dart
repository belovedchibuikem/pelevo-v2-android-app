import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/compliance/age_majority_gate.dart';
import 'package:pelevo/features/earn/earn_wallet_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';

enum PayoutGateway { paystack, paypal, flutterwave }

extension PayoutGatewayX on PayoutGateway {
  String get label => switch (this) {
    PayoutGateway.paystack => 'Paystack',
    PayoutGateway.paypal => 'PayPal',
    PayoutGateway.flutterwave => 'Flutterwave',
  };

  String get subtitle => switch (this) {
    PayoutGateway.paystack => 'Nigerian banks & mobile money',
    PayoutGateway.paypal => 'Global PayPal balance payouts',
    PayoutGateway.flutterwave => 'Cards, banks & African wallets',
  };

  Color get color => switch (this) {
    PayoutGateway.paystack => const Color(0xFF00C3F7),
    PayoutGateway.paypal => const Color(0xFF003087),
    PayoutGateway.flutterwave => const Color(0xFFF5A623),
  };

  IconData get icon => switch (this) {
    PayoutGateway.paystack => Icons.account_balance_rounded,
    PayoutGateway.paypal => Icons.payments_outlined,
    PayoutGateway.flutterwave => Icons.bolt_rounded,
  };

  String get setupRoute => switch (this) {
    PayoutGateway.paystack => '/screen/withdraw-setup-paystack',
    PayoutGateway.paypal => '/screen/withdraw-setup-paypal',
    PayoutGateway.flutterwave => '/screen/withdraw-setup-flutterwave',
  };

  String get provider => name;

  bool get supported => this != PayoutGateway.flutterwave;
}

class PayoutMethodConfig {
  const PayoutMethodConfig({
    required this.gateway,
    required this.destination,
    required this.accountName,
    this.verified = false,
  });

  final PayoutGateway gateway;
  final String destination;
  final String accountName;
  final bool verified;
}

class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    required this.gateway,
    required this.coins,
    required this.destination,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final PayoutGateway gateway;
  final int coins;
  final String destination;
  final DateTime createdAt;
  final String status;
}

/// Legacy local machine. Money movement is server-authoritative.
class EarnWalletService extends ChangeNotifier {
  EarnWalletService._();
  static final EarnWalletService instance = EarnWalletService._();

  static const processingWindow = 'Monthly (1st–5th)';

  final Map<PayoutGateway, PayoutMethodConfig> linkedMethods = {};
  final List<WithdrawalRequest> history = [];
  PayoutGateway? selectedGateway;
  int draftCoins = 0;

  bool isLinked(PayoutGateway gateway) =>
      linkedMethods[gateway]?.verified == true;

  void selectGateway(PayoutGateway gateway) {
    selectedGateway = gateway;
    notifyListeners();
  }

  void setDraftCoins(int coins) {
    draftCoins = coins;
    notifyListeners();
  }

  void linkMethod(PayoutMethodConfig config) {
    linkedMethods[config.gateway] = config;
    selectedGateway = config.gateway;
    notifyListeners();
  }

  String? validateDraft() =>
      'Verified payout setup and submission are not connected yet. No withdrawal has been submitted.';

  WithdrawalRequest? submitDraft() => null;
}

EarnPayoutMethod? _verifiedMethod(
  List<EarnPayoutMethod> methods,
  PayoutGateway gateway,
) {
  for (final method in methods) {
    if (method.provider == gateway.provider && method.verified) {
      return method;
    }
  }
  return null;
}

class WithdrawHomeScreen extends ConsumerWidget {
  const WithdrawHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(earnWalletProvider);
    final methods = ref.watch(earnPayoutMethodsProvider);
    if (wallet.isLoading || methods.isLoading) {
      return EarnWalletStatus(
        retry: () {
          ref.invalidate(earnWalletProvider);
          ref.invalidate(earnPayoutMethodsProvider);
        },
      );
    }
    final walletError = wallet.error;
    final methodsError = methods.error;
    if (walletError != null || methodsError != null) {
      return EarnWalletStatus(
        error: walletError ?? methodsError,
        retry: () {
          ref.invalidate(earnWalletProvider);
          ref.invalidate(earnPayoutMethodsProvider);
        },
      );
    }
    final balance = wallet.requireValue;
    final payouts = methods.requireValue;
    final draft = ref.watch(withdrawDraftProvider);
    final meets = balance.balance >= balance.minimum;
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/earn-wallet'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Withdraw Earnings'),
        actions: [
          TextButton(
            onPressed: () => context.push('/screen/withdraw-history'),
            child: const Text('History'),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BalanceBanner(coins: balance.balance),
              const SizedBox(height: PelevoSpacing.lg),
              _ThresholdCard(
                meetsThreshold: meets,
                balance: balance.balance,
                minimum: balance.minimum,
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Text(
                'Payout Gateways',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              const Text(
                'Earn coins are separate from gift coins. PayPal is the only way to withdraw Earn coins.',
                style: TextStyle(color: PelevoColors.textMuted, height: 1.35),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              for (final gateway in [PayoutGateway.paypal])
                _GatewayTile(
                  gateway: gateway,
                  method: _verifiedMethod(payouts, gateway),
                  selected: draft.method?.provider == gateway.provider,
                  onSelect: () {
                    final method = _verifiedMethod(payouts, gateway);
                    if (method == null) {
                      context.push(gateway.setupRoute);
                      return;
                    }
                    ref.read(withdrawDraftProvider.notifier).select(method);
                  },
                  onSetup: () => context.push(gateway.setupRoute),
                ),
              const SizedBox(height: PelevoSpacing.lg),
              const Text(
                'Withdrawals are reviewed and paid monthly between the 1st and 5th. Linked accounts must be verified before payout.',
                style: TextStyle(color: PelevoColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              PelevoButton(
                label: 'Continue',
                color: PelevoColors.green,
                onPressed: () {
                  final error = () {
                    if (!balance.withdrawalsEnabled) {
                      return 'Withdrawals are awaiting finance sign-off.';
                    }
                    if (!meets) {
                      return 'Reach ${balance.minimum} coins to withdraw.';
                    }
                    if (draft.method == null || !draft.method!.verified) {
                      return 'Select a verified payout gateway.';
                    }
                    return null;
                  }();
                  if (error != null) {
                    context.showPelevoMessage(error);
                    return;
                  }
                  ref
                      .read(withdrawDraftProvider.notifier)
                      .setCoins(
                        balance.balance < balance.minimum
                            ? balance.minimum
                            : balance.minimum,
                      );
                  context.push('/screen/withdraw-amount');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawSetupPaystackScreen extends ConsumerStatefulWidget {
  const WithdrawSetupPaystackScreen({super.key});

  @override
  ConsumerState<WithdrawSetupPaystackScreen> createState() =>
      _WithdrawSetupPaystackScreenState();
}

class _WithdrawSetupPaystackScreenState
    extends ConsumerState<WithdrawSetupPaystackScreen> {
  final _name = TextEditingController();
  final _account = TextEditingController();
  String? _bank;
  String _accountType = 'NUBAN';
  var _saving = false;
  var _ageConfirmed = false;
  String? _proofPath;
  String? _proofName;
  String? _pendingMethodId;

  static const _banks = [
    ('044', 'Access Bank'),
    ('058', 'Guaranty Trust Bank'),
    ('011', 'First Bank'),
    ('033', 'UBA'),
    ('057', 'Zenith Bank'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    try {
      final file = await pickAccountProof();
      if (file == null || !mounted) return;
      setState(() {
        _proofPath = file.path;
        _proofName = file.name;
        _pendingMethodId = null;
      });
    } on FormatException catch (error) {
      if (mounted) context.showPelevoMessage(error.message);
    }
  }

  Future<void> _save() async {
    if (_saving || !_ageConfirmed) return;
    if (_accountType != 'NUBAN') {
      context.showPelevoMessage(
        'Paystack setup in this app supports NUBAN bank accounts only.',
      );
      return;
    }
    final bank = _bank;
    final proofPath = _proofPath;
    final proofName = _proofName;
    if (bank == null || _account.text.trim().length < 10) {
      context.showPelevoMessage('Enter a valid 10-digit account number');
      return;
    }
    if (proofPath == null || proofName == null) {
      context.showPelevoMessage(
        'Upload a cropped proof that shows your full name and account number.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).confirmAgeMajority();
      final methodId = _pendingMethodId;
      final method =
          methodId == null
              ? await ref
                  .read(earnWalletRepositoryProvider)
                  .createPayoutMethod(
                    provider: 'paystack',
                    kind: 'bank',
                    destination: {
                      'account_number': _account.text.trim(),
                      'bank_code': bank,
                    },
                  )
              : null;
      final id = method?.id ?? methodId!;
      _pendingMethodId = id;
      await ref
          .read(earnWalletRepositoryProvider)
          .uploadAccountProof(
            payoutMethodId: id,
            filePath: proofPath,
            fileName: proofName,
          );
      ref.invalidate(earnPayoutMethodsProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        'Proof uploaded. A reviewer will check your name and account number.',
      );
      context.go('/screen/withdraw');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SetupScaffold(
    title: 'Set up Paystack',
    gateway: PayoutGateway.paystack,
    children: [
      const Text(
        'Paystack pays verified Nigerian bank accounts. Enter NUBAN details exactly as they appear on your account.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Account name'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      DropdownButtonFormField<String>(
        value: _bank,
        decoration: const InputDecoration(labelText: 'Bank name'),
        items: [
          for (final bank in _banks)
            DropdownMenuItem(value: bank.$1, child: Text(bank.$2)),
        ],
        onChanged:
            (value) => setState(() {
              _bank = value;
              _pendingMethodId = null;
            }),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      TextField(
        controller: _account,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Account number',
          hintText: '10-digit NUBAN',
        ),
        onChanged: (_) => _pendingMethodId = null,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      DropdownButtonFormField<String>(
        value: _accountType,
        decoration: const InputDecoration(labelText: 'Account type'),
        items: const [
          DropdownMenuItem(value: 'NUBAN', child: Text('NUBAN')),
          DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
        ],
        onChanged: (value) => setState(() => _accountType = value ?? 'NUBAN'),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      AccountProofUpload(fileName: _proofName, onPick: _pickProof),
      const SizedBox(height: PelevoSpacing.md),
      AgeMajorityCheckbox(
        value: _ageConfirmed,
        onChanged: (value) => setState(() => _ageConfirmed = value),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: _saving ? 'Uploading…' : 'Verify & Link Paystack',
        color: PayoutGateway.paystack.color,
        onPressed: _saving || !_ageConfirmed ? null : _save,
      ),
    ],
  );
}

class WithdrawSetupPaypalScreen extends ConsumerStatefulWidget {
  const WithdrawSetupPaypalScreen({super.key});

  @override
  ConsumerState<WithdrawSetupPaypalScreen> createState() =>
      _WithdrawSetupPaypalScreenState();
}

class _WithdrawSetupPaypalScreenState
    extends ConsumerState<WithdrawSetupPaypalScreen> {
  final _email = TextEditingController();
  final _confirm = TextEditingController();
  var _saving = false;
  var _ageConfirmed = false;

  @override
  void dispose() {
    _email.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_ageConfirmed) return;
    final email = _email.text.trim();
    if (!email.contains('@') || email != _confirm.text.trim()) {
      context.showPelevoMessage('PayPal emails must match');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).confirmAgeMajority();
      final method = await ref
          .read(earnWalletRepositoryProvider)
          .createPayoutMethod(
            provider: 'paypal',
            kind: 'paypal',
            destination: {'email': email},
          );
      ref.invalidate(earnPayoutMethodsProvider);
      if (!mounted) return;
      if (!method.verified) {
        context.showPelevoMessage(
          'PayPal destination was saved but is not verified yet.',
        );
        context.go('/screen/withdraw');
        return;
      }
      ref.read(withdrawDraftProvider.notifier).select(method);
      context.showPelevoMessage('PayPal account linked');
      context.go('/screen/withdraw');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SetupScaffold(
    title: 'Set up PayPal',
    gateway: PayoutGateway.paypal,
    children: [
      const Text(
        'PayPal payouts are sent in USD to your verified PayPal email. Confirm the address carefully.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'PayPal email',
          hintText: 'name@email.com',
        ),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      TextField(
        controller: _confirm,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Confirm PayPal email'),
      ),
      const SizedBox(height: PelevoSpacing.md),
      AgeMajorityCheckbox(
        value: _ageConfirmed,
        onChanged: (value) => setState(() => _ageConfirmed = value),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: _saving ? 'Verifying…' : 'Verify & Link PayPal',
        color: PayoutGateway.paypal.color,
        onPressed: _saving || !_ageConfirmed ? null : _save,
      ),
    ],
  );
}

class WithdrawSetupFlutterwaveScreen extends StatelessWidget {
  const WithdrawSetupFlutterwaveScreen({super.key});

  @override
  Widget build(BuildContext context) => _SetupScaffold(
    title: 'Set up Flutterwave',
    gateway: PayoutGateway.flutterwave,
    children: [
      const Text(
        'Flutterwave supports bank transfers and mobile wallets across Africa. Choose your preferred payout channel.',
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      const TextField(
        enabled: false,
        decoration: InputDecoration(labelText: 'Beneficiary name'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      DropdownButtonFormField<String>(
        value: 'Bank Transfer',
        decoration: const InputDecoration(labelText: 'Payout channel'),
        items: const [
          DropdownMenuItem(
            value: 'Bank Transfer',
            child: Text('Bank Transfer'),
          ),
          DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
          DropdownMenuItem(value: 'Barter', child: Text('Barter')),
        ],
        onChanged: null,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Phone / wallet ID',
          hintText: '+234…',
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Verify & Link Flutterwave',
        color: PayoutGateway.flutterwave.color,
        onPressed: () => context.showPelevoMessage(
          'Flutterwave is not offered by the payout API. No destination has been saved.',
        ),
      ),
    ],
  );
}

class WithdrawAmountScreen extends ConsumerStatefulWidget {
  const WithdrawAmountScreen({super.key});

  @override
  ConsumerState<WithdrawAmountScreen> createState() =>
      _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends ConsumerState<WithdrawAmountScreen> {
  late final TextEditingController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(earnWalletProvider);
    return wallet.when(
      skipLoadingOnRefresh: false,
      loading:
          () => EarnWalletStatus(
            retry: () => ref.invalidate(earnWalletProvider),
          ),
      error:
          (error, stack) => EarnWalletStatus(
            error: error,
            retry: () => ref.invalidate(earnWalletProvider),
          ),
      data: (balance) {
        final draft = ref.watch(withdrawDraftProvider);
        final coins = draft.coins ?? balance.minimum;
        if (!_ready) {
          _ready = true;
          _controller.text = '$coins';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(withdrawDraftProvider.notifier).setCoins(coins);
            }
          });
        }
        return PelevoPage(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.go('/screen/withdraw'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Withdrawal Amount'),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Available ${balance.balance} coins',
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                  const SizedBox(height: PelevoSpacing.md),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Coins to withdraw',
                      helperText: 'Minimum ${balance.minimum} coins',
                    ),
                    onChanged: (value) {
                      final parsed = BigInt.tryParse(value) ?? BigInt.zero;
                      ref.read(withdrawDraftProvider.notifier).setCoins(parsed);
                    },
                  ),
                  const SizedBox(height: PelevoSpacing.md),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in {
                        balance.minimum,
                        if (balance.balance >= balance.minimum) balance.balance,
                      })
                        ActionChip(
                          label: Text(
                            preset == balance.balance ? 'Max' : '$preset',
                          ),
                          onPressed: () {
                            ref
                                .read(withdrawDraftProvider.notifier)
                                .setCoins(preset);
                            _controller.text = '$preset';
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: PelevoSpacing.xl),
                  _AmountSummary(
                    coins: coins,
                    gateway: draft.method == null
                        ? '—'
                        : (draft.method!.provider == 'paypal'
                            ? 'PayPal'
                            : 'Paystack'),
                  ),
                  const SizedBox(height: PelevoSpacing.xl),
                  PelevoButton(
                    label: 'Review Withdrawal',
                    color: PelevoColors.green,
                    onPressed: () {
                      if (!balance.withdrawalsEnabled) {
                        context.showPelevoMessage(
                          'Withdrawals are awaiting finance sign-off.',
                        );
                        return;
                      }
                      if (draft.method == null || !draft.method!.verified) {
                        context.showPelevoMessage(
                          'Select a verified payout gateway.',
                        );
                        return;
                      }
                      if (coins < balance.minimum) {
                        context.showPelevoMessage(
                          'Reach ${balance.minimum} coins to withdraw.',
                        );
                        return;
                      }
                      if (coins > balance.balance) {
                        context.showPelevoMessage(
                          'Earn wallet balance is insufficient.',
                        );
                        return;
                      }
                      context.push('/screen/withdraw-review');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class WithdrawReviewScreen extends ConsumerStatefulWidget {
  const WithdrawReviewScreen({super.key});

  @override
  ConsumerState<WithdrawReviewScreen> createState() =>
      _WithdrawReviewScreenState();
}

class _WithdrawReviewScreenState extends ConsumerState<WithdrawReviewScreen> {
  var _saving = false;
  var _ageConfirmed = false;

  Future<void> _confirm() async {
    if (_saving || !_ageConfirmed) return;
    final draft = ref.read(withdrawDraftProvider);
    final method = draft.method;
    final coins = draft.coins;
    if (method == null || !method.verified || coins == null) {
      context.showPelevoMessage('Select a verified payout gateway.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).confirmAgeMajority();
      final key = ref
          .read(withdrawDraftProvider.notifier)
          .keyFor(method.id, coins);
      final receipt = await ref
          .read(earnWalletRepositoryProvider)
          .submitWithdrawal(
            payoutMethodId: method.id,
            coins: coins,
            idempotencyKey: key,
          );
      ref.read(withdrawDraftProvider.notifier).remember(receipt);
      ref.invalidate(earnWalletProvider);
      if (!mounted) return;
      context.go('/screen/withdraw-success');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(withdrawDraftProvider);
    final method = draft.method;
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/withdraw-amount'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Review & Confirm'),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReviewRow(
                label: 'Gateway',
                value: method == null
                    ? '—'
                    : (method.provider == 'paypal' ? 'PayPal' : 'Paystack'),
              ),
              _ReviewRow(
                label: 'Destination',
                value: method?.destinationLabel ?? '—',
              ),
              _ReviewRow(
                label: 'Account name',
                value: method?.accountName ?? '—',
              ),
              _ReviewRow(label: 'Coins', value: '${draft.coins ?? '—'}'),
              const _ReviewRow(
                label: 'Processing',
                value: EarnWalletService.processingWindow,
              ),
              const SizedBox(height: PelevoSpacing.lg),
              const Text(
                'By confirming, you queue this payout for the next monthly settlement cycle. Coins are reserved immediately and cannot be spent while pending.',
                style: TextStyle(color: PelevoColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: PelevoSpacing.md),
              AgeMajorityCheckbox(
                value: _ageConfirmed,
                onChanged: (value) => setState(() => _ageConfirmed = value),
              ),
              const SizedBox(height: PelevoSpacing.xl),
              PelevoButton(
                label: _saving ? 'Submitting…' : 'Confirm Withdrawal',
                color: PelevoColors.green,
                onPressed: _saving || !_ageConfirmed ? null : _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawSuccessScreen extends ConsumerWidget {
  const WithdrawSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(withdrawDraftProvider).receipt;
    return PelevoPage(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const SizedBox(height: 48),
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFF14532D),
                child: Icon(
                  latest == null ? Icons.info_outline : Icons.check_rounded,
                  color: PelevoColors.green,
                  size: 42,
                ),
              ),
              const SizedBox(height: PelevoSpacing.xl),
              Text(
                latest == null
                    ? 'No withdrawal confirmation'
                    : 'Withdrawal queued',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: PelevoSpacing.sm),
              Text(
                latest == null
                    ? 'No server-confirmed payout request is available. Check your withdrawal history for actual requests.'
                    : '${latest.coins} coins will process ${EarnWalletService.processingWindow.toLowerCase()}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: PelevoColors.textMuted),
              ),
              const SizedBox(height: PelevoSpacing.xxl),
              PelevoButton(
                label: 'View History',
                color: PelevoColors.green,
                onPressed: () => context.go('/screen/withdraw-history'),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              PelevoButton(
                label: 'Back to Wallet',
                outlined: true,
                color: PelevoColors.green,
                onPressed: () => context.go('/screen/earn-wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawHistoryScreen extends StatelessWidget {
  const WithdrawHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const EarnWithdrawalHistory();
}

class _SetupScaffold extends StatelessWidget {
  const _SetupScaffold({
    required this.title,
    required this.gateway,
    required this.children,
  });

  final String title;
  final PayoutGateway gateway;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/withdraw'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(title),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: gateway.color.withValues(alpha: .18),
                  child: Icon(gateway.icon, color: gateway.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    gateway.subtitle,
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PelevoSpacing.lg),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.coins});

  final BigInt coins;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.lg),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(PelevoRadii.large),
      gradient: const LinearGradient(
        colors: [Color(0xFF14532D), Color(0xFF0B1F14)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Withdrawable balance'),
        const SizedBox(height: 6),
        Text(
          '$coins coins',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'ECN · quoted by the payout service',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    ),
  );
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.meetsThreshold,
    required this.balance,
    required this.minimum,
  });

  final bool meetsThreshold;
  final BigInt balance;
  final BigInt minimum;

  @override
  Widget build(BuildContext context) {
    final progress =
        minimum == BigInt.zero
            ? 0.0
            : (balance.toDouble() / minimum.toDouble()).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      decoration: BoxDecoration(
        color: PelevoColors.surface,
        borderRadius: BorderRadius.circular(PelevoRadii.large),
        border: Border.all(color: PelevoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                meetsThreshold
                    ? Icons.verified_rounded
                    : Icons.hourglass_bottom_rounded,
                color:
                    meetsThreshold ? PelevoColors.green : PelevoColors.yellow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meetsThreshold
                      ? 'Threshold met — you can withdraw'
                      : 'Withdrawal threshold',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum $minimum coins.',
            style: const TextStyle(color: PelevoColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: PelevoColors.border,
              color: meetsThreshold ? PelevoColors.green : PelevoColors.yellow,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayTile extends StatelessWidget {
  const _GatewayTile({
    required this.gateway,
    required this.method,
    required this.selected,
    required this.onSelect,
    required this.onSetup,
  });

  final PayoutGateway gateway;
  final EarnPayoutMethod? method;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final linked = method != null;
    return Card(
      margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PelevoRadii.large),
        side: BorderSide(
          color: selected ? gateway.color : PelevoColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: gateway.color.withValues(alpha: .16),
          child: Icon(gateway.icon, color: gateway.color),
        ),
        title: Text(
          gateway.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          linked ? method!.destinationLabel : gateway.subtitle,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        trailing:
            linked
                ? Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? gateway.color : PelevoColors.textDim,
                )
                : TextButton(onPressed: onSetup, child: const Text('Set up')),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.coins, required this.gateway});

  final BigInt coins;
  final String gateway;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      color: PelevoColors.surface,
      borderRadius: BorderRadius.circular(PelevoRadii.large),
      border: Border.all(color: PelevoColors.border),
    ),
    child: Column(
      children: [
        _ReviewRow(label: 'Coins', value: '$coins'),
        _ReviewRow(label: 'Gateway', value: gateway),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: PelevoColors.textMuted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
