// ─────────────────────────────────────────────────────────────
// acceso_descarga.dart — Gate de acceso a descargas: la ÚNICA
// diferencia entre Free y Premium son las descargas.
// - Premium (código activado/lifetime) → descargas siempre.
// - Free → descargas solo dentro de la ventana de trial de 8h
//   registrada en el setup (trial_expires_at).
// - El streaming NUNCA se ve afectado por este gate.
// Se conecta con: caches (CachePremium, CacheAjustes) vía inyección.
// Parte del flujo: botón de descarga (gate).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../../app/inyeccion.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../cache/almacenes/cache_premium.dart';

/// Resultado del gate de acceso a descargas.
enum AccesoDescarga { premium, ventanaFree, expirado }

/// Decide si el usuario puede descargar ahora mismo.
class VerificadorAccesoDescarga {
  static Future<AccesoDescarga> verificar() async {
    // 1. Premium / lifetime (tier local + vigencia) → siempre permitido.
    try {
      final estado = await sl<CachePremium>().getEstadoPremium();
      if (estado.esPremium) return AccesoDescarga.premium;
    } catch (e) {
      debugPrint('[AccesoDescarga] error leyendo premium: $e');
    }

    // 2. Modo free → permitido mientras dure la ventana de 8h.
    try {
      final setup = await sl<CacheAjustes>().cargarDatosSetup();
      if (setup != null && setup.mode == 'free' && setup.trialExpiraEn != null) {
        final exp = DateTime.tryParse(setup.trialExpiraEn!);
        if (exp != null) {
          return DateTime.now().isBefore(exp)
              ? AccesoDescarga.ventanaFree
              : AccesoDescarga.expirado;
        }
      }
    } catch (e) {
      debugPrint('[AccesoDescarga] error leyendo setup: $e');
    }

    // Sin datos de setup aún (no debería pasar post-setup) → tratar la
    // ventana free como activa para que los usuarios nuevos nunca queden
    // bloqueados por una fila faltante.
    return AccesoDescarga.ventanaFree;
  }
}