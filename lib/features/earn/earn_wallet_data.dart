import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalid = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Earn data could not be verified. Please retry.',
);

BigInt _coins(Object? value) {
  if (value is! String || !RegExp(r'^(0|[1-9]\d*)$').hasMatch(value)) {
    throw _invalid;
  }
  return BigInt.parse(value);
}

class EarnWallet {
  const EarnWallet(
    this.owner,
    this.balance,
    this.minimum,
    this.withdrawalsEnabled, {
    this.coinUsdMilli = 4,
    this.payoutSchedule = 'monthly',
  });
  final String owner;
  final BigInt balance, minimum;
  final bool withdrawalsEnabled;
  final int coinUsdMilli;
  final String payoutSchedule;

  String get usdLabel {
    final milli = balance * BigInt.from(coinUsdMilli);
    final whole = milli ~/ BigInt.from(1000);
    final fraction = (milli % BigInt.from(1000)).toString().padLeft(3, '0');
    return '\$$whole.$fraction';
  }

  factory EarnWallet.parse(Map<String, dynamic> data, String owner) {
    if (data['user_id'] != owner ||
        data['unit'] != 'ECN' ||
        data['withdrawals_enabled'] is! bool) {
      throw _invalid;
    }
    final minimum = _coins(data['minimum_withdrawal']);
    if (minimum <= BigInt.zero) throw _invalid;
    return EarnWallet(
      owner,
      _coins(data['balance']),
      minimum,
      data['withdrawals_enabled'],
      coinUsdMilli: _usdMilli(data['coin_usd']),
      payoutSchedule:
          data['payout_schedule'] is String &&
              (data['payout_schedule'] as String).isNotEmpty
          ? data['payout_schedule'] as String
          : 'monthly',
    );
  }
}

int _usdMilli(Object? value) {
  if (value is! String || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return 4;
  final parts = value.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1
      ? '000'
      : parts[1].padRight(3, '0').substring(0, 3);
  return whole * 1000 + int.parse(fraction);
}

class EarnWithdrawal {
  const EarnWithdrawal(this.id, this.coins, this.state, this.createdAt);
  final String id, state;
  final BigInt coins;
  final DateTime createdAt;
  factory EarnWithdrawal.parse(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['state'] is! String ||
        (data['state'] as String).isEmpty ||
        data['created_at'] is! String) {
      throw _invalid;
    }
    final date = DateTime.tryParse(data['created_at']);
    if (date == null) throw _invalid;
    return EarnWithdrawal(
      data['id'],
      _coins(data['coins']),
      data['state'],
      date,
    );
  }
}

class EarnHistoryPage {
  const EarnHistoryPage(this.items, this.cursor);
  final List<EarnWithdrawal> items;
  final String? cursor;
}

class EarnPayoutMethod {
  const EarnPayoutMethod({
    required this.id,
    required this.provider,
    required this.kind,
    this.label,
    this.destinationLastFour,
    this.verifiedAt,
  });

  factory EarnPayoutMethod.parse(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        data['provider'] is! String ||
        (data['provider'] as String).isEmpty ||
        data['kind'] is! String ||
        (data['kind'] as String).isEmpty) {
      throw _invalid;
    }
    final verified = data['verified_at'];
    if (verified != null && verified is! String) throw _invalid;
    final label = data['label'];
    if (label != null && label is! String) throw _invalid;
    final lastFour = data['destination_last_four'];
    if (lastFour != null && lastFour is! String) throw _invalid;
    return EarnPayoutMethod(
      id: data['id'] as String,
      provider: data['provider'] as String,
      kind: data['kind'] as String,
      label: label as String?,
      destinationLastFour: lastFour as String?,
      verifiedAt: verified as String?,
    );
  }

  final String id;
  final String provider;
  final String kind;
  final String? label;
  final String? destinationLastFour;
  final String? verifiedAt;

  bool get verified => verifiedAt != null && verifiedAt!.isNotEmpty;

  String get destinationLabel {
    if (kind == 'paypal' && label != null && label!.isNotEmpty) {
      return label!;
    }
    final lastFour = destinationLastFour;
    if (lastFour != null && lastFour.isNotEmpty) {
      return '•••• $lastFour';
    }
    return (label != null && label!.isNotEmpty) ? label! : kind;
  }

  String get accountName =>
      (label != null && label!.isNotEmpty) ? label! : 'Verified destination';
}

