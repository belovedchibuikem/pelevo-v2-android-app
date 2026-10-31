import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_trial_offer.dart';
import 'package:pelevo/features/premium/storefront_price.dart';
import 'package:pelevo/features/store/regional_prices.dart';

class PremiumPurchaseResult {
  const PremiumPurchaseResult({
    required this.productId,
    required this.reference,
  });

  final String productId;
  final String reference;
}

/// Google Play / App Store subscription for Pelevo Plus.
///
/// Monthly prices are set per country in each store console. The paywall
/// shows that store's formatted price and does not convert a base amount.
class PremiumStore {
  PremiumStore._();

  static final instance = PremiumStore._();

  /// Google Play subscription product (monthly + yearly base plans).
  static const googleProductId = 'pelevo_plus_individual';

  /// App Store product IDs, and logical IDs after Play base-plan mapping.
  static const monthlyProductId = 'pelevo_plus_monthly';
  static const yearlyProductId = 'pelevo_plus_yearly';

  static const monthlyBasePlanId = 'monthly';
  static const yearlyBasePlanId = 'yearly';

  final _iap = InAppPurchase.instance;
  final Map<String, List<ProductDetails>> _catalog = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<PremiumPurchaseResult>? _pending;
  Completer<List<PremiumPurchaseResult>>? _restorePending;
  final List<PremiumPurchaseResult> _restoreBuffer = [];
  Timer? _restoreSettle;
  DateTime? _restoreStarted;
  Map<String, StorefrontPrice>? _quoteOverride;
  final Map<String, bool> _introEligible = {};

  bool get _isMobileStore => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get storeProvider => !kIsWeb && Platform.isIOS ? 'apple' : 'google';

  bool get _isAndroidStore => !kIsWeb && Platform.isAndroid;

  String productIdFor(PremiumPlan plan) {
    if (_isAndroidStore) return googleProductId;
    return plusIntervalIsYearly(plan.interval)
        ? yearlyProductId
        : monthlyProductId;
  }

  String? basePlanIdFor(PremiumPlan plan) {
    if (!_isAndroidStore) return null;
    return plusIntervalIsYearly(plan.interval)
        ? yearlyBasePlanId
        : monthlyBasePlanId;
  }

  String _eligibilityKey(PremiumPlan plan) {
    final productId = productIdFor(plan);
    final basePlanId = basePlanIdFor(plan);
    if (basePlanId == null) return productId;
    return '$productId|$basePlanId';
  }

  static bool isPlusStoreProduct(String productId) =>
      productId == googleProductId ||
      productId == monthlyProductId ||
      productId == yearlyProductId;

  /// Installs store quotes for tests. Production reads the native catalog.
  @visibleForTesting
  void debugInstallQuotes(Map<String, StorefrontPrice> quotes) {
    _quoteOverride = Map.unmodifiable(quotes);
  }

  @visibleForTesting
  void debugClearQuotes() {
    _quoteOverride = null;
    _introEligible.clear();
  }

  bool get hasDebugQuotes => _quoteOverride != null;

  StorefrontPrice? quoteForPlan(PremiumPlan plan) {
    final override = _quoteOverride;
    if (override != null) {
      return override[productIdFor(plan)] ??
          override[plusIntervalIsYearly(plan.interval)
              ? yearlyProductId
              : monthlyProductId];
    }
    final product = _productForPurchase(plan);
    if (product == null) return null;
    final quote = storefrontPriceFromProduct(product);
    if (quote == null) return null;
    return storefrontQuoteForEligibility(
      quote,
      eligible: _introEligible[_eligibilityKey(plan)] != false,
    );
  }

  String priceLabel(PremiumPlan plan) =>
      subscriptionPriceLine(quoteForPlan(plan));

