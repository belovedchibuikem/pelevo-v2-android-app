import 'dart:convert';

import 'package:pelevo/server/plus_subscriptions/money.dart';
import 'package:pelevo/server/plus_subscriptions/notice.dart';

bool revenueCatAuthorized(String? header, String secret) {
  final presented = header?.trim() ?? '';
  final bearer =
      presented.toLowerCase().startsWith('bearer ')
          ? presented.substring(7).trim()
          : presented;
  return _fixedTimeEquals(bearer, secret);
}

bool _fixedTimeEquals(String left, String right) {
  final a = utf8.encode(left);
  final b = utf8.encode(right);
  var diff = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final l = i < a.length ? a[i] : 0;
    final r = i < b.length ? b[i] : 0;
    diff |= l ^ r;
  }
  return diff == 0;
}

/// Decoded App Store Server Notification V2. The JWS has already been verified.
StoreNotice? normalizeAppleNotification(Map<String, dynamic> notification) {
  final typeName = _text(notification, 'notificationType');
  final subtype = _optionalText(notification, 'subtype');
  final event = _appleEvent(typeName, subtype);
  if (event == null) return null;
  final eventId = _text(notification, 'notificationUUID');
  final data = _map(notification['data']);
  final transaction = _map(data?['transaction'] ?? data);
  if (transaction == null) {
    throw SubscriptionNoticeRejected('Apple notification has no transaction.');
  }
  final productId = _text(transaction, 'productId');
  final currency = requireCurrency(_optionalText(transaction, 'currency'));
  final intro = _appleIntro(transaction);
  final amount =
      intro && transaction['price'] == null
          ? 0
          : minorFromAppleMilliunits(_int(transaction['price']), currency);
  return _notice(
    platform: StorePlatform.iosAppStore,
    storeEventId: eventId,
    type: event.type,
    revoked: event.revoked,
    originalTransactionId: _text(transaction, 'originalTransactionId'),
    productId: productId,
    billingCountryCode: countryFromAppleStorefront(
      _optionalText(transaction, 'storefront'),
    ),
    billingCurrency: currency,
    amountMinor: amount,
    introOffer: intro,
    periodStart: _time(transaction['purchaseDate'], 'purchaseDate'),
    periodEnd: _time(transaction['expiresDate'], 'expiresDate'),
    accountId: _account(_optionalText(transaction, 'appAccountToken')),
    gracePeriodEndsAt: _optionalTime(transaction['gracePeriodExpiresDate']),
    raw: _raw(notification),
  );
}

class _AppleEvent {
  const _AppleEvent(this.type, {this.revoked = false});

  final SubscriptionEventType type;
  final bool revoked;
}

_AppleEvent? _appleEvent(String type, String? subtype) {
  switch (type) {
    case 'SUBSCRIBED':
    case 'OFFER_REDEEMED':
    case 'INITIAL_BUY':
      return const _AppleEvent(SubscriptionEventType.initialPurchase);
    case 'DID_RENEW':
      return const _AppleEvent(SubscriptionEventType.renewal);
    case 'DID_FAIL_TO_RENEW':
      return const _AppleEvent(SubscriptionEventType.didFailToRenew);
    case 'DID_CHANGE_RENEWAL_STATUS':
      if (subtype == 'AUTO_RENEW_DISABLED') {
        return const _AppleEvent(SubscriptionEventType.cancellation);
      }
      if (subtype == 'AUTO_RENEW_ENABLED') {
        return const _AppleEvent(SubscriptionEventType.autoRenewEnabled);
      }
      return null;
    case 'EXPIRED':
    case 'GRACE_PERIOD_EXPIRED':
      return const _AppleEvent(SubscriptionEventType.expiration);
    case 'REFUND':
    case 'REVOKE':
      return const _AppleEvent(SubscriptionEventType.expiration, revoked: true);
    default:
      return null;
  }
}

bool _appleIntro(Map<String, dynamic> transaction) {
  final discount = _optionalText(transaction, 'offerDiscountType');
  if (discount == 'FREE_TRIAL' || discount == 'PAY_UP_FRONT') return true;
  final offerType = transaction['offerType'];
  return offerType == 1 || offerType == 2 || offerType == 3;
}

