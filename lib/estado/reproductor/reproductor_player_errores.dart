// ─────────────────────────────────────────────────────────────
// reproductor_player_errores.dart — PART de cubit_reproductor.dart:
// manejo de los errores del motor de audio. Un recurso fallando
// (403/expirado/HTML) hace que libmpv lo reabra en loop apretado
// spameando "Error decoding audio"; acá se corta ese loop — tras
// algunos fallos consecutivos se para el player y, si el archivo local
// quedó muerto, se re-descarga (acotado) antes de rendirse.
// Cadena de mixins: … → locales → player_errores → player_setup.
// Se conecta con: cubit_reproductor.dart (misma library).
// Parte del flujo: reproducción (errores del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

mixin ReproductorPlayerErrores on ReproductorLocales {
  void _manejarErrorPlayer(String error) {
// Mientras se recupera de un fallo de decode O se cambia de track,
    // ignorar errores residuales del media que se está deteniendo; si no,
    // un switch local↔stream rápido cuenta 3 errores y mata el track nuevo.
    if (_recuperando || _switchPendiente) return;
    // Un recurso fallando (403/expirado/HTML) hace que libmpv lo reabra en
    // loop apretado, spameando "Error decoding audio" para siempre. Romper
    // el loop: tras algunos fallos consecutivos, parar el player y marcar
    // el track como fallido.
    _erroresConsecutivos++;
    if (_erroresConsecutivos >= 3) {
      _erroresConsecutivos = 0;
      final fallido = _queueCubit.state.actual;
      final uriMuerta = _ultimaUriAbierta ?? '';
      if (fallido != null) {
        _urlRotaPorTrack[normalizarId(fallido.id)] = uriMuerta;
      }
      // Un archivo local que no decodifica reabriría para siempre. Parar el
      // media fallido PRIMERO (rompe la tormenta de errores de libmpv),
      // luego borrar el archivo muerto, dropear su resolución cacheada y
      // reintentar el MISMO track. Re-descargas acotadas por track.
      if (fallido != null && uriMuerta.startsWith('file://')) {
        final reintentos =
            (_reintentosArchivoMuerto[normalizarId(fallido.id)] ?? 0) + 1;
        _reintentosArchivoMuerto[normalizarId(fallido.id)] = reintentos;
        if (reintentos > 2) {
          _recuperando = true;
          // Serializado: stop encolado para no pisar un open en vuelo.
          unawaited(_enColaPlayer(() => _player.detener()));
          if (!isClosed) {
            emit(
              state.copiarCon(estadoReproduccion: EstadoReproduccion.error),
            );
          }
          return;
        }
        final fallidoNorm = normalizarId(fallido.id);
        _recuperando = true;
        _urlRotaPorTrack[fallidoNorm] = uriMuerta;
        _cacheUrlStream.remove(_claveCacheStream(fallidoNorm));
        unawaited(_borrarUriMuerta(uriMuerta));
        // Serializado: el stop (y el re-open que le sigue) espera su turno.
        unawaited(_enColaPlayer(() => _player.detener()));
        unawaited(_openTrack(fallido));
        return;
      }
      unawaited(_enColaPlayer(() => _player.detener()));
      if (!isClosed) {
        emit(state.copiarCon(estadoReproduccion: EstadoReproduccion.error));
      }
    }
  }
}
