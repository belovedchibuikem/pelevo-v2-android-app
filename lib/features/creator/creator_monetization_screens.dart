import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/compliance/age_majority_gate.dart';
import 'package:pelevo/features/creator/creator_withdrawal_data.dart';
import 'package:pelevo/features/creator/studio_data.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> creatorMonetizationScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'creator-monetization',
    section: 'Creator Monetization',
    title: 'Monetization Overview',
    builder: _buildOverview,
  ),
  const PelevoScreenSpec(
    id: 'creator-transactions',
    section: 'Creator Monetization',
    title: 'Transaction History',
    builder: _buildTransactions,
  ),
  const PelevoScreenSpec(
    id: 'creator-transaction-details',
    section: 'Creator Monetization',
    title: 'Transaction Details',
    builder: _buildTransactionDetails,
  ),
  const PelevoScreenSpec(
    id: 'creator-payout-settings',
    section: 'Creator Monetization',
    title: 'Payout Settings',
    builder: _buildPayoutSettings,
  ),
  const PelevoScreenSpec(
    id: 'creator-add-payout',
    section: 'Creator Monetization',
    title: 'Add Payout Method',
    builder: _buildAddPayout,
  ),
  const PelevoScreenSpec(
    id: 'creator-withdraw',
    section: 'Creator Monetization',
    title: 'Request Withdrawal',
    builder: _buildWithdraw,
  ),
]);

Widget _buildOverview(BuildContext context) =>
    const CreatorMonetizationScreen();
Widget _buildTransactions(BuildContext context) =>
    const CreatorTransactionHistoryScreen();
Widget _buildTransactionDetails(BuildContext context) =>
    const CreatorTransactionDetailsScreen();
Widget _buildPayoutSettings(BuildContext context) =>
    const CreatorPayoutSettingsScreen();
Widget _buildAddPayout(BuildContext context) =>
    const CreatorAddPayoutMethodScreen();
Widget _buildWithdraw(BuildContext context) =>
    const CreatorWithdrawScreen();

class CreatorMonetizationScreen extends ConsumerStatefulWidget {
  const CreatorMonetizationScreen({super.key});

  @override
  ConsumerState<CreatorMonetizationScreen> createState() =>
      _CreatorMonetizationScreenState();
}

