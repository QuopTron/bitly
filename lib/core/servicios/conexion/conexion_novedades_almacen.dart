// ─────────────────────────────────────────────────────────────
// conexion_novedades_almacen.dart — Guarda qué novedades de la conexión el
// usuario YA VIO, para que el mininumerito no quede encendido para siempre.
//
// Son solo ids ('prueba', 'dev_xxx') en los ajustes locales: no hace falta
// esquema nuevo ni migrar nada. Si el guardado está roto, se arranca con el
// conjunto vacío (peor caso: se muestra un aviso de más, nunca de menos).
//
// Se conecta con: servicio_conexion (lo usa) + cache_ajustes.
// Parte del flujo: Ajustes → Conexión (novedades vistas).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../cache/almacenes/cache_ajustes.dart';

/// Clave única de los ajustes donde se guarda el conjunto.
const String _claveNovedadesVistas = 'conexion_novedades_vistas';

/// Los ids de las novedades que el usuario ya vio.
Future<Set<String>> leerNovedadesVistas(CacheAjustes cache) async {
  final raw = await cache.getAjuste(_claveNovedadesVistas);
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final parsed = jsonDecode(raw);
    if (parsed is List) {
      return {
        for (final e in parsed)
          if (e is String && e.isNotEmpty) e,
      };
    }
  } catch (e) {
    debugPrint('[Conexion] novedades vistas ilegibles: $e');
  }
  return <String>{};
}

/// Deja guardados los ids vistos (reemplaza el conjunto anterior).
Future<void> guardarNovedadesVistas(CacheAjustes cache, Set<String> ids) =>
    cache.guardarAjuste(_claveNovedadesVistas, jsonEncode(ids.toList()));
