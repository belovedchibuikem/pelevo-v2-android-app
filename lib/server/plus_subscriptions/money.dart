/// ISO 4217 minor-unit exponents for the Plus storefront currencies.
///
/// The API stores the charged amount. It does not convert ₦1,600 into another
/// currency.
const plusCurrencyExponent = <String, int>{
  'NGN': 2,
  'ZAR': 2,
  'KES': 2,
  'GHS': 2,
  'EGP': 2,
  'MAD': 2,
  'XOF': 0,
  'XAF': 0,
  'USD': 2,
};

/// Apple storefront codes (ISO 3166-1 alpha-3) used by the Plus countries.
const appleStorefrontCountry = <String, String>{
  'NGA': 'NG',
  'ZAF': 'ZA',
  'KEN': 'KE',
  'GHA': 'GH',
  'EGY': 'EG',
  'MAR': 'MA',
  'CIV': 'CI',
  'CMR': 'CM',
  'USA': 'US',
  'GBR': 'GB',
  'TZA': 'TZ',
  'UGA': 'UG',
};

class SubscriptionNoticeRejected implements Exception {
  SubscriptionNoticeRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

int exponentFor(String currency) {
  final code = currency.trim().toUpperCase();
  final exponent = plusCurrencyExponent[code];
  if (exponent == null) {
    throw SubscriptionNoticeRejected(
      'Currency $code is not a Plus storefront currency.',
    );
  }
  return exponent;
}

String requireCountryCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
    throw SubscriptionNoticeRejected(
      'Billing country must be the storefront ISO code.',
    );
  }
  return code;
}

String countryFromAppleStorefront(String? storefront) {
  final code = storefront?.trim().toUpperCase() ?? '';
  if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
  final country = appleStorefrontCountry[code];
  if (country == null) {
    throw SubscriptionNoticeRejected(
      'Apple storefront $code has no ISO country.',
    );
  }
  return country;
}

String requireCurrency(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  exponentFor(code);
  return code;
}

int _pow10(int exponent) {
  var scale = 1;
  for (var i = 0; i < exponent; i++) {
    scale *= 10;
  }
  return scale;
}

/// Apple's transaction `price` is in milliunits of the currency.
int minorFromAppleMilliunits(int milliunits, String currency) {
  if (milliunits < 0) {
    throw SubscriptionNoticeRejected('A store charge cannot be negative.');
  }
  final numerator = milliunits * _pow10(exponentFor(currency));
  if (numerator % 1000 != 0) {
    throw SubscriptionNoticeRejected(
      'Apple price $milliunits $currency does not land on a minor unit.',
    );
  }
  return numerator ~/ 1000;
}

/// Google recurring price: whole `units` plus `nanos` (billionths).
int minorFromUnitsAndNanos({
  required int units,
  required int nanos,
  required String currency,
}) {
  if (units < 0 || nanos < 0 || nanos > 999999999) {
    throw SubscriptionNoticeRejected('A store charge cannot be negative.');
  }
  final exponent = exponentFor(currency);
  final scale = _pow10(exponent);
  final denom = _pow10(9 - exponent);
  if (nanos % denom != 0) {
    throw SubscriptionNoticeRejected(
      'Google price $units.$nanos $currency does not land on a minor unit.',
    );
  }
  return units * scale + nanos ~/ denom;
}

/// RevenueCat sends the major amount charged in the store currency.
int minorFromMajorAmount(Object? amount, String currency) {
  final exponent = exponentFor(currency);
  final scale = _pow10(exponent);
  if (amount is int) {
    if (amount < 0) {
      throw SubscriptionNoticeRejected('A store charge cannot be negative.');
    }
    return amount * scale;
  }
  final text = amount is num ? amount.toString() : amount?.toString().trim();
  if (text == null || text.isEmpty) {
    throw SubscriptionNoticeRejected('The store charge amount is missing.');
  }
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null) {
    throw SubscriptionNoticeRejected('The store charge amount is not decimal.');
  }
  final whole = int.parse(match.group(1)!);
  final fraction = match.group(2) ?? '';
  if (fraction.length > exponent) {
    throw SubscriptionNoticeRejected(
      'The store charge has more precision than $currency allows.',
    );
  }
  final padded = fraction.padRight(exponent, '0');
  final fractional = padded.isEmpty ? 0 : int.parse(padded);
  return whole * scale + fractional;
}
