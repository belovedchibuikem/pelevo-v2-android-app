import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/store/regional_prices.dart';

void main() {
  test('plus and coin prices follow the listener country', () {
    expect(listenerCountryCode(profileCountry: 'ng'), 'NG');
    expect(listenerCountryCode(deviceCountry: 'us'), 'US');
    expect(seededPlusPrice('NG', yearly: false), '₦1,600 / month');
    expect(seededPlusPrice('US', yearly: false), r'$10.50 / month');
    expect(seededCoinPrice(300, 'NG'), '₦500');
    expect(seededCoinPrice(300, 'US'), r'$0.99');
    expect(seededCoinPrice(2000, 'US'), r'$4.99');
  });
}
