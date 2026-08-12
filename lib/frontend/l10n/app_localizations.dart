import 'package:flutter/material.dart';
import 'strings/strings_splash.dart';
import 'strings/strings_setup.dart';

class AppLocalizations {
  final Locale locale;
  late final StringsSplash splash;
  late final StringsSetup setup;

  AppLocalizations(this.locale) {
    final isEn = locale.languageCode == 'en';
    splash = isEn ? StringsSplash.en : StringsSplash.es;
    setup = isEn ? StringsSetup.en : StringsSetup.es;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

