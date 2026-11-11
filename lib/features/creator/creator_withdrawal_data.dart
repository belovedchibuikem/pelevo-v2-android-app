import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/studio_data.dart';

const _invalidWithdrawal = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Withdrawal details could not be verified. Please retry.',
);

class FlutterwaveCountry {
  const FlutterwaveCountry({
    required this.code,
    required this.name,
    required this.currency,
  });

  factory FlutterwaveCountry.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    final currency = json['currency'];
    if (code is! String ||
        code.isEmpty ||
        name is! String ||
        name.isEmpty ||
        currency is! String ||
        currency.isEmpty) {
      throw _invalidWithdrawal;
    }
    return FlutterwaveCountry(code: code, name: name, currency: currency);
  }

  final String code, name, currency;
}

class FlutterwaveBank {
  const FlutterwaveBank({required this.code, required this.name});

  factory FlutterwaveBank.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    if (code is! String || code.isEmpty || name is! String || name.isEmpty) {
      throw _invalidWithdrawal;
    }
    return FlutterwaveBank(code: code, name: name);
  }

  final String code, name;
}

class CreatorWithdrawalSource {
  const CreatorWithdrawalSource({
    required this.eligible,
    required this.thresholdUsd,
    required this.thresholdUsdCents,
    this.balanceLabel,
    this.moneyLabel,
    this.currency,
    this.availableUsdCents,
    this.diamonds,
    this.minDiamonds,
  });

  final bool eligible;
  final String thresholdUsd;
  final int thresholdUsdCents;
  final String? balanceLabel;
  final String? moneyLabel;
  final String? currency;
  final int? availableUsdCents;
  final int? diamonds;
  final int? minDiamonds;
}

class CreatorWithdrawalWorkspace {
  const CreatorWithdrawalWorkspace({
    required this.gifts,
    required this.ads,
    required this.methods,
    required this.hasVerifiedPayoutMethod,
    required this.manualPayout,
    this.selectedPayoutMethodId,
    this.payoutCurrency,
    this.note,
  });

  factory CreatorWithdrawalWorkspace.fromJson(Map<String, dynamic> json) {
    final gifts = json['gifts'];
    final ads = json['ads'];
    final methods = json['payout_methods'];
    if (gifts is! Map<String, dynamic> ||
        ads is! Map<String, dynamic> ||
        methods is! List) {
      throw _invalidWithdrawal;
    }
    final giftQuote = gifts['quotes'] is Map ? gifts['quotes']['USD'] : null;
    final giftBalance = (gifts['balance'] as num?)?.toInt() ?? 0;
    final giftMoney =
        giftQuote is Map && giftQuote['gross_minor'] is num
            ? '\$${((giftQuote['gross_minor'] as num) / 100).toStringAsFixed(2)} USD'
            : null;
    final payoutCurrency =
        json['payout_currency'] is String
            ? (json['payout_currency'] as String).toUpperCase()
            : null;
    final selectedId =
        json['selected_payout_method_id'] == null
            ? null
            : '${json['selected_payout_method_id']}';
    final adsUsdRaw =
        '${ads['available_usd'] ?? ads['cleared_ad_usd'] ?? '0.00'}';
    final adsUsdLabel =
        adsUsdRaw.contains('USD')
            ? adsUsdRaw
            : adsUsdRaw.contains('\$')
            ? '$adsUsdRaw USD'
            : '\$$adsUsdRaw USD';
    return CreatorWithdrawalWorkspace(
      gifts: CreatorWithdrawalSource(
        eligible: gifts['eligible'] == true,
        thresholdUsd: '${gifts['threshold_usd'] ?? '\$10.00'}',
        thresholdUsdCents: (gifts['threshold_usd_cents'] as num?)?.toInt() ?? 1000,
        balanceLabel: '$giftBalance coins',
        moneyLabel: giftMoney,
        // Request currency stays on the bank route for Flutterwave FX.
        currency: payoutCurrency ?? 'USD',
        diamonds: giftBalance,
        minDiamonds: (gifts['min_cashout_diamonds'] as num?)?.toInt(),
      ),
      ads: CreatorWithdrawalSource(
        eligible: ads['eligible'] == true,
        thresholdUsd: '${ads['threshold_usd'] ?? '\$100.00'}',
        thresholdUsdCents: (ads['threshold_usd_cents'] as num?)?.toInt() ?? 10000,
        balanceLabel: adsUsdLabel,
        moneyLabel: adsUsdLabel,
        currency: payoutCurrency ?? 'USD',
        availableUsdCents: (ads['available_usd_cents'] as num?)?.toInt() ?? 0,
      ),
      methods:
          methods
              .whereType<Map<String, dynamic>>()
              .map(StudioPayoutMethod.fromJson)
              .toList(growable: false),
      selectedPayoutMethodId: selectedId,
      hasVerifiedPayoutMethod: json['has_verified_payout_method'] == true,
      payoutCurrency: payoutCurrency,
      manualPayout: json['manual_payout'] != false,
      note: json['note'] as String?,
    );
  }

  final CreatorWithdrawalSource gifts;
  final CreatorWithdrawalSource ads;
  final List<StudioPayoutMethod> methods;
  final String? selectedPayoutMethodId;
  final bool hasVerifiedPayoutMethod;
  final String? payoutCurrency;
  final bool manualPayout;
  final String? note;

