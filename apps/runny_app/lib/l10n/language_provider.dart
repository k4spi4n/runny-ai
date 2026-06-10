import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  final SharedPreferences _prefs;
  
  Locale _locale;

  LanguageProvider(this._prefs) : _locale = _loadLocale(_prefs);

  Locale get locale => _locale;

  static Locale _loadLocale(SharedPreferences prefs) {
    final code = prefs.getString(_localeKey);
    if (code == 'vi') return const Locale('vi');
    return const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'vi'].contains(locale.languageCode)) return;
    
    _locale = locale;
    notifyListeners();
    await _prefs.setString(_localeKey, locale.languageCode);
  }
}
