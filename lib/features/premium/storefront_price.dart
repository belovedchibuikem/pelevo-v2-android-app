import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Shown until Google Play or the App Store returns a formatted price.
const storefrontPricePending = 'Shown by your store account';

/// Price text taken from the signed-in store account.
///
/// [priceString] and [introductoryPriceString] are the store's own formatted
/// strings. This object never converts an amount or chooses a currency symbol.
class StorefrontPrice {
  const StorefrontPrice({
    required this.priceString,
    required this.currencyCode,
    this.introductoryPriceString,
    this.introductoryPeriodLabel,
    this.introductoryPriceIsFree = false,
  });

  final String priceString;
  final String currencyCode;
  final String? introductoryPriceString;
  final String? introductoryPeriodLabel;
  final bool introductoryPriceIsFree;
}

/// Badge taken from the store introductory phase. No store offer means no badge.
String storefrontPromoBadge(StorefrontPrice? price) {
  if (price == null) return '';
  if (price.introductoryPriceIsFree) {
    final period = price.introductoryPeriodLabel?.trim() ?? '';
    if (period.isEmpty) return 'Free trial';
    return '$period free';
  }
  final intro = price.introductoryPriceString?.trim() ?? '';
  if (intro.isEmpty) return '';
  return 'Intro offer';
}

/// Checkout callout. Null when the store did not return an introductory phase.
String? storefrontIntroNotice(StorefrontPrice? price) {
  if (price == null) return null;
  if (price.introductoryPriceIsFree) {
    final period = price.introductoryPeriodLabel?.trim() ?? '';
    if (period.isEmpty) return 'Promo: Your first period is free.';
    return 'Promo: Get your first $period free.';
  }
  final intro = price.introductoryPriceString?.trim() ?? '';
  if (intro.isEmpty) return null;
  final period = price.introductoryPeriodLabel?.trim() ?? '';
  if (period.isEmpty) {
    return 'Promo: Get the introductory price for only $intro!';
  }
  return 'Promo: Get your first $period for only $intro!';
}

/// Button under the plan list. Preview keeps the catalog label.
String plansSubscribeLabel({
  required bool claimingTrial,
  required bool preview,
  StorefrontPrice? quote,
}) {
  if (claimingTrial) return 'Claim Offer';
  if (preview || quote == null || quote.priceString.trim().isEmpty) {
    return 'Start Free Trial';
  }
  if (quote.introductoryPriceIsFree) return 'Start Free Trial';
  final intro = quote.introductoryPriceString?.trim() ?? '';
  if (intro.isNotEmpty) return 'Subscribe for $intro';
  return 'Subscribe for ${quote.priceString}';
}

/// Drops an introductory phase when the signed-in store account cannot redeem it.
StorefrontPrice storefrontQuoteForEligibility(
  StorefrontPrice quote, {
  required bool eligible,
}) {
  if (eligible) return quote;
  return StorefrontPrice(
    priceString: quote.priceString,
    currencyCode: quote.currencyCode,
  );
}

/// Paywall copy for a store quote. A missing quote stays unlabeled.
String subscriptionPriceLine(StorefrontPrice? price) {
  final listed = price?.priceString.trim() ?? '';
  if (price == null || listed.isEmpty) return storefrontPricePending;
  if (price.introductoryPriceIsFree) {
    final period = price.introductoryPeriodLabel;
    if (period == null || period.isEmpty) return 'Free, then $listed';
    return 'Free for your first $period, then $listed';
  }
  final intro = price.introductoryPriceString?.trim() ?? '';
  if (intro.isEmpty) return price.priceString;
  final period = price.introductoryPeriodLabel;
  if (period == null || period.isEmpty) return 'Pay only $intro, then $listed';
  return 'Pay only $intro for your first $period, then $listed';
}

/// Reads the recurring price, currency code, and introductory phase from a
/// native store product. Formatting stays on the string the store returned.
StorefrontPrice? storefrontPriceFromProduct(ProductDetails product) {
  if (product is GooglePlayProductDetails) return _fromGoogle(product);
  if (product is AppStoreProduct2Details) return _fromAppStore2(product);
  if (product is AppStoreProductDetails) return _fromAppStore(product);
  return _fromPlain(product);
}

