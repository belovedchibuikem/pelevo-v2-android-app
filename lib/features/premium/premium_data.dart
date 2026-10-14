import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';

const _invalidPremium = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Premium details could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidPremium;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidPremium;
  return value as String?;
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw _invalidPremium;
}

int? _optionalCount(Object? value) {
  if (value == null) return null;
  return _count(value);
}

Map<String, dynamic>? _optionalMap(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, dynamic>) throw _invalidPremium;
  return value;
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidPremium;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _listBody(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidPremium;
  }
  return _maps(body['data']);
}

String formatPremiumPrice(int minor, String currency, String interval) {
  final major = (minor / 100).toStringAsFixed(2);
  return '$currency $major / $interval';
}

class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.slug,
    required this.name,
    required this.priceMinor,
    required this.currency,
    required this.interval,
    this.trialMonths = 0,
  });

  factory PremiumPlan.parse(Map<String, dynamic> data) => PremiumPlan(
    id: _text(data, 'id'),
    slug: _text(data, 'slug'),
    name: _text(data, 'name'),
    priceMinor: _count(data['price_minor']),
    currency: _text(data, 'currency'),
    interval: _text(data, 'interval'),
    trialMonths: _optionalCount(data['trial_months']) ?? 0,
  );

  final String id, slug, name, currency, interval;
  final int priceMinor;
  final int trialMonths;

  bool get isThreeMonthTrial =>
      trialMonths == PremiumTrialOffer.trialMonths ||
      slug == PremiumTrialOffer.slug;

  String get priceLabel => formatPremiumPrice(priceMinor, currency, interval);
}

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.state,
    required this.startsAt,
    this.endsAt,
    required this.planId,
  });

  factory PremiumEntitlement.parse(Map<String, dynamic> data) {
    final starts = _text(data, 'starts_at');
    final ends = _optionalText(data, 'ends_at');
    if (DateTime.tryParse(starts) == null) throw _invalidPremium;
    if (ends != null && DateTime.tryParse(ends) == null) throw _invalidPremium;
    return PremiumEntitlement(
      state: _text(data, 'state'),
      startsAt: starts,
      endsAt: ends,
      planId: _text(data, 'plan_id'),
    );
  }

  final String state, startsAt, planId;
  final String? endsAt;

  bool get active => state == 'active';
}

class PremiumSubscription {
  const PremiumSubscription({
    required this.id,
    required this.state,
    required this.provider,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.planId,
    this.cancelAt,
  });

  factory PremiumSubscription.parse(Map<String, dynamic> data) {
    final start = _text(data, 'current_period_start');
    final end = _text(data, 'current_period_end');
    final cancel = _optionalText(data, 'cancel_at');
    if (DateTime.tryParse(start) == null || DateTime.tryParse(end) == null) {
      throw _invalidPremium;
    }
    if (cancel != null && DateTime.tryParse(cancel) == null)
      throw _invalidPremium;
    return PremiumSubscription(
      id: _text(data, 'id'),
      state: _text(data, 'state'),
      provider: _text(data, 'provider'),
      currentPeriodStart: start,
      currentPeriodEnd: end,
      planId: _text(data, 'plan_id'),
      cancelAt: cancel,
    );
  }

  final String id,
      state,
      provider,
      currentPeriodStart,
      currentPeriodEnd,
      planId;
  final String? cancelAt;
}

class PremiumAccount {
  const PremiumAccount({this.entitlement, this.subscription});

  factory PremiumAccount.parse(Map<String, dynamic> data) {
    final entitlement = _optionalMap(data['entitlement']);
    final subscription = _optionalMap(data['subscription']);
    return PremiumAccount(
      entitlement:
          entitlement == null ? null : PremiumEntitlement.parse(entitlement),
      subscription:
          subscription == null ? null : PremiumSubscription.parse(subscription),
    );
  }

  final PremiumEntitlement? entitlement;
  final PremiumSubscription? subscription;
}

/// Active Pelevo Plus for a listener or a creator.
/// Plus removes ads on the home feed and on search.
bool pelevoPlusRemovesAds(PremiumAccount? account) =>
    account?.entitlement?.active == true;

class PremiumInvoice {
  const PremiumInvoice({
    required this.id,
    required this.totalMinor,
    required this.currency,
    required this.state,
    this.receiptUrl,
    this.paidAt,
    this.createdAt,
  });

  factory PremiumInvoice.parse(Map<String, dynamic> data) {
    final paid = _optionalText(data, 'paid_at');
    final created = _optionalText(data, 'created_at');
    if (paid != null && DateTime.tryParse(paid) == null) throw _invalidPremium;
    if (created != null && DateTime.tryParse(created) == null)
      throw _invalidPremium;
    return PremiumInvoice(
      id: _text(data, 'id'),
      totalMinor: _count(data['total_minor']),
      currency: _text(data, 'currency'),
      state: _text(data, 'state'),
      receiptUrl: _optionalText(data, 'receipt_url'),
      paidAt: paid,
      createdAt: created,
    );
  }

  final String id, currency, state;
  final int totalMinor;
  final String? receiptUrl, paidAt, createdAt;

  String get amountLabel => formatPremiumPrice(totalMinor, currency, state);
}

