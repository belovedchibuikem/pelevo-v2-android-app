import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/store/country_currency.dart';
import 'package:pelevo/features/store/fx_rates.dart';
import 'package:pelevo/features/store/regional_prices.dart';
import '../support/api_adapter.dart';

void main() {
  test('listener country prefers the profile', () {
    expect(listenerCountryCode(profileCountry: 'ng'), 'NG');
    expect(listenerCountryCode(deviceCountry: 'us'), 'US');
    expect(currencyForCountry('NG'), 'NGN');
    expect(currencyForCountry('JP'), 'JPY');
    expect(currencyForCountry('ZZ'), 'USD');
  });

  test('USD shelf stays the lead price', () {
    expect(coinPriceLabel(coins: 500, countryCode: 'US'), r'$0.49');
    expect(coinPriceLabel(coins: 1200, countryCode: 'US'), r'$1.19');
    expect(coinPriceLabel(coins: 400, countryCode: 'US'), r'$0.40');
    expect(
      plusPriceLabel(countryCode: 'US', yearly: false),
      r'$10.50 / month',
    );
    expect(coinPriceLabel(coins: 500, countryCode: 'NG'), r'$0.49');
  });

  test('a reviewed naira rate converts the USD shelf', () {
    const rates = FxRateBook(
      rates: {'USD': 1, 'NGN': 1000, 'JPY': 150},
      source: 'reviewed',
      quotedAt: null,
      reviewed: {'NGN'},
    );
    expect(
      coinPriceLabel(coins: 500, countryCode: 'NG', rates: rates),
      '₦490.00',
    );
    expect(
      plusPriceLabel(countryCode: 'NG', yearly: false, rates: rates),
      '₦10,500.00 / month',
    );
    expect(
      localPriceFromUsd(usdMinor: 100, countryCode: 'JP', rates: rates),
      '¥150',
    );
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

  test('admin save sends reviewed USD rates', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse({
        'base': 'USD',
        'source': 'reviewed',
        'reviewed': ['NGN'],
        'rates': {'NGN': '1600'},
      });
    });
    final repository = FxRateRepository(
      dio,
      adminFxUri: Uri.parse('https://api.invalid/api/admin/v1/settings/fx'),
    );

    final saved = await repository.saveReviewed({'ngn': 1600});

    expect(seen.method, 'PUT');
    expect(seen.uri.path, '/api/admin/v1/settings/fx');
    expect(seen.data['base'], 'USD');
    expect(seen.data['source'], 'reviewed');
    expect(seen.data['reviewed'], ['NGN']);
    expect(seen.data['rates'], {'NGN': '1600'});
    expect(saved.rateFor('NGN'), 1600);
    expect(saved.reviewed, {'NGN'});
  });
}
