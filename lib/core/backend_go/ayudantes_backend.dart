// ─────────────────────────────────────────────────────────────
// ayudantes_backend.dart — Lógica compartida entre las
// implementaciones del backend (Android/Desktop) para construir y
// parsear datos sin duplicar código.
// Se conecta con: backend_go (implementaciones concretas).
// Parte del flujo: setup (buildSetupData) y parseo de respuestas RPC.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../modelos/datos_setup.dart';
import '../modelos/estado_premium.dart';
import '../modelos/item_feed.dart';
import '../modelos/seccion_feed.dart';

/// Helpers estáticos para armar/parsear payloads del backend.
class AyudantesBackend {
  /// Arma el payload de setup (datos de configuración inicial).
  /// Preserva timestamps de trial existentes para que el usuario NO pueda
  /// extender su trial gratuito reiniciando el setup repetidamente.
  static Map<String, dynamic> construirDatosSetup({
    required String locale,
    required String mode,
    required String username,
    String? codigoPremium,
    String? trialIniciadoEnExistente,
    String? trialExpiraEnExistente,
  }) {
    final datos = <String, dynamic>{
      'locale': locale,
      'mode': mode,
      'username': username,
      'setup_completed': true,
      'setup_completed_at': DateTime.now().toIso8601String(),
    };
    if (mode == 'free') {
      datos['trial_started_at'] = trialIniciadoEnExistente ?? DateTime.now().toIso8601String();
      datos['trial_expires_at'] = trialExpiraEnExistente ??
          DateTime.now().add(const Duration(hours: 8)).toIso8601String();
      datos['trial_used'] = true;
    }
    if (codigoPremium != null) {
      datos['premium_code'] = codigoPremium;
    }
    return datos;
  }

  static DatosSetup? parsearDatosSetup(dynamic resultado) {
    if (resultado == null || resultado == '') return null;
    final decodificado = jsonDecode(resultado as String);
    return DatosSetup.desdeJson(decodificado);
  }

  static EstadoPremium parsearEstadoPremium(dynamic resultado) {
    try {
      if (resultado == null || resultado == '') {
        return const EstadoPremium(tier: 'free', premiumHasta: 0, activo: false);
      }
      final decodificado = jsonDecode(resultado as String);
      return EstadoPremium.desdeJson(decodificado);
    } catch (_) {
      return const EstadoPremium(tier: 'free', premiumHasta: 0, activo: false);
    }
  }

  static List<SeccionFeed> parsearSeccionesFeed(dynamic resultado) {
    try {
      if (resultado is String && resultado.isNotEmpty) {
        final lista = jsonDecode(resultado) as List<dynamic>;
        return lista.map((e) => SeccionFeed.desdeJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static String? parsearResultadoValidacion(dynamic resultado) {
    try {
      if (resultado is String && resultado.isNotEmpty) {
        resultado = jsonDecode(resultado);
      }
      if (resultado is Map && resultado['valido'] == true) return null;
      if (resultado is Map && resultado['error'] is String) return resultado['error'];
      return 'Código inválido';
    } catch (_) {
      return 'Código inválido';
    }
  }

  static List<String> parsearBusquedasRecientes(dynamic resultado) {
    try {
      if (resultado is String && resultado.isNotEmpty) {
        final lista = jsonDecode(resultado) as List<dynamic>;
        return lista.cast<String>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static List<ItemFeed> parsearResultadosBusqueda(dynamic resultado) {
    try {
      if (resultado is String && resultado.isNotEmpty) {
        final lista = jsonDecode(resultado) as List<dynamic>;
        return lista.map((e) => ItemFeed.desdeJson(e as Map<String, dynamic>)).toList();
      }
      if (resultado is List) {
        return resultado.map((e) => ItemFeed.desdeJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}