/// Google RTDN plus the SubscriptionPurchaseV2 payload from the Play Developer API.
///
/// [originalPurchaseToken] is the first token in the linked chain when the
/// Play API lookup has resolved it. Otherwise the notification token is used.
StoreNotice? normalizeGoogleNotification({
  required Map<String, dynamic> developerNotification,
  required Map<String, dynamic> subscriptionPurchase,
  required String messageId,
  String? originalPurchaseToken,
}) {
  final subscription = _map(developerNotification['subscriptionNotification']);
  if (subscription == null) return null;
  final typeCode = _int(subscription['notificationType']);
  final event = _googleEvent(typeCode);
  if (event == null) return null;
  final token = _text(subscription, 'purchaseToken');
  final line = _firstMap(subscriptionPurchase['lineItems']);
  if (line == null) {
    throw SubscriptionNoticeRejected('Google subscription has no line item.');
  }
  final price = _map(_map(line['autoRenewingPlan'])?['recurringPrice']);
  final currency = requireCurrency(
    price == null ? null : _optionalText(price, 'currencyCode'),
  );
  final offerDetails = _map(line['offerDetails']);
  final intro = offerDetails != null;
  final amount =
      price == null
          ? 0
          : minorFromUnitsAndNanos(
            units: int.parse(_text(price, 'units')),
            nanos: price['nanos'] == null ? 0 : _int(price['nanos']),
            currency: currency,
          );
  final external = _map(subscriptionPurchase['externalAccountIdentifiers']);
  final rawProductId =
      _optionalText(line, 'productId') ??
      _text(subscription, 'subscriptionId');
  return _notice(
    platform: StorePlatform.googlePlayStore,
    storeEventId: messageId,
    type: event.type,
    revoked: event.revoked,
    originalTransactionId:
        originalPurchaseToken?.trim().isNotEmpty == true
            ? originalPurchaseToken!.trim()
            : (_optionalText(subscriptionPurchase, 'linkedPurchaseToken') ??
                token),
    productId: logicalPlusProductId(
      productId: rawProductId,
      basePlanId:
          offerDetails == null
              ? null
              : _optionalText(offerDetails, 'basePlanId'),
      offerId:
          offerDetails == null ? null : _optionalText(offerDetails, 'offerId'),
    ),
    billingCountryCode: requireCountryCode(
      _optionalText(subscriptionPurchase, 'regionCode'),
    ),
    billingCurrency: currency,
    amountMinor:
        intro && (price == null || _text(price, 'units') == '0') ? 0 : amount,
    introOffer: intro,
    periodStart: _time(
      subscriptionPurchase['startTime'] ??
          developerNotification['eventTimeMillis'],
      'startTime',
    ),
    periodEnd: _time(line['expiryTime'], 'expiryTime'),
    accountId: _account(
      external == null
          ? null
          : _optionalText(external, 'obfuscatedExternalAccountId'),
    ),
    gracePeriodEndsAt: _optionalTime(
      _map(line['autoRenewingPlan'])?['gracePeriodEndTime'],
    ),
    raw: _raw({
      'developerNotification': developerNotification,
      'subscriptionPurchase': subscriptionPurchase,
    }),
  );
}

class _GoogleEvent {
  const _GoogleEvent(this.type, {this.revoked = false});

  final SubscriptionEventType type;
  final bool revoked;
}

_GoogleEvent? _googleEvent(int type) {
  switch (type) {
    case 4:
      return const _GoogleEvent(SubscriptionEventType.initialPurchase);
    case 1:
    case 2:
    case 7:
      return const _GoogleEvent(SubscriptionEventType.renewal);
    case 6:
      return const _GoogleEvent(SubscriptionEventType.didFailToRenew);
    case 3:
      return const _GoogleEvent(SubscriptionEventType.cancellation);
    case 5:
    case 13:
      return const _GoogleEvent(SubscriptionEventType.expiration);
    case 12:
      return const _GoogleEvent(
        SubscriptionEventType.expiration,
        revoked: true,
      );
    default:
      return null;
  }
}