  StudioPayoutMethod? get verifiedMethod {
    final banks =
        methods
            .where(
              (method) =>
                  method.verified &&
                  method.kind != 'paypal' &&
                  method.provider != 'paypal',
            )
            .toList(growable: false);
    if (banks.isEmpty) return null;
    final selectedId = selectedPayoutMethodId;
    if (selectedId != null) {
      for (final method in banks) {
        if (method.id == selectedId) return method;
      }
    }
    return banks.first;
  }
}

class CreatorWithdrawalHistoryItem {
  const CreatorWithdrawalHistoryItem({
    required this.id,
    required this.source,
    required this.amountLabel,
    required this.state,
    this.usdLabel,
    this.createdAt,
  });

  factory CreatorWithdrawalHistoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final source = json['source'];
    final amount = json['amount_label'];
    final state = json['state'];
    if (id == null ||
        '$id'.isEmpty ||
        source is! String ||
        source.isEmpty ||
        amount is! String ||
        amount.isEmpty ||
        state is! String ||
        state.isEmpty) {
      throw _invalidWithdrawal;
    }
    return CreatorWithdrawalHistoryItem(
      id: '$id',
      source: source,
      amountLabel: amount,
      usdLabel: json['usd_label'] as String?,
      state: state,
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String source;
  final String amountLabel;
  final String? usdLabel;
  final String state;
  final String? createdAt;

  String get title => source == 'ads' ? 'Ads withdrawal' : 'Gift withdrawal';

  String get createdLabel {
    if (createdAt == null || createdAt!.isEmpty) return '';
    final parsed = DateTime.tryParse(createdAt!);
    if (parsed == null) return createdAt!;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day · $hour:$minute';
  }

  String get stateLabel {
    final value = state.trim().toLowerCase();
    return switch (value) {
      'queued' => 'Queued',
      'approved' => 'Approved',
      'processing' => 'Processing',
      'paid' => 'Paid',
      'failed' => 'Failed',
      'rejected' => 'Rejected',
      'reversed' => 'Reversed',
      _ => state,
    };
  }
}

class CreatorWithdrawalRepository {
  CreatorWithdrawalRepository(this._dio);
  final Dio _dio;

  Future<CreatorWithdrawalWorkspace> workspace() async {
    try {
      return CreatorWithdrawalWorkspace.fromJson(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/creators/withdrawals/workspace',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<FlutterwaveCountry>> flutterwaveCountries() async {
    try {
      return _list(
        (await _dio.get<Map<String, dynamic>>(
          '/payout-methods/flutterwave/countries',
        )).data,
      ).map(FlutterwaveCountry.fromJson).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<FlutterwaveBank>> flutterwaveBanks(String country) async {
    try {
      return _list(
        (await _dio.get<Map<String, dynamic>>(
          '/payout-methods/flutterwave/banks',
          queryParameters: {'country': country},
        )).data,
      ).map(FlutterwaveBank.fromJson).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<String> resolveFlutterwaveAccount({
    required String country,
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/payout-methods/flutterwave/resolve',
          data: {
            'country': country,
            'bank_code': bankCode,
            'account_number': accountNumber,
          },
        )).data,
      );
      final name = data['account_name'];
      if (name is! String || name.trim().isEmpty) throw _invalidWithdrawal;
      return name.trim();
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required String source,
    required String payoutMethodId,
    required String currency,
    int? diamonds,
    int? amountUsdCents,
  }) async {
    try {
      return requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/creators/withdrawals',
          data: {
            'source': source,
            'payout_method_id': payoutMethodId,
            'currency': currency,
            if (diamonds != null) 'diamonds': diamonds,
            if (amountUsdCents != null) 'amount_usd_cents': amountUsdCents,
          },
          options: Options(
            headers: {
              'Idempotency-Key':
                  'creator-withdraw-$source-$payoutMethodId-${DateTime.now().millisecondsSinceEpoch}',
            },
          ),
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<CreatorWithdrawalHistoryItem>> history() async {
    try {
      return _list(
        (await _dio.get<Map<String, dynamic>>('/creators/withdrawals')).data,
      ).map(CreatorWithdrawalHistoryItem.fromJson).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidWithdrawal;
    }
    final data = body['data'];
    if (data is! List) throw _invalidWithdrawal;
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}

final creatorWithdrawalRepositoryProvider = Provider(
  (ref) => CreatorWithdrawalRepository(ref.watch(dioProvider)),
);

final creatorWithdrawalWorkspaceProvider =
    FutureProvider.autoDispose<CreatorWithdrawalWorkspace>((ref) async {
      ref.watch(authSessionProvider);
      return ref.watch(creatorWithdrawalRepositoryProvider).workspace();
    }, retry: (count, error) => null);

final flutterwaveCountriesProvider =
    FutureProvider.autoDispose<List<FlutterwaveCountry>>((ref) {
      return ref.watch(creatorWithdrawalRepositoryProvider).flutterwaveCountries();
    }, retry: (count, error) => null);

final flutterwaveBanksProvider = FutureProvider.autoDispose
    .family<List<FlutterwaveBank>, String>((ref, country) {
      return ref
          .watch(creatorWithdrawalRepositoryProvider)
          .flutterwaveBanks(country);
    }, retry: (count, error) => null);

final creatorWithdrawalHistoryProvider =
    FutureProvider.autoDispose<List<CreatorWithdrawalHistoryItem>>((ref) async {
      ref.watch(authSessionProvider);
      return ref.watch(creatorWithdrawalRepositoryProvider).history();
    }, retry: (count, error) => null);