/// Picks the store product whose offer token matches the plan being purchased.
///
/// A trial plan buys the free introductory phase. Any other plan buys the
/// priced phase, including a paid introductory phase on that same offer.
ProductDetails? storeProductForPlan(
  List<ProductDetails> offers, {
  required bool trialPlan,
  required bool android,
}) {
  if (offers.isEmpty) return null;
  if (trialPlan) {
    for (final offer in offers) {
      if (_playOfferIsThreeMonthFree(offer)) return offer;
    }
    if (android) return null;
    for (final offer in offers) {
      if (storefrontPriceFromProduct(offer)?.introductoryPriceIsFree == true) {
        return offer;
      }
    }
    return offers.first;
  }
  ProductDetails? priced;
  for (final offer in offers) {
    if (_playOfferIsThreeMonthFree(offer)) continue;
    final quote = storefrontPriceFromProduct(offer);
    if (quote == null) continue;
    priced ??= offer;
    if (quote.introductoryPriceString?.isNotEmpty ?? false) return offer;
  }
  return priced ?? offers.first;
}

bool _playOfferIsThreeMonthFree(ProductDetails product) {
  if (product is! GooglePlayProductDetails) return false;
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index < 0 || index >= offers.length) {
    return false;
  }
  final phases = offers[index].pricingPhases;
  if (phases.isEmpty || phases.first.priceAmountMicros != 0) return false;
  return phases.first.billingPeriod == 'P3M';
}

StorefrontPrice? _fromPlain(ProductDetails product) {
  if (product.price.trim().isEmpty) return null;
  return StorefrontPrice(
    priceString: product.price,
    currencyCode: product.currencyCode,
  );
}

StorefrontPrice? _fromGoogle(GooglePlayProductDetails product) {
  final offers = product.productDetails.subscriptionOfferDetails;
  if (offers == null || offers.isEmpty) return _fromPlain(product);
  final recurring = _recurringPhase(offers, product.subscriptionIndex);
  if (recurring == null || recurring.formattedPrice.trim().isEmpty) {
    return _fromPlain(product);
  }
  final intro = _introPhase(offers, product.subscriptionIndex, recurring);
  final free = intro != null && intro.priceAmountMicros == 0;
  final introText = intro?.formattedPrice.trim() ?? '';
  final showIntro =
      intro != null &&
      !free &&
      introText.isNotEmpty &&
      introText != recurring.formattedPrice;
  return StorefrontPrice(
    priceString: recurring.formattedPrice,
    currencyCode: recurring.priceCurrencyCode,
    introductoryPriceString: showIntro ? introText : null,
    introductoryPeriodLabel:
        intro == null
            ? null
            : billingPeriodLabel(intro.billingPeriod, intro.billingCycleCount),
    introductoryPriceIsFree: free,
  );
}

PricingPhaseWrapper? _recurringPhase(
  List<SubscriptionOfferDetailsWrapper> offers,
  int? selectedIndex,
) {
  if (selectedIndex != null &&
      selectedIndex >= 0 &&
      selectedIndex < offers.length) {
    final selected = _infinitePhase(offers[selectedIndex].pricingPhases);
    if (selected != null && selected.priceAmountMicros > 0) return selected;
  }
  for (final offer in offers) {
    final phase = _infinitePhase(offer.pricingPhases);
    if (phase != null && phase.priceAmountMicros > 0) return phase;
  }
  if (offers.isEmpty) return null;
  return _infinitePhase(offers.first.pricingPhases);
}

PricingPhaseWrapper? _infinitePhase(List<PricingPhaseWrapper> phases) {
  for (final phase in phases.reversed) {
    if (phase.recurrenceMode == RecurrenceMode.infiniteRecurring) return phase;
  }
  return phases.isEmpty ? null : phases.last;
}

PricingPhaseWrapper? _introPhase(
  List<SubscriptionOfferDetailsWrapper> offers,
  int? selectedIndex,
  PricingPhaseWrapper recurring,
) {
  if (selectedIndex == null ||
      selectedIndex < 0 ||
      selectedIndex >= offers.length) {
    return null;
  }
  PricingPhaseWrapper? paid;
  for (final phase in offers[selectedIndex].pricingPhases) {
    if (phase.recurrenceMode == RecurrenceMode.infiniteRecurring &&
        phase.priceAmountMicros == recurring.priceAmountMicros &&
        phase.formattedPrice == recurring.formattedPrice) {
      continue;
    }
    if (phase.priceAmountMicros == 0) return phase;
    if (phase.formattedPrice != recurring.formattedPrice) {
      paid ??= phase;
    }
  }
  return paid;
}

