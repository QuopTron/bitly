// ─────────────────────────────────────────────────────────────
// descargas_estado.dart — PART de cubit_descargas.dart: acks de
// UI (reinicio, error de decrypt, gate, carpeta), bloqueo por gate
// free, manejo del estado "verification_required" de Go (WebView de
// cada proveedor + reintento de lotes), reintento de lotes
// interrumpidos y checks previos a descargar (carpeta y sesiones).
// Se conecta con: descargas_cola.dart (misma library).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Acks, gate y verificación. Mixin aplicado en CubitDescargas.
mixin DescargasEstado on DescargasEstadoReintento {
  void confirmarReinicio() {
    if (state.backendReiniciado) {
      emit(state.copiarCon(backendReiniciado: false));
    }
  }

  /// Limpia el snackbar de fallo de decrypt pendiente de la sesión.
  void confirmarErrorDesencriptado() {
    if (_errorDesencriptadoPendiente != null) {
      _errorDesencriptadoPendiente = null;
      emit(
        state.copiarCon(
          errorDesencriptado: null,
          limpiarErrorDesencriptado: true,
        ),
      );
    }
  }

  /// Limpia el snackbar del gate del plan free tras verlo.
  void confirmarBloqueoDescarga() {
    if (state.gateDescargaBloqueado != null) {
      emit(
        state.copiarCon(
          gateDescargaBloqueado: null,
          limpiarGateBloqueado: true,
        ),
      );
    }
  }

  /// Marca [baseId] como bloqueada por el gate free (ventana de 8h expirada),
  /// muestra el [mensaje] en la UI y libera el procesador de la cola.
  void bloquearDescarga(String baseId, String mensaje) {
    // Necesita al usuario: reintentar repetiría el mismo aviso.
    _falloReintentable = false;
    final dl = Map<String, DatosEstadoDescarga>.from(state.descargas);
    dl[baseId] = DatosEstadoDescarga(
      estado: EstadoDescarga.interrumpido,
      progreso: 0.0,
      mensajeError: mensaje,
    );
    emit(state.copiarCon(descargas: dl, gateDescargaBloqueado: mensaje));
    if (_completadorTrackActual != null &&
        !_completadorTrackActual!.isCompleted &&
        _idTrackActualCola == baseId) {
      _completadorTrackActual!.complete();
    }
  }

  /// Cuando _pollProgreso detecta "verification_required": recorre todos los
  /// proveedores, muestra el WebView de verificación de cada uno y reintenta
  /// los lotes interrumpidos al terminar.
  Future<void> _manejarVerificacionRequerida() async {
    _log.i('[_manejarVerificacionRequerida] Iniciando...');
    final servicio = ServicioVerificacion();
    if (!servicio.estaListo) {
      _log.w(
        '[_manejarVerificacionRequerida] ServicioVerificacion no inicializado',
      );
      return;
    }
    // Sin fuentes con sesión firmada no hay nada que verificar: el
    // "verification_required" del backend es un falso positivo (p.ej. error de
    // red clasificado erróneamente). Cortamos para no abrir el WebView.
    if (ServicioVerificacion.fuentesSesionFirmada.isEmpty) {
      _log.i(
        '[_manejarVerificacionRequerida] sin fuentes con sesión firmada, skip',
      );
      return;
    }
    try {
      for (final extId in _nombresMostrarProveedor.keys) {
        try {
          var url = await _backend.getPendingVerificationUrl(extId);
          _log.i('[$extId] getPendingVerificationUrl -> "$url"');
          if (url.isEmpty) {
            url = await _backend.triggerExtensionVerification(extId);
            _log.i('[$extId] triggerExtensionVerification -> "$url"');
          }
          if (url.isEmpty) {
            _log.i('[$extId] sin URL de auth pendiente, saltando');
            continue;
          }
          final nombreMostrado = _nombresMostrarProveedor[extId] ?? extId;
          // NUNCA abrir una cadena de modals: intento silencioso + aviso con
          // acción "Verificar" (el usuario decide cuándo resolver).
          _log.i('[$extId] verificando sin intrusión ($nombreMostrado)');
          await servicio.verificarFuenteNoIntrusiva(extId, nombreMostrado, url);
        } catch (e) {
          _log.w('[$extId] error de verificación: $e');
        }
      }
      _log.i(
        '[_manejarVerificacionRequerida] Verificación completa, reintentando lotes interrumpidos',
      );
      reintentarTodosInterrumpidos();
    } catch (e) {
      _log.e('[_manejarVerificacionRequerida] Error: $e');
    }
  }

  /// Reintenta TODOS los lotes interrumpidos/fallidos (los timeouts duros
  /// ponen el lote en ninguno directo, así que se chequean ambos estados).
}
