import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_background.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _backgroundKey = 'app_background';
  final SharedPreferences _prefs;

  ThemeMode _themeMode;
  AppBackground _background;

  ThemeProvider(this._prefs)
    : _themeMode = _loadThemeMode(_prefs),
      _background = _loadBackground(_prefs);

  ThemeMode get themeMode => _themeMode;

  AppBackground get background => _background;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final mode = prefs.getString(_themeKey);
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    // First-time web visitors should see the intended dark landing page
    // regardless of Safari, OS, or embedded browser defaults.
    return ThemeMode.dark;
  }

  static AppBackground _loadBackground(SharedPreferences prefs) {
    final saved = prefs.getString(_backgroundKey);
    return AppBackground.values.firstWhere(
      (background) => background.name == saved,
      orElse: () => AppBackground.none,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setBackground(AppBackground background) async {
    if (_background == background) return;
    _background = background;
    notifyListeners();
    await _prefs.setString(_backgroundKey, background.name);
  }
}
