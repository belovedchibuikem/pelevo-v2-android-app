import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const pelevoThemeModeKey = 'pelevo_theme_mode';

class PelevoThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _decode(_preferences()?.getString(pelevoThemeModeKey));

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await _preferences()?.setString(pelevoThemeModeKey, _encode(mode));
  }

  SharedPreferences? _preferences() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }
}

final pelevoThemeModeProvider =
    NotifierProvider<PelevoThemeModeNotifier, ThemeMode>(
      PelevoThemeModeNotifier.new,
    );

ThemeMode _decode(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String _encode(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};
