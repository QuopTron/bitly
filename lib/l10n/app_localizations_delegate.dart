// ─────────────────────────────────────────────────────────────
// app_localizations_delegate.dart — PART de app_localizations.dart: el
// delegate que Flutter usa para resolver los textos por locale.
//
// Va aparte porque es plomería de Flutter (soporte de idiomas y carga), no la
// lista de textos.
//
// Se conecta con: app_localizations.dart (misma library).
// Parte del flujo: presentación (textos de toda la app).
// ─────────────────────────────────────────────────────────────

part of 'app_localizations.dart';

/// Delegate de Flutter: qué idiomas se soportan y cómo se cargan.
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
