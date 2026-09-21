// ─────────────────────────────────────────────────────────────
// preferencias_estilo_json.dart — Guardar y leer el estilo con cover.
//
// Va aparte del modelo para que el modelo sea sólo datos, y acá vive lo
// único delicado: la MIGRACIÓN. El guardado viejo eran 5 booleanos (el modo
// Clásico/Spotify), donde un `true` era "todo el color del cover" y un
// `false` "nada". Se leen como 1 y 0, así que nadie pierde lo que había
// elegido al actualizar la app.
//
// Se conecta con: preferencias_estilo (el modelo) + cache_ajustes.
// Parte del flujo: arranque (leer) y Ajustes (guardar).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'preferencias_apariencia.dart' show acotar;
import 'preferencias_estilo.dart';

/// Serializa y deserializa [PreferenciasEstilo].
class PreferenciasEstiloJson {
  PreferenciasEstiloJson._();

  /// Texto para guardar en la base.
  static String codificar(PreferenciasEstilo prefs) => jsonEncode({
    'cardsCancion': prefs.cardsCancion,
    'cardsGrilla': prefs.cardsGrilla,
    'fondoPrincipal': prefs.fondoPrincipal,
    'fondoReproductor': prefs.fondoReproductor,
    'fondosModals': prefs.fondosModals,
  });

  /// Lee lo guardado; cualquier problema deja el estilo Normal (nunca rompe
  /// el arranque por una preferencia vieja o rota).
  static PreferenciasEstilo decodificar(String? raw) {
    if (raw == null || raw.isEmpty) return PreferenciasEstilo.normal;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return _desdeMapa(parsed);
    } catch (e) {
      debugPrint('[Estilo] preferencias ilegibles: $e');
    }
    return PreferenciasEstilo.normal;
  }

  /// Un nivel del mapa: acepta el número nuevo y el booleano viejo.
  static double _nivel(Map<String, dynamic> json, String clave) {
    final valor = json[clave];
    if (valor == true) return 1;
    if (valor == false) return 0;
    if (valor is num) return acotar(valor.toDouble(), 0, 1);
    return 0;
  }

  static PreferenciasEstilo _desdeMapa(Map<String, dynamic> json) {
    return PreferenciasEstilo(
      cardsCancion: _nivel(json, 'cardsCancion'),
      cardsGrilla: _nivel(json, 'cardsGrilla'),
      fondoPrincipal: _nivel(json, 'fondoPrincipal'),
      fondoReproductor: _nivel(json, 'fondoReproductor'),
      fondosModals: _nivel(json, 'fondosModals'),
    );
  }
}
