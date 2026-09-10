// ─────────────────────────────────────────────────────────────
// descargas_poll_item.dart — PART de cubit_descargas.dart: switch
// por status de CADA item del progreso de Go dentro del poll.
// 'completed'/'finalizing' delega en _procesarItemCompletado
// (descargas_poll_completado.dart), 'downloading'/'preparing'
// actualiza el progreso sin resucitar interrumpidos ni pisar
// completados (un proveedor perdedor puede seguir reportando
// 'downloading' después de que el ganador terminó), y
// 'failed'/'cancelled' delega en _procesarItemFallido
// (descargas_poll_fallido.dart). También salta entradas recién
// borradas por el usuario (resurrección fantasma).
// Se conecta con: descargas_poll_decrypt.dart (misma library).
// Parte del flujo: descargas (poll de progreso → items).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Procesamiento por status de cada item del poll. Mixin en CubitDescargas.
mixin DescargasPollItem on DescargasPollDecrypt {
  /// Procesa un item del progreso según su status. Devuelve true si cambió
  /// el estado. [dl] y [fps] son los maps mutables del ciclo de poll.
  Future<bool> _procesarItemPoll(
    String rawId,
    String stateKey,
    Map<String, dynamic> p,
    Map<String, DatosEstadoDescarga> dl,
    Set<String> fps,
  ) async {
    // Saltar entradas que el usuario acaba de borrar — el RPC cancel de Go
    // puede no haber surtido efecto aún, evitando resurrección fantasma.
    if (_borradosPendientes.contains(rawId)) return false;
    final status = _estadoDe(p);
    final progress = (p['progress'] ?? 0.0) as num;

    if (status == 'completed' || status == 'finalizing') {
      return _procesarItemCompletado(rawId, stateKey, p, dl, fps);
    }
    if (status == 'downloading' || status == 'preparing') {
      // No resucitar tracks marcados interrumpidos por timeout duro o
      // cancelación del usuario — el tracker de Go puede seguir mostrándolos
      // 'downloading' porque la goroutine no terminó. Y no pisar completados:
      // un proveedor perdedor (p.ej. Amazon .flac encriptado) puede reportar
      // 'downloading' después de que el ganador (Apple Music .m4a) terminó.
      final estadoActual = dl[stateKey]?.estado;
      if (estadoActual != EstadoDescarga.interrumpido &&
          estadoActual != EstadoDescarga.completado) {
        dl[stateKey] = DatosEstadoDescarga(
            estado: EstadoDescarga.enProgreso, progreso: progress.toDouble());
        return true;
      }
      return false;
    }
    if (status == 'failed' || status == 'cancelled') {
      return _procesarItemFallido(rawId, stateKey, p, dl);
    }
    return false;
  }
}