// ─────────────────────────────────────────────────────────────
// l10n_servicio.dart — Acceso a los strings localizados SIN
// BuildContext, para la capa de servicio/bloc (snacks, mensajes de
// error y textos que no nacen dentro de un widget).
//
// Lee el MISMO notifier de idioma que usa la UI (idioma_helper), así
// que respeta el idioma elegido. Si el notifier todavía no está
// registrado (tests, arranque temprano), cae a español en vez de
// romper.
//
// Se conecta con: inyeccion (el notifier de Locale) + app_localizations.
// Parte del flujo: mensajes de servicios y blocs.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../l10n/app_localizations.dart';

/// Acceso a AppLocalizations sin contexto para la capa de servicio.
class L10n {
  L10n._();

  /// Idioma activo, o español si el notifier no está disponible.
  static Locale get _locale {
    try {
      return sl<ValueNotifier<Locale>>().value;
    } catch (_) {
      return const Locale('es');
    }
  }

  /// Strings ya resueltos para el idioma activo.
  static AppLocalizations get actual => AppLocalizations(_locale);

  /// ¿El idioma activo es inglés?
  static bool get esIngles => _locale.languageCode == 'en';
}
