import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/store/fx_rates.dart';
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
class PremiumStore {
  PremiumStore._();

  static final instance = PremiumStore._();

  static const monthlyProductId = 'pelevo_plus_monthly';
  static const yearlyProductId = 'pelevo_plus_yearly';

  final _iap = InAppPurchase.instance;
  final Map<String, List<ProductDetails>> _catalog = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<PremiumPurchaseResult>? _pending;
  Completer<List<PremiumPurchaseResult>>? _restorePending;
  final List<PremiumPurchaseResult> _restoreBuffer = [];
  Timer? _restoreSettle;
  DateTime? _restoreStarted;

  bool get _isMobileStore => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get storeProvider => !kIsWeb && Platform.isIOS ? 'apple' : 'google';

  String productIdFor(PremiumPlan plan) =>
      plusIntervalIsYearly(plan.interval) ? yearlyProductId : monthlyProductId;

  String priceLabel(
    PremiumPlan plan,
    String countryCode, {
    FxRateBook? rates,
  }) {
    final listed = _pricedProduct(productIdFor(plan))?.price;
    if (listed != null && listed.isNotEmpty) return listed;
    return plusPriceLabel(
      countryCode: countryCode,
      yearly: plusIntervalIsYearly(plan.interval),
      rates: rates,
    );
  }

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
      ids.addAll({monthlyProductId, yearlyProductId});
    }
    final response = await _iap.queryProductDetails(ids);
    for (final product in response.productDetails) {
      final offers = _catalog.putIfAbsent(product.id, () => []);
      if (offers.every((existing) => !_sameOffer(existing, product))) {
        offers.add(product);
      }
    }
  }

  ProductDetails? _pricedProduct(String productId) {
    final offers = _catalog[productId] ?? const <ProductDetails>[];
    for (final offer in offers) {
      if (_isThreeMonthFreeOffer(offer)) continue;
      return offer;
    }
    return offers.isEmpty ? null : offers.first;
  }

  ProductDetails? _productForPurchase(PremiumPlan plan) {
    final offers = _catalog[productIdFor(plan)] ?? const <ProductDetails>[];
    if (plan.isThreeMonthTrial) {
      for (final offer in offers) {
        if (_isThreeMonthFreeOffer(offer)) return offer;
      }
      if (!kIsWeb && Platform.isAndroid) return null;
      return offers.isEmpty ? null : offers.first;
    }
    return _pricedProduct(productIdFor(plan));
  }

  bool _sameOffer(ProductDetails left, ProductDetails right) {
    if (left is GooglePlayProductDetails && right is GooglePlayProductDetails) {
      return left.id == right.id &&
          left.subscriptionIndex == right.subscriptionIndex;
    }
    return left.id == right.id;
  }

  bool _isThreeMonthFreeOffer(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return false;
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null ||
        offers == null ||
        index < 0 ||
        index >= offers.length) {
      return false;
    }
    final phases = offers[index].pricingPhases;
    if (phases.isEmpty || phases.first.priceAmountMicros != 0) return false;
    return phases.first.billingPeriod == 'P3M';
  }

  PurchaseParam _purchaseParam(ProductDetails product) {
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
      );
    }
    return PurchaseParam(productDetails: product);
  }

  Future<PremiumPurchaseResult> buy(PremiumPlan plan) async {
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
        plan.isThreeMonthTrial
            ? 'The 3-month trial is not available in the store for this account yet.'
            : 'Pelevo Plus is not available in the store for this account yet.',
      );
    }
    _pending = Completer<PremiumPurchaseResult>();
    final started = await _iap.buyNonConsumable(
      purchaseParam: _purchaseParam(product),
    );
    if (!started) {
      _pending = null;
      throw PremiumStoreException('The store could not start this purchase.');
    }
    return _pending!.future;
  }

  /// Restores Pelevo Plus from Google Play or the App Store, the same billing
  /// path used to subscribe. Returns each restored Plus receipt.
  Future<List<PremiumPurchaseResult>> restore() async {
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
      await _iap.restorePurchases();
    } catch (_) {
      _failRestore(
        'The store could not restore purchases. Please try again.',
      );
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
      if (purchase.productID != monthlyProductId &&
          purchase.productID != yearlyProductId) {
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
PremiumPlan? planForPlusProduct(Iterable<PremiumPlan> plans, String productId) {
  final yearly = switch (productId) {
    PremiumStore.yearlyProductId => true,
    PremiumStore.monthlyProductId => false,
    _ => null,
  };
  if (yearly == null) return null;
  PremiumPlan? trial;
  for (final plan in plans) {
    if (plusIntervalIsYearly(plan.interval) != yearly) continue;
    if (plan.isThreeMonthTrial) {
      trial ??= plan;
      continue;
    }
    return plan;
  }
  return trial;
}

class PremiumStoreException implements Exception {
  PremiumStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
