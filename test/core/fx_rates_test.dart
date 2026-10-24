import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/store/country_currency.dart';
import 'package:pelevo/features/store/fx_rates.dart';
import 'package:pelevo/features/store/regional_prices.dart';

void main() {
  test('listener country prefers the profile', () {
    expect(listenerCountryCode(profileCountry: 'ng'), 'NG');
    expect(listenerCountryCode(deviceCountry: 'us'), 'US');
    expect(currencyForCountry('NG'), 'NGN');
    expect(currencyForCountry('JP'), 'JPY');
    expect(currencyForCountry('ZZ'), 'USD');
  });

  test('a reviewed rate converts a USD amount for non-store balances', () {
    const rates = FxRateBook(
      rates: {'USD': 1, 'NGN': 1000, 'JPY': 150},
      source: 'reviewed',
      quotedAt: null,
      reviewed: {'NGN'},
    );
    expect(
      localPriceFromUsd(usdMinor: 49, countryCode: 'NG', rates: rates),
      '₦490.00',
    );
    expect(
      localPriceFromUsd(usdMinor: 100, countryCode: 'JP', rates: rates),
      '¥150',
    );
    expect(localPriceFromUsd(usdMinor: 49, countryCode: 'NG'), r'$0.49');
  });

  test('reviewed currencies override the automatic board', () {
    final merged = FxRateBook.merge(
      auto: FxRateBook(
        rates: const {'USD': 1, 'EUR': 0.9, 'NGN': 1500},
        source: 'auto',
        quotedAt: DateTime.utc(2026, 10, 19),
      ),
      reviewed: FxRateBook.parse({
        'base': 'USD',
        'source': 'auto',
        'reviewed': ['NGN'],
        'rates': {'NGN': '1600', 'EUR': '0.5'},
      }),
    );
    expect(merged.rateFor('NGN'), 1600);
    expect(merged.rateFor('EUR'), 0.9);
    expect(merged.rateFor('USD'), 1);
    expect(merged.reviewed, {'NGN'});
    expect(merged.source, 'mixed');
  });

  test('a fully reviewed board still fills currencies it does not list', () {
    final merged = FxRateBook.merge(
      auto: FxRateBook(
        rates: const {'USD': 1, 'GBP': 0.78, 'NGN': 1500},
        source: 'auto',
        quotedAt: DateTime.utc(2026, 10, 19),
      ),
      reviewed: FxRateBook.parse({
        'base': 'USD',
        'source': 'reviewed',
        'rates': {'NGN': '1700'},
      }),
    );
    expect(merged.rateFor('NGN'), 1700);
    expect(merged.rateFor('GBP'), 0.78);
    expect(merged.source, 'mixed');
  });

}