/// RevenueCat webhook body. Call [revenueCatAuthorized] before trusting it.
StoreNotice? normalizeRevenueCatEvent(
  Map<String, dynamic> body, {
  required DateTime now,
}) {
  final event = _map(body['event']);
  if (event == null) {
    throw SubscriptionNoticeRejected('RevenueCat webhook has no event.');
  }
  final typeName = _text(event, 'type');
  final expires = _time(event['expiration_at_ms'], 'expiration_at_ms');
  final eventType = _revenueCatEvent(typeName, expiresAt: expires, now: now);
  if (eventType == null) return null;
  final store = _text(event, 'store');
  final platform = switch (store) {
    'APP_STORE' || 'MAC_APP_STORE' => StorePlatform.iosAppStore,
    'PLAY_STORE' => StorePlatform.googlePlayStore,
    _ =>
      throw SubscriptionNoticeRejected('RevenueCat store $store is not Plus.'),
  };
  final currency = requireCurrency(_optionalText(event, 'currency'));
  final periodType = _optionalText(event, 'period_type');
  final intro =
      periodType == 'TRIAL' ||
      periodType == 'INTRO' ||
      periodType == 'PROMOTIONAL';
  final rawProductId = _text(event, 'product_id');
  final productParts = rawProductId.split(':');
  return _notice(
    platform: platform,
    storeEventId: _text(event, 'id'),
    type: eventType,
    revoked:
        typeName == 'EXPIRATION' &&
        event['cancel_reason'] == 'CUSTOMER_SUPPORT',
    originalTransactionId: _text(event, 'original_transaction_id'),
    productId: logicalPlusProductId(
      productId: productParts.first,
      basePlanId: productParts.length > 1 ? productParts[1] : null,
    ),
    billingCountryCode: requireCountryCode(
      _optionalText(event, 'country_code'),
    ),
    billingCurrency: currency,
    amountMinor: minorFromMajorAmount(
      event['price_in_purchased_currency'],
      currency,
    ),
    introOffer: intro,
    periodStart: _time(event['purchased_at_ms'], 'purchased_at_ms'),
    periodEnd: expires,
    accountId: _account(_optionalText(event, 'app_user_id')),
    raw: _raw(body),
  );
}

SubscriptionEventType? _revenueCatEvent(
  String type, {
  required DateTime expiresAt,
  required DateTime now,
}) {
  switch (type) {
    case 'INITIAL_PURCHASE':
      return SubscriptionEventType.initialPurchase;
    case 'RENEWAL':
      return SubscriptionEventType.renewal;
    case 'UNCANCELLATION':
      return expiresAt.isAfter(now) ? SubscriptionEventType.renewal : null;
    case 'BILLING_ISSUE':
      return SubscriptionEventType.didFailToRenew;
    case 'CANCELLATION':
      return SubscriptionEventType.cancellation;
    case 'EXPIRATION':
      return SubscriptionEventType.expiration;
    default:
      return null;
  }
}

StoreNotice _notice({
  required StorePlatform platform,
  required String storeEventId,
  required SubscriptionEventType type,
  required bool revoked,
  required String originalTransactionId,
  required String productId,
  required String billingCountryCode,
  required String billingCurrency,
  required int amountMinor,
  required bool introOffer,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String? accountId,
  DateTime? gracePeriodEndsAt,
  required Map<String, Object?> raw,
}) {
  if (storeEventId.trim().isEmpty || originalTransactionId.trim().isEmpty) {
    throw SubscriptionNoticeRejected('The store event is missing its id.');
  }
  if (!periodEnd.isAfter(periodStart)) {
    throw SubscriptionNoticeRejected(
      'The store period end must be after the period start.',
    );
  }
  return StoreNotice(
    platform: platform,
    storeEventId: storeEventId.trim(),
    type: type,
    originalTransactionId: originalTransactionId.trim(),
    productId: productId.trim(),
    billingCountryCode: billingCountryCode,
    billingCurrency: billingCurrency,
    amountMinor: amountMinor,
    introOffer: introOffer,
    periodStart: periodStart.toUtc(),
    periodEnd: periodEnd.toUtc(),
    accountId: accountId,
    gracePeriodEndsAt: gracePeriodEndsAt?.toUtc(),
    revoked: revoked,
    raw: raw,
  );
}

String? _account(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final id = plusAccountId(value);
  if (id == null) {
    throw SubscriptionNoticeRejected(
      'The store account token is not the Pelevo user id.',
    );
  }
  return id;
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return null;
}

Map<String, dynamic>? _firstMap(Object? value) {
  if (value is! List || value.isEmpty) return null;
  return _map(value.first);
}

String _text(Map<String, dynamic> data, String key) {
  final value = _optionalText(data, key);
  if (value == null || value.isEmpty) {
    throw SubscriptionNoticeRejected('Store field $key is missing.');
  }
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) return value;
  final parsed = int.tryParse('$value');
  if (parsed == null) {
    throw SubscriptionNoticeRejected('A store number was not an integer.');
  }
  return parsed;
}

DateTime _time(Object? value, String field) {
  final parsed = _optionalTime(value);
  if (parsed == null) {
    throw SubscriptionNoticeRejected('Store field $field is not a time.');
  }
  return parsed;
}

DateTime? _optionalTime(Object? value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  final text = '$value'.trim();
  if (text.isEmpty) return null;
  final millis = int.tryParse(text);
  if (millis != null) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
  return DateTime.tryParse(text)?.toUtc();
}

Map<String, Object?> _raw(Map<String, dynamic> value) =>
    value.map((key, item) => MapEntry(key, item));