class PremiumCheckout {
  const PremiumCheckout({
    required this.id,
    required this.state,
    required this.amountMinor,
    required this.currency,
    required this.provider,
    this.checkoutUrl,
    this.expiresAt,
  });

  factory PremiumCheckout.parse(Map<String, dynamic> data) {
    if (data.containsKey('request_hash') ||
        data.containsKey('idempotency_key') ||
        data.containsKey('provider_reference')) {
      throw _invalidPremium;
    }
    final expires = _optionalText(data, 'expires_at');
    if (expires != null && DateTime.tryParse(expires) == null)
      throw _invalidPremium;
    return PremiumCheckout(
      id: _text(data, 'id'),
      state: _text(data, 'state'),
      amountMinor: _count(data['amount_minor']),
      currency: _text(data, 'currency'),
      provider: _text(data, 'provider'),
      checkoutUrl: _optionalText(data, 'checkout_url'),
      expiresAt: expires,
    );
  }

  final String id, state, currency, provider;
  final int amountMinor;
  final String? checkoutUrl, expiresAt;
}

class PremiumExclusiveEpisode {
  const PremiumExclusiveEpisode({
    required this.id,
    required this.showId,
    required this.title,
    this.showTitle,
    this.artworkUrl,
    this.durationSeconds,
    this.publishedAt,
  });

  factory PremiumExclusiveEpisode.parse(Map<String, dynamic> data) {
    final published = _optionalText(data, 'published_at');
    if (published != null && DateTime.tryParse(published) == null) {
      throw _invalidPremium;
    }
    return PremiumExclusiveEpisode(
      id: _text(data, 'id'),
      showId: _text(data, 'show_id'),
      title: _text(data, 'title'),
      showTitle: _optionalText(data, 'show_title'),
      artworkUrl: _optionalText(data, 'artwork_url'),
      durationSeconds: _optionalCount(data['duration_seconds']),
      publishedAt: published,
    );
  }

  final String id, showId, title;
  final String? showTitle, artworkUrl, publishedAt;
  final int? durationSeconds;
}

class PremiumRepository {
  PremiumRepository(this._dio);
  final Dio _dio;

  Future<List<PremiumPlan>> plans(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/premium/plans',
          cancelToken: token,
        )).data,
      ).map(PremiumPlan.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumAccount> me(CancelToken token) async {
    try {
      return PremiumAccount.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/premium/me',
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

  Future<List<PremiumInvoice>> invoices(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/premium/invoices',
          cancelToken: token,
        )).data,
      ).map(PremiumInvoice.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<PremiumExclusiveEpisode>> exclusive(CancelToken token) async {
    try {
      return _listBody(
        (await _dio.get<Map<String, dynamic>>(
          '/premium/exclusive',
          cancelToken: token,
        )).data,
      ).map(PremiumExclusiveEpisode.parse).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumCheckout> checkout({
    required String planId,
    required String provider,
    required String idempotencyKey,
  }) async {
    try {
      return PremiumCheckout.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/premium/checkout',
            data: {'plan_id': planId, 'provider': provider},
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumCheckout> changePlan({
    required String planId,
    required String provider,
    required String idempotencyKey,
  }) async {
    try {
      return PremiumCheckout.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/premium/change-plan',
            data: {'plan_id': planId, 'provider': provider},
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumTrialEvaluation> recordTrialSession(String sessionId) async {
    try {
      return PremiumTrialEvaluation.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/premium/offers/${PremiumTrialOffer.slug}/sessions',
            data: {'session_id': sessionId},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> markTrialShown() async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/premium/offers/${PremiumTrialOffer.slug}/shown',
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumAccount> confirmStorePurchase({
    required String store,
    required String receipt,
    required String planId,
  }) async {
    try {
      return PremiumAccount.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/premium/store-purchase',
            data: {'store': store, 'receipt': receipt, 'plan_id': planId},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PremiumInvoice> restore({
    required String provider,
    required String reference,
  }) async {
    try {
      return PremiumInvoice.parse(
        requireApiData(
          (await _dio.post<Map<String, dynamic>>(
            '/premium/restore',
            data: {'provider': provider, 'reference': reference},
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

class SelectedPremiumPlanIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedPremiumPlanIdProvider =
    NotifierProvider<SelectedPremiumPlanIdNotifier, String?>(
      SelectedPremiumPlanIdNotifier.new,
    );

final premiumRepositoryProvider = Provider(
  (ref) => PremiumRepository(ref.watch(dioProvider)),
);

final premiumPlansProvider = FutureProvider.autoDispose<List<PremiumPlan>>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(premiumRepositoryProvider).plans(token);
}, retry: (count, error) => null);

final premiumAccountProvider = FutureProvider.autoDispose<PremiumAccount>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(premiumRepositoryProvider).me(token);
}, retry: (count, error) => null);

final premiumInvoicesProvider =
    FutureProvider.autoDispose<List<PremiumInvoice>>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(premiumRepositoryProvider).invoices(token);
    }, retry: (count, error) => null);

final premiumExclusiveProvider =
    FutureProvider.autoDispose<List<PremiumExclusiveEpisode>>((ref) async {
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      return ref.watch(premiumRepositoryProvider).exclusive(token);
    }, retry: (count, error) => null);
