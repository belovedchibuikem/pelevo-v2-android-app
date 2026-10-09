import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pelevo/features/premium/premium_data.dart';
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

  bool get _isMobileStore => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get storeProvider => !kIsWeb && Platform.isIOS ? 'apple' : 'google';

  String productIdFor(PremiumPlan plan) =>
      plusIntervalIsYearly(plan.interval) ? yearlyProductId : monthlyProductId;

  String priceLabel(PremiumPlan plan, String countryCode) =>
      _pricedProduct(productIdFor(plan))?.price ??
      seededPlusPrice(countryCode, yearly: plusIntervalIsYearly(plan.interval));

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

  Future<void> restore() => _iap.restorePurchases();

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

class PremiumStoreException implements Exception {
  PremiumStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
