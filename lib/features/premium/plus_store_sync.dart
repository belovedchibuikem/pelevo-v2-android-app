import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/premium/premium_store.dart';

/// Confirms Play / App Store Plus receipts with the API and keeps the
/// purchase listener attached for the life of the app.
class PlusStoreSync {
  PlusStoreSync(this._ref);

  final Ref _ref;
  Future<void>? _inFlight;

  void bind() {
    PremiumStore.instance.onDelivered = _deliver;
    PremiumStore.instance.listenForPurchases();
  }

  void unbind() {
    if (PremiumStore.instance.onDelivered == _deliver) {
      PremiumStore.instance.onDelivered = null;
    }
  }

  /// Queries subscriptions the store still treats as active.
  Future<void> sync({String? accountId}) {
    final current = _inFlight;
    if (current != null) return current;
    final run = _run(accountId);
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<void> _run(String? accountId) async {
    if (_ref.read(catalogPreviewProvider)) return;
    final session = _ref.read(authSessionProvider);
    if (!session.authenticated) return;
    try {
      await PremiumStore.instance.checkActiveSubscription(
        accountId: accountId ?? session.userId,
      );
    } on Object catch (error) {
      debugPrint('Pelevo Plus subscription check failed: $error');
    }
  }

  Future<void> _deliver(PremiumPurchaseResult purchase) async {
    final token = CancelToken();
    final plans = await _ref.read(premiumRepositoryProvider).plans(token);
    final plan = _planFor(plans, purchase);
    if (plan == null) {
      throw PremiumStoreException(
        'The store purchase could not be matched to a Pelevo Plus plan.',
      );
    }
    try {
      final account = await _ref
          .read(premiumRepositoryProvider)
          .confirmStorePurchase(
            store: PremiumStore.instance.storeProvider,
            receipt: purchase.reference,
            planId: plan.id,
          );
      _ref.read(premiumAccountSeedProvider.notifier).remember(account);
      _ref.invalidate(premiumAccountProvider);
      _ref.invalidate(premiumInvoicesProvider);
    } on ApiFailure catch (error) {
      throw PremiumStoreException(error.message);
    }
  }

  PremiumPlan? _planFor(
    List<PremiumPlan> plans,
    PremiumPurchaseResult purchase,
  ) {
    final hinted = purchase.planId;
    if (hinted != null) {
      for (final plan in plans) {
        if (plan.id == hinted) return plan;
      }
    }
    return planForPlusProduct(plans, purchase.productId);
  }
}

final plusStoreSyncProvider = Provider<PlusStoreSync>((ref) {
  final sync = PlusStoreSync(ref);
  sync.bind();
  ref.onDispose(sync.unbind);
  return sync;
});