  Future<void> prepare(Iterable<PremiumPlan> plans) async {
    if (!_isMobileStore) return;
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object _) {
        _fail('The store connection was interrupted. Please try again.');
      },
    );
    if (!await _iap.isAvailable()) return;
    final ids = plans.map(productIdFor).toSet();
    if (ids.isEmpty) {
      ids.addAll(
        _isAndroidStore
            ? {googleProductId}
            : {monthlyProductId, yearlyProductId},
      );
    }
    final response = await _iap.queryProductDetails(ids);
    for (final product in response.productDetails) {
      final offers = _catalog.putIfAbsent(product.id, () => []);
      if (offers.every((existing) => !_sameOffer(existing, product))) {
        offers.add(product);
      }
    }
    await _noteIntroEligibility(plans);
  }

  Future<void> _noteIntroEligibility(Iterable<PremiumPlan> plans) async {
    if (kIsWeb) return;
    final targets =
        plans.isEmpty
            ? const <PremiumPlan>[
              PremiumPlan(
                id: '_monthly',
                slug: 'plus-monthly',
                name: 'Monthly',
                interval: 'month',
                priceMinor: 0,
                currency: 'USD',
              ),
              PremiumPlan(
                id: '_yearly',
                slug: 'plus-yearly',
                name: 'Yearly',
                interval: 'year',
                priceMinor: 0,
                currency: 'USD',
              ),
            ]
            : plans.toList(growable: false);
    for (final plan in targets) {
      final key = _eligibilityKey(plan);
      final productId = productIdFor(plan);
      if (_isAndroidStore) {
        // Play only returns the free-trial offer when the account is eligible.
        _introEligible[key] = _catalogHasPlayTrialOffer(plan);
        continue;
      }
      if (!_catalogHasIntro(productId)) {
        _introEligible[key] = false;
        continue;
      }
      if (!Platform.isIOS) continue;
      try {
        _introEligible[key] = await SK2Product.isIntroductoryOfferEligible(
          productId,
        );
      } on Object {
        _introEligible[key] = false;
      }
    }
  }

  bool _catalogHasIntro(String productId) {
    for (final product in _catalog[productId] ?? const <ProductDetails>[]) {
      final quote = storefrontPriceFromProduct(product);
      if (quote == null) continue;
      if (quote.introductoryPriceIsFree ||
          (quote.introductoryPriceString?.isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  bool _catalogHasPlayTrialOffer(PremiumPlan plan) {
    final yearly = plusIntervalIsYearly(plan.interval);
    final preferred = PremiumTrialOffer.playOfferIdFor(yearly: yearly);
    final scoped = playOffersForInterval(
      _catalog[productIdFor(plan)] ?? const <ProductDetails>[],
      yearly: yearly,
      basePlanId: basePlanIdFor(plan),
    );
    for (final product in scoped) {
      if (product is! GooglePlayProductDetails) continue;
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (index == null ||
          offers == null ||
          index < 0 ||
          index >= offers.length) {
        continue;
      }
      final offer = offers[index];
      if (offer.offerId == preferred) {
        final phases = offer.pricingPhases;
        if (phases.isNotEmpty && phases.first.priceAmountMicros == 0) {
          return true;
        }
      }
      final quote = storefrontPriceFromProduct(product);
      if (quote?.introductoryPriceIsFree == true) return true;
    }
    return false;
  }

  ProductDetails? _productForPurchase(PremiumPlan plan) {
    final yearly = plusIntervalIsYearly(plan.interval);
    return storeProductForPlan(
      _catalog[productIdFor(plan)] ?? const <ProductDetails>[],
      trialPlan: plan.isIntroTrial,
      android: _isAndroidStore,
      yearly: _isAndroidStore ? yearly : null,
      basePlanId: basePlanIdFor(plan),
      preferredPlayOfferId: PremiumTrialOffer.playOfferIdFor(yearly: yearly),
    );
  }

  bool _sameOffer(ProductDetails left, ProductDetails right) {
    if (left is GooglePlayProductDetails && right is GooglePlayProductDetails) {
      return left.id == right.id &&
          left.subscriptionIndex == right.subscriptionIndex;
    }
    return left.id == right.id;
  }

  PurchaseParam _purchaseParam(ProductDetails product, String? accountId) {
    if (!kIsWeb && Platform.isAndroid && product is GooglePlayProductDetails) {
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      final token =
          index != null && offers != null && index >= 0 && index < offers.length
              ? offers[index].offerIdToken
              : null;
      return GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: token,
        applicationUserName: accountId,
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppStorePurchaseParam(
        productDetails: product,
        applicationUserName: accountId,
      );
    }
    return PurchaseParam(
      productDetails: product,
      applicationUserName: accountId,
    );
  }

  Future<PremiumPurchaseResult> buy(
    PremiumPlan plan, {
    String? accountId,
  }) async {
    if (_pending != null && !_pending!.isCompleted) {
      throw PremiumStoreException('A Plus purchase is already in progress.');
    }
    if (!_isMobileStore) {
      throw PremiumStoreException(
        'Pelevo Plus is purchased through Google Play or the App Store.',
      );
    }
    await prepare([plan]);
    final product = _productForPurchase(plan);
    if (product == null) {
      throw PremiumStoreException(
        'Pelevo Plus is not available in the store for this account yet.',
      );
    }
    _pending = Completer<PremiumPurchaseResult>();
    final started = await _iap.buyNonConsumable(
      purchaseParam: _purchaseParam(product, storeAccountToken(accountId)),
    );
    if (!started) {
      _pending = null;
      throw PremiumStoreException('The store could not start this purchase.');
    }
    return _pending!.future;
  }

  /// Restores Pelevo Plus from Google Play or the App Store, the same billing
  /// path used to subscribe. Returns each restored Plus receipt.
  Future<List<PremiumPurchaseResult>> restore({String? accountId}) async {
    if (!_isMobileStore) {
      throw PremiumStoreException(
        'Pelevo Plus is restored through Google Play or the App Store.',
      );
    }
    if (_restorePending != null && !_restorePending!.isCompleted) {
      throw PremiumStoreException('A Plus restore is already in progress.');
    }
    await prepare(const []);
    if (!await _iap.isAvailable()) {
      throw PremiumStoreException(
        'The store is unavailable. Sign in to Google Play or the App Store and try again.',
      );
    }
    _restoreBuffer.clear();
    _restoreStarted = DateTime.now();
    final pending = Completer<List<PremiumPurchaseResult>>();
    _restorePending = pending;
    try {
      await _iap.restorePurchases(
        applicationUserName: storeAccountToken(accountId),
      );
    } catch (_) {
      _failRestore('The store could not restore purchases. Please try again.');
      return pending.future;
    }
    _scheduleRestoreSettle();
    return pending.future;
  }

  void _scheduleRestoreSettle() {
    _restoreSettle?.cancel();
    final started = _restoreStarted ?? DateTime.now();
    final remaining =
        const Duration(seconds: 12) - DateTime.now().difference(started);
    if (remaining <= Duration.zero) {
      _finishRestore();
      return;
    }
    const quiet = Duration(milliseconds: 1200);
    _restoreSettle = Timer(
      quiet < remaining ? quiet : remaining,
      _finishRestore,
    );
  }

  void _finishRestore() {
    _restoreSettle?.cancel();
    _restoreSettle = null;
    final pending = _restorePending;
    _restorePending = null;
    _restoreStarted = null;
    final results = List<PremiumPurchaseResult>.unmodifiable(_restoreBuffer);
    _restoreBuffer.clear();
    if (pending != null && !pending.isCompleted) {
      pending.complete(results);
    }
  }

  void _failRestore(String message) {
    _restoreSettle?.cancel();
    _restoreSettle = null;
    final pending = _restorePending;
    _restorePending = null;
    _restoreStarted = null;
    _restoreBuffer.clear();
    if (pending != null && !pending.isCompleted) {
      pending.completeError(PremiumStoreException(message));
    }
  }

  void _collectRestored(PurchaseDetails purchase, String reference) {
    if (_restorePending == null || reference.isEmpty) return;
    final already = _restoreBuffer.any(
      (item) =>
          item.productId == purchase.productID && item.reference == reference,
    );
    if (!already) {
      _restoreBuffer.add(
        PremiumPurchaseResult(
          productId: purchase.productID,
          reference: reference,
        ),
      );
    }
    _scheduleRestoreSettle();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!isPlusStoreProduct(purchase.productID)) {
        continue;
      }
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.canceled) {
        _fail('Purchase cancelled');
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _fail(purchase.error?.message ?? 'The purchase could not complete.');
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      final receipt = purchase.verificationData.serverVerificationData.trim();
      final reference =
          receipt.isNotEmpty ? receipt : (purchase.purchaseID ?? '');
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
      _collectRestored(purchase, reference);
      final pending = _pending;
      _pending = null;
      if (pending != null && !pending.isCompleted && reference.isNotEmpty) {
        pending.complete(
          PremiumPurchaseResult(
            productId: purchase.productID,
            reference: reference,
          ),
        );
      }
    }
  }

  void _fail(String message) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(PremiumStoreException(message));
    }
  }
}

