import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/store/country_currency.dart';
import 'package:pelevo/features/store/fx_auto_io.dart'
    if (dart.library.html) 'package:pelevo/features/store/fx_auto_web.dart';

/// Units of [currency] for one US dollar.
///
/// A reviewed board from `GET /fx/rates` replaces the automatic quote for the
/// currencies finance has set. Every other currency stays on the automatic
/// USD board so a store-style local price can be shown worldwide.
class FxRateBook {
  const FxRateBook({
    required this.rates,
    required this.source,
    required this.quotedAt,
    this.reviewed = const {},
  });

  final Map<String, double> rates;
  final String source;
  final DateTime? quotedAt;
  final Set<String> reviewed;

  bool get hasQuotes => rates.keys.any((code) => code != 'USD');

  double? rateFor(String currency) {
    final code = currency.trim().toUpperCase();
    if (code == 'USD') return 1;
    final rate = rates[code];
    if (rate == null || rate <= 0 || !rate.isFinite) return null;
    return rate;
  }

  static FxRateBook usdOnly() => FxRateBook(
    rates: const {'USD': 1},
    source: 'auto',
    quotedAt: null,
  );

  static FxRateBook merge({FxRateBook? auto, FxRateBook? reviewed}) {
    final rates = <String, double>{'USD': 1, ...?auto?.rates};
    rates['USD'] = 1;
    final locked = <String>{};
    if (reviewed != null) {
      final keys = reviewed.source == 'reviewed'
          ? reviewed.rates.keys
          : reviewed.reviewed;
      for (final code in keys) {
        final rate = reviewed.rates[code];
        if (rate == null || rate <= 0 || !rate.isFinite) continue;
        rates[code] = rate;
        locked.add(code);
      }
    }
    final source = locked.isEmpty
        ? 'auto'
        : auto == null || !auto.hasQuotes
        ? 'reviewed'
        : 'mixed';
    return FxRateBook(
      rates: Map.unmodifiable(rates),
      source: source,
      quotedAt: reviewed?.quotedAt ?? auto?.quotedAt,
      reviewed: Set.unmodifiable(locked),
    );
  }

  factory FxRateBook.parse(Map<String, dynamic> data) {
    if ('${data['base'] ?? 'USD'}'.toUpperCase() != 'USD') {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Exchange rates must use USD as the lead currency.',
      );
    }
    final raw = data['rates'];
    if (raw is! Map) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Exchange rates could not be verified.',
      );
    }
    final rates = <String, double>{'USD': 1};
    for (final entry in raw.entries) {
      final code = '${entry.key}'.trim().toUpperCase();
      final rate = _rate(entry.value);
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) || rate == null) continue;
      rates[code] = rate;
    }
    final reviewed = <String>{};
    final listed = data['reviewed'];
    if (listed is List) {
      for (final code in listed) {
        final value = '$code'.trim().toUpperCase();
        if (rates.containsKey(value)) reviewed.add(value);
      }
    }
    final source = '${data['source'] ?? 'auto'}'.toLowerCase();
    return FxRateBook(
      rates: Map.unmodifiable(rates),
      source: source == 'reviewed' ? 'reviewed' : 'auto',
      quotedAt: DateTime.tryParse('${data['quoted_at'] ?? ''}'),
      reviewed: Set.unmodifiable(reviewed),
    );
  }
}

double? _rate(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || parsed <= 0 || !parsed.isFinite) return null;
  return parsed;
}

int fractionDigits(String currency) {
  if (_threeDecimal.contains(currency)) return 3;
  if (_zeroDecimal.contains(currency)) return 0;
  return 2;
}

const _zeroDecimal = {
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'ISK',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
};

const _threeDecimal = {'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'};

String formatMoney(int minor, String currency) {
  final digits = fractionDigits(currency);
  final negative = minor < 0;
  final absolute = minor.abs();
  final scale = _pow10(digits);
  final whole = digits == 0 ? absolute : absolute ~/ scale;
  final fraction = digits == 0 ? '' : '.${(absolute % scale).toString().padLeft(digits, '0')}';
  final text = '${negative ? '-' : ''}${_grouped(whole)}$fraction';
  final symbol = _symbols[currency];
  if (symbol == null) return '$currency $text';
  return '$symbol$text';
}

const _symbols = {
  'USD': r'$',
  'NGN': '₦',
  'GBP': '£',
  'EUR': '€',
  'GHS': 'GH₵',
  'KES': 'KSh ',
  'ZAR': 'R',
  'CAD': r'CA$',
  'AUD': r'A$',
  'JPY': '¥',
  'CNY': '¥',
  'INR': '₹',
  'XOF': 'CFA ',
  'XAF': 'FCFA ',
};

String _grouped(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

int _pow10(int digits) {
  var scale = 1;
  for (var i = 0; i < digits; i++) {
    scale *= 10;
  }
  return scale;
}

/// Converts a USD cent amount into the listener's currency.
///
/// Missing rates stay in USD, which is the lead currency.
String localPriceFromUsd({
  required int usdMinor,
  required String countryCode,
  FxRateBook? rates,
  String suffix = '',
}) {
  final currency = currencyForCountry(countryCode);
  final rate = rates?.rateFor(currency);
  if (currency == 'USD' || rate == null) {
    return '${formatMoney(usdMinor, 'USD')}$suffix';
  }
  final digits = fractionDigits(currency);
  final minor = ((usdMinor / 100) * rate * _pow10(digits)).round();
  return '${formatMoney(minor, currency)}$suffix';
}

class FxRateRepository {
  FxRateRepository(this._dio);

  final Dio _dio;
  FxRateBook? _cached;
  DateTime? _cachedAt;

  static bool get autoFetchEnabled => fxAutoFetchEnabled;

  Future<FxRateBook> load() async {
    final cached = _cached;
    final at = _cachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(hours: 6)) {
      return cached;
    }
    final auto = autoFetchEnabled ? await _fetchAuto() : null;
    final reviewed = await _fetchReviewed();
    final book = FxRateBook.merge(auto: auto, reviewed: reviewed);
    if (book.hasQuotes) {
      _cached = book;
      _cachedAt = DateTime.now();
    }
    return book;
  }

  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  Future<FxRateBook?> _fetchReviewed() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/fx/rates');
      return FxRateBook.parse(requireApiData(response.data));
    } on Object {
      return null;
    }
  }

  Future<FxRateBook?> _fetchAuto() async {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    try {
      final response = await client.get<Map<String, dynamic>>(
        'https://open.er-api.com/v6/latest/USD',
      );
      final body = response.data;
      if (body == null || body['result'] != 'success') return null;
      final rates = body['rates'];
      if (rates is! Map) return null;
      final updated = body['time_last_update_unix'];
      return FxRateBook.parse({
        'base': 'USD',
        'source': 'auto',
        'quoted_at': updated is num
            ? DateTime.fromMillisecondsSinceEpoch(
                updated.toInt() * 1000,
                isUtc: true,
              ).toIso8601String()
            : null,
        'rates': rates,
      });
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

final fxRateRepositoryProvider = Provider<FxRateRepository>(
  (ref) => FxRateRepository(ref.watch(dioProvider)),
);

final fxRatesProvider = FutureProvider<FxRateBook>(
  (ref) => ref.watch(fxRateRepositoryProvider).load(),
);
