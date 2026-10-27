import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

final _countryCode = RegExp(r'^[A-Za-z]{2}$');

/// Where this signup is happening: the network country, then the device locale.
Future<String?> detectSignupCountry() async {
  final lookedUp = await _networkCountry();
  if (lookedUp != null) return lookedUp;
  final locale = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  if (locale != null && _countryCode.hasMatch(locale)) {
    return locale.toUpperCase();
  }
  return null;
}

Future<String?> _networkCountry() async {
  try {
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    ).get<Map<String, dynamic>>('https://ipwho.is/');
    final data = response.data;
    if (data == null || data['success'] == false) return null;
    final code = data['country_code'];
    if (code is! String || !_countryCode.hasMatch(code)) return null;
    return code.toUpperCase();
  } on Object {
    return null;
  }
}
