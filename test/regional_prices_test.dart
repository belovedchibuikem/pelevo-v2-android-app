import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/store/regional_prices.dart';

void main() {
  test('plus and coin prices follow the listener country', () {
    expect(listenerCountryCode(profileCountry: 'ng'), 'NG');
    expect(listenerCountryCode(deviceCountry: 'us'), 'US');
    expect(seededPlusPrice('NG', yearly: false), '₦1,600 / month');
    expect(seededPlusPrice('US', yearly: false), r'$10.50 / month');
    expect(seededCoinPrice(300, 'NG'), '₦500');
    expect(seededCoinPrice(500, 'NG'), '₦850');
    expect(seededCoinPrice(750, 'NG'), '₦1,250');
    expect(seededCoinPrice(1000, 'NG'), '₦1,700');
    expect(seededCoinPrice(1500, 'NG'), '₦2,500');
    expect(seededCoinPrice(2000, 'NG'), '₦3,350');
    expect(seededCoinPrice(1200, 'NG'), '₦2,040');
    expect(seededCoinPrice(2500, 'NG'), '₦4,250');
    expect(seededCoinPrice(6500, 'NG'), '₦11,050');
    expect(seededCoinPrice(15000, 'NG'), '₦25,500');
    expect(seededCoinPrice(400, 'NG'), '₦680');
    expect(seededCoinPrice(300, 'US'), r'$0.35');
    expect(seededCoinPrice(500, 'US'), r'$0.49');
    expect(seededCoinPrice(750, 'US'), r'$0.79');
    expect(seededCoinPrice(1000, 'US'), r'$0.99');
    expect(seededCoinPrice(1500, 'US'), r'$1.49');
    expect(seededCoinPrice(2000, 'US'), r'$1.99');
    expect(seededCoinPrice(1200, 'US'), r'$1.19');
    expect(seededCoinPrice(2500, 'US'), r'$2.48');
    expect(seededCoinPrice(6500, 'US'), r'$6.44');
    expect(seededCoinPrice(15000, 'US'), r'$14.85');
    expect(seededCoinPrice(400, 'US'), r'$0.40');
  });
}