/// ISO 8601 billing period from Play, multiplied by the phase cycle count.
String? billingPeriodLabel(String period, int cycles) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period.trim());
  if (match == null) return null;
  final units = int.tryParse(match.group(1)!);
  if (units == null || units <= 0) return null;
  final repeats = cycles <= 0 ? 1 : cycles;
  final singular = switch (match.group(2)) {
    'D' => 'day',
    'W' => 'week',
    'M' => 'month',
    'Y' => 'year',
    _ => null,
  };
  if (singular == null) return null;
  return _periodLabel(units * repeats, singular);
}

StorefrontPrice? _fromAppStore(AppStoreProductDetails product) {
  if (product.price.trim().isEmpty) return null;
  final intro = product.skProduct.introductoryPrice;
  if (intro == null) {
    return StorefrontPrice(
      priceString: product.price,
      currencyCode: product.currencyCode,
    );
  }
  final free =
      intro.paymentMode == SKProductDiscountPaymentMode.freeTrail ||
      _numericAmountIsZero(intro.price);
  final introText =
      free
          ? null
          : _storeLocaleAmount(
            currencySymbol: intro.priceLocale.currencySymbol,
            currencyCode: intro.priceLocale.currencyCode,
            amount: intro.price,
          );
  if (!free && (introText == null || introText == product.price)) {
    return StorefrontPrice(
      priceString: product.price,
      currencyCode: product.currencyCode,
    );
  }
  return StorefrontPrice(
    priceString: product.price,
    currencyCode: product.currencyCode,
    introductoryPriceString: introText,
    introductoryPeriodLabel: _applePeriod(
      intro.subscriptionPeriod,
      intro.numberOfPeriods,
    ),
    introductoryPriceIsFree: free,
  );
}

/// StoreKit reports an introductory amount and the locale's own symbol
/// separately. The regular product price is already formatted by StoreKit.
String? _storeLocaleAmount({
  required String currencySymbol,
  required String currencyCode,
  required String amount,
}) {
  final value = amount.trim();
  if (value.isEmpty) return null;
  final token =
      currencySymbol.trim().isNotEmpty
          ? currencySymbol.trim()
          : currencyCode.trim();
  if (token.isEmpty) return value;
  return '$token$value';
}

String? _applePeriod(SKProductSubscriptionPeriodWrapper period, int cycles) {
  if (period.numberOfUnits <= 0) return null;
  final repeats = cycles <= 0 ? 1 : cycles;
  final unit = switch (period.unit) {
    SKSubscriptionPeriodUnit.day => 'day',
    SKSubscriptionPeriodUnit.week => 'week',
    SKSubscriptionPeriodUnit.month => 'month',
    SKSubscriptionPeriodUnit.year => 'year',
  };
  return _periodLabel(period.numberOfUnits * repeats, unit);
}

StorefrontPrice? _fromAppStore2(AppStoreProduct2Details product) {
  if (product.price.trim().isEmpty) return null;
  final listed = StorefrontPrice(
    priceString: product.price,
    currencyCode: product.currencyCode,
  );
  final intro = _sk2IntroductoryOffer(product.sk2Product);
  if (intro == null) return listed;
  final free =
      intro.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial ||
      intro.price == 0;
  final introText =
      free
          ? null
          : storeAmountLikeSample(
            sample: product.price,
            currencySymbol: product.currencySymbol,
            amount: intro.price,
          );
  if (!free && (introText == null || introText == product.price)) return listed;
  return StorefrontPrice(
    priceString: product.price,
    currencyCode: product.currencyCode,
    introductoryPriceString: introText,
    introductoryPeriodLabel: _sk2Period(intro.period, intro.periodCount),
    introductoryPriceIsFree: free,
  );
}

SK2SubscriptionOffer? _sk2IntroductoryOffer(SK2Product product) {
  final offers = product.subscription?.promotionalOffers;
  if (offers == null) return null;
  for (final offer in offers) {
    if (offer.type == SK2SubscriptionOfferType.introductory) return offer;
  }
  return null;
}

