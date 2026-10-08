import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/compliance/age_majority_gate.dart';
import 'package:pelevo/features/gifts/gift_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/gifts/gift_service.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> giftScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'gift-coin-store',
    section: 'Gifts & Coins',
    title: 'Buy Coins',
    builder: _buildCoinStore,
  ),
  const PelevoScreenSpec(
    id: 'gift-wallet',
    section: 'Gifts & Coins',
    title: 'Coin Wallet',
    builder: _buildWallet,
  ),
  const PelevoScreenSpec(
    id: 'gift-purchase-success',
    section: 'Gifts & Coins',
    title: 'Coins Added',
    builder: _buildPurchaseSuccess,
  ),
  const PelevoScreenSpec(
    id: 'gift-purchase-failed',
    section: 'Gifts & Coins',
    title: 'Purchase Failed',
    builder: _buildPurchaseFailed,
  ),
  const PelevoScreenSpec(
    id: 'gift-receipt',
    section: 'Gifts & Coins',
    title: 'Gift Sent',
    builder: _buildGiftReceipt,
  ),
]);

Widget _buildCoinStore(BuildContext context) => const CoinStoreScreen();
Widget _buildWallet(BuildContext context) => const CoinWalletScreen();
Widget _buildPurchaseSuccess(BuildContext context) =>
    const PurchaseResultScreen(success: true);
Widget _buildPurchaseFailed(BuildContext context) =>
    const PurchaseResultScreen(success: false);
Widget _buildGiftReceipt(BuildContext context) => const GiftReceiptScreen();

IconData giftTypeIcon(String slug) => switch (slug) {
  'applause' => Icons.back_hand_rounded,
  'love' => Icons.favorite_rounded,
  'star' => Icons.star_rounded,
  'champion' => Icons.emoji_events_rounded,
  _ => Icons.card_giftcard_rounded,
};

Future<void> showPelevoGiftFlow(
  BuildContext context, {
  required String creator,
  required String contentTitle,
  String? creatorProfileId,
}) => showPelevoSheet<void>(
  context: context,
  isScrollControlled: true,
  heightFactor: .78,
  builder:
      (context) => GiftComposerSheet(
        creator: creator,
        contentTitle: contentTitle,
        creatorProfileId: creatorProfileId,
      ),
);

class GiftComposerSheet extends ConsumerStatefulWidget {
  const GiftComposerSheet({
    required this.creator,
    required this.contentTitle,
    this.creatorProfileId,
    super.key,
  });

  final String creator;
  final String contentTitle;
  final String? creatorProfileId;

  @override
  ConsumerState<GiftComposerSheet> createState() => _GiftComposerSheetState();
}

