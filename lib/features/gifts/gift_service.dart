import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pelevo/features/premium/storefront_price.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GiftPurchaseStage {
  idle,
  purchasing,
  pending,
  verifying,
  success,
  cancelled,
  failed,
}

class CoinPack {
  const CoinPack({required this.productId, required this.coins, this.badge});

  final String productId;
  final int coins;
  final String? badge;
}

class GiftOption {
  const GiftOption({
    required this.icon,
    required this.name,
    required this.coins,
  });

  final IconData icon;
  final String name;
  final int coins;
}

class GiftLedgerEntry {
  const GiftLedgerEntry({
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.createdAt,
    required this.isCredit,
  });

  final String title;
  final String subtitle;
  final int coins;
  final DateTime createdAt;
  final bool isCredit;
}

typedef GiftPurchaseVerifier =
    Future<bool> Function(PurchaseDetails purchaseDetails);

class GiftWalletService extends ChangeNotifier {
  GiftWalletService._();

  static final instance = GiftWalletService._();

  static const _balanceKey = 'pelevo_coin_balance';
  /// Must match Google Play / App Store SKUs and `coin_products.product_id`.
  static const coinPacks = [
    CoinPack(productId: 'coins_300', coins: 300),
    CoinPack(productId: 'coins_500', coins: 500, badge: 'Popular'),
    CoinPack(productId: 'coins_750', coins: 750),
    CoinPack(productId: 'coins_1000', coins: 1000, badge: 'Best value'),
    CoinPack(productId: 'coins_1500', coins: 1500),
    CoinPack(productId: 'coins_2000', coins: 2000),
  ];

  /// Fallback catalog; live UI prefers `GET /gifts/catalog`.
  static const gifts = [
    GiftOption(icon: Icons.back_hand_rounded, name: 'Applause', coins: 300),
    GiftOption(icon: Icons.favorite_rounded, name: 'Love', coins: 500),
    GiftOption(icon: Icons.star_rounded, name: 'Star', coins: 750),
    GiftOption(icon: Icons.emoji_events_rounded, name: 'Champion', coins: 1000),
    GiftOption(icon: Icons.workspace_premium_rounded, name: 'Crown', coins: 1500),
    GiftOption(icon: Icons.auto_awesome_rounded, name: 'Legend', coins: 2000),
  ];

  final _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _storeProducts = {};
  final List<GiftLedgerEntry> _ledger = [];

  SharedPreferences? _preferences;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  GiftPurchaseVerifier? _verifier;
  Completer<GiftPurchaseStage>? _purchaseCompleter;

  int _balance = 0;
  GiftPurchaseStage _purchaseStage = GiftPurchaseStage.idle;
  Map<String, StorefrontPrice>? _quoteOverride;
  String? _purchaseError;
  CoinPack? _lastPurchasedPack;
  GiftOption? _lastGift;
  String? _lastCreator;
  bool _sendingGift = false;
  bool _storeAvailable = false;
  bool _catalogQueried = false;
  final Set<String> _notFoundIds = {};
  String? _catalogError;

  int get balance => _balance;
  GiftPurchaseStage get purchaseStage => _purchaseStage;
  String? get purchaseError => _purchaseError;
  CoinPack? get lastPurchasedPack => _lastPurchasedPack;
  GiftOption? get lastGift => _lastGift;
  String? get lastCreator => _lastCreator;
  bool get sendingGift => _sendingGift;
  bool get storeAvailable => _storeAvailable || isDemoMode;
  bool get catalogQueried => _catalogQueried;
  bool get hasStorePrices => _storeProducts.isNotEmpty || _quoteOverride != null;
  Set<String> get notFoundProductIds => Set.unmodifiable(_notFoundIds);
  /// Human-readable reason when Play returned no coin prices.
  String? get catalogError => _catalogError;
  List<GiftLedgerEntry> get ledger => List.unmodifiable(_ledger);

  bool get _isMobileStore => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get storeProvider => !kIsWeb && Platform.isIOS ? 'apple' : 'google';

  /// Demo IAP credit is debug-only unless explicitly enabled.
  bool get isDemoMode =>
      !_isMobileStore &&
      (kDebugMode ||
          const bool.fromEnvironment(
            'PELEVO_ALLOW_DEMO_IAP',
            defaultValue: false,
          ));

