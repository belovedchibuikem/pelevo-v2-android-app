/// Store list prices used until Apple or Google Play returns a localized price.
String listenerCountryCode({String? profileCountry, String? deviceCountry}) {
  final profile = profileCountry?.trim().toUpperCase();
  if (profile != null && RegExp(r'^[A-Z]{2}$').hasMatch(profile)) {
    return profile;
  }
  final device = deviceCountry?.trim().toUpperCase();
  if (device != null && RegExp(r'^[A-Z]{2}$').hasMatch(device)) return device;
  return 'US';
}

String seededCoinPrice(int coins, String countryCode) {
  final country = countryCode.toUpperCase();
  final listed = _coinLists[country] ?? _coinLists['US']!;
  final exact = listed[coins];
  if (exact != null) return exact;
  final rate = _coinUnitMinor[country] ?? _coinUnitMinor['US']!;
  final minor = (coins * rate).round();
  return _formatMinor(country, minor);
}

String seededPlusPrice(String countryCode, {required bool yearly}) {
  final country = countryCode.toUpperCase();
  final monthly = _plusMonthly[country] ?? _plusMonthly['US']!;
  if (!yearly) return '$monthly / month';
  final yearlyLabel = _plusYearly[country] ?? _plusYearly['US']!;
  return '$yearlyLabel / year';
}

bool plusIntervalIsYearly(String interval) {
  final value = interval.toLowerCase();
  return value.contains('year') || value.contains('annual');
}

const _coinLists = <String, Map<int, String>>{
  'NG': {
    300: '₦500',
    500: '₦800',
    750: '₦1,200',
    1000: '₦1,500',
    1200: '₦1,900',
    1500: '₦2,200',
    2000: '₦2,800',
    2500: '₦3,500',
    6500: '₦8,500',
    15000: '₦18,500',
  },
  'US': {
    300: r'$0.99',
    500: r'$1.49',
    750: r'$1.99',
    1000: r'$2.99',
    1200: r'$3.49',
    1500: r'$3.99',
    2000: r'$4.99',
    2500: r'$5.99',
    6500: r'$14.99',
    15000: r'$29.99',
  },
  'GB': {
    300: '£0.79',
    500: '£1.19',
    750: '£1.49',
    1000: '£2.49',
    1500: '£3.49',
    2000: '£3.99',
  },
  'GH': {
    300: 'GH₵15',
    500: 'GH₵25',
    750: 'GH₵35',
    1000: 'GH₵45',
    1500: 'GH₵65',
    2000: 'GH₵85',
  },
  'KE': {
    300: 'KSh 130',
    500: 'KSh 200',
    750: 'KSh 300',
    1000: 'KSh 390',
    1500: 'KSh 550',
    2000: 'KSh 720',
  },
  'ZA': {
    300: 'R18',
    500: 'R28',
    750: 'R40',
    1000: 'R55',
    1500: 'R75',
    2000: 'R99',
  },
};

/// Minor currency units per coin, used when a pack size is not listed.
const _coinUnitMinor = <String, double>{
  'NG': 150,
  'US': 0.25,
  'GB': 0.20,
  'GH': 4,
  'KE': 36,
  'ZA': 5,
};

const _plusMonthly = <String, String>{
  'NG': '₦1,600',
  'US': r'$10.50',
  'GB': '£8.49',
  'GH': 'GH₵165',
  'KE': 'KSh 1,350',
  'ZA': 'R195',
  'CA': r'CA$14.50',
};

const _plusYearly = <String, String>{
  'NG': '₦16,000',
  'US': r'$105.00',
  'GB': '£84.90',
  'GH': 'GH₵1,650',
  'KE': 'KSh 13,500',
  'ZA': 'R1,950',
  'CA': r'CA$145.00',
};

String _formatMinor(String country, num minor) {
  switch (country) {
    case 'NG':
      return '₦${_grouped(minor.round())}';
    case 'GB':
      return '£${(minor / 100).toStringAsFixed(2)}';
    case 'GH':
      return 'GH₵${minor.round()}';
    case 'KE':
      return 'KSh ${_grouped(minor.round())}';
    case 'ZA':
      return 'R${minor.round()}';
    default:
      return '\$${(minor / 100).toStringAsFixed(2)}';
  }
}

String _grouped(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
