// ─────────────────────────────────────────────────────────────
// preferencias_vistas_json.dart — Guardar y leer el diseño por vista.
//
// Va aparte del modelo para que el modelo sea sólo datos y acá viva lo único
// delicado: la TOLERANCIA. Lo guardado viene de la versión anterior de la app
// (o de una vista que ya no existe), así que:
//   · una clave de vista desconocida se IGNORA (no rompe el arranque);
//   · una vista que quedó heredando no se guarda;
//   · un json roto devuelve el estado de fábrica.
//
// Se conecta con: preferencias_vistas (el modelo) + vista_app (las claves) +
// cache_ajustes (dónde se persiste).
// Parte del flujo: arranque (leer) y Ajustes (guardar).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'diseno_vista.dart';
import 'preferencias_vistas.dart';
import 'vista_app.dart';

/// Serializa y deserializa [PreferenciasVistas].
class PreferenciasVistasJson {
  PreferenciasVistasJson._();

  /// Texto para guardar en la base. La clave de cada entrada es la clave
  /// estable de la vista (no el índice del enum).
  static String codificar(PreferenciasVistas prefs) => jsonEncode({
    for (final e in prefs.vistas.entries) e.key.clave: e.value.aJson(),
  });

  /// Lee lo guardado. Cualquier problema deja el estado de fábrica.
  static PreferenciasVistas decodificar(String? raw) {
    if (raw == null || raw.isEmpty) return PreferenciasVistas.deFabrica;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return _desdeMapa(parsed);
    } catch (e) {
      debugPrint('[Vistas] preferencias ilegibles: $e');
    }
    return PreferenciasVistas.deFabrica;
  }

  static PreferenciasVistas _desdeMapa(Map<String, dynamic> json) {
    final mapa = <VistaApp, DisenoVista>{};
    for (final e in json.entries) {
      final vista = VistaApp.desdeClave(e.key);
      if (vista == null) continue;
      final valor = e.value;
      if (valor is! Map<String, dynamic>) continue;
      final diseno = DisenoVista.desdeJson(valor);
      if (diseno.esHereda) continue;
      mapa[vista] = diseno;
    }
    if (mapa.isEmpty) return PreferenciasVistas.deFabrica;
    return PreferenciasVistas(vistas: Map.unmodifiable(mapa));
  }
}
