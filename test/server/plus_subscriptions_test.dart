import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/server/plus_subscriptions/plus_subscriptions.dart';

void main() {
  const user = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  const other = 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';

  late DateTime now;
  late int ids;
  late SubscriptionLedger ledger;

  setUp(() {
    now = DateTime.utc(2026, 8, 10);
    ids = 0;
    ledger = SubscriptionLedger(clock: () => now, ids: () => 'id-${++ids}');
  });

  StoreNotice purchase({
    String eventId = 'evt-1',
    String origin = 'orig-1',
    SubscriptionEventType type = SubscriptionEventType.initialPurchase,
    String productId = plusMonthlyProductId,
    String country = 'NG',
    String currency = 'NGN',
    int amountMinor = 160000,
    bool introOffer = false,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? accountId = user,
    DateTime? gracePeriodEndsAt,
    bool revoked = false,
    StorePlatform platform = StorePlatform.googlePlayStore,
  }) {
    final start = periodStart ?? DateTime.utc(2026, 8, 10);
    return StoreNotice(
      platform: platform,
      storeEventId: eventId,
      type: type,
      originalTransactionId: origin,
      productId: productId,
      billingCountryCode: country,
      billingCurrency: currency,
      amountMinor: amountMinor,
      introOffer: introOffer,
      periodStart: start,
      periodEnd: periodEnd ?? start.add(const Duration(days: 31)),
      accountId: accountId,
      gracePeriodEndsAt: gracePeriodEndsAt,
      revoked: revoked,
    );
  }

  test('minor units follow the storefront exponent and do not convert', () {
    expect(minorFromAppleMilliunits(1600000, 'NGN'), 160000);
    expect(minorFromAppleMilliunits(69990, 'ZAR'), 6999);
    expect(minorFromAppleMilliunits(1800000, 'XOF'), 1800);
    expect(
      minorFromUnitsAndNanos(units: 69, nanos: 990000000, currency: 'ZAR'),
      6999,
    );
    expect(minorFromMajorAmount('69.99', 'ZAR'), 6999);
    expect(minorFromMajorAmount(1800, 'XOF'), 1800);
    expect(minorFromMajorAmount('2.99', 'USD'), 299);
    expect(() => minorFromMajorAmount('1.17', 'USD'), returnsNormally);
    expect(minorFromMajorAmount('1.17', 'USD'), isNot(160000));
  });

  test('an initial purchase grants Plus and a replay does not pay twice', () {
    final first = ledger.apply(purchase());
    final replay = ledger.apply(
      purchase(eventId: 'evt-2', periodEnd: DateTime.utc(2026, 9, 10)),
    );
    final row = ledger.subscription(
      platform: StorePlatform.googlePlayStore,
      originalTransactionId: 'orig-1',
    );

    expect(first.changed, isTrue);
    expect(replay.changed, isFalse);
    expect(ledger.transactionsFor(row!.subscriptionId), hasLength(1));
    expect(row.status, SubscriptionStatus.active);
    expect(row.amountMinor, 160000);
    expect(row.billingCountryCode, 'NG');
    expect(ledger.premiumMe(user)['entitlement'], {
      'state': 'active',
      'starts_at': '2026-08-10T00:00:00.000Z',
      'ends_at': '2026-09-10T00:00:00.000Z',
      'plan_id': plusMonthlyProductId,
    });
  });

  test('the same store event id is a duplicate and writes nothing new', () {
    ledger.apply(purchase());
    final again = ledger.apply(purchase());

    expect(again.duplicate, isTrue);
    expect(again.statusCode, 200);
    expect(
      ledger.transactionsFor(
        ledger
            .subscription(
              platform: StorePlatform.googlePlayStore,
              originalTransactionId: 'orig-1',
            )!
            .subscriptionId,
      ),
      hasLength(1),
    );
  });

  test('a renewal in a new storefront keeps the old charge unchanged', () {
    ledger.apply(purchase());
    now = now.add(const Duration(seconds: 1));
    ledger.apply(
      purchase(
        eventId: 'renew-1',
        type: SubscriptionEventType.renewal,
        country: 'ZA',
        currency: 'ZAR',
        amountMinor: 6999,
        periodStart: DateTime.utc(2026, 9, 10),
        periodEnd: DateTime.utc(2026, 10, 10),
      ),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;
    final transactions = ledger.transactionsFor(row.subscriptionId);

    expect(row.billingCurrency, 'ZAR');
    expect(row.amountMinor, 6999);
    expect(row.billingCountryCode, 'ZA');
    expect(transactions.first.billingCurrency, 'NGN');
    expect(transactions.first.amountMinor, 160000);
    expect(transactions.last.billingCurrency, 'ZAR');
    expect(row.expiryDate, DateTime.utc(2026, 10, 10));
  });

  test('a yearly renewal uses the store end date', () {
    ledger.apply(
      purchase(
        productId: plusYearlyProductId,
        periodEnd: DateTime.utc(2027, 8, 10),
      ),
    );
    ledger.apply(
      purchase(
        eventId: 'year-2',
        type: SubscriptionEventType.renewal,
        productId: plusYearlyProductId,
        periodStart: DateTime.utc(2027, 8, 10),
        periodEnd: DateTime.utc(2028, 8, 10),
      ),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;

    expect(row.expiryDate, DateTime.utc(2028, 8, 10));
    expect(
      row.expiryDate.difference(DateTime.utc(2027, 8, 10)).inDays,
      greaterThan(360),
    );
  });

  test(
    'a free introductory purchase stores zero and the renewal clears it',
    () {
      ledger.apply(purchase(amountMinor: 0, introOffer: true));
      ledger.apply(
        purchase(
          eventId: 'paid-1',
          type: SubscriptionEventType.renewal,
          periodStart: DateTime.utc(2026, 11, 10),
          periodEnd: DateTime.utc(2027, 11, 10),
        ),
      );
      final row =
          ledger.subscription(
            platform: StorePlatform.googlePlayStore,
            originalTransactionId: 'orig-1',
          )!;
      final transactions = ledger.transactionsFor(row.subscriptionId);

      expect(transactions.first.introOffer, isTrue);
      expect(transactions.first.amountMinor, 0);
      expect(row.introOffer, isFalse);
      expect(row.amountMinor, 160000);
    },
  );

  test('billing failure keeps Plus and a missing grace end uses 7 days', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'grace-1', type: SubscriptionEventType.didFailToRenew),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;
    final me = ledger.premiumMe(user);

    expect(row.status, SubscriptionStatus.inGracePeriod);
    expect(row.expiryDate, DateTime.utc(2026, 9, 10));
    expect(row.gracePeriodEndsAt, DateTime.utc(2026, 9, 17));
    expect((me['entitlement'] as Map)['state'], 'in_grace_period');
  });

  test('a store grace end later than the paid period extends expiry', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(
        eventId: 'grace-2',
        type: SubscriptionEventType.didFailToRenew,
        gracePeriodEndsAt: DateTime.utc(2026, 9, 20),
      ),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;

    expect(row.expiryDate, DateTime.utc(2026, 9, 20));
    expect(row.gracePeriodEndsAt, DateTime.utc(2026, 9, 20));
  });

  test('turning off auto-renew keeps Plus until the paid period ends', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'cancel-1', type: SubscriptionEventType.cancellation),
    );
    final me = ledger.premiumMe(user);
    final subscription = me['subscription'] as Map;

    expect(subscription['state'], 'active');
    expect(subscription['cancel_at'], '2026-09-10T00:00:00.000Z');
    expect((me['entitlement'] as Map)['state'], 'active');
  });

  test('expiration after cancel is canceled, and a revoke is canceled', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'cancel-1', type: SubscriptionEventType.cancellation),
    );
    ledger.apply(
      purchase(
        eventId: 'end-1',
        type: SubscriptionEventType.expiration,
        periodStart: DateTime.utc(2026, 8, 10),
        periodEnd: DateTime.utc(2026, 9, 10),
      ),
    );

    expect(
      ledger
          .subscription(
            platform: StorePlatform.googlePlayStore,
            originalTransactionId: 'orig-1',
          )!
          .status,
      SubscriptionStatus.canceled,
    );

    ledger.apply(
      purchase(eventId: 'buy-2', origin: 'orig-2', accountId: other),
    );
    ledger.apply(
      purchase(
        eventId: 'revoke-2',
        origin: 'orig-2',
        type: SubscriptionEventType.expiration,
        revoked: true,
        accountId: other,
      ),
    );

    expect(
      ledger
          .subscription(
            platform: StorePlatform.googlePlayStore,
            originalTransactionId: 'orig-2',
          )!
          .status,
      SubscriptionStatus.canceled,
    );
    expect(
      (ledger.premiumMe(other)['entitlement'] as Map)['state'],
      'canceled',
    );
  });

  test('expiration without cancel is the free tier', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'end-1', type: SubscriptionEventType.expiration),
    );

    expect((ledger.premiumMe(user)['entitlement'] as Map)['state'], 'expired');
  });

  test('a later renewal clears cancel and grace', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'grace-1', type: SubscriptionEventType.didFailToRenew),
    );
    ledger.apply(
      purchase(eventId: 'cancel-1', type: SubscriptionEventType.cancellation),
    );
    ledger.apply(
      purchase(
        eventId: 'renew-1',
        type: SubscriptionEventType.renewal,
        periodStart: DateTime.utc(2026, 9, 10),
        periodEnd: DateTime.utc(2026, 10, 10),
      ),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;

    expect(row.status, SubscriptionStatus.active);
    expect(row.cancelAt, isNull);
    expect(row.gracePeriodEndsAt, isNull);
  });

  test('turning auto-renew back on clears cancel without a new charge', () {
    ledger.apply(purchase());
    ledger.apply(
      purchase(eventId: 'cancel-1', type: SubscriptionEventType.cancellation),
    );
    ledger.apply(
      purchase(
        eventId: 'resume-1',
        type: SubscriptionEventType.autoRenewEnabled,
      ),
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;

    expect(row.cancelAt, isNull);
    expect(row.status, SubscriptionStatus.active);
    expect(
      ledger.transactionsFor(row.subscriptionId).map((row) => row.eventType),
      [
        SubscriptionEventType.initialPurchase,
        SubscriptionEventType.cancellation,
      ],
    );
  });

  test('the open subscription with the later expiry wins', () {
    ledger.apply(purchase(periodEnd: DateTime.utc(2026, 9, 10)));
    now = now.add(const Duration(seconds: 1));
    ledger.apply(
      purchase(
        eventId: 'buy-2',
        origin: 'orig-2',
        productId: plusYearlyProductId,
        periodEnd: DateTime.utc(2027, 8, 10),
      ),
    );

    expect(
      (ledger.premiumMe(user)['subscription'] as Map)['plan_id'],
      plusYearlyProductId,
    );
    expect(
      (ledger.premiumMe(user)['entitlement'] as Map)['ends_at'],
      '2027-08-10T00:00:00.000Z',
    );
  });

  test('a signed-in confirmation links an unassigned receipt', () {
    final notice = purchase(accountId: null);
    ledger.confirmVerifiedPurchase(
      notice: notice,
      signedInUserId: user,
      planIdHint: 'plan-monthly',
    );
    final row =
        ledger.subscription(
          platform: StorePlatform.googlePlayStore,
          originalTransactionId: 'orig-1',
        )!;

    expect(row.userId, user);
    expect(row.planId, 'plan-monthly');
    expect(row.productId, plusMonthlyProductId);
    expect((ledger.premiumMe(user)['entitlement'] as Map)['state'], 'active');
  });

  test('a receipt cannot be moved onto a different account', () {
    ledger.apply(purchase());

    expect(
      () => ledger.attachSignedInUser(
        platform: StorePlatform.googlePlayStore,
        originalTransactionId: 'orig-1',
        userId: other,
      ),
      throwsA(isA<SubscriptionNoticeRejected>()),
    );
    expect(
      ledger
          .subscription(
            platform: StorePlatform.googlePlayStore,
            originalTransactionId: 'orig-1',
          )!
          .userId,
      user,
    );
  });

  test('a missing billing country is rejected and writes nothing', () {
    expect(
      () => ledger.apply(purchase(country: '')),
      throwsA(isA<SubscriptionNoticeRejected>()),
    );
  });

  test('a coin product does not grant Plus', () {
    final result = ledger.apply(purchase(productId: 'pelevo_coins_500'));

    expect(result.changed, isFalse);
    expect(
      ledger.subscription(
        platform: StorePlatform.googlePlayStore,
        originalTransactionId: 'orig-1',
      ),
      isNull,
    );
    expect(ledger.premiumMe(user)['entitlement'], isNull);
  });

  test(
    'Apple, Google, and RevenueCat notifications normalize to one ledger',
    () {
      final apple =
          normalizeAppleNotification({
            'notificationType': 'SUBSCRIBED',
            'subtype': 'INITIAL_BUY',
            'notificationUUID': 'apple-1',
            'data': {
              'transaction': {
                'originalTransactionId': 'apple-orig',
                'productId': plusMonthlyProductId,
                'purchaseDate': 1754784000000,
                'expiresDate': 1757462400000,
                'storefront': 'NGA',
                'currency': 'NGN',
                'price': 1600000,
                'appAccountToken': user,
              },
            },
          })!;
      final google =
          normalizeGoogleNotification(
            messageId: 'pubsub-1',
            developerNotification: {
              'subscriptionNotification': {
                'notificationType': 2,
                'purchaseToken': 'token-2',
                'subscriptionId': plusMonthlyProductId,
              },
            },
            subscriptionPurchase: {
              'regionCode': 'ZA',
              'linkedPurchaseToken': 'token-1',
              'startTime': '2026-09-10T00:00:00Z',
              'externalAccountIdentifiers': {
                'obfuscatedExternalAccountId': user,
              },
              'lineItems': [
                {
                  'productId': plusMonthlyProductId,
                  'expiryTime': '2026-10-10T00:00:00Z',
                  'autoRenewingPlan': {
                    'recurringPrice': {
                      'currencyCode': 'ZAR',
                      'units': '69',
                      'nanos': 990000000,
                    },
                  },
                },
              ],
            },
            originalPurchaseToken: 'token-1',
          )!;
      final revenueCat =
          normalizeRevenueCatEvent({
            'event': {
              'id': 'rc-1',
              'type': 'BILLING_ISSUE',
              'store': 'PLAY_STORE',
              'original_transaction_id': 'token-1',
              'product_id': plusMonthlyProductId,
              'country_code': 'ZA',
              'currency': 'ZAR',
              'price_in_purchased_currency': 69.99,
              'purchased_at_ms': 1757462400000,
              'expiration_at_ms': 1760054400000,
              'app_user_id': user,
            },
          }, now: DateTime.utc(2026, 9, 12))!;

      expect(apple.billingCountryCode, 'NG');
      expect(apple.amountMinor, 160000);
      expect(apple.type, SubscriptionEventType.initialPurchase);
      expect(google.type, SubscriptionEventType.renewal);
      expect(google.originalTransactionId, 'token-1');
      expect(google.amountMinor, 6999);
      expect(google.billingCountryCode, 'ZA');
      expect(revenueCat.type, SubscriptionEventType.didFailToRenew);

      ledger.apply(apple);
      ledger.apply(google);
      ledger.apply(revenueCat);
      final row =
          ledger.subscription(
            platform: StorePlatform.googlePlayStore,
            originalTransactionId: 'token-1',
          )!;

      expect(row.status, SubscriptionStatus.inGracePeriod);
      expect(
        ledger
            .subscription(
              platform: StorePlatform.iosAppStore,
              originalTransactionId: 'apple-orig',
            )!
            .status,
        SubscriptionStatus.active,
      );
    },
  );

  test('store notification names map onto the internal events', () {
    expect(
      normalizeAppleNotification({
        'notificationType': 'DID_CHANGE_RENEWAL_STATUS',
        'subtype': 'AUTO_RENEW_DISABLED',
        'notificationUUID': 'apple-cancel',
        'data': {'transaction': _appleTransaction()},
      })!.type,
      SubscriptionEventType.cancellation,
    );
    expect(
      normalizeAppleNotification({
        'notificationType': 'REFUND',
        'notificationUUID': 'apple-refund',
        'data': {'transaction': _appleTransaction()},
      })!.revoked,
      isTrue,
    );
    expect(
      normalizeAppleNotification({
        'notificationType': 'DID_FAIL_TO_RENEW',
        'notificationUUID': 'apple-grace',
        'data': {'transaction': _appleTransaction()},
      })!.type,
      SubscriptionEventType.didFailToRenew,
    );
    expect(
      normalizeGoogleNotification(
        messageId: 'hold',
        developerNotification: {
          'subscriptionNotification': {
            'notificationType': 5,
            'purchaseToken': 'token',
            'subscriptionId': plusMonthlyProductId,
          },
        },
        subscriptionPurchase: _googlePurchase(),
      )!.type,
      SubscriptionEventType.expiration,
    );
    expect(
      normalizeGoogleNotification(
        messageId: 'revoked',
        developerNotification: {
          'subscriptionNotification': {
            'notificationType': 12,
            'purchaseToken': 'token',
            'subscriptionId': plusMonthlyProductId,
          },
        },
        subscriptionPurchase: _googlePurchase(),
      )!.revoked,
      isTrue,
    );
    expect(
      normalizeRevenueCatEvent({
        'event': {
          'id': 'rc-uncancel',
          'type': 'UNCANCELLATION',
          'store': 'APP_STORE',
          'original_transaction_id': 'apple-orig',
          'product_id': plusMonthlyProductId,
          'country_code': 'NG',
          'currency': 'NGN',
          'price_in_purchased_currency': 1600,
          'purchased_at_ms': '2026-08-10T00:00:00Z',
          'expiration_at_ms': '2026-09-10T00:00:00Z',
          'app_user_id': user,
        },
      }, now: DateTime.utc(2026, 8, 11))!.type,
      SubscriptionEventType.renewal,
    );
    expect(
      normalizeRevenueCatEvent({
        'event': {
          'id': 'rc-late',
          'type': 'UNCANCELLATION',
          'store': 'APP_STORE',
          'original_transaction_id': 'apple-orig',
          'product_id': plusMonthlyProductId,
          'country_code': 'NG',
          'currency': 'NGN',
          'price_in_purchased_currency': 1600,
          'purchased_at_ms': '2026-08-10T00:00:00Z',
          'expiration_at_ms': '2026-09-10T00:00:00Z',
          'app_user_id': user,
        },
      }, now: DateTime.utc(2026, 10, 1)),
      isNull,
    );
  });

  test('RevenueCat authorization compares the shared secret', () {
    expect(revenueCatAuthorized('Bearer top-secret', 'top-secret'), isTrue);
    expect(revenueCatAuthorized('top-secret', 'top-secret'), isTrue);
    expect(revenueCatAuthorized('Bearer other', 'top-secret'), isFalse);
    expect(revenueCatAuthorized(null, 'top-secret'), isFalse);
  });

  test('an unknown Apple storefront is rejected', () {
    expect(
      () => normalizeAppleNotification({
        'notificationType': 'SUBSCRIBED',
        'notificationUUID': 'apple-x',
        'data': {'transaction': _appleTransaction(storefront: 'ZZZ')},
      }),
      throwsA(isA<SubscriptionNoticeRejected>()),
    );
  });
}

Map<String, Object?> _appleTransaction({String storefront = 'NGA'}) => {
  'originalTransactionId': 'apple-orig',
  'productId': plusMonthlyProductId,
  'purchaseDate': 1754784000000,
  'expiresDate': 1757462400000,
  'storefront': storefront,
  'currency': 'NGN',
  'price': 1600000,
  'appAccountToken': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
};

Map<String, dynamic> _googlePurchase() => {
  'regionCode': 'NG',
  'startTime': '2026-08-10T00:00:00Z',
  'lineItems': [
    {
      'productId': plusMonthlyProductId,
      'expiryTime': '2026-09-10T00:00:00Z',
      'autoRenewingPlan': {
        'recurringPrice': {'currencyCode': 'NGN', 'units': '1600', 'nanos': 0},
      },
    },
  ],
};
