// ─────────────────────────────────────────────────────────────
// deteccion_plataforma.dart — Detección global de la plataforma
// de ejecución (celular/tablet/escritorio/TV) usada por TODAS las
// vistas para elegir entre el layout móvil (diseño actual: bottom
// nav + full width) y el layout de escritorio (sidebar + paneles +
// contenido centrado). Centraliza la lógica para que ninguna vista
// duplique Platform.isAndroid / MediaQuery width checks.
//
// [plataformaUi] es el selector de TRES VÍAS que usan los selector de
// vistas (pagina_*): devuelve `tv`, `celu` o `pc` y con eso cada vista elige
// su variante (<x>_tv / <x>_movil / <x>_escritorio). Antes la TV caía en el
// layout de escritorio; ahora tiene el suyo.
// Se conecta con: features (pagina_* que eligen vista por
// plataforma) + shared/widgets.
// Parte del flujo: presentación (elección de layout global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

import 'tv/deteccion_tv.dart';

/// Ancho mínimo de pantalla (px) para considerar layout de escritorio.
const double anchoMinimoEscritorio = 900;

/// Ancho mínimo de pantalla (px) para considerar Smart TV.
/// TVs Android típicamente reportan 960px+ de ancho.
const double anchoMinimoTV = 960;

/// True en Android/iOS (celular real, layout móvil por defecto).
bool esMovil() {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

/// True en Windows/Linux/macOS (escritorio real).
bool esEscritorio() {
  if (kIsWeb) return true; // Web se trata como escritorio.
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// True en pantallas anchas (tablet landscape o ventana de escritorio
/// redimensionada), independientemente del SO.
bool esPantallaAncha(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= anchoMinimoEscritorio;
}

/// True en Smart TV (Android TV, Google TV, Fire TV Stick).
///
/// Manda lo que dice el SISTEMA ([esTelevisor]): es lo único confiable en TVs
/// que reportan poco ancho (720p), donde el proxy por tamaño las tomaría por
/// un celular. El ancho queda solo como respaldo si el nativo no respondió.
bool esSmartTV(BuildContext context) {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  if (esTelevisor) return true;
  final width = MediaQuery.sizeOf(context).width;
  return width >= anchoMinimoTV;
}

/// Decide si esta sesión usa el layout de escritorio:
/// plataforma de escritorio/web, Smart TV, O ventana lo suficientemente ancha.
/// Es el selector ÚNICO que usan las páginas para elegir vista.
bool usarLayoutEscritorio(BuildContext context) {
  return esEscritorio() || esSmartTV(context) || esPantallaAncha(context);
}

/// Decide si esta sesión usa el layout de TV.
///
/// Se pregunta PRIMERO que el de escritorio, porque Android TV también reporta
/// ser Android y una tele ancha también entra en [usarLayoutEscritorio]: sin
/// este orden, la TV terminaría usando la variante de PC. El selector de cada
/// vista queda, entonces, en tres pasos: TV → escritorio → celular.
bool usarLayoutTv(BuildContext context) => esSmartTV(context);
