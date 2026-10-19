import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pelevo/features/store/fx_rates.dart';
import 'package:pelevo/features/store/regional_prices.dart';
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
  const CoinPack({
    required this.productId,
    required this.coins,
    required this.fallbackPrice,
    this.badge,
  });

  final String productId;
  final int coins;
  final String fallbackPrice;
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
  static const coinPacks = [
    CoinPack(productId: 'pelevo_coins_500', coins: 500, fallbackPrice: r'$0.49'),
    CoinPack(
      productId: 'pelevo_coins_1200',
      coins: 1200,
      fallbackPrice: r'$1.19',
      badge: 'Popular',
    ),
    CoinPack(
      productId: 'pelevo_coins_2500',
      coins: 2500,
      fallbackPrice: r'$2.48',
      badge: 'Best value',
    ),
    CoinPack(
      productId: 'pelevo_coins_6500',
      coins: 6500,
      fallbackPrice: r'$6.44',
    ),
    CoinPack(
      productId: 'pelevo_coins_15000',
      coins: 15000,
      fallbackPrice: r'$14.85',
    ),
  ];

  static const gifts = [
    GiftOption(icon: Icons.back_hand_rounded, name: 'Applause', coins: 100),
    GiftOption(icon: Icons.favorite_rounded, name: 'Love', coins: 500),
    GiftOption(icon: Icons.star_rounded, name: 'Star', coins: 1000),
    GiftOption(icon: Icons.emoji_events_rounded, name: 'Champion', coins: 5000),
  ];

  final _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _storeProducts = {};
  final List<GiftLedgerEntry> _ledger = [];

  SharedPreferences? _preferences;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  GiftPurchaseVerifier? _verifier;
  Completer<GiftPurchaseStage>? _purchaseCompleter;

  int _balance = 1250;
  GiftPurchaseStage _purchaseStage = GiftPurchaseStage.idle;
  String? _purchaseError;
  CoinPack? _lastPurchasedPack;
  GiftOption? _lastGift;
  String? _lastCreator;
  bool _sendingGift = false;
  bool _storeAvailable = false;

  int get balance => _balance;
  GiftPurchaseStage get purchaseStage => _purchaseStage;
  String? get purchaseError => _purchaseError;
  CoinPack? get lastPurchasedPack => _lastPurchasedPack;
  GiftOption? get lastGift => _lastGift;
  String? get lastCreator => _lastCreator;
  bool get sendingGift => _sendingGift;
  bool get storeAvailable => _storeAvailable || isDemoMode;
  List<GiftLedgerEntry> get ledger => List.unmodifiable(_ledger);

  bool get _isMobileStore => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    _verifier = verifier;
    _balance = preferences.getInt(_balanceKey) ?? 1250;
    if (!_isMobileStore) {
      _storeAvailable = true;
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

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      notifyListeners();
      return;
    }

    final response = await _iap.queryProductDetails(
      coinPacks.map((pack) => pack.productId).toSet(),
    );
    for (final product in response.productDetails) {
      _storeProducts[product.id] = product;
    }
    notifyListeners();
  }

  void configureVerifier(GiftPurchaseVerifier verifier) {
    _verifier = verifier;
  }

  String localizedPrice(CoinPack pack) =>
      _storeProducts[pack.productId]?.price ?? pack.fallbackPrice;

  String? storePrice(String productId) => _storeProducts[productId]?.price;

  /// Store listing for this country when Play or the App Store has one.
  /// Otherwise the USD shelf converted with the current FX book.
  String priceFor({
    required String productId,
    required int coins,
    required String countryCode,
    FxRateBook? rates,
  }) {
    final listed = _storeProducts[productId]?.price;
    if (listed != null && listed.isNotEmpty) return listed;
    return coinPriceLabel(coins: coins, countryCode: countryCode, rates: rates);
  }

  Future<void> ensureProducts(Iterable<String> productIds) async {
    if (!_isMobileStore || !_storeAvailable) return;
    final missing =
        productIds
            .where((id) => id.isNotEmpty && !_storeProducts.containsKey(id))
            .toSet();
    if (missing.isEmpty) return;
    final response = await _iap.queryProductDetails(missing);
    for (final product in response.productDetails) {
      _storeProducts[product.id] = product;
    }
    if (response.productDetails.isNotEmpty) notifyListeners();
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
      final valid = await _verifier!(purchase);
      if (!valid) {
        _finishPurchase(
          GiftPurchaseStage.failed,
          error: 'We could not securely verify this purchase.',
        );
        continue;
      }

      final pack =
          coinPacks
              .where((item) => item.productId == purchase.productID)
              .firstOrNull;
      if (pack == null) {
        _finishPurchase(
          GiftPurchaseStage.failed,
          error: 'The purchased product is not recognized.',
        );
        continue;
      }

      _creditPurchasedCoins(pack);
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
