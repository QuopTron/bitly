// ─────────────────────────────────────────────────────────────
// app_localizations.dart — AppLocalizations: agrupa todos los strings localizados de la app
// (setup, splash, red, tutorial) y expone el acceso por contexto y
// la selección de idioma (es/en).
// Se conecta con: strings/ (todos los archivos de strings).
// Parte del flujo: presentación (textos de toda la app).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'strings/strings_red.dart';
import 'strings/strings_splash.dart';
import 'strings/strings_setup.dart';
import 'strings/strings_tutorial.dart';
import 'strings/strings_tutorial_interactivo.dart';

class AppLocalizations {
  final Locale locale;
  late final StringsSplash splash;
  late final StringsSetup setup;
  late final StringsTutorial tutorial;
  late final StringsTutorialInteractivo tutorialInteractivo;
  late final StringsRed red;

  AppLocalizations(this.locale) {
    final isEn = locale.languageCode == 'en';
    splash = isEn ? StringsSplash.en : StringsSplash.es;
    setup = isEn ? StringsSetup.en : StringsSetup.es;
    tutorial = isEn ? StringsTutorial.en : StringsTutorial.es;
    tutorialInteractivo =
        isEn ? StringsTutorialInteractivo.en : StringsTutorialInteractivo.es;
    red = isEn ? StringsRed.en : StringsRed.es;
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

