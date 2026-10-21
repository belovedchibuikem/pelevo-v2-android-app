import 'dart:math';

import 'package:pelevo/server/plus_subscriptions/money.dart';
import 'package:pelevo/server/plus_subscriptions/notice.dart';

class SubscriptionRecord {
  SubscriptionRecord({
    required this.subscriptionId,
    required this.userId,
    required this.platform,
    required this.originalTransactionId,
    required this.productId,
    required this.planId,
    required this.status,
    required this.billingCountryCode,
    required this.billingCurrency,
    required this.amountMinor,
    required this.expiryDate,
    required this.gracePeriodEndsAt,
    required this.cancelAt,
    required this.introOffer,
    required this.periodStart,
    required this.updatedAt,
  });

  final String subscriptionId;
  String? userId;
  final StorePlatform platform;
  final String originalTransactionId;
  String productId;
  String planId;
  SubscriptionStatus status;
  String billingCountryCode;
  String billingCurrency;
  int amountMinor;
  DateTime expiryDate;
  DateTime? gracePeriodEndsAt;
  DateTime? cancelAt;
  bool introOffer;
  DateTime periodStart;
  DateTime updatedAt;

  bool get grantsPlus => status.grantsPlus;
}

class SubscriptionTransactionRecord {
  const SubscriptionTransactionRecord({
    required this.transactionId,
    required this.subscriptionId,
    required this.platform,
    required this.storeEventId,
    required this.eventType,
    required this.productId,
    required this.billingCountryCode,
    required this.billingCurrency,
    required this.amountMinor,
    required this.introOffer,
    required this.periodStart,
    required this.periodEnd,
    required this.raw,
  });

  final String transactionId;
  final String subscriptionId;
  final StorePlatform platform;
  final String storeEventId;
  final SubscriptionEventType eventType;
  final String productId;
  final String billingCountryCode;
  final String billingCurrency;
  final int amountMinor;
  final bool introOffer;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, Object?> raw;
}

class EntitlementRecord {
  EntitlementRecord({
    required this.userId,
    required this.state,
    required this.planId,
    required this.startsAt,
    required this.endsAt,
    required this.updatedAt,
  });

  final String userId;
  SubscriptionStatus state;
  String planId;
  final DateTime startsAt;
  DateTime? endsAt;
  DateTime updatedAt;
}

class ApplyResult {
  const ApplyResult({required this.duplicate, required this.changed});

  final bool duplicate;
  final bool changed;

  int get statusCode => 200;
}

/// Applies verified Plus notifications.
///
/// A SQL host wraps [apply] in one database transaction and is the only writer
/// of `user_subscriptions`, `subscription_transactions`, and
/// `premium_entitlements`. The phone reads the projection from `GET /premium/me`.
class SubscriptionLedger {
  SubscriptionLedger({DateTime Function()? clock, String Function()? ids})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _ids = ids ?? _uuidV4;

  static const graceWindow = Duration(days: 7);

  final DateTime Function() _clock;
  final String Function() _ids;
  final Map<String, SubscriptionRecord> _subscriptions = {};
  final Map<String, EntitlementRecord> _entitlements = {};
  final List<SubscriptionTransactionRecord> _transactions = [];
  final Set<String> _inbox = {};

  List<SubscriptionTransactionRecord> transactionsFor(String subscriptionId) =>
      _transactions
          .where((row) => row.subscriptionId == subscriptionId)
          .toList(growable: false);

  SubscriptionRecord? subscription({
    required StorePlatform platform,
    required String originalTransactionId,
  }) => _subscriptions['${platform.name}|$originalTransactionId'];

  EntitlementRecord? entitlementFor(String userId) => _entitlements[userId];

