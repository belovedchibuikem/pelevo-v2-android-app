import 'package:pelevo/features/store/fx_rates.dart';

/// Listener country: profile first, then the device locale, then the US.
String listenerCountryCode({String? profileCountry, String? deviceCountry}) {
  final profile = profileCountry?.trim().toUpperCase();
  if (profile != null && RegExp(r'^[A-Z]{2}$').hasMatch(profile)) {
    return profile;
  }
  final device = deviceCountry?.trim().toUpperCase();
  if (device != null && RegExp(r'^[A-Z]{2}$').hasMatch(device)) return device;
  return 'US';
}

bool plusIntervalIsYearly(String interval) {
  final value = interval.toLowerCase();
  return value.contains('year') || value.contains('annual');
}

/// USD shelf used as the lead price. Local currencies are converted from this.
const plusMonthlyUsdMinor = 1050;
const plusYearlyUsdMinor = 10500;

const _usdCoinMinor = <int, int>{
  300: 35,
  500: 49,
  750: 79,
  1000: 99,
  1200: 119,
  1500: 149,
  2000: 199,
  2500: 248,
  6500: 644,
  15000: 1485,
};

int usdMinorForCoins(int coins) {
  final listed = _usdCoinMinor[coins];
  if (listed != null) return listed;
  return (coins * 0.099).round();
}

int usdMinorForPlus({required bool yearly}) =>
    yearly ? plusYearlyUsdMinor : plusMonthlyUsdMinor;

String coinPriceLabel({
  required int coins,
  required String countryCode,
  FxRateBook? rates,
}) => localPriceFromUsd(
  usdMinor: usdMinorForCoins(coins),
  countryCode: countryCode,
  rates: rates,
);

String plusPriceLabel({
  required String countryCode,
  required bool yearly,
  FxRateBook? rates,
}) => localPriceFromUsd(
  usdMinor: usdMinorForPlus(yearly: yearly),
  countryCode: countryCode,
  rates: rates,
  suffix: yearly ? ' / year' : ' / month',
);