class _GiftComposerSheetState extends ConsumerState<GiftComposerSheet> {
  int _selected = 0;
  bool _sending = false;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _buyCoins() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const CoinStoreScreen(returnToGift: true),
      ),
    );
    ref.invalidate(giftWalletProvider);
  }

  Future<void> _sendGift(List<GiftTypeOption> catalog, GiftWallet wallet) async {
    if (catalog.isEmpty) return;
    final gift = catalog[_selected.clamp(0, catalog.length - 1)];
    if (wallet.balance < gift.coins) {
      await _buyCoins();
      return;
    }
    final creatorId = widget.creatorProfileId;
    if (creatorId == null || creatorId.isEmpty) {
      context.showPelevoMessage('Gift sending needs a creator profile.');
      return;
    }
    if (gift.coins >= 1000) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: Icon(giftTypeIcon(gift.slug), size: 46, color: PelevoColors.purple),
              title: Text('Send ${gift.name}?'),
              content: Text(
                '${gift.coins} coins will be deducted from your balance and sent to ${widget.creator}. Gifts cannot be exchanged or transferred.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: PelevoColors.purple,
                  ),
                  child: const Text('Confirm Gift'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    setState(() => _sending = true);
    try {
      final receipt = await ref.read(giftRepositoryProvider).send(
        giftTypeId: gift.id,
        creatorProfileId: creatorId,
        idempotencyKey:
            '${DateTime.now().toUtc().microsecondsSinceEpoch}-${gift.id}',
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      ref.read(selectedGiftIdProvider.notifier).select(receipt.id);
      ref.invalidate(giftWalletProvider);
      ref.invalidate(giftActivityProvider);
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/screen/gift-receipt');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(giftFailure(error).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(giftWalletProvider);
    final catalogAsync = ref.watch(giftCatalogProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: walletAsync.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Column(
                children: [
                  Text(giftFailure(error).message),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(giftWalletProvider);
                      ref.invalidate(giftCatalogProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
          data: (wallet) {
            final catalog = catalogAsync.asData?.value ?? const <GiftTypeOption>[];
            final hasCatalog = catalog.isNotEmpty;
            final gift =
                hasCatalog
                    ? catalog[_selected.clamp(0, catalog.length - 1)]
                    : null;
            final shortfall =
                gift == null ? 0 : gift.coins - wallet.balance;
            final canSend = gift != null && shortfall <= 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PelevoColors.border,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: PelevoColors.purple.withValues(alpha: .2),
                      child: Text(
                        widget.creator.isEmpty
                            ? '?'
                            : widget.creator.characters.first,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support ${widget.creator}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'Send a gift to show your appreciation',
                            style: TextStyle(
                              color: PelevoColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close gifts',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => context.push('/screen/gift-wallet'),
                  borderRadius: PelevoRadii.card,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: PelevoColors.surfaceHigh,
                      borderRadius: PelevoRadii.card,
                      border: Border.all(color: PelevoColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0x33FFBE16),
                          child: Icon(
                            Icons.monetization_on_rounded,
                            color: PelevoColors.yellow,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(child: Text('Your Balance')),
                        Text(
                          '${wallet.balance} coins',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose a gift',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                if (catalogAsync.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(giftCatalogProvider),
                    child: const Text('Retry'),
                  )
                else if (catalogAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!hasCatalog)
                  const Text(
                    'No gifts are available yet.',
                    style: TextStyle(color: PelevoColors.textMuted),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          childAspectRatio: .82,
                        ),
                    itemCount: catalog.length,
                    itemBuilder: (context, index) {
                      final option = catalog[index];
                      final selected = _selected == index;
                      return InkWell(
                        onTap: () => setState(() => _selected = index),
                        borderRadius: PelevoRadii.card,
                        child: AnimatedContainer(
                          duration: PelevoMotion.fast,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? PelevoColors.purple.withValues(alpha: .14)
                                    : PelevoColors.surfaceHigh,
                            borderRadius: PelevoRadii.card,
                            border: Border.all(
                              color:
                                  selected
                                      ? PelevoColors.purple
                                      : PelevoColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                giftTypeIcon(option.slug),
                                size: 27,
                                color:
                                    selected
                                        ? PelevoColors.purple
                                        : PelevoColors.yellow,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                option.name,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                '${option.coins}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _messageController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    hintText: 'Add a message (optional)',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    counterText: '',
                  ),
                ),
                const Spacer(),
                if (gift != null && !canSend)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: PelevoColors.red.withValues(alpha: .08),
                      borderRadius: PelevoRadii.card,
                      border: Border.all(
                        color: PelevoColors.red.withValues(alpha: .35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: PelevoColors.red,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not enough coins · $shortfall more needed',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _buyCoins,
                          child: const Text(
                            'Buy Coins',
                            style: TextStyle(color: PelevoColors.purple),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Want more options?',
                        style: TextStyle(
                          color: PelevoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: _buyCoins,
                        child: const Text(
                          'Buy Coins',
                          style: TextStyle(color: PelevoColors.purple),
                        ),
                      ),
                    ],
                  ),
                PelevoButton(
                  label:
                      _sending
                          ? 'Sending gift…'
                          : gift == null
                          ? 'Send gift'
                          : canSend
                          ? 'Send ${gift.name} · ${gift.coins} coins'
                          : 'Buy Coins to Send ${gift.name}',
                  color: PelevoColors.purple,
                  icon:
                      _sending
                          ? Icons.hourglass_top_rounded
                          : gift == null
                          ? Icons.card_giftcard_rounded
                          : giftTypeIcon(gift.slug),
                  onPressed:
                      _sending || gift == null
                          ? null
                          : () => _sendGift(catalog, wallet),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Gifts are voluntary and cannot be exchanged or transferred.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PelevoColors.textDim, fontSize: 10),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CoinStoreScreen extends ConsumerStatefulWidget {
  const CoinStoreScreen({super.key, this.returnToGift = false});

  final bool returnToGift;

  @override
  ConsumerState<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends ConsumerState<CoinStoreScreen> {
  int _selected = 0;
  var _ageConfirmed = false;

  Future<void> _purchase(List<GiftPack> packs) async {
    if (packs.isEmpty || !_ageConfirmed) return;
    final pack = packs[_selected.clamp(0, packs.length - 1)];
    try {
      await ref.read(profileRepositoryProvider).confirmAgeMajority();
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(giftFailure(error).message);
      return;
    }
    if (!mounted) return;
    final store = GiftWalletService.instance;
    const unavailable = 'In-app purchases are not available on this device.';
    if (store.isDemoMode || !store.storeAvailable) {
      ref.read(lastGiftPurchaseErrorProvider.notifier).select(unavailable);
      if (widget.returnToGift) {
        context.showPelevoMessage(unavailable);
        return;
      }
      context.go('/screen/gift-purchase-failed');
      return;
    }
    final result = await store.purchase(
      CoinPack(productId: pack.productId, coins: pack.coins, fallbackPrice: ''),
    );
    if (!mounted) return;
    if (result == GiftPurchaseStage.success) {
      context.showPelevoMessage(
        'A verified store receipt is required before coins can be added.',
      );
      return;
    }
    if (result == GiftPurchaseStage.cancelled) {
      context.showPelevoMessage('Purchase cancelled');
      return;
    }
    ref
        .read(lastGiftPurchaseErrorProvider.notifier)
        .select(
          store.purchaseError ?? 'A verified store receipt is required.',
        );
    context.go('/screen/gift-purchase-failed');
  }

  void _close() {
    GiftWalletService.instance.resetPurchaseState();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/screen/reels');
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(giftWalletProvider);
    final packsAsync = ref.watch(giftPacksProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close coin store',
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Buy Coins'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Coin wallet',
            onPressed: () => context.push('/screen/gift-wallet'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: walletAsync.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Column(
                  children: [
                    Text(giftFailure(error).message),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(giftWalletProvider);
                        ref.invalidate(giftPacksProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            data: (wallet) {
              final packs = packsAsync.asData?.value ?? const <GiftPack>[];
              if (_selected >= packs.length && packs.isNotEmpty) {
                _selected = 0;
              }
              final selected =
                  packs.isEmpty
                      ? null
                      : packs[_selected.clamp(0, packs.length - 1)];
              final price =
                  selected == null
                      ? 'Price unavailable'
                      : GiftWalletService.instance.storePrice(
                            selected.productId,
                          ) ??
                          'Price unavailable';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PelevoColors.surface,
                      borderRadius: PelevoRadii.card,
                      border: Border.all(color: PelevoColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: PelevoColors.yellow,
                          size: 30,
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coin Balance',
                                style: TextStyle(color: PelevoColors.textMuted),
                              ),
                              Text(
                                'Use coins to support creators you love',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${wallet.balance}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Choose a coin pack',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your Apple ID or Google Play account will be charged.',
                    style: TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (packsAsync.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(giftPacksProvider),
                      child: const Text('Retry'),
                    )
                  else if (packsAsync.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (packs.isEmpty)
                    const Text(
                      'No coin packs are available yet.',
                      style: TextStyle(color: PelevoColors.textMuted),
                    )
                  else
                    for (var index = 0; index < packs.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _CoinPackTile(
                          coins: packs[index].coins,
                          price:
                              GiftWalletService.instance.storePrice(
                                packs[index].productId,
                              ) ??
                              'Price unavailable',
                          selected: _selected == index,
                          onTap: () => setState(() => _selected = index),
                        ),
                      ),
                  const SizedBox(height: 12),
                  if (!GiftWalletService.instance.storeAvailable ||
                      GiftWalletService.instance.isDemoMode)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'In-app purchases are not available on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PelevoColors.red),
                      ),
                    ),
                  AgeMajorityCheckbox(
                    value: _ageConfirmed,
                    onChanged: (value) => setState(() => _ageConfirmed = value),
                  ),
                  const SizedBox(height: 12),
                  PelevoButton(
                    label: 'Continue · $price',
                    color: PelevoColors.purple,
                    icon: Icons.lock_outline_rounded,
                    onPressed:
                        selected == null || !_ageConfirmed
                            ? null
                            : () => _purchase(packs),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment is processed securely by Apple or Google. Coin purchases are consumable and are synchronized through your Pelevo wallet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PelevoColors.textDim,
                      fontSize: 10,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            () => context.showPelevoMessage(
                              'Terms are not available yet.',
                            ),
                        child: const Text('Terms'),
                      ),
                      TextButton(
                        onPressed:
                            () => context.showPelevoMessage(
                              'Privacy policy is not available yet.',
                            ),
                        child: const Text('Privacy'),
                      ),
                      TextButton(
                        onPressed:
                            () => context.showPelevoMessage(
                              'Purchase sync is not available yet.',
                            ),
                        child: const Text('Sync Purchases'),
                      ),
                    ],
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

class CoinWalletScreen extends ConsumerWidget {
  const CoinWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(giftWalletProvider);
    final activityAsync = ref.watch(giftActivityProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/screen/reels'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Coin Wallet'),
        centerTitle: true,
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 4,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: walletAsync.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Column(
                  children: [
                    Text(giftFailure(error).message),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(giftWalletProvider);
                        ref.invalidate(giftActivityProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            data: (wallet) {
              final activity = activityAsync.asData?.value ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: PelevoColors.yellow.withValues(alpha: .09),
                      borderRadius: PelevoRadii.card,
                      border: Border.all(
                        color: PelevoColors.yellow.withValues(alpha: .3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 46,
                          color: PelevoColors.yellow,
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Available Balance',
                          style: TextStyle(color: PelevoColors.textMuted),
                        ),
                        Text(
                          '${wallet.balance} coins',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PelevoButton(
                    label: 'Buy Coins',
                    color: PelevoColors.purple,
                    icon: Icons.add_circle_outline_rounded,
                    onPressed: () => context.push('/screen/gift-coin-store'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (activityAsync.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(giftActivityProvider),
                      child: const Text('Retry'),
                    )
                  else if (activityAsync.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (activity.isEmpty)
                    const _EmptyWalletHistory()
                  else
                    for (final entry in activity)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              entry.isCredit
                                  ? PelevoColors.green.withValues(alpha: .15)
                                  : PelevoColors.purple.withValues(alpha: .15),
                          child: Icon(
                            entry.isCredit
                                ? Icons.add_rounded
                                : Icons.card_giftcard_rounded,
                            color:
                                entry.isCredit
                                    ? PelevoColors.green
                                    : PelevoColors.purple,
                          ),
                        ),
                        title: Text(entry.eventType),
                        subtitle: Text(entry.createdAt.toUtc().toIso8601String()),
                        trailing: Text(
                          '${entry.isCredit ? '+' : ''}${entry.amount}',
                          style: TextStyle(
                            color:
                                entry.isCredit
                                    ? PelevoColors.green
                                    : PelevoColors.purple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

class PurchaseResultScreen extends ConsumerWidget {
  const PurchaseResultScreen({required this.success, super.key});

  final bool success;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(lastVerifiedGiftPurchaseProvider);
    final error = ref.watch(lastGiftPurchaseErrorProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => context.go('/screen/reels'),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child:
              success
                  ? purchase == null
                      ? const _PurchaseUnavailable(
                        message: 'No completed purchase is available yet.',
                      )
                      : _CoinPurchaseSuccess(
                        coins: purchase.coins,
                        balance: purchase.remainingBalance,
                        buttonLabel: 'Back to Reels',
                        onContinue: () => context.go('/screen/reels'),
                      )
                  : _PurchaseFailure(
                    message:
                        error ??
                        'Your payment was not completed. No charge was made.',
                    onRetry: () => context.go('/screen/gift-coin-store'),
                  ),
        ),
      ),
    );
  }
}

class GiftReceiptScreen extends ConsumerWidget {
  const GiftReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(giftReceiptProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close receipt',
          onPressed: () => context.go('/screen/reels'),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: receiptAsync.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Column(
                  children: [
                    const SizedBox(height: 50),
                    Text(giftFailure(error).message),
                    TextButton(
                      onPressed: () => ref.invalidate(giftReceiptProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            data: (receipt) {
              if (receipt == null) {
                return const Column(
                  children: [
                    SizedBox(height: 50),
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 62,
                      color: PelevoColors.purple,
                    ),
                    SizedBox(height: 22),
                    Text('No gift receipt is available yet.'),
                  ],
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 50),
                  Container(
                    width: 118,
                    height: 118,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PelevoColors.purple.withValues(alpha: .14),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      size: 62,
                      color: PelevoColors.purple,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Gift sent!',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your ${receipt.giftTypeName} was sent to ${receipt.creatorDisplayName}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PelevoColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: PelevoColors.surface,
                      borderRadius: PelevoRadii.card,
                      border: Border.all(color: PelevoColors.border),
                    ),
                    child: Column(
                      children: [
                        _ReceiptRow('Gift', receipt.giftTypeName),
                        _ReceiptRow('Coins sent', '${receipt.coins}'),
                        _ReceiptRow('Creator', receipt.creatorDisplayName),
                        _ReceiptRow(
                          'Remaining balance',
                          '${receipt.remainingBalance} coins',
                          divider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  PelevoButton(
                    label: 'Continue Watching',
                    color: PelevoColors.purple,
                    onPressed: () => context.go('/screen/reels'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/screen/gift-wallet'),
                    child: const Text('View Coin Activity'),
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

class _CoinPackTile extends StatelessWidget {
  const _CoinPackTile({
    required this.coins,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final int coins;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: PelevoRadii.card,
    child: AnimatedContainer(
      duration: PelevoMotion.fast,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            selected
                ? PelevoColors.purple.withValues(alpha: .1)
                : PelevoColors.surface,
        borderRadius: PelevoRadii.card,
        border: Border.all(
          color: selected ? PelevoColors.purple : PelevoColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? PelevoColors.purple : PelevoColors.textDim,
          ),
          const SizedBox(width: 11),
          const Icon(Icons.monetization_on_rounded, color: PelevoColors.yellow),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$coins coins',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

class _CoinPurchaseSuccess extends StatelessWidget {
  const _CoinPurchaseSuccess({
    required this.coins,
    required this.balance,
    required this.buttonLabel,
    required this.onContinue,
  });

  final int coins;
  final int balance;
  final String buttonLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 54),
      const Icon(
        Icons.check_circle_rounded,
        color: PelevoColors.green,
        size: 92,
      ),
      const SizedBox(height: 18),
      Text(
        'Coins added!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 7),
      Text(
        '$coins coins were securely added to your Pelevo wallet.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PelevoColors.surface,
          borderRadius: PelevoRadii.card,
          border: Border.all(color: PelevoColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: PelevoColors.yellow,
            ),
            const SizedBox(width: 10),
            const Text('New Balance'),
            const Spacer(),
            Text(
              '$balance coins',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      PelevoButton(
        label: buttonLabel,
        color: PelevoColors.purple,
        onPressed: onContinue,
      ),
    ],
  );
}

class _PurchaseUnavailable extends StatelessWidget {
  const _PurchaseUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 54),
      const Icon(
        Icons.check_circle_rounded,
        color: PelevoColors.green,
        size: 92,
      ),
      const SizedBox(height: 18),
      Text(
        'Coins added!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 7),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: PelevoColors.textMuted),
      ),
    ],
  );
}

class _PurchaseFailure extends StatelessWidget {
  const _PurchaseFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 54),
      const Icon(
        Icons.error_outline_rounded,
        color: PelevoColors.red,
        size: 92,
      ),
      const SizedBox(height: 18),
      Text(
        'Purchase not completed',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 7),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: 26),
      PelevoButton(
        label: 'Try Again',
        color: PelevoColors.purple,
        onPressed: onRetry,
      ),
      TextButton(
        onPressed: () => context.push('/screen/profile-help'),
        child: const Text('Contact Support'),
      ),
    ],
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.divider = true});

  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: BoxDecoration(
      border:
          divider
              ? const Border(bottom: BorderSide(color: PelevoColors.border))
              : null,
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: PelevoColors.textMuted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _EmptyWalletHistory extends StatelessWidget {
  const _EmptyWalletHistory();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    decoration: BoxDecoration(
      color: PelevoColors.surface,
      borderRadius: PelevoRadii.card,
    ),
    child: const Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          color: PelevoColors.textDim,
          size: 42,
        ),
        SizedBox(height: 9),
        Text('No coin activity yet'),
        Text(
          'Purchases and gifts will appear here.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
      ],
    ),
  );
}