class WithdrawDraft {
  const WithdrawDraft({this.method, this.coins, this.receipt, this.key});
  final EarnPayoutMethod? method;
  final BigInt? coins;
  final EarnWithdrawal? receipt;
  final String? key;

  WithdrawDraft copyWith({
    EarnPayoutMethod? method,
    BigInt? coins,
    EarnWithdrawal? receipt,
    String? key,
    bool clearReceipt = false,
    bool clearKey = false,
  }) => WithdrawDraft(
    method: method ?? this.method,
    coins: coins ?? this.coins,
    receipt: clearReceipt ? null : (receipt ?? this.receipt),
    key: clearKey ? null : (key ?? this.key),
  );
}

class EarnWalletRepository {
  EarnWalletRepository(this.dio);
  final Dio dio;
  Future<EarnWallet> wallet(String owner, CancelToken token) async =>
      EarnWallet.parse(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/earn/wallet',
            cancelToken: token,
          )).data,
        ),
        owner,
      );
  Future<EarnHistoryPage> history(
    String owner,
    CancelToken token, {
    String? cursor,
  }) async {
    final result =
        (await dio.get<Map<String, dynamic>>(
          '/withdrawals',
          queryParameters: {'limit': 20, if (cursor != null) 'cursor': cursor},
          cancelToken: token,
        )).data;
    if (result?['ok'] != true) requireApiData(result);
    final meta = result?['meta'];
    final rows = result?['data'];
    if (meta is! Map ||
        meta['user_id'] != owner ||
        meta['has_more'] is! bool ||
        rows is! List ||
        rows.any((row) => row is! Map<String, dynamic>) ||
        (meta['cursor'] != null && meta['cursor'] is! String) ||
        (meta['has_more'] == true &&
            (meta['cursor'] == null ||
                meta['cursor'] == '' ||
                meta['cursor'] == cursor)) ||
        (meta['has_more'] == false && meta['cursor'] != null)) {
      throw _invalid;
    }
    final items =
        rows
            .map((row) => EarnWithdrawal.parse(row as Map<String, dynamic>))
            .toList();
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw _invalid;
    }
    return EarnHistoryPage(items, meta['cursor'] as String?);
  }

  Future<List<EarnPayoutMethod>> payoutMethods(CancelToken token) async {
    try {
      final body =
          (await dio.get<Map<String, dynamic>>(
            '/payout-methods',
            cancelToken: token,
          )).data;
      if (body == null || body['ok'] != true) requireApiData(body);
      final rows = body?['data'];
      if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
        throw _invalid;
      }
      final items =
          rows
              .map((row) => EarnPayoutMethod.parse(row as Map<String, dynamic>))
              .toList();
      if (items.map((item) => item.id).toSet().length != items.length) {
        throw _invalid;
      }
      return items;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnPayoutMethod> createPayoutMethod({
    required String provider,
    required String kind,
    required Map<String, dynamic> destination,
    CancelToken? token,
  }) async {
    try {
      return EarnPayoutMethod.parse(
        requireApiData(
          (await dio.post<Map<String, dynamic>>(
            '/payout-methods',
            data: {
              'provider': provider,
              'kind': kind,
              'destination': destination,
            },
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> uploadAccountProof({
    required String payoutMethodId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      requireApiData(
        (await dio.post<Map<String, dynamic>>(
          '/payout-methods/$payoutMethodId/account-proof',
          data: FormData.fromMap({
            'account_proof': await MultipartFile.fromFile(
              filePath,
              filename: fileName,
            ),
          }),
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<EarnWithdrawal> submitWithdrawal({
    required String payoutMethodId,
    required BigInt coins,
    required String idempotencyKey,
    CancelToken? token,
  }) async {
    try {
      return EarnWithdrawal.parse(
        requireApiData(
          (await dio.post<Map<String, dynamic>>(
            '/withdrawals',
            data: {
              'payout_method_id': payoutMethodId,
              'coins': int.parse(coins.toString()),
            },
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final earnWalletRepositoryProvider = Provider(
  (ref) => EarnWalletRepository(ref.watch(dioProvider)),
);
final earnWalletProvider = FutureProvider.autoDispose<EarnWallet>((ref) {
  final owner = ref.watch(authSessionProvider.select((s) => s.userId));
  if (owner == null) throw _invalid;
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(earnWalletRepositoryProvider).wallet(owner, token);
}, retry: (count, error) => null);

final earnPayoutMethodsProvider =
    FutureProvider.autoDispose<List<EarnPayoutMethod>>((ref) {
  ref.watch(authSessionProvider.select((s) => s.userId));
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(earnWalletRepositoryProvider).payoutMethods(token);
}, retry: (count, error) => null);

class WithdrawDraftNotifier extends Notifier<WithdrawDraft> {
  @override
  WithdrawDraft build() => const WithdrawDraft();

  void select(EarnPayoutMethod method) =>
      state = state.copyWith(method: method, clearReceipt: true, clearKey: true);

  void clearMethod() => state = WithdrawDraft(
        coins: state.coins,
        receipt: state.receipt,
        key: state.key,
      );

  void setCoins(BigInt coins) =>
      state = state.copyWith(coins: coins, clearReceipt: true, clearKey: true);

  void remember(EarnWithdrawal receipt) =>
      state = state.copyWith(receipt: receipt);

  String keyFor(String methodId, BigInt coins) {
    final current = state;
    if (current.key != null &&
        current.method?.id == methodId &&
        current.coins == coins) {
      return current.key!;
    }
    final key =
        'withdraw-${DateTime.now().toUtc().microsecondsSinceEpoch}-$methodId';
    state = current.copyWith(key: key);
    return key;
  }
}

final withdrawDraftProvider =
    NotifierProvider<WithdrawDraftNotifier, WithdrawDraft>(
      WithdrawDraftNotifier.new,
    );

class EarnWalletStatus extends StatelessWidget {
  const EarnWalletStatus({super.key, this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(title: const Text('Earn Wallet')),
    child:
        error == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                Text(profileFailure(error!).message),
                TextButton(onPressed: retry, child: const Text('Retry')),
              ],
            ),
  );
}

class EarnBalanceLabel extends ConsumerWidget {
  const EarnBalanceLabel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(earnWalletProvider)
      .when(
        skipLoadingOnRefresh: false,
        data:
            (wallet) => Text(
              '${wallet.balance} coins',
              style: const TextStyle(
                color: PelevoColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
        loading: () => const Text('Loading balance…'),
        error: (error, stack) => const Text('Balance unavailable'),
      );
}

class EarnWithdrawalHistory extends ConsumerWidget {
  const EarnWithdrawalHistory({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authSessionProvider.select((s) => s.userId));
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/earn-wallet'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Withdrawal History'),
      ),
      child:
          owner == null
              ? const Text('Sign in to view withdrawals.')
              : _History(key: ValueKey(owner), owner: owner),
    );
  }
}

class _History extends ConsumerStatefulWidget {
  const _History({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_History> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<_History> {
  final List<EarnWithdrawal> items = [];
  CancelToken? token;
  String? cursor;
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    token?.cancel();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    token?.cancel();
    final current = token = CancelToken();
    setState(() {
      loading = true;
      error = null;
      if (refresh) {
        items.clear();
        cursor = null;
      }
    });
    try {
      final page = await ref
          .read(earnWalletRepositoryProvider)
          .history(widget.owner, current, cursor: cursor);
      if (!mounted ||
          current.isCancelled ||
          ref.read(authSessionProvider).userId != widget.owner) {
        return;
      }
      setState(() {
        final ids = items.map((item) => item.id).toSet();
        items.addAll(page.items.where((item) => ids.add(item.id)));
        cursor = page.cursor;
        loading = false;
      });
    } catch (failure) {
      if (!mounted || current.isCancelled) return;
      setState(() {
        error = failure;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: [
          TextButton(
            onPressed: loading ? null : () => load(refresh: true),
            child: const Text('Refresh'),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(profileFailure(error!).message),
            TextButton(
              onPressed: loading ? null : load,
              child: const Text('Retry'),
            ),
          ],
          if (!loading && error == null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Text('No withdrawals yet', textAlign: TextAlign.center),
            ),
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.payments_outlined),
                ),
                title: Text(
                  '${item.coins} coins',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${item.id}\n${item.state}'),
                isThreeLine: true,
                trailing: Text(
                  item.createdAt.toLocal().toIso8601String().substring(0, 10),
                  style: const TextStyle(color: PelevoColors.green),
                ),
              ),
            ),
          if (cursor != null && error == null)
            TextButton(
              onPressed: loading ? null : load,
              child: const Text('Load more'),
            ),
        ],
      ),
    ),
  );
}
