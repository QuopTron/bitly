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
    final retryBatchKeys =
        state.descargas.entries
            .where(
              (e) =>
                  (e.value.estado == EstadoDescarga.interrumpido ||
                      e.value.estado == EstadoDescarga.ninguno) &&
                  (e.key.startsWith('album_') ||
                      e.key.startsWith('playlist_')) &&
                  _datosLote.containsKey(e.key),
            )
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

  /// Chequea que la carpeta de descargas sea accesible y escribible.
  ///
  /// Antes esto era un portazo: si la ruta guardada no existía (el caso típico
  /// es reinstalar la app, que invalida el permiso de la carpeta elegida con
  /// SAF, o abrir la app en otro dispositivo) TODA descarga fallaba con el
  /// diálogo de "carpeta perdida", aunque el teléfono tuviera lugar de sobra.
  ///
  /// Ahora se auto-repara: se intenta crear la ruta configurada y, si no se
  /// puede, la descarga sigue en la carpeta propia de la app (siempre
  /// escribible). El diálogo queda solo para el caso en que NINGUNA carpeta
  /// sirva, que es cuando de verdad hay que pedirle algo al usuario.
  Future<bool> _verificarCarpetaDescargas() async {
    final ruta = await di.sl<CacheAjustes>().getRutaDescargas();
    if (await _carpetaEscribible(ruta)) return true;

    // Segundo intento: crear la carpeta configurada (existe el caso de que la
    // eligiera el usuario y después la borró desde el explorador).
    if (ruta != null && ruta.isNotEmpty) {
      try {
        await Directory(ruta).create(recursive: true);
        if (await _carpetaEscribible(ruta)) {
          _log.i('[descarga] carpeta recreada: $ruta');
          return true;
        }
      } catch (e) {
        _log.w('[descarga] no se pudo recrear $ruta: $e');
      }
    }

    // Último recurso: la carpeta privada de la app, que nunca depende de un
    // permiso del sistema. Se guarda como ruta para que el resto del flujo
    // (borrado, biblioteca, sync con Go) apunte al mismo lugar.
    final respaldo = await _rutaRespaldoApp();
    if (respaldo != null && await _carpetaEscribible(respaldo)) {
      _log.w('[descarga] usando carpeta de respaldo de la app: $respaldo');
      await di.sl<CacheAjustes>().guardarRutaDescargas(respaldo);
      return true;
    }

    _log.e('[descarga] ninguna carpeta escribible — se pide al usuario');
    emit(state.copiarCon(carpetaPerdida: true));
    return false;
  }

  /// ¿Se puede escribir de verdad en [ruta]? (existencia + prueba real).
  Future<bool> _carpetaEscribible(String? ruta) async {
    if (ruta == null || ruta.isEmpty) return false;
    try {
      final dir = Directory(ruta);
      if (!await dir.exists()) return false;
      final testFile = File('$ruta/.access_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Carpeta propia de la app, sin permisos del sistema de por medio.
  Future<String?> _rutaRespaldoApp() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      return '${base.path}${Platform.pathSeparator}Bitly';
    } catch (e) {
      debugPrint('[descarga] sin carpeta de respaldo: $e');
      return null;
    }
  }

  /// Limpia el flag de carpeta perdida tras re-seleccionar la carpeta.
  void confirmarCarpetaRestaurada() {
    emit(state.copiarCon(limpiarCarpetaPerdida: true));
  }
}
