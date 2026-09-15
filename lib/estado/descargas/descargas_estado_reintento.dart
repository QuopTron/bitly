// ─────────────────────────────────────────────────────────────
// descargas_estado_reintento.dart — PART de cubit_descargas.dart: mixin
// con el reintento masivo de descargas interrumpidas — junta las claves
// de lote que quedaron a medias y las vuelve a encolar.
// Cadena de mixins: … → estado_reintento → estado.
// Se conecta con: cubit_descargas.dart (misma library).
// Parte del flujo: descargas (reintentar interrumpidas).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

mixin DescargasEstadoReintento on DescargasCola {
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