/// Matches a restored Play / App Store product to the Plus plan that uses
/// that billing period. A priced plan is preferred over the introductory trial
/// when both share the same store product.
///
/// Google Play uses one product ([PremiumStore.googleProductId]); pass
/// [basePlanId] (`monthly` / `yearly`) when known. Without it, any priced Plus
/// plan is returned so restore can still confirm the receipt.
PremiumPlan? planForPlusProduct(
  Iterable<PremiumPlan> plans,
  String productId, {
  String? basePlanId,
}) {
  final yearly = switch (productId) {
    PremiumStore.yearlyProductId => true,
    PremiumStore.monthlyProductId => false,
    PremiumStore.googleProductId => _yearlyFromPlayBasePlan(basePlanId),
    _ => null,
  };
  if (yearly == null && productId != PremiumStore.googleProductId) {
    return null;
  }
  PremiumPlan? trial;
  PremiumPlan? anyPriced;
  for (final plan in plans) {
    if (yearly != null && plusIntervalIsYearly(plan.interval) != yearly) {
      continue;
    }
    if (plan.isIntroTrial) {
      trial ??= plan;
      continue;
    }
    if (yearly != null) return plan;
    anyPriced ??= plan;
  }
  return yearly != null ? trial : (anyPriced ?? trial);
}