  Future<void> initialize(
    SharedPreferences preferences, {
    GiftPurchaseVerifier? verifier,
  }) async {
    _preferences = preferences;
    if (verifier != null) _verifier = verifier;
    // Local cache is never a free grant — server wallet is authoritative.
    _balance = preferences.getInt(_balanceKey) ?? 0;
    if (!_isMobileStore) {
      _storeAvailable = true;
      notifyListeners();
      return;
    }

    _purchaseSubscription ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _finishPurchase(
          GiftPurchaseStage.failed,
          error: 'The store connection was interrupted. Please try again.',
        );
      },
    );
    notifyListeners();
    // Play Billing can hang on cold start — never await catalog from main().
    unawaited(warmStoreCatalog());
  }

  /// Loads the Play / App Store coin catalog without blocking app startup.
  Future<void> warmStoreCatalog() async {
    if (!_isMobileStore) return;
    try {
      _storeAvailable = await _iap.isAvailable().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (!_storeAvailable) {
        _catalogQueried = true;
        _catalogError =
            'Google Play Billing is not available on this install. Install from Play (internal testing) with a license-tester account.';
        notifyListeners();
        return;
      }
      await _queryStoreProducts(
        coinPacks.map((pack) => pack.productId).toSet(),
      );
    } on Object catch (error) {
      _catalogQueried = true;
      _catalogError = 'Coin catalog query failed: $error';
    }
    notifyListeners();
  }

  void configureVerifier(GiftPurchaseVerifier verifier) {
    _verifier = verifier;
  }

  /// Installs store quotes for tests. Production reads the native catalog.
  @visibleForTesting
  void debugInstallQuotes(Map<String, StorefrontPrice> quotes) {
    _quoteOverride = Map.unmodifiable(quotes);
    notifyListeners();
  }

  @visibleForTesting
  void debugClearQuotes() {
    _quoteOverride = null;
    notifyListeners();
  }

  /// Formatted price and currency from the signed-in store account.
  StorefrontPrice? quoteFor(String productId) {
    final override = _quoteOverride;
    if (override != null) return override[productId];
    final product = _storeProducts[productId];
    if (product == null) return null;
    return storefrontPriceFromProduct(product);
  }

  /// Store-formatted price. A missing catalog row stays unlabeled.
  String priceFor(String productId) =>
      subscriptionPriceLine(quoteFor(productId));

  Future<void> ensureProducts(Iterable<String> productIds) async {
    if (!_isMobileStore) {
      await warmStoreCatalog();
      return;
    }
    if (!_storeAvailable && _storeProducts.isEmpty) {
      await warmStoreCatalog();
    }
    if (!_storeAvailable) return;
    final wanted = {
      ...coinPacks.map((pack) => pack.productId),
      ...productIds.where((id) => id.isNotEmpty),
    };
    final missing =
        wanted.where((id) => !_storeProducts.containsKey(id)).toSet();
    if (missing.isEmpty) {
      _catalogQueried = true;
      notifyListeners();
      return;
    }
    try {
      await _queryStoreProducts(missing);
      notifyListeners();
    } on Object {
      _catalogQueried = true;
      notifyListeners();
    }
  }

  Future<void> _queryStoreProducts(Set<String> ids) async {
    if (ids.isEmpty) {
      _catalogQueried = true;
      return;
    }
    final response = await _iap
        .queryProductDetails(ids)
        .timeout(const Duration(seconds: 12));
    for (final product in response.productDetails) {
      _storeProducts[product.id] = product;
      _notFoundIds.remove(product.id);
    }
    _notFoundIds
      ..addAll(response.notFoundIDs)
      ..addAll(ids.where((id) => !_storeProducts.containsKey(id)));
    _catalogQueried = true;
    final queryError = response.error?.message.trim();
    if (_storeProducts.isEmpty) {
      final missing = _notFoundIds.isEmpty ? ids.join(', ') : _notFoundIds.join(', ');
      _catalogError =
          queryError?.isNotEmpty == true
              ? queryError
              : 'Play did not return prices for: $missing. In Play Console open each pack → purchase option "buy" → Advanced options → enable backwards compatible, then reinstall from Play.';
    } else {
      _catalogError = null;
    }
    debugPrint(
      'Pelevo coin catalog: found=${_storeProducts.keys.toList()} '
      'missing=${_notFoundIds.toList()} error=${queryError ?? 'none'}',
    );
  }

  Future<GiftPurchaseStage> purchase(CoinPack pack) async {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      return GiftPurchaseStage.pending;
    }

    _lastPurchasedPack = pack;
    _purchaseError = null;
    _setPurchaseStage(GiftPurchaseStage.purchasing);

    if (isDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      _setPurchaseStage(GiftPurchaseStage.verifying);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      _creditPurchasedCoins(pack);
      _setPurchaseStage(GiftPurchaseStage.success);
      return GiftPurchaseStage.success;
    }

    if (kReleaseMode && !_isMobileStore) {
      return _finishPurchase(
        GiftPurchaseStage.failed,
        error: 'In-app purchases require the App Store or Google Play.',
      );
    }
    if (!_storeAvailable) {
      return _finishPurchase(
        GiftPurchaseStage.failed,
        error: 'In-app purchases are currently unavailable.',
      );
    }
    if (_verifier == null) {
      return _finishPurchase(
        GiftPurchaseStage.failed,
        error: 'Secure purchase verification is not configured.',
      );
    }

    final product = _storeProducts[pack.productId];
    if (product == null) {
      return _finishPurchase(
        GiftPurchaseStage.failed,
        error: 'This coin pack is not available in your region.',
      );
    }

    _purchaseCompleter = Completer<GiftPurchaseStage>();
    final started = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
      autoConsume: true,
    );
    if (!started) {
      return _finishPurchase(
        GiftPurchaseStage.failed,
        error: 'The store could not start this purchase.',
      );
    }
    return _purchaseCompleter!.future;
  }

  Future<bool> sendGift({
    required GiftOption gift,
    required String creator,
    required String contentTitle,
  }) async {
    if (_sendingGift || _balance < gift.coins) return false;
    _sendingGift = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _balance -= gift.coins;
    _lastGift = gift;
    _lastCreator = creator;
    _ledger.insert(
      0,
      GiftLedgerEntry(
        title: '${gift.name} sent to $creator',
        subtitle: contentTitle,
        coins: gift.coins,
        createdAt: DateTime.now(),
        isCredit: false,
      ),
    );
    await _preferences?.setInt(_balanceKey, _balance);
    _sendingGift = false;
    notifyListeners();
    return true;
  }

  void resetPurchaseState() {
    _purchaseStage = GiftPurchaseStage.idle;
    _purchaseError = null;
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID.startsWith('pelevo_plus_')) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _setPurchaseStage(GiftPurchaseStage.pending);
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        _finishPurchase(GiftPurchaseStage.cancelled);
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _finishPurchase(
          GiftPurchaseStage.failed,
          error: purchase.error?.message ?? 'The purchase could not complete.',
        );
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      _setPurchaseStage(GiftPurchaseStage.verifying);
      final verifier = _verifier;
      if (verifier == null) {
        _finishPurchase(
          GiftPurchaseStage.failed,
          error: 'Secure purchase verification is not configured.',
        );
        continue;
      }
      try {
        final valid = await verifier(purchase);
        if (!valid) {
          _finishPurchase(
            GiftPurchaseStage.failed,
            error: 'We could not securely verify this purchase.',
          );
          continue;
        }
      } on Object catch (error) {
        final message = '$error'.trim();
        _finishPurchase(
          GiftPurchaseStage.failed,
          error:
              message.isEmpty
                  ? 'We could not securely verify this purchase.'
                  : message,
        );
        continue;
      }

      final pack =
          coinPacks
              .where((item) => item.productId == purchase.productID)
              .firstOrNull ??
          (_lastPurchasedPack?.productId == purchase.productID
              ? _lastPurchasedPack
              : null);
      if (pack != null) {
        _creditPurchasedCoins(pack);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      _finishPurchase(GiftPurchaseStage.success);
    }
  }

  void _creditPurchasedCoins(CoinPack pack) {
    _balance += pack.coins;
    _lastPurchasedPack = pack;
    _ledger.insert(
      0,
      GiftLedgerEntry(
        title: '${pack.coins} coins purchased',
        subtitle: 'Apple App Store / Google Play',
        coins: pack.coins,
        createdAt: DateTime.now(),
        isCredit: true,
      ),
    );
    _preferences?.setInt(_balanceKey, _balance);
  }

  void _setPurchaseStage(GiftPurchaseStage stage) {
    _purchaseStage = stage;
    notifyListeners();
  }

  GiftPurchaseStage _finishPurchase(GiftPurchaseStage stage, {String? error}) {
    _purchaseStage = stage;
    _purchaseError = error;
    notifyListeners();
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete(stage);
    }
    _purchaseCompleter = null;
    return stage;
  }
}