  ApplyResult apply(StoreNotice notice, {String? planIdHint}) {
    requireCountryCode(notice.billingCountryCode);
    requireCurrency(notice.billingCurrency);
    if (notice.amountMinor < 0) {
      throw SubscriptionNoticeRejected('A store charge cannot be negative.');
    }
    if (!notice.periodEnd.isAfter(notice.periodStart)) {
      throw SubscriptionNoticeRejected(
        'The store period end must be after the period start.',
      );
    }
    if (_inbox.contains(notice.eventKey)) {
      return const ApplyResult(duplicate: true, changed: false);
    }
    if (!isPlusProduct(notice.productId)) {
      _inbox.add(notice.eventKey);
      return const ApplyResult(duplicate: false, changed: false);
    }
    final hint = planIdHint?.trim();
    final effective =
        hint == null || hint.isEmpty
            ? notice
            : StoreNotice(
              platform: notice.platform,
              storeEventId: notice.storeEventId,
              type: notice.type,
              originalTransactionId: notice.originalTransactionId,
              productId: notice.productId,
              billingCountryCode: notice.billingCountryCode,
              billingCurrency: notice.billingCurrency,
              amountMinor: notice.amountMinor,
              introOffer: notice.introOffer,
              periodStart: notice.periodStart,
              periodEnd: notice.periodEnd,
              accountId: notice.accountId,
              gracePeriodEndsAt: notice.gracePeriodEndsAt,
              revoked: notice.revoked,
              planIdHint: hint,
              raw: notice.raw,
            );
    final changed = switch (effective.type) {
      SubscriptionEventType.initialPurchase => _initial(effective),
      SubscriptionEventType.renewal => _renew(effective),
      SubscriptionEventType.didFailToRenew => _grace(effective),
      SubscriptionEventType.cancellation => _cancel(effective),
      SubscriptionEventType.expiration => _expire(effective),
      SubscriptionEventType.autoRenewEnabled => _enableRenewal(effective),
    };
    _inbox.add(notice.eventKey);
    return ApplyResult(duplicate: false, changed: changed);
  }

  /// Same writer as a webhook, used so the first unlock does not wait.
  /// The verified product id wins over [planIdHint].
  ApplyResult confirmVerifiedPurchase({
    required StoreNotice notice,
    required String signedInUserId,
    String? planIdHint,
  }) {
    if (notice.type != SubscriptionEventType.initialPurchase) {
      throw SubscriptionNoticeRejected(
        'A store purchase confirmation must be the initial purchase.',
      );
    }
    final userId = plusAccountId(signedInUserId);
    if (userId == null) {
      throw SubscriptionNoticeRejected('The signed-in user id is not a UUID.');
    }
    if (notice.accountId != null && notice.accountId != userId) {
      throw SubscriptionNoticeRejected(
        'This subscription is already linked to another account.',
      );
    }
    final result = apply(notice, planIdHint: planIdHint);
    final linked =
        subscription(
          platform: notice.platform,
          originalTransactionId: notice.originalTransactionId,
        )?.userId;
    attachSignedInUser(
      platform: notice.platform,
      originalTransactionId: notice.originalTransactionId,
      userId: userId,
    );
    return ApplyResult(
      duplicate: result.duplicate,
      changed: result.changed || linked != userId,
    );
  }

  void attachSignedInUser({
    required StorePlatform platform,
    required String originalTransactionId,
    required String userId,
  }) {
    final accountId = plusAccountId(userId);
    if (accountId == null) {
      throw SubscriptionNoticeRejected('The signed-in user id is not a UUID.');
    }
    final row = subscription(
      platform: platform,
      originalTransactionId: originalTransactionId,
    );
    if (row == null) {
      throw SubscriptionNoticeRejected(
        'No verified subscription matches this receipt.',
      );
    }
    if (row.userId != null && row.userId != accountId) {
      throw SubscriptionNoticeRejected(
        'This subscription is already linked to another account.',
      );
    }
    if (row.userId == accountId) {
      _project(accountId);
      return;
    }
    row.userId = accountId;
    row.updatedAt = _clock().toUtc();
    _project(accountId);
  }