bool? _yearlyFromPlayBasePlan(String? basePlanId) {
  final id = basePlanId?.trim().toLowerCase() ?? '';
  if (id.isEmpty) return null;
  if (id == PremiumStore.yearlyBasePlanId ||
      id.contains('year') ||
      id.contains('annual')) {
    return true;
  }
  if (id == PremiumStore.monthlyBasePlanId || id.contains('month')) {
    return false;
  }
  return null;
}

const plusPlayPackageName = 'com.Podemeraldltd.pelevo';

/// Store page where the member turns auto-renew off. Access stays on until
/// the paid period ends; the store webhook is what changes the entitlement.
Uri? plusStoreSubscriptionUri({required String provider, String? productId}) {
  if (provider == 'apple') {
    return Uri.parse('https://apps.apple.com/account/subscriptions');
  }
  if (provider != 'google') return null;
  final params = <String, String>{'package': plusPlayPackageName};
  final sku = switch (productId) {
    PremiumStore.googleProductId ||
    PremiumStore.monthlyProductId ||
    PremiumStore.yearlyProductId =>
      PremiumStore.googleProductId,
    _ => null,
  };
  if (sku != null) params['sku'] = sku;
  return Uri.https('play.google.com', '/store/account/subscriptions', params);
}

/// Apple's app account token is a UUID. Google accepts the same id as the
/// obfuscated external account id. Anything else is omitted so a purchase
/// still starts; the signed-in store-purchase call attaches the row.
String? storeAccountToken(String? userId) {
  final value = userId?.trim().toLowerCase() ?? '';
  const uuid =
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  if (!RegExp(uuid).hasMatch(value)) return null;
  return value;
}

/// Loads Play / App Store products for the paywall. Access still comes from
/// `GET /premium/me`, which the API updates from store webhooks.
final premiumStoreCatalogProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final plans = ref.watch(premiumPlansProvider).asData?.value;
  if (plans == null || PremiumStore.instance.hasDebugQuotes) return;
  try {
    await PremiumStore.instance.prepare(plans);
  } on Object {
    // A store outage leaves the paywall on the unlabeled price.
  }
});

class PremiumStoreException implements Exception {
  PremiumStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
