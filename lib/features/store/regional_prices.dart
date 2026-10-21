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