  Map<String, Object?> premiumMe(String userId) {
    final entitlement = _entitlements[userId];
    final winning = _winning(userId);
    return {
      'entitlement':
          entitlement == null
              ? null
              : {
                'state': entitlement.state.wire,
                'starts_at': entitlement.startsAt.toUtc().toIso8601String(),
                'ends_at': entitlement.endsAt?.toUtc().toIso8601String(),
                'plan_id': entitlement.planId,
              },
      'subscription':
          winning == null
              ? null
              : {
                'id': winning.subscriptionId,
                'state': winning.status.wire,
                'provider':
                    winning.platform == StorePlatform.iosAppStore
                        ? 'apple'
                        : 'google',
                'current_period_start':
                    winning.periodStart.toUtc().toIso8601String(),
                'current_period_end':
                    winning.expiryDate.toUtc().toIso8601String(),
                'plan_id': winning.planId,
                'cancel_at': winning.cancelAt?.toUtc().toIso8601String(),
              },
    };
  }

  bool _initial(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null) {
      _insert(notice, SubscriptionStatus.active, intro: notice.introOffer);
      return true;
    }
    final attached = _assignAccount(existing, notice.accountId);
    final replay = !notice.periodEnd.isAfter(existing.expiryDate);
    if (replay) {
      if (attached) _project(existing.userId);
      return attached;
    }
    _becomeActive(
      existing,
      notice,
      event: SubscriptionEventType.initialPurchase,
    );
    return true;
  }

  bool _renew(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null) {
      _insert(notice, SubscriptionStatus.active, intro: notice.introOffer);
      return true;
    }
    _becomeActive(existing, notice, event: SubscriptionEventType.renewal);
    return true;
  }

  bool _grace(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null || !existing.grantsPlus) return false;
    final paidEnd = existing.expiryDate;
    final storeGrace = notice.gracePeriodEndsAt?.toUtc();
    existing.status = SubscriptionStatus.inGracePeriod;
    existing.gracePeriodEndsAt = storeGrace ?? paidEnd.add(graceWindow);
    if (storeGrace != null && storeGrace.isAfter(paidEnd)) {
      existing.expiryDate = storeGrace;
    }
    existing.updatedAt = _clock().toUtc();
    _assignAccount(existing, notice.accountId);
    _append(existing, notice, SubscriptionEventType.didFailToRenew);
    _project(existing.userId);
    return true;
  }

  bool _cancel(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null || !existing.grantsPlus) return false;
    existing.cancelAt = existing.expiryDate;
    existing.updatedAt = _clock().toUtc();
    _assignAccount(existing, notice.accountId);
    _append(existing, notice, SubscriptionEventType.cancellation);
    _project(existing.userId);
    return true;
  }

  bool _expire(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null) return false;
    final next =
        notice.revoked || existing.cancelAt != null
            ? SubscriptionStatus.canceled
            : SubscriptionStatus.expired;
    if (existing.status == next &&
        existing.expiryDate == notice.periodEnd.toUtc()) {
      return false;
    }
    existing.status = next;
    existing.expiryDate = notice.periodEnd.toUtc();
    existing.gracePeriodEndsAt = null;
    existing.introOffer = false;
    existing.updatedAt = _clock().toUtc();
    _assignAccount(existing, notice.accountId);
    _append(existing, notice, SubscriptionEventType.expiration);
    _project(existing.userId);
    return true;
  }

  bool _enableRenewal(StoreNotice notice) {
    final existing = _existing(notice);
    if (existing == null || !existing.grantsPlus || existing.cancelAt == null) {
      return false;
    }
    existing.cancelAt = null;
    existing.updatedAt = _clock().toUtc();
    _project(existing.userId);
    return true;
  }

  void _insert(
    StoreNotice notice,
    SubscriptionStatus status, {
    required bool intro,
  }) {
    final now = _clock().toUtc();
    final row = SubscriptionRecord(
      subscriptionId: _ids(),
      userId: notice.accountId,
      platform: notice.platform,
      originalTransactionId: notice.originalTransactionId,
      productId: notice.productId,
      planId: _planId(notice, null),
      status: status,
      billingCountryCode: notice.billingCountryCode,
      billingCurrency: notice.billingCurrency,
      amountMinor: notice.amountMinor,
      expiryDate: notice.periodEnd.toUtc(),
      gracePeriodEndsAt: null,
      cancelAt: null,
      introOffer: intro,
      periodStart: notice.periodStart.toUtc(),
      updatedAt: now,
    );
    _subscriptions[notice.originKey] = row;
    _append(row, notice, notice.type);
    _project(row.userId);
  }

  void _becomeActive(
    SubscriptionRecord row,
    StoreNotice notice, {
    required SubscriptionEventType event,
  }) {
    row.productId = notice.productId;
    row.planId = _planId(notice, row);
    row.status = SubscriptionStatus.active;
    row.billingCountryCode = notice.billingCountryCode;
    row.billingCurrency = notice.billingCurrency;
    row.amountMinor = notice.amountMinor;
    row.expiryDate = notice.periodEnd.toUtc();
    row.periodStart = notice.periodStart.toUtc();
    row.gracePeriodEndsAt = null;
    row.cancelAt = null;
    row.introOffer = notice.introOffer;
    row.updatedAt = _clock().toUtc();
    _assignAccount(row, notice.accountId);
    _append(row, notice, event);
    _project(row.userId);
  }

  bool _assignAccount(SubscriptionRecord row, String? accountId) {
    if (accountId == null || row.userId == accountId) return false;
    if (row.userId != null) return false;
    row.userId = accountId;
    return true;
  }

  void _append(
    SubscriptionRecord row,
    StoreNotice notice,
    SubscriptionEventType event,
  ) {
    if (!event.recorded) return;
    _transactions.add(
      SubscriptionTransactionRecord(
        transactionId: _ids(),
        subscriptionId: row.subscriptionId,
        platform: notice.platform,
        storeEventId: notice.storeEventId,
        eventType: event,
        productId: notice.productId,
        billingCountryCode: notice.billingCountryCode,
        billingCurrency: notice.billingCurrency,
        amountMinor: notice.amountMinor,
        introOffer: notice.introOffer,
        periodStart: notice.periodStart.toUtc(),
        periodEnd: notice.periodEnd.toUtc(),
        raw: Map<String, Object?>.unmodifiable(notice.raw),
      ),
    );
  }

  String _planId(StoreNotice notice, SubscriptionRecord? existing) {
    final hint = notice.planIdHint?.trim();
    if (hint != null && hint.isNotEmpty) return hint;
    if (existing != null &&
        existing.productId == notice.productId &&
        existing.planId.isNotEmpty) {
      return existing.planId;
    }
    return notice.productId;
  }

  SubscriptionRecord? _existing(StoreNotice notice) =>
      _subscriptions[notice.originKey];

  void _project(String? userId) {
    if (userId == null) return;
    final winning = _winning(userId);
    if (winning == null) return;
    final ends =
        winning.status == SubscriptionStatus.inGracePeriod
            ? (winning.gracePeriodEndsAt ?? winning.expiryDate)
            : winning.expiryDate;
    final current = _entitlements[userId];
    if (current == null) {
      _entitlements[userId] = EntitlementRecord(
        userId: userId,
        state: winning.status,
        planId: winning.planId,
        startsAt: winning.periodStart,
        endsAt: ends,
        updatedAt: winning.updatedAt,
      );
      return;
    }
    current.state = winning.status;
    current.planId = winning.planId;
    current.endsAt = ends;
    current.updatedAt = winning.updatedAt;
  }

  SubscriptionRecord? _winning(String userId) {
    final rows = _subscriptions.values
        .where((row) => row.userId == userId)
        .toList(growable: false);
    if (rows.isEmpty) return null;
    final open = rows.where((row) => row.grantsPlus).toList(growable: false);
    if (open.isNotEmpty) {
      open.sort((a, b) {
        final byExpiry = b.expiryDate.compareTo(a.expiryDate);
        if (byExpiry != 0) return byExpiry;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return open.first;
    }
    final terminal = [...rows]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return terminal.first;
  }
}

final _random = Random.secure();

String _uuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
