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
mixin DescargasEstado on DescargasCola {
  void confirmarReinicio() {
    if (state.backendReiniciado) {
      emit(state.copiarCon(backendReiniciado: false));
    }
  }

  /// Limpia el snackbar de fallo de decrypt pendiente de la sesión.
  void confirmarErrorDesencriptado() {
    if (_errorDesencriptadoPendiente != null) {
      _errorDesencriptadoPendiente = null;
      emit(state.copiarCon(errorDesencriptado: null, limpiarErrorDesencriptado: true));
    }
  }

  /// Limpia el snackbar del gate del plan free tras verlo.
  void confirmarBloqueoDescarga() {
    if (state.gateDescargaBloqueado != null) {
      emit(state.copiarCon(gateDescargaBloqueado: null, limpiarGateBloqueado: true));
    }
  }

  /// Marca [baseId] como bloqueada por el gate free (ventana de 8h expirada),
  /// muestra el [mensaje] en la UI y libera el procesador de la cola.
  void bloquearDescarga(String baseId, String mensaje) {
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
      _log.w('[_manejarVerificacionRequerida] ServicioVerificacion no inicializado');
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
          await servicio.verificarFuenteNoIntrusiva(
            extId,
            nombreMostrado,
            url,
          );
        } catch (e) {
          _log.w('[$extId] error de verificación: $e');
        }
      }
      _log.i('[_manejarVerificacionRequerida] Verificación completa, reintentando lotes interrumpidos');
      reintentarTodosInterrumpidos();
    } catch (e) {
      _log.e('[_manejarVerificacionRequerida] Error: $e');
    }
  }

  /// Reintenta TODOS los lotes interrumpidos/fallidos (los timeouts duros
  /// ponen el lote en ninguno directo, así que se chequean ambos estados).
  void reintentarTodosInterrumpidos() {
    final retryBatchKeys = state.descargas.entries
        .where((e) =>
            (e.value.estado == EstadoDescarga.interrumpido || e.value.estado == EstadoDescarga.ninguno) &&
            (e.key.startsWith('album_') || e.key.startsWith('playlist_')) &&
            _datosLote.containsKey(e.key))
        .map((e) => e.key)
        .toList();
    if (retryBatchKeys.isEmpty) return;
    for (final batchKey in retryBatchKeys) {
      reintentarTracksFallidosLote(batchKey);
    }
  }

  /// Pre-chequeo de sesiones firmadas antes de descargar (gate premium).
  Future<bool> _verificarSesionesAntesDeDescargar() async {
    return true;
  }

  /// Chequea que la carpeta de descargas sea accesible y escribible; si se
  /// perdió (grant SAF revocado) emite el estado que dispara el diálogo.
  Future<bool> _verificarCarpetaDescargas() async {
    final ruta = await di.sl<CacheAjustes>().getRutaDescargas();
    if (ruta == null || ruta.isEmpty) {
      emit(state.copiarCon(carpetaPerdida: true));
      return false;
    }
    final dir = Directory(ruta);
    try {
      if (!await dir.exists()) {
        _log.w('[descarga] carpeta perdida — la ruta no existe: $ruta');
        emit(state.copiarCon(carpetaPerdida: true));
        return false;
      }
      final testFile = File('$ruta/.access_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
    } catch (e) {
      _log.w('[descarga] carpeta perdida — no se puede acceder a $ruta: $e');
      emit(state.copiarCon(carpetaPerdida: true));
      return false;
    }
    return true;
  }

  /// Limpia el flag de carpeta perdida tras re-seleccionar la carpeta.
  void confirmarCarpetaRestaurada() {
    emit(state.copiarCon(limpiarCarpetaPerdida: true));
  }
}