String? _sk2Period(SK2SubscriptionPeriod period, int cycles) {
  if (period.value <= 0) return null;
  final repeats = cycles <= 0 ? 1 : cycles;
  final unit = switch (period.unit) {
    SK2SubscriptionPeriodUnit.day => 'day',
    SK2SubscriptionPeriodUnit.week => 'week',
    SK2SubscriptionPeriodUnit.month => 'month',
    SK2SubscriptionPeriodUnit.year => 'year',
  };
  return _periodLabel(period.value * repeats, unit);
}

String? _periodLabel(int count, String singular) {
  if (count <= 0) return null;
  if (count == 1) return singular;
  return '$count ${singular}s';
}

/// Formats [amount] with the symbol, grouping, and fraction digits already
/// present in the store's [sample] price. The amount is not converted.
String? storeAmountLikeSample({
  required String sample,
  required String currencySymbol,
  required double amount,
}) {
  if (amount.isNaN || amount.isInfinite || amount < 0) return null;
  final pattern = _pricePattern(sample, currencySymbol);
  if (pattern == null) return _fallbackAmount(sample, currencySymbol, amount);
  return _applyPricePattern(pattern, amount);
}

class _PricePattern {
  const _PricePattern({
    required this.symbol,
    required this.symbolFirst,
    required this.gap,
    required this.group,
    required this.decimal,
    required this.fractionDigits,
  });

  final String symbol;
  final bool symbolFirst;
  final String gap;
  final String group;
  final String decimal;
  final int fractionDigits;
}

_PricePattern? _pricePattern(String sample, String currencySymbol) {
  final symbol = currencySymbol.trim();
  var text = sample.trim();
  if (text.isEmpty) return null;
  var symbolFirst = true;
  var gap = '';
  if (symbol.isNotEmpty && text.startsWith(symbol)) {
    final rest = text.substring(symbol.length);
    gap = rest.startsWith(' ') ? ' ' : '';
    text = rest.trimLeft();
  } else if (symbol.isNotEmpty && text.endsWith(symbol)) {
    symbolFirst = false;
    final rest = text.substring(0, text.length - symbol.length);
    gap = rest.endsWith(' ') ? ' ' : '';
    text = rest.trimRight();
  } else if (symbol.isNotEmpty) {
    return null;
  }
  if (!RegExp(r'^[\d.,\s]+$').hasMatch(text)) return null;
  var decimal = '';
  var fractionDigits = 0;
  var integerPart = text;
  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  final decIndex = lastDot > lastComma ? lastDot : lastComma;
  if (decIndex >= 0) {
    final tail = text.substring(decIndex + 1).replaceAll(RegExp(r'\s'), '');
    if (RegExp(r'^\d{1,2}$').hasMatch(tail)) {
      decimal = text[decIndex];
      fractionDigits = tail.length;
      integerPart = text.substring(0, decIndex);
    }
  }
  final groupMatch = RegExp(r'[^\d]').firstMatch(integerPart);
  final group = groupMatch?.group(0) ?? '';
  if (group == decimal) return null;
  return _PricePattern(
    symbol: symbol,
    symbolFirst: symbolFirst,
    gap: gap,
    group: group,
    decimal: decimal,
    fractionDigits: fractionDigits,
  );
}

String _applyPricePattern(_PricePattern pattern, double amount) {
  final fixed = amount.toStringAsFixed(pattern.fractionDigits);
  final parts = fixed.split('.');
  final digits = _groupDigits(parts.first, pattern.group);
  final number =
      pattern.fractionDigits == 0
          ? digits
          : '$digits${pattern.decimal}${parts[1]}';
  if (pattern.symbol.isEmpty) return number;
  if (pattern.symbolFirst) return '${pattern.symbol}${pattern.gap}$number';
  return '$number${pattern.gap}${pattern.symbol}';
}

String _groupDigits(String digits, String group) {
  if (group.isEmpty || digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(group);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _fallbackAmount(String sample, String currencySymbol, double amount) {
  final symbol = currencySymbol.trim();
  final digits = amount.toStringAsFixed(2);
  if (symbol.isEmpty) return digits;
  if (sample.trim().endsWith(symbol)) return '$digits $symbol';
  return '$symbol$digits';
}

bool _numericAmountIsZero(String amount) {
  final value = double.tryParse(amount.trim().replaceAll(',', ''));
  return value == 0;
}
