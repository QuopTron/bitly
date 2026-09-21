// ─────────────────────────────────────────────────────────────
// caratula_util.dart — Reglas compartidas de carátulas: si una ruta
// local sirve de verdad (archivo que existe y no está vacío) y cuál
// es la mejor carátula disponible entre la del ítem y un respaldo.
//
// Por qué existe: una ruta local MUERTA (carpeta movida, instalación
// vieja, guardado que falló y dejó 0 bytes) le ganaba a la URL remota
// en `local ?? remota`, así que la tarjeta quedaba gris aunque la URL
// estuviera perfecta. Acá la ruta muerta se descarta.
// Se conecta con: dart:io (existeSync/lengthSync).
// Parte del flujo: Mi Espacio, búsqueda, detalle, reproductor.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';
/// True si [ruta] apunta a un archivo local y no a una URL http.
bool esRutaDeArchivo(String ruta) {
  if (ruta.isEmpty) return false;
  if (ruta.startsWith('http://') || ruta.startsWith('https://')) return false;
  return ruta.startsWith('/') ||
      ruta.startsWith(r'\\') ||
      (ruta.length > 3 && ruta[1] == ':');
}

/// True si [ruta] es una carátula local usable AHORA: archivo local que
/// existe y tiene contenido. Un guardado a medias deja un archivo de 0
/// bytes que `Image.file` no puede pintar (y sin error visible).
bool caratulaLocalUsable(String? ruta) {
  if (ruta == null || ruta.isEmpty) return false;
  if (!esRutaDeArchivo(ruta)) return false;
  try {
    final archivo = File(ruta);
    return archivo.existsSync() && archivo.lengthSync() > 0;
  } catch (e) {
    debugPrint('[caratula_util] $e');
    return false;
  }
}

/// Mejor carátula disponible: la de [caratula] si sirve (URL, o archivo
/// local que existe), y si no el [respaldo] (p. ej. la de la biblioteca).
/// Una ruta local muerta NO gana nunca. Devuelve null si no hay nada.
String? mejorCaratula(String? caratula, String? respaldo) {
  final propia = caratula?.trim() ?? '';
  final otra = respaldo?.trim() ?? '';
  if (propia.isEmpty) return otra.isEmpty ? null : otra;
  if (caratulaLocalUsable(propia)) return propia;
  // Ruta local que ya no está en disco: se prefiere cualquier respaldo.
  if (esRutaDeArchivo(propia)) return otra.isEmpty ? null : otra;
  return propia;
}

/// Carátula de una PLAYLIST: [propia] (la portada elegida por el usuario o la
/// que sincronizó el proveedor) gana SIEMPRE sobre la del like y la del lote de
/// descarga.
///
/// Por qué: el detalle resolvía primero la del like y después la del lote, así
/// que una playlist descargada (o con el corazón) mostraba el arte del
/// proveedor y "se comía" la foto que el usuario acababa de ponerle.
String? mejorCaratulaPlaylist(String? propia, String? like, String? lote) =>
    mejorCaratula(propia, mejorCaratula(like, lote));