class _CreatorMonetizationScreenState
    extends ConsumerState<CreatorMonetizationScreen> {
  StudioEarningsPeriodKey _period = StudioEarningsPeriodKey.thisMonth;

  @override
  Widget build(BuildContext context) {
    final monetization = ref.watch(studioMonetizationProvider);
    final supporters = ref.watch(studioSupportersProvider);
    final earnings = ref.watch(studioEarningsProvider(_period));
    return _MoneyPage(
      title: 'Creator Studio',
      backRoute: '/screen/creator-studio',
      child: monetization.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () {
                ref.invalidate(studioMonetizationProvider);
                ref.invalidate(studioWorkspaceProvider);
                ref.invalidate(studioSupportersProvider);
              },
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final show = selectedStudioShow(ref);
          final supporterPage = supporters.asData?.value;
          final period = earnings.asData?.value;
          final adBalances = value.accounts
              .where((account) => account.type.startsWith('reels_ad_'))
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PodcastHeader(show: show),
              const SizedBox(height: 10),
              const _CreatorTabs(),
              const SizedBox(height: 16),
              Text(
                'Monetization (Creator)',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  DropdownButton<StudioEarningsPeriodKey>(
                    value: _period,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final option in StudioEarningsPeriodKey.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged:
                        (next) => setState(() => _period = next ?? _period),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _EarningsChart(
                period: period,
                loading: earnings.isLoading,
                error: earnings.hasError,
                onRetry: () => ref.invalidate(studioEarningsProvider(_period)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoneyMetric(
                      title: 'Gifts (Coins)',
                      value: period == null ? '—' : '${period.giftCoins}',
                      caption:
                          period == null
                              ? null
                              : () {
                                final local = value.gifts.moneyLabelFor(
                                  period.giftCoins,
                                );
                                final giftsLabel =
                                    '${period.giftCount} gift${period.giftCount == 1 ? '' : 's'}';
                                return local == null
                                    ? '$giftsLabel received'
                                    : '≈ $local · $giftsLabel';
                              }(),
                      accent: PelevoColors.yellow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MoneyMetric(
                      title: 'Payouts',
                      value: period == null ? '—' : '${period.payoutsCount}',
                      caption:
                          period == null || period.payoutsCount == 0
                              ? null
                              : '${period.payoutsAmount} ${period.payoutsUnit ?? ''}'
                                  .trim(),
                      accent: PelevoColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (adBalances.isNotEmpty) ...[
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reels ad revenue',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final account in adBalances)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            account.type
                                .replaceFirst('reels_ad_', '')
                                .replaceAll('_', ' '),
                          ),
                          trailing: Text(account.balanceLabel),
                        ),
                      if (value.adAllocations.isNotEmpty) ...[
                        const Divider(),
                        const Text(
                          'Recent ad allocations',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final allocation in value.adAllocations.take(3))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              allocation.status == 'pending'
                                  ? 'Pending · estimated'
                                  : allocation.status,
                            ),
                            subtitle: Text(
                              '${allocation.status == 'pending' ? 'Held until ${allocation.heldUntil ?? 'settlement approval'}' : allocation.releasedAt ?? 'Awaiting release'}'
                              '${allocation.clawbackUsdMicros > 0 ? ' · clawback \$${(allocation.clawbackUsdMicros / 1000000).toStringAsFixed(4)}' : ''}',
                            ),
                            trailing: Text(
                              formatUsdMicros(allocation.grossUsdMicros),
                            ),
                          ),
                      ],
                      if (value.currencyConversions.isNotEmpty) ...[
                        const Divider(),
                        const Text(
                          'Recent currency conversions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final conversion in value.currencyConversions.take(
                          3,
                        ))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(conversion.label),
                            subtitle: Text(
                              '${conversion.rateSource} · rate ${conversion.netRate} · ${conversion.spreadBps} bps · ${conversion.quotedAt}',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _BreakdownCard(
                period: period,
                balance: value.primaryBalance,
                gifts: value.gifts,
                adAvailableLabel: value.adAvailableLabel ?? value.adAvailableUsd,
              ),
              const SizedBox(height: 10),
              _SupportersCard(page: supporterPage),
              const SizedBox(height: 10),
              _NavigationCard(
                icon: Icons.payments_outlined,
                label: 'Request Withdrawal',
                onTap: () => context.push('/screen/creator-withdraw'),
              ),
              _NavigationCard(
                icon: Icons.receipt_long_outlined,
                label: 'Transaction History',
                onTap: () => context.push('/screen/creator-transactions'),
              ),
              _NavigationCard(
                icon: Icons.settings_outlined,
                label: 'Payout Settings',
                onTap: () => context.push('/screen/creator-payout-settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorTransactionHistoryScreen extends ConsumerStatefulWidget {
  const CreatorTransactionHistoryScreen({super.key});

  @override
  ConsumerState<CreatorTransactionHistoryScreen> createState() =>
      _CreatorTransactionHistoryScreenState();
}

class _CreatorTransactionHistoryScreenState
    extends ConsumerState<CreatorTransactionHistoryScreen> {
  StudioTransactionFilter _filter = StudioTransactionFilter.all;
  StudioEarningsPeriodKey _period = StudioEarningsPeriodKey.thisMonth;

  static const _filters = [
    StudioTransactionFilter.all,
    StudioTransactionFilter.earnings,
    StudioTransactionFilter.payouts,
    StudioTransactionFilter.gifts,
  ];

  @override
  Widget build(BuildContext context) {
    final query = (filter: _filter, period: _period);
    final page = ref.watch(studioTransactionsProvider(query));
    final monetization = ref.watch(studioMonetizationProvider);
    final earnings = ref.watch(studioEarningsProvider(_period)).asData?.value;
    return _MoneyPage(
      title: 'Transaction History',
      backRoute: '/screen/creator-monetization',
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioTransactionsProvider(query)),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final money = monetization.asData?.value;
          final balance = money?.primaryBalance;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _filters.length; i++)
                      InkWell(
                        onTap: () => setState(() => _filter = _filters[i]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color:
                                    _filter == _filters[i]
                                        ? PelevoColors.green
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            const [
                              'All',
                              'Earnings',
                              'Payouts',
                              'Gifts (Coins)',
                            ][i],
                            style: TextStyle(
                              color:
                                  _filter == _filters[i]
                                      ? PelevoColors.green
                                      : context.pelevo.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  DropdownButton<StudioEarningsPeriodKey>(
                    value: _period,
                    items: [
                      for (final option in StudioEarningsPeriodKey.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged:
                        (next) => setState(() => _period = next ?? _period),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                gifts: earnings?.giftCount,
                payouts: earnings?.payoutsCount,
                balance: balance,
              ),
              const SizedBox(height: 18),
              if (value.items.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No transactions in this period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                )
              else
                for (final item in value.items)
                  _TransactionTile(
                    item: item,
                    onTap: () {
                      ref
                          .read(selectedStudioTransactionIdProvider.notifier)
                          .select(item.id);
                      context.push('/screen/creator-transaction-details');
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorTransactionDetailsScreen extends ConsumerWidget {
  const CreatorTransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(studioTransactionDetailProvider);
    return _MoneyPage(
      title: 'Transaction Details',
      backRoute: '/screen/creator-transactions',
      child: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioTransactionDetailProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (item) {
          final color = item.amount < 0 ? PelevoColors.red : PelevoColors.green;
          final icon =
              item.eventType == 'gift.sent'
                  ? Icons.card_giftcard_rounded
                  : item.eventType == 'reel.revenue'
                  ? Icons.movie_creation_outlined
                  : Icons.account_balance_outlined;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .15),
                  ),
                  child: Icon(icon, size: 42, color: color),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 18),
              ),
              Text(
                item.amountLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              _Panel(
                child: Column(
                  children: [
                    _DetailRow('Type', item.typeLabel),
                    if (item.counterpartName != null &&
                        item.counterpartName!.trim().isNotEmpty)
                      _DetailRow(
                        'From',
                        item.counterpartHandle == null ||
                                item.counterpartHandle!.trim().isEmpty
                            ? item.counterpartName!
                            : '${item.counterpartName}  ›',
                        onTap:
                            () => context.push(
                              '/screen/creator-audience-supporters',
                            ),
                      ),
                    if (item.giftTypeName != null &&
                        item.giftTypeName!.trim().isNotEmpty)
                      _DetailRow('For', item.giftTypeName!),
                    if (item.message != null && item.message!.trim().isNotEmpty)
                      _DetailRow('Note', item.message!),
                    if (item.createdLabel.isNotEmpty)
                      _DetailRow('Date', item.createdLabel),
                    if (item.payoutState != null &&
                        item.payoutState!.trim().isNotEmpty)
                      _DetailRow(
                        'Status',
                        item.payoutState!,
                        valueColor: PelevoColors.green,
                      ),
                    _DetailRow(
                      'Amount',
                      item.amountLabel,
                      valueColor: color,
                      divider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction ID',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.reference,
                            style: TextStyle(
                              color: context.pelevo.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy transaction ID',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: item.reference),
                        );
                        if (context.mounted) {
                          context.showPelevoMessage('Transaction ID copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: PelevoColors.green,
                  ),
                  title: const Text('Need help?'),
                  subtitle: const Text(
                    'If you have any questions about this transaction, please contact our support team.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/screen/profile-help'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorPayoutSettingsScreen extends ConsumerStatefulWidget {
  const CreatorPayoutSettingsScreen({super.key});

  @override
  ConsumerState<CreatorPayoutSettingsScreen> createState() =>
      _CreatorPayoutSettingsScreenState();
}

class _CreatorPayoutSettingsScreenState
    extends ConsumerState<CreatorPayoutSettingsScreen> {
  var _selecting = false;

  Future<void> _selectMethod(StudioPayoutMethod method) async {
    if (_selecting) return;
    if (method.kind == 'paypal' || method.provider == 'paypal') {
      context.showPelevoMessage('PayPal payouts are coming soon.');
      return;
    }
    if (!method.verified) {
      context.showPelevoMessage('Verify this bank account before selecting it.');
      return;
    }
    setState(() => _selecting = true);
    try {
      await ref
          .read(studioRepositoryProvider)
          .updatePayoutSettings(payoutMethodId: method.id);
      ref.invalidate(studioPayoutWorkspaceProvider);
      ref.invalidate(creatorWithdrawalWorkspaceProvider);
      if (!mounted) return;
      context.showPelevoMessage('Payout method selected');
    } on Object catch (error) {
      if (!mounted) return;
      final failure =
          error is ApiFailure
              ? error
              : error is DioException
              ? apiFailureFromDio(error)
              : const ApiFailure(
                code: 'UNEXPECTED',
                message: 'Could not select that payout method.',
              );
      context.showPelevoMessage(failure.message);
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = ref.watch(studioPayoutWorkspaceProvider);
    final back =
        GoRouterState.of(context).uri.queryParameters['return'] ??
        '/screen/creator-monetization';
    return _MoneyPage(
      title: 'Payout Settings',
      backRoute: back,
      action: IconButton(
        tooltip: 'Payout notifications',
        onPressed: () => context.push('/screen/notifications-1'),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      child: payout.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(studioPayoutWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final gifts = value.monetization.gifts;
          final selectedId = value.selectedMethod?.id;
          final methods = value.methods;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator payout destination',
                      style: TextStyle(color: context.pelevo.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose which verified local bank account receives withdrawals. PayPal is coming soon.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Gift coins: ${gifts.balance}',
                      style: const TextStyle(
                        color: PelevoColors.green,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (gifts.moneyLabelFor(gifts.balance) != null)
                      Text(
                        '≈ ${gifts.moneyLabelFor(gifts.balance)}',
                        style: TextStyle(
                          color: context.pelevo.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    if (value.monetization.adAvailableLabel != null ||
                        value.monetization.adAvailableUsd != null)
                      Text(
                        'Ads available: ${value.monetization.adAvailableLabel ?? value.monetization.adAvailableUsd}',
                        style: TextStyle(
                          color: context.pelevo.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Gifts withdraw from \$15. Ads withdraw from \$100. Finance pays approved requests manually.',
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'Payout Method',
                subtitle: 'Select the method you want to use for withdrawals',
                child: Column(
                  children: [
                    if (methods.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('No payout method yet'),
                        subtitle: Text(
                          'Add a verified local bank account to receive earnings.',
                        ),
                      )
                    else
                      for (final method in methods)
                        Opacity(
                          opacity:
                              method.kind == 'paypal' || !method.verified
                                  ? 0.72
                                  : 1,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: !_selecting,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF24430E),
                              child: Icon(
                                method.kind == 'paypal'
                                    ? Icons.paypal_rounded
                                    : Icons.account_balance_rounded,
                                color: PelevoColors.green,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(method.title)),
                                if (method.kind == 'paypal')
                                  Text(
                                    'Coming soon',
                                    style: TextStyle(
                                      color: context.pelevo.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else if (method.verified)
                                  const Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: PelevoColors.green,
                                      fontSize: 11,
                                    ),
                                  )
                                else if (method.proofStatus == 'pending')
                                  Text(
                                    'Pending review',
                                    style: TextStyle(
                                      color: context.pelevo.textMuted,
                                      fontSize: 11,
                                    ),
                                  )
                                else if (method.proofStatus == 'rejected')
                                  const Text(
                                    'Proof rejected',
                                    style: TextStyle(
                                      color: PelevoColors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(method.subtitle),
                            trailing: Icon(
                              method.kind == 'paypal'
                                  ? Icons.schedule_rounded
                                  : selectedId == method.id
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color:
                                  selectedId == method.id &&
                                          method.kind != 'paypal'
                                      ? PelevoColors.green
                                      : context.pelevo.textMuted,
                            ),
                            onTap: () => _selectMethod(method),
                          ),
                        ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.add_rounded,
                        color: PelevoColors.green,
                      ),
                      title: const Text(
                        'Add Payout Method',
                        style: TextStyle(color: PelevoColors.green),
                      ),
                      onTap:
                          () => context.push(
                            '/screen/creator-add-payout?return=${Uri.encodeComponent('/screen/creator-payout-settings')}',
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PelevoButton(
                label: 'Request Withdrawal',
                color: const Color(0xFF55C51F),
                onPressed: () => context.push('/screen/creator-withdraw'),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'Payout History',
                subtitle: 'View your past payouts and their status',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('View Payout History'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/screen/creator-transactions'),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'Important Information',
                child: Text(
                  '• Withdrawals are requested by you and paid by Pelevo finance.\n'
                  '• Gift withdrawals start at \$15. Ad withdrawals start at \$100.\n'
                  '• Select a verified local bank account for payouts. PayPal is coming soon.\n'
                  '• Ensure your bank details are accurate to avoid delays.',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CreatorAddPayoutMethodScreen extends ConsumerStatefulWidget {
  const CreatorAddPayoutMethodScreen({super.key});

  @override
  ConsumerState<CreatorAddPayoutMethodScreen> createState() =>
      _CreatorAddPayoutMethodScreenState();
}

class _CreatorAddPayoutMethodScreenState
    extends ConsumerState<CreatorAddPayoutMethodScreen> {
  int _method = 0;
  String? _country;
  String? _bank;
  var _saving = false;
  var _resolving = false;
  var _ageConfirmed = false;
  String? _proofPath;
  String? _proofName;
  String? _pendingMethodId;
  final _accountNumber = TextEditingController();
  final _accountName = TextEditingController();
  final _paypalEmail = TextEditingController();

  @override
  void dispose() {
    _accountNumber.dispose();
    _accountName.dispose();
    _paypalEmail.dispose();
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

  Future<void> _resolveAccount() async {
    final country = _country;
    final bank = _bank;
    final number = _accountNumber.text.trim();
    if (_resolving ||
        country == null ||
        country.isEmpty ||
        bank == null ||
        bank.isEmpty ||
        number.length < 8) {
      return;
    }
    setState(() => _resolving = true);
    try {
      final name = await ref
          .read(creatorWithdrawalRepositoryProvider)
          .resolveFlutterwaveAccount(
            country: country,
            bankCode: bank,
            accountNumber: number,
          );
      if (!mounted) return;
      setState(() => _accountName.text = name);
      context.showPelevoMessage('Account name verified.');
    } on Object catch (error) {
      if (!mounted) return;
      final failure =
          error is ApiFailure
              ? error
              : error is DioException
              ? apiFailureFromDio(error)
              : const ApiFailure(
                code: 'UNEXPECTED',
                message: 'Account verification failed. Please try again.',
              );
      context.showPelevoMessage(failure.message);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_ageConfirmed) return;
    final returnTo =
        GoRouterState.of(context).uri.queryParameters['return'] ??
        '/screen/creator-payout-settings';
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).confirmAgeMajority();
      if (_method == 0) {
        final country = _country;
        final bank = _bank;
        final number = _accountNumber.text.trim();
        final name = _accountName.text.trim();
        final proofPath = _proofPath;
        final proofName = _proofName;
        if (country == null ||
            country.isEmpty ||
            bank == null ||
            bank.isEmpty ||
            number.isEmpty) {
          if (mounted) {
            context.showPelevoMessage(
              'Select a country, bank, and account number to continue.',
            );
          }
          return;
        }
        if (name.isEmpty) {
          if (mounted) {
            context.showPelevoMessage(
              'Verify the account number so we can fill the account name.',
            );
          }
          return;
        }
        if (proofPath == null || proofName == null) {
          if (mounted) {
            context.showPelevoMessage(
              'Upload a cropped proof that shows your full name and account number.',
            );
          }
          return;
        }
        final method =
            _pendingMethodId == null
                ? await ref
                    .read(studioRepositoryProvider)
                    .createPayoutMethod(
                      provider: 'flutterwave',
                      kind: 'bank',
                      destination: {
                        'account_number': number,
                        'bank_code': bank,
                        'country': country,
                        'account_name': name,
                      },
                    )
                : null;
        final methodId = method?.id ?? _pendingMethodId!;
        _pendingMethodId = methodId;
        await ref
            .read(studioRepositoryProvider)
            .uploadAccountProof(
              payoutMethodId: methodId,
              filePath: proofPath,
              fileName: proofName,
            );
      } else {
        if (mounted) {
          context.showPelevoMessage('PayPal payouts are coming soon.');
        }
        return;
      }
      ref.invalidate(studioPayoutWorkspaceProvider);
      ref.invalidate(creatorWithdrawalWorkspaceProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        _method == 0
            ? 'Bank account verified and saved for payouts.'
            : 'PayPal account verified and saved for payouts.',
      );
      context.go(returnTo);
    } on Object catch (error) {
      if (!mounted) return;
      final failure =
          error is ApiFailure
              ? error
              : error is DioException
              ? apiFailureFromDio(error)
              : const ApiFailure(
                code: 'UNEXPECTED',
                message: 'Payout method could not be saved. Please try again.',
              );
      context.showPelevoMessage(failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(flutterwaveCountriesProvider);
    final banks =
        _country == null
            ? const AsyncValue<List<FlutterwaveBank>>.data([])
            : ref.watch(flutterwaveBanksProvider(_country!));
    final returnTo =
        GoRouterState.of(context).uri.queryParameters['return'] ??
        '/screen/creator-payout-settings';
    return _MoneyPage(
      title: 'Add Payout Method',
      backRoute: returnTo,
      action: IconButton(
        tooltip: 'Payout notifications',
        onPressed: () => context.push('/screen/notifications-1'),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select Payout Method',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 12),
          _PayoutMethodCard(
            selected: _method == 0,
            icon: Icons.account_balance_rounded,
            title: 'Bank Transfer (Local Banks)',
            subtitle:
                'Receive your earnings to a supported\nlocal bank account',
            onTap:
                () => setState(() {
                  _method = 0;
                  _pendingMethodId = null;
                }),
          ),
          const SizedBox(height: 10),
          _PayoutMethodCard(
            selected: false,
            comingSoon: true,
            icon: Icons.paypal_rounded,
            title: 'PayPal',
            subtitle: 'Coming soon — use local bank transfer for now',
            onTap: () {
              context.showPelevoMessage('PayPal payouts are coming soon.');
            },
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Bank transfer details',
            subtitle:
                'Choose a supported country, then verify the bank account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_method == 0) ...[
                  const Text('Country'),
                  const SizedBox(height: 6),
                  countries.when(
                    loading: () => const LinearProgressIndicator(),
                    error:
                        (error, _) => TextButton(
                          onPressed:
                              () =>
                                  ref.invalidate(flutterwaveCountriesProvider),
                          child: Text(catalogFailure(error).message),
                        ),
                    data: (items) {
                      final selected = items.where((c) => c.code == _country);
                      final label =
                          selected.isEmpty
                              ? null
                              : '${selected.first.name} (${selected.first.currency})';
                      return SearchableSelectField(
                        key: const Key('payout-country'),
                        valueLabel: label,
                        hint: 'Select country',
                        searchHint: 'Search countries',
                        sheetTitle: 'Select country',
                        options: [
                          for (final country in items)
                            (
                              value: country.code,
                              label: '${country.name} (${country.currency})',
                            ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _country = value;
                            _bank = null;
                            _accountName.clear();
                            _pendingMethodId = null;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Bank Name'),
                  const SizedBox(height: 6),
                  banks.when(
                    loading: () => const LinearProgressIndicator(),
                    error:
                        (error, _) => TextButton(
                          onPressed:
                              _country == null
                                  ? null
                                  : () => ref.invalidate(
                                    flutterwaveBanksProvider(_country!),
                                  ),
                          child: Text(catalogFailure(error).message),
                        ),
                    data: (items) {
                      final selected = items.where((b) => b.code == _bank);
                      final label =
                          selected.isEmpty ? null : selected.first.name;
                      return SearchableSelectField(
                        key: const Key('payout-bank'),
                        valueLabel: label,
                        hint:
                            _country == null
                                ? 'Select a country first'
                                : 'Select your bank',
                        searchHint: 'Search banks',
                        sheetTitle: 'Select bank',
                        enabled: _country != null,
                        options: [
                          for (final bank in items)
                            (value: bank.code, label: bank.name),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _bank = value;
                            _accountName.clear();
                            _pendingMethodId = null;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Number'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _accountNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter your account number',
                    ),
                    onChanged: (_) {
                      _pendingMethodId = null;
                      if (_accountName.text.isNotEmpty) {
                        setState(() => _accountName.clear());
                      }
                    },
                    onEditingComplete: _resolveAccount,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _resolving ? null : _resolveAccount,
                      icon:
                          _resolving
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.verified_outlined),
                      label: Text(
                        _resolving ? 'Verifying…' : 'Verify account name',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Account Name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _accountName,
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'Verified name appears here',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'We fill this from the bank directory after you enter the account number.',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Upload a cropped statement that shows your full name and account number.',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AccountProofUpload(fileName: _proofName, onPick: _pickProof),
                ] else ...[
                  const Text('PayPal Email'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _paypalEmail,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Your PayPal email is verified automatically and can be changed later.',
                    style: TextStyle(
                      color: context.pelevo.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AgeMajorityCheckbox(
            value: _ageConfirmed,
            onChanged: (value) => setState(() => _ageConfirmed = value),
          ),
          const SizedBox(height: 12),
          PelevoButton(
            label: _saving ? 'Saving…' : 'Save Payout Method',
            color: const Color(0xFF55C51F),
            onPressed: _saving || !_ageConfirmed ? null : _save,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your information is secure and encrypted',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
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

class _MoneyPage extends StatelessWidget {
  const _MoneyPage({
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
        constraints: const BoxConstraints(maxWidth: 620),
        child: child,
      ),
    ),
  );
}

class _PodcastHeader extends StatelessWidget {
  const _PodcastHeader({this.show});

  final StudioShow? show;

  @override
  Widget build(BuildContext context) {
    final artwork = show?.artworkUrl;
    final fallback = Container(
      width: 54,
      height: 54,
      color: const Color(0xFF111016),
      alignment: Alignment.center,
      child: Icon(Icons.podcasts_rounded, color: context.pelevo.textMuted),
    );
    final episodes = show?.episodeCount;
    final updated = show?.updatedAt;
    final subtitle = [
      if (episodes != null) '$episodes Episodes',
      if (updated != null && updated.isNotEmpty) updated,
    ].join(' · ');
    return InkWell(
      onTap: () => context.push('/screen/creator-studios'),
      borderRadius: PelevoRadii.card,
      child: _Panel(
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

class _CreatorTabs extends StatelessWidget {
  const _CreatorTabs();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < 5; i++)
          InkWell(
            onTap: () {
              final routes = [
                '/screen/creator-dashboard',
                '/screen/creator-episodes',
                '/screen/creator-reels',
                '/screen/creator-audience',
                '/screen/creator-monetization',
              ];
              context.go(routes[i]);
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: i == 4 ? PelevoColors.green : Colors.transparent,
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
                  color: i == 4 ? PelevoColors.green : context.pelevo.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _EarningsChart extends StatelessWidget {
  const _EarningsChart({
    required this.period,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final StudioEarningsPeriod? period;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value = period;
    final series = value?.series ?? const <StudioEarningsPoint>[];
    final labels = _axisLabels(series);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reels Ad Earnings',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value?.adRevenueLabel ?? (loading ? '…' : '\$0.00 USD'),
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          if (value != null)
            Text(
              '+ ${value.giftCoins} coins from ${value.giftCount} gift${value.giftCount == 1 ? '' : 's'}',
              style: const TextStyle(color: PelevoColors.yellow, fontSize: 12),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 145,
            width: double.infinity,
            child:
                loading && value == null
                    ? const Center(child: CircularProgressIndicator())
                    : error && value == null
                    ? Center(
                      child: TextButton(
                        onPressed: onRetry,
                        child: const Text('Earnings could not load. Retry'),
                      ),
                    )
                    : CustomPaint(
                      painter: _EarningsPainter(
                        series,
                        gridColor: context.pelevo.border.withValues(alpha: .45),
                      ),
                    ),
          ),
          if (labels.isNotEmpty) ...[
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
          ],
          const SizedBox(height: 10),
          const Row(
            children: [
              _ChartKey(color: PelevoColors.green, label: 'Ad earnings (USD)'),
              SizedBox(width: 16),
              _ChartKey(color: PelevoColors.yellow, label: 'Gift coins'),
            ],
          ),
          if (value != null && !value.hasActivity) ...[
            const SizedBox(height: 8),
            Text(
              'No earnings recorded in this period yet.',
              style: TextStyle(color: context.pelevo.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static List<String> _axisLabels(List<StudioEarningsPoint> series) {
    if (series.isEmpty) return const [];
    if (series.length <= 5) return [for (final point in series) point.label];
    final last = series.length - 1;
    return [
      for (final index in [0, last ~/ 4, last ~/ 2, last * 3 ~/ 4, last])
        series[index].label,
    ];
  }
}

class _ChartKey extends StatelessWidget {
  const _ChartKey({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(color: context.pelevo.textMuted, fontSize: 11),
      ),
    ],
  );
}

/// Gift coins and ad USD are different units, so each is scaled to its own peak.
class _EarningsPainter extends CustomPainter {
  const _EarningsPainter(this.series, {required this.gridColor});

  final List<StudioEarningsPoint> series;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (series.isEmpty) return;
    final maxCoins = series.fold<int>(
      0,
      (peak, point) => math.max(peak, point.giftCoins),
    );
    final maxAds = series.fold<int>(
      0,
      (peak, point) => math.max(peak, point.adUsdMicros),
    );
    final slot = size.width / series.length;
    final chartHeight = size.height - 4;
    if (maxCoins > 0) {
      final bar = Paint()..color = PelevoColors.yellow.withValues(alpha: .55);
      final width = math.max(2.0, slot * .5);
      for (var i = 0; i < series.length; i++) {
        final coins = series[i].giftCoins;
        if (coins == 0) continue;
        final height = chartHeight * coins / maxCoins;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              slot * i + (slot - width) / 2,
              size.height - height,
              width,
              height,
            ),
            const Radius.circular(2),
          ),
          bar,
        );
      }
    }
    if (maxAds > 0) {
      final points = [
        for (var i = 0; i < series.length; i++)
          Offset(
            slot * i + slot / 2,
            size.height - chartHeight * series[i].adUsdMicros / maxAds,
          ),
      ];
      final fill =
          Path()
            ..moveTo(points.first.dx, size.height)
            ..lineTo(points.first.dx, points.first.dy);
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        line.lineTo(point.dx, point.dy);
        fill.lineTo(point.dx, point.dy);
      }
      fill
        ..lineTo(points.last.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PelevoColors.green.withValues(alpha: .35),
              PelevoColors.green.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = PelevoColors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EarningsPainter oldDelegate) =>
      !identical(oldDelegate.series, series) ||
      oldDelegate.gridColor != gridColor;
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({
    required this.title,
    required this.value,
    required this.accent,
    this.caption,
  });
  final String title;
  final String value;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: accent)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (caption != null && caption!.isNotEmpty)
          Text(
            caption!,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 11),
          ),
      ],
    ),
  );
}

class CreatorWithdrawScreen extends ConsumerStatefulWidget {
  const CreatorWithdrawScreen({super.key});

  @override
  ConsumerState<CreatorWithdrawScreen> createState() =>
      _CreatorWithdrawScreenState();
}

class _CreatorWithdrawScreenState extends ConsumerState<CreatorWithdrawScreen> {
  String _source = 'gifts';
  var _busy = false;

  Future<void> _request(CreatorWithdrawalWorkspace workspace) async {
    if (_busy) return;
    if (!workspace.hasVerifiedPayoutMethod) {
      context.showPelevoMessage(
        'Set up a verified payout method before requesting a withdrawal.',
      );
      context.push(
        '/screen/creator-add-payout?return=${Uri.encodeComponent('/screen/creator-withdraw')}',
      );
      return;
    }
    final method = workspace.verifiedMethod;
    if (method == null) {
      context.push(
        '/screen/creator-payout-settings?return=${Uri.encodeComponent('/screen/creator-withdraw')}',
      );
      return;
    }
    final source = _source == 'ads' ? workspace.ads : workspace.gifts;
    if (!source.eligible) {
      context.showPelevoMessage(
        _source == 'ads'
            ? 'Ad revenue withdrawals start at \$100.'
            : 'Gift withdrawals start at \$15.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(creatorWithdrawalRepositoryProvider).requestWithdrawal(
        source: _source,
        payoutMethodId: method.id,
        currency:
            workspace.payoutCurrency ?? source.currency ?? 'USD',
        diamonds: _source == 'gifts' ? source.diamonds : null,
        amountUsdCents: _source == 'ads' ? source.availableUsdCents : null,
      );
      ref.invalidate(creatorWithdrawalWorkspaceProvider);
      ref.invalidate(studioMonetizationProvider);
      if (!mounted) return;
      context.showPelevoMessage(
        'Withdrawal requested. Pelevo finance will pay this manually after review.',
      );
      context.go('/screen/creator-payout-settings');
    } on Object catch (error) {
      if (!mounted) return;
      final failure =
          error is ApiFailure
              ? error
              : error is DioException
              ? apiFailureFromDio(error)
              : const ApiFailure(
                code: 'UNEXPECTED',
                message: 'Withdrawal could not be requested. Please try again.',
              );
      if (failure.code == 'PAYOUT_METHOD_REQUIRED' ||
          failure.code == 'PAYOUT_METHOD_UNVERIFIED') {
        context.push(
          '/screen/creator-add-payout?return=${Uri.encodeComponent('/screen/creator-withdraw')}',
        );
      }
      context.showPelevoMessage(failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(creatorWithdrawalWorkspaceProvider);
    return _MoneyPage(
      title: 'Request Withdrawal',
      backRoute: '/screen/creator-monetization',
      child: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _StudioLoadError(
              error: error,
              onRetry: () => ref.invalidate(creatorWithdrawalWorkspaceProvider),
              onClaim: () => context.go('/screen/claim-podcast'),
            ),
        data: (value) {
          final selected = _source == 'ads' ? value.ads : value.gifts;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Panel(
                child: Text(
                  value.note ??
                      'Withdrawals are requested by you. Pelevo finance pays approved requests manually. Ad revenue covers every claimed podcast.',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose source',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 10),
              _PayoutMethodCard(
                selected: _source == 'gifts',
                icon: Icons.card_giftcard_rounded,
                title: 'Gift earnings',
                subtitle:
                    '${value.gifts.balanceLabel ?? '0 coins'}\n'
                    '${value.gifts.moneyLabel == null ? 'Threshold ${value.gifts.thresholdUsd}' : '≈ ${value.gifts.moneyLabel} · from ${value.gifts.thresholdUsd}'}',
                onTap: () => setState(() => _source = 'gifts'),
              ),
              const SizedBox(height: 10),
              _PayoutMethodCard(
                selected: _source == 'ads',
                icon: Icons.play_circle_outline_rounded,
                title: 'Ads revenue',
                subtitle:
                    '${value.ads.balanceLabel ?? '\$0.00'}\n'
                    'All claimed podcasts · from ${value.ads.thresholdUsd}',
                onTap: () => setState(() => _source = 'ads'),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Payout destination',
                subtitle:
                    value.hasVerifiedPayoutMethod
                        ? 'Verified method ready for this request'
                        : 'Set up payout details before withdrawing',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    value.hasVerifiedPayoutMethod
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color:
                        value.hasVerifiedPayoutMethod
                            ? PelevoColors.green
                            : PelevoColors.yellow,
                  ),
                  title: Text(
                    value.verifiedMethod?.title ?? 'No verified payout method',
                  ),
                  subtitle: Text(
                    value.verifiedMethod?.subtitle ??
                        'Add a verified Bank Transfer (Local Banks) payout method. PayPal is coming soon.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => context.push(
                        value.hasVerifiedPayoutMethod
                            ? '/screen/creator-payout-settings?return=${Uri.encodeComponent('/screen/creator-withdraw')}'
                            : '/screen/creator-add-payout?return=${Uri.encodeComponent('/screen/creator-withdraw')}',
                      ),
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _source == 'ads' ? 'Ads request' : 'Gifts request',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(selected.balanceLabel ?? '0'),
                    if (selected.moneyLabel != null)
                      Text(
                        '≈ ${selected.moneyLabel}',
                        style: TextStyle(color: context.pelevo.textMuted),
                      ),
                    Text(
                      selected.eligible
                          ? 'Ready to request. Finance will review and pay manually.'
                          : 'Available balance is below ${selected.thresholdUsd}.',
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PelevoButton(
                label:
                    _busy
                        ? 'Submitting…'
                        : value.hasVerifiedPayoutMethod
                        ? 'Request withdrawal'
                        : 'Set up payout method first',
                color: const Color(0xFF55C51F),
                onPressed: _busy ? null : () => _request(value),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.period,
    this.balance,
    this.gifts = const StudioGiftMoney(balance: 0),
    this.adAvailableLabel,
  });

  final StudioEarningsPeriod? period;
  final StudioAccount? balance;
  final StudioGiftMoney gifts;
  final String? adAvailableLabel;

  static const _statusColors = {
    'pending': PelevoColors.yellow,
    'confirmed': PelevoColors.blue,
    'released': PelevoColors.green,
    'available': PelevoColors.green,
  };

  static String _statusLabel(String status) => switch (status) {
    'pending' => 'Pending (estimated)',
    'confirmed' => 'Confirmed',
    'released' || 'available' => 'Available',
    _ =>
      status.isEmpty
          ? 'Other'
          : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
  };

  @override
  Widget build(BuildContext context) {
    final totals = period?.adStatusTotals ?? const <String, int>{};
    final total = totals.values.fold<int>(0, (sum, value) => sum + value);
    final entries =
        totals.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final segments = [
      for (final entry in entries)
        (
          color: _statusColors[entry.key] ?? PelevoColors.purple,
          share: total == 0 ? 0.0 : entry.value / total,
        ),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ad Earnings Breakdown',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 126,
                height: 126,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: segments,
                    trackColor: context.pelevo.border,
                  ),
                  child: Center(
                    child: Text(
                      '${formatUsdMicros(total)}\nthis period',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    if (entries.isEmpty)
                      Text(
                        'No ad earnings in this period yet.',
                        style: TextStyle(color: context.pelevo.textMuted),
                      )
                    else
                      for (final entry in entries) ...[
                        _Legend(
                          color:
                              _statusColors[entry.key] ?? PelevoColors.purple,
                          title: _statusLabel(entry.key),
                          percent:
                              '${(entry.value * 100 / math.max(1, total)).round()}%',
                          amount: formatUsdMicros(entry.value),
                        ),
                        const SizedBox(height: 12),
                      ],
                    const Divider(height: 18),
                    _Legend(
                      color: PelevoColors.orange,
                      title: 'Coin balance',
                      percent:
                          gifts.balance > 0
                              ? '${gifts.balance} coins'
                              : (balance?.balanceLabel ?? '0'),
                      amount: () {
                        final local = gifts.moneyLabelFor(gifts.balance);
                        return local == null ? 'From gifts' : '≈ $local';
                      }(),
                    ),
                    if (adAvailableLabel != null) ...[
                      const SizedBox(height: 12),
                      _Legend(
                        color: PelevoColors.green,
                        title: 'Ads available',
                        percent: adAvailableLabel!,
                        amount: 'All claimed podcasts',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments, required this.trackColor});

  final List<({Color color, double share})> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.butt;
    paint.color = trackColor;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.pi * 2 * segment.share.clamp(0.0, 1.0);
      if (sweep <= 0) continue;
      paint.color = segment.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.trackColor != trackColor;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.title,
    required this.percent,
    required this.amount,
  });
  final Color color;
  final String title;
  final String percent;
  final String amount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title)),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(percent, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            amount,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 10),
          ),
        ],
      ),
    ],
  );
}

class _SupportersCard extends StatelessWidget {
  const _SupportersCard({this.page});

  final StudioSupporterPage? page;

  @override
  Widget build(BuildContext context) {
    final items = page?.items.take(5).toList() ?? const <StudioSupporter>[];
    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Top Supporters',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed:
                    () => context.push('/screen/creator-audience-supporters'),
                child: const Text(
                  'See All',
                  style: TextStyle(color: PelevoColors.green),
                ),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No supporters yet.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: context.pelevo.surfaceHigh,
                  child: Text('${i + 1}'),
                ),
                title: Text(items[i].name),
                subtitle: Text(
                  items[i].subtitle,
                  style: const TextStyle(color: PelevoColors.green),
                ),
              ),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: context.pelevo.surface,
    shape: RoundedRectangleBorder(borderRadius: PelevoRadii.card),
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({this.gifts, this.payouts, this.balance});

  final int? gifts;
  final int? payouts;
  final StudioAccount? balance;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryValue(
                'Gifts received',
                '${gifts ?? 0}',
                PelevoColors.green,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                'Payouts',
                '${payouts ?? 0}',
                PelevoColors.purple,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                'Balance',
                balance?.balanceLabel ?? '0',
                PelevoColors.green,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: context.pelevo.textMuted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    ],
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.onTap});
  final StudioTransaction item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.amount < 0 ? PelevoColors.red : PelevoColors.green;
    final icon =
        item.eventType == 'gift.sent'
            ? Icons.card_giftcard_rounded
            : item.eventType == 'reel.revenue'
            ? Icons.movie_creation_outlined
            : Icons.account_balance_outlined;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tileColor: context.pelevo.surface,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .15),
        child: Icon(icon, color: color),
      ),
      title: Text(item.title),
      subtitle: Text(
        [
          item.subtitle,
          if (item.createdLabel.isNotEmpty) item.createdLabel,
        ].join('\n'),
      ),
      isThreeLine: item.createdLabel.isNotEmpty,
      trailing: Text(
        item.amountLabel,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
    this.label,
    this.value, {
    this.valueColor,
    this.onTap,
    this.divider = true,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            divider
                ? Border(bottom: BorderSide(color: context.pelevo.border))
                : null,
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: context.pelevo.textMuted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _PayoutMethodCard extends StatelessWidget {
  const _PayoutMethodCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
  });
  final bool selected;
  final bool comingSoon;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: comingSoon ? 0.72 : 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: PelevoRadii.card,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.pelevo.surface,
          borderRadius: PelevoRadii.card,
          border: Border.all(
            color: selected ? PelevoColors.green : context.pelevo.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              comingSoon
                  ? Icons.schedule_rounded
                  : selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color:
                  comingSoon
                      ? context.pelevo.textMuted
                      : selected
                      ? PelevoColors.green
                      : context.pelevo.textMuted,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: context.pelevo.surfaceHigh,
              child: Icon(icon),
            ),
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
                ],
              ),
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.pelevo.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.pelevo.border),
                ),
                child: Text(
                  'Coming soon',
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
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
