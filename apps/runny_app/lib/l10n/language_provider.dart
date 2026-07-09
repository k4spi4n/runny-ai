import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  final SharedPreferences _prefs;
  
  Locale _locale;

  LanguageProvider(this._prefs) : _locale = _loadLocale(_prefs) {
    Intl.defaultLocale = _locale.languageCode;
  }

  Locale get locale => _locale;

  static Locale _loadLocale(SharedPreferences prefs) {
    final code = prefs.getString(_localeKey);
    // Mặc định Tiếng Việt; chỉ dùng Tiếng Anh khi người dùng đã chọn.
    if (code == 'en') return const Locale('en');
    return const Locale('vi');
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'vi'].contains(locale.languageCode)) return;
    
    _locale = locale;
    Intl.defaultLocale = locale.languageCode;
    notifyListeners();
    await _prefs.setString(_localeKey, locale.languageCode);
  }
}
