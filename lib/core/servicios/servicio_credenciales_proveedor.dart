// ─────────────────────────────────────────────────────────────
// servicio_credenciales_proveedor.dart — Empuja las credenciales
// guardadas de los proveedores (CacheAjustes) al sistema de
// extensiones de Go al arrancar, y guarda/reinicializa credenciales
// al editar ajustes. Separado de la UI para no acoplar widget→backend.
// Se conecta con: backend_go (setExtensionSettings,
// reinitializeExtension) + cache_ajustes + modelos de proveedor.
// Parte del flujo: arranque y Ajustes → Credenciales.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../backend_go/contrato_backend.dart';
import '../cache/cache_ajustes.dart';
import '../modelos/config_proveedor.dart';

/// Empuja credenciales guardadas a Go y reinicializa las extensiones.
class ServicioCredencialesProveedor {
  final BackendService _backend;
  final CacheAjustes _cache;

  ServicioCredencialesProveedor(this._backend, this._cache);

  /// Empuja las credenciales guardadas de todos los proveedores a Go
  /// y reinicializa las extensiones relevantes.
  Future<void> empujarCredencialesAlArrancar() async {
    for (final proveedor in ConfigProveedor.todos) {
      await _empujarCredencialesProveedor(proveedor);
    }
  }

  /// Guarda credenciales localmente, las empuja a la extensión de Go y la
  /// reinicializa para que la función JS [initialize] pueda guardarlas vía
  /// [credentials.store].
  Future<void> guardarYReinicializar(
    String extensionId,
    Map<String, String> ajustes,
  ) async {
    // 1. Persistir localmente
    for (final e in ajustes.entries) {
      await _cache.guardarAjuste('${extensionId}_${e.key}', e.value);
    }

    // 2. Empujar al store en memoria de la extensión Go
    await _backend.rpcCall('setExtensionSettings', {
      'extension_id': extensionId,
      'settings': jsonEncode(ajustes),
    });

    // 3. Reinicializar la extensión para que initialize() guarde vía store
    await _backend.rpcCall('reinitializeExtension', {
      'extension_id': extensionId,
    });
  }

  /// Empuja las credenciales guardadas de un solo proveedor.
  Future<void> _empujarCredencialesProveedor(ConfigProveedor proveedor) async {
    final ajustes = <String, String>{};

    for (final campo in proveedor.campos) {
      final valor =
          (await _cache.getAjuste('${proveedor.id}_${campo.key}') ?? '').trim();
      if (valor.isNotEmpty) {
        ajustes[campo.key] = valor;
      }
    }
    // Los tokens OAuth producidos por la app (sin campo visible) también
    // deben sobrevivir reinicios: se empujan como campos para que la
    // extensión reinicialice con la sesión intacta.
    for (final clave in proveedor.clavesAjusteExtra) {
      final valor =
          (await _cache.getAjuste('${proveedor.id}_$clave') ?? '').trim();
      if (valor.isNotEmpty) {
        ajustes[clave] = valor;
      }
    }

    if (ajustes.isEmpty) {
      debugPrint('[CredencialesProveedor] Sin credenciales guardadas de ${proveedor.nombreMostrado}');
      return;
    }

    await _backend.rpcCall('setExtensionSettings', {
      'extension_id': proveedor.id,
      'settings': jsonEncode(ajustes),
    });

    await _backend.rpcCall('reinitializeExtension', {
      'extension_id': proveedor.id,
    });

    debugPrint('[CredencialesProveedor] Credenciales de ${proveedor.nombreMostrado} empujadas al arrancar');
  }
}