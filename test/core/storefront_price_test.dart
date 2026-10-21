import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:pelevo/features/premium/storefront_price.dart';

void main() {
  test(
    'Play recurring price stays the formatted phase, not the free intro',
    () {
      final product =
          GooglePlayProductDetails.fromProductDetails(
            const ProductDetailsWrapper(
              description: 'Pelevo Plus',
              name: 'Pelevo Plus',
              productId: 'pelevo_plus_monthly',
              productType: ProductType.subs,
              title: 'Pelevo Plus (Pelevo)',
              subscriptionOfferDetails: [
                SubscriptionOfferDetailsWrapper(
                  basePlanId: 'monthly',
                  offerId: 'three-month-trial',
                  offerTags: [],
                  offerIdToken: 'trial-token',
                  pricingPhases: [
                    PricingPhaseWrapper(
                      billingCycleCount: 1,
                      billingPeriod: 'P3M',
                      formattedPrice: 'Free',
                      priceAmountMicros: 0,
                      priceCurrencyCode: 'NGN',
                      recurrenceMode: RecurrenceMode.finiteRecurring,
                    ),
                    PricingPhaseWrapper(
                      billingCycleCount: 0,
                      billingPeriod: 'P1M',
                      formattedPrice: '₦1,600.00',
                      priceAmountMicros: 1600000000,
                      priceCurrencyCode: 'NGN',
                      recurrenceMode: RecurrenceMode.infiniteRecurring,
                    ),
                  ],
                ),
              ],
            ),
          ).single;

      final price = storefrontPriceFromProduct(product);

      expect(price?.priceString, '₦1,600.00');
      expect(price?.currencyCode, 'NGN');
      expect(price?.introductoryPriceIsFree, isTrue);
      expect(price?.introductoryPeriodLabel, '3 months');
      expect(storefrontPromoBadge(price), '3 months free');
      expect(
        subscriptionPriceLine(price),
        'Free for your first 3 months, then ₦1,600.00',
      );
    },
  );

  test('a paid introductory phase uses the store formatted string', () {
    final product =
        GooglePlayProductDetails.fromProductDetails(
          const ProductDetailsWrapper(
            description: 'Pelevo Plus',
            name: 'Pelevo Plus',
            productId: 'pelevo_plus_monthly',
            productType: ProductType.subs,
            title: 'Pelevo Plus (Pelevo)',
            subscriptionOfferDetails: [
              SubscriptionOfferDetailsWrapper(
                basePlanId: 'monthly',
                offerId: 'intro',
                offerTags: [],
                offerIdToken: 'intro-token',
                pricingPhases: [
                  PricingPhaseWrapper(
                    billingCycleCount: 3,
                    billingPeriod: 'P1M',
                    formattedPrice: 'KES 199.00',
                    priceAmountMicros: 199000000,
                    priceCurrencyCode: 'KES',
                    recurrenceMode: RecurrenceMode.finiteRecurring,
                  ),
                  PricingPhaseWrapper(
                    billingCycleCount: 0,
                    billingPeriod: 'P1M',
                    formattedPrice: 'KES 419.00',
                    priceAmountMicros: 419000000,
                    priceCurrencyCode: 'KES',
                    recurrenceMode: RecurrenceMode.infiniteRecurring,
                  ),
                ],
              ),
            ],
          ),
        ).single;

    final price = storefrontPriceFromProduct(product);

    expect(price?.priceString, 'KES 419.00');
    expect(price?.introductoryPriceString, 'KES 199.00');
    expect(price?.currencyCode, 'KES');
    expect(
      subscriptionPriceLine(price),
      'Pay only KES 199.00 for your first 3 months, then KES 419.00',
    );
  });

  test('USD fallback store text is displayed as returned', () {
    final price = storefrontPriceFromProduct(
      ProductDetails(
        id: 'pelevo_plus_monthly',
        title: 'Pelevo Plus',
        description: 'Pelevo Plus',
        price: r'$2.99',
        rawPrice: 2.99,
        currencyCode: 'USD',
      ),
    );

    expect(price?.priceString, r'$2.99');
    expect(price?.currencyCode, 'USD');
    expect(subscriptionPriceLine(price), r'$2.99');
  });

  test('App Store introductory amount uses the store locale token', () {
    final price = storefrontPriceFromProduct(
      AppStoreProductDetails(
        id: 'pelevo_plus_monthly',
        title: 'Pelevo Plus',
        description: 'Pelevo Plus',
        price: 'R69.99',
        rawPrice: 69.99,
        currencyCode: 'ZAR',
        currencySymbol: 'R',
        skProduct: SKProductWrapper(
          productIdentifier: 'pelevo_plus_monthly',
          localizedTitle: 'Pelevo Plus',
          localizedDescription: 'Pelevo Plus',
          priceLocale: SKPriceLocaleWrapper(
            currencySymbol: 'R',
            currencyCode: 'ZAR',
            countryCode: 'ZA',
          ),
          price: '69.99',
          introductoryPrice: SKProductDiscountWrapper(
            price: '0',
            priceLocale: SKPriceLocaleWrapper(
              currencySymbol: 'R',
              currencyCode: 'ZAR',
              countryCode: 'ZA',
            ),
            numberOfPeriods: 1,
            paymentMode: SKProductDiscountPaymentMode.freeTrail,
            subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
              numberOfUnits: 3,
              unit: SKSubscriptionPeriodUnit.month,
            ),
            identifier: null,
            type: SKProductDiscountType.introductory,
          ),
        ),
      ),
    );

    expect(price?.priceString, 'R69.99');
    expect(price?.currencyCode, 'ZAR');
    expect(price?.introductoryPriceIsFree, isTrue);
    expect(
      subscriptionPriceLine(price),
      'Free for your first 3 months, then R69.99',
    );
  });

  test('a missing store quote does not invent a currency amount', () {
    expect(subscriptionPriceLine(null), storefrontPricePending);
  });

  test('a paid introductory price gets its own promo line', () {
    const price = StorefrontPrice(
      priceString: 'KES 419.00',
      currencyCode: 'KES',
      introductoryPriceString: 'KES 199.00',
      introductoryPeriodLabel: 'month',
    );

    expect(
      storefrontIntroNotice(price),
      'Promo: Get your first month for only KES 199.00!',
    );
    expect(
      plansSubscribeLabel(claimingTrial: false, preview: false, quote: price),
      'Subscribe for KES 199.00',
    );
    expect(
      plansSubscribeLabel(claimingTrial: false, preview: true, quote: price),
      'Start Free Trial',
    );
  });

  test('an ineligible store account does not keep the introductory price', () {
    const price = StorefrontPrice(
      priceString: 'R69.99',
      currencyCode: 'ZAR',
      introductoryPriceString: 'R34.99',
      introductoryPeriodLabel: 'month',
    );

    final hidden = storefrontQuoteForEligibility(price, eligible: false);

    expect(hidden.priceString, 'R69.99');
    expect(hidden.introductoryPriceString, isNull);
    expect(storefrontIntroNotice(hidden), isNull);
    expect(storefrontQuoteForEligibility(price, eligible: true), price);
  });

  test('Play base plan does not inherit a sibling introductory offer', () {
    final products = GooglePlayProductDetails.fromProductDetails(
      const ProductDetailsWrapper(
        description: 'Pelevo Plus',
        name: 'Pelevo Plus',
        productId: 'pelevo_plus_monthly',
        productType: ProductType.subs,
        title: 'Pelevo Plus (Pelevo)',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: [],
            offerIdToken: 'base-token',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: '₦1,600.00',
                priceAmountMicros: 1600000000,
                priceCurrencyCode: 'NGN',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'three-month-trial',
            offerTags: [],
            offerIdToken: 'trial-token',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P3M',
                formattedPrice: 'Free',
                priceAmountMicros: 0,
                priceCurrencyCode: 'NGN',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: '₦1,600.00',
                priceAmountMicros: 1600000000,
                priceCurrencyCode: 'NGN',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'intro',
            offerTags: [],
            offerIdToken: 'intro-token',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P1M',
                formattedPrice: '₦800.00',
                priceAmountMicros: 800000000,
                priceCurrencyCode: 'NGN',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: '₦1,600.00',
                priceAmountMicros: 1600000000,
                priceCurrencyCode: 'NGN',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      ),
    );

    final base = storefrontPriceFromProduct(products[0]);
    final trial = storefrontPriceFromProduct(products[1]);
    final intro = storefrontPriceFromProduct(products[2]);

    expect(base?.introductoryPriceString, isNull);
    expect(base?.introductoryPriceIsFree, isFalse);
    expect(trial?.introductoryPriceIsFree, isTrue);
    expect(intro?.introductoryPriceString, '₦800.00');
    expect(
      storefrontIntroNotice(intro),
      'Promo: Get your first month for only ₦800.00!',
    );
    expect(
      (storeProductForPlan(products, trialPlan: true, android: true)
              as GooglePlayProductDetails)
          .offerToken,
      'trial-token',
    );
    expect(
      (storeProductForPlan(products, trialPlan: false, android: true)
              as GooglePlayProductDetails)
          .offerToken,
      'intro-token',
    );
  });

  test('StoreKit 2 introductory offer uses the product display price', () {
    final free = storefrontPriceFromProduct(
      _sk2Product(
        displayPrice: 'R69.99',
        currencySymbol: 'R',
        currencyCode: 'ZAR',
        offer: SK2SubscriptionOffer(
          price: 0,
          type: SK2SubscriptionOfferType.introductory,
          period: const SK2SubscriptionPeriod(
            value: 3,
            unit: SK2SubscriptionPeriodUnit.month,
          ),
          periodCount: 1,
          paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial,
        ),
      ),
    );
    expect(free?.introductoryPriceIsFree, isTrue);
    expect(free?.introductoryPeriodLabel, '3 months');
    expect(
      subscriptionPriceLine(free),
      'Free for your first 3 months, then R69.99',
    );

    final paid = storefrontPriceFromProduct(
      _sk2Product(
        displayPrice: '₦1,600.00',
        currencySymbol: '₦',
        currencyCode: 'NGN',
        offer: SK2SubscriptionOffer(
          price: 800,
          type: SK2SubscriptionOfferType.introductory,
          period: const SK2SubscriptionPeriod(
            value: 1,
            unit: SK2SubscriptionPeriodUnit.month,
          ),
          periodCount: 1,
          paymentMode: SK2SubscriptionOfferPaymentMode.payAsYouGo,
        ),
      ),
    );
    expect(paid?.priceString, '₦1,600.00');
    expect(paid?.introductoryPriceString, '₦800.00');
    expect(
      storefrontIntroNotice(paid),
      'Promo: Get your first month for only ₦800.00!',
    );

    final promotional = storefrontPriceFromProduct(
      _sk2Product(
        displayPrice: r'$2.99',
        currencySymbol: r'$',
        currencyCode: 'USD',
        offer: SK2SubscriptionOffer(
          id: 'win-back',
          price: 0.99,
          type: SK2SubscriptionOfferType.promotional,
          period: const SK2SubscriptionPeriod(
            value: 1,
            unit: SK2SubscriptionPeriodUnit.month,
          ),
          periodCount: 1,
          paymentMode: SK2SubscriptionOfferPaymentMode.payUpFront,
        ),
      ),
    );
    expect(promotional?.introductoryPriceString, isNull);
    expect(promotional?.introductoryPriceIsFree, isFalse);
    expect(subscriptionPriceLine(promotional), r'$2.99');
  });

  test('store amount formatting copies the sample, without converting', () {
    expect(
      storeAmountLikeSample(
        sample: 'KES 419.00',
        currencySymbol: 'KES',
        amount: 199,
      ),
      'KES 199.00',
    );
    expect(
      storeAmountLikeSample(
        sample: '1,800 XOF',
        currencySymbol: 'XOF',
        amount: 900,
      ),
      '900 XOF',
    );
    expect(
      storeAmountLikeSample(
        sample: '₦1,600.00',
        currencySymbol: '₦',
        amount: 1600,
      ),
      '₦1,600.00',
    );
  });
}

AppStoreProduct2Details _sk2Product({
  required String displayPrice,
  required String currencySymbol,
  required String currencyCode,
  required SK2SubscriptionOffer offer,
}) {
  return AppStoreProduct2Details(
    id: 'pelevo_plus_monthly',
    title: 'Pelevo Plus',
    description: 'Pelevo Plus',
    price: displayPrice,
    rawPrice: 69.99,
    currencyCode: currencyCode,
    currencySymbol: currencySymbol,
    sk2Product: SK2Product(
      id: 'pelevo_plus_monthly',
      displayName: 'Pelevo Plus',
      displayPrice: displayPrice,
      description: 'Pelevo Plus',
      price: 69.99,
      type: SK2ProductType.autoRenewable,
      priceLocale: SK2PriceLocale(
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      ),
      subscription: SK2SubscriptionInfo(
        subscriptionGroupID: 'plus',
        promotionalOffers: [offer],
        subscriptionPeriod: const SK2SubscriptionPeriod(
          value: 1,
          unit: SK2SubscriptionPeriodUnit.month,
        ),
      ),
    ),
  );
}
