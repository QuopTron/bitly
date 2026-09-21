// ─────────────────────────────────────────────────────────────
// idioma_helper.dart — Helper del IDIOMA de la app: leerlo, cambiarlo y
// guardarlo, sin que cada pantalla tenga que conocer el notifier ni la
// caché (igual que AparienciaHelper y EstiloHelper).
//
// Cambiar el valor del notifier repinta la app entera con el locale nuevo
// (app_vista lo escucha), así que el cambio se ve al instante.
//
// Se conecta con: inyeccion (los singletons) y cache_ajustes (persistencia).
// Parte del flujo: Ajustes → Apariencia (selector de idioma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../l10n/app_localizations.dart';

/// Idiomas soportados por la app, con su nombre en el propio idioma.
const List<Locale> idiomasDisponibles = [Locale('es'), Locale('en')];

/// Nombre del idioma para mostrar en el selector.
String nombreDeIdioma(AppLocalizations loc, Locale idioma) {
  final t = loc.aparienciaEstilo;
  return idioma.languageCode == 'en' ? t.idiomaIngles : t.idiomaEspanol;
}

/// Acceso al idioma actual de la app.
class IdiomaHelper {
  IdiomaHelper._();

  /// Idioma activo ahora mismo.
  static Locale actual(BuildContext context) =>
      sl<ValueNotifier<Locale>>().value;

  /// ¿Este idioma es el que está puesto?
  static bool esActual(BuildContext context, Locale idioma) =>
      actual(context).languageCode == idioma.languageCode;

  /// Cambia el idioma y lo persiste. Si ya estaba puesto, no toca nada
  /// (así tocar dos veces el mismo idioma no reescribe la base).
  static void cambiar(BuildContext context, Locale idioma) {
    if (esActual(context, idioma)) return;
    sl<ValueNotifier<Locale>>().value = idioma;
    sl<CacheAjustes>().guardarIdioma(idioma.languageCode);
  }
}
