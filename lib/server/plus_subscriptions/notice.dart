const plusMonthlyProductId = 'pelevo_plus_monthly';
const plusYearlyProductId = 'pelevo_plus_yearly';

bool isPlusProduct(String productId) =>
    productId == plusMonthlyProductId || productId == plusYearlyProductId;

enum StorePlatform { iosAppStore, googlePlayStore }

enum SubscriptionEventType {
  initialPurchase('INITIAL_PURCHASE'),
  renewal('RENEWAL'),
  didFailToRenew('DID_FAIL_TO_RENEW'),
  cancellation('CANCELLATION'),
  expiration('EXPIRATION'),
  autoRenewEnabled('AUTO_RENEW_ENABLED');

  const SubscriptionEventType(this.wire);

  final String wire;

  bool get recorded => this != SubscriptionEventType.autoRenewEnabled;
}

enum SubscriptionStatus {
  active('active'),
  inGracePeriod('in_grace_period'),
  expired('expired'),
  canceled('canceled');

  const SubscriptionStatus(this.wire);

  final String wire;

  bool get grantsPlus =>
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.inGracePeriod;
}

/// A store notification after signature checks and store API lookups.
///
/// [billingCountryCode] comes from the storefront on this charge. It is never
/// the listener profile country and never an IP geolocation.
class StoreNotice {
  const StoreNotice({
    required this.platform,
    required this.storeEventId,
    required this.type,
    required this.originalTransactionId,
    required this.productId,
    required this.billingCountryCode,
    required this.billingCurrency,
    required this.amountMinor,
    required this.introOffer,
    required this.periodStart,
    required this.periodEnd,
    this.accountId,
    this.gracePeriodEndsAt,
    this.revoked = false,
    this.planIdHint,
    this.raw = const {},
  });

  final StorePlatform platform;
  final String storeEventId;
  final SubscriptionEventType type;
  final String originalTransactionId;
  final String productId;
  final String billingCountryCode;
  final String billingCurrency;
  final int amountMinor;
  final bool introOffer;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? accountId;
  final DateTime? gracePeriodEndsAt;
  final bool revoked;
  final String? planIdHint;
  final Map<String, Object?> raw;

  String get originKey => '${platform.name}|$originalTransactionId';

  String get eventKey => '${platform.name}|$storeEventId';
}

const _accountUuid =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

/// Apple app account token and Google obfuscated account id. Null when absent.
String? plusAccountId(String? value) {
  final id = value?.trim().toLowerCase() ?? '';
  if (id.isEmpty) return null;
  if (!RegExp(_accountUuid).hasMatch(id)) return null;
  return id;
}
