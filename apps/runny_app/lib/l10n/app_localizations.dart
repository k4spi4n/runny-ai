import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String>? _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    try {
      String jsonString = await rootBundle
          .loadString('lib/l10n/locales/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      return true;
    } catch (e) {
      debugPrint('Error loading localization: $e');
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key, [List<String>? args]) {
    if (_localizedStrings == null || !_localizedStrings!.containsKey(key)) {
      return key;
    }
    String translation = _localizedStrings![key]!;
    if (args != null && args.isNotEmpty) {
      for (var i = 0; i < args.length; i++) {
        translation = translation.replaceFirst('%s', args[i]);
      }
    }
    return translation;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'vi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsExtension on BuildContext {
  String translate(String key, [List<String>? args]) =>
      AppLocalizations.of(this)?.translate(key, args) ?? key;
}
