import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _themeKey = 'theme_mode';

  ThemeModeNotifier(this._prefs) : super(_loadTheme(_prefs));

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'light') return ThemeMode.light;
    if (savedTheme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setString(_themeKey, mode.name);
  }
}
