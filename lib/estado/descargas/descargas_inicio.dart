// ─────────────────────────────────────────────────────────────
// descargas_inicio.dart — PART de cubit_descargas.dart: punto de
// entrada de descargas INDIVIDUALES y la declaración que comparten
// los lotes. El encolado real de un track único vive en
// `encolarTrackIndividual` (descargas_cola_verificar.dart) y SIEMPRE
// usa los ajustes del usuario — así el single, el álbum y la playlist
// respetan la misma calidad, letras y video, y entran a la MISMA cola
// FIFO.
//
// Antes existía acá un `iniciarDescarga` que encolaba con
// `const AjustesDescarga()` (calidad/letras/video por defecto, no las
// del usuario) y ninguna vista lo llamaba: se eliminó para no dejar un
// segundo camino de descarga que ignorara los ajustes.
// Se conecta con: descargas_cola_verificar.dart + descargas_inicio_album
// .dart + descargas_inicio_playlist.dart.
// Parte del flujo: descargas (entrada desde la UI).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Contrato compartido por los inicios de descarga (single/álbum/playlist).
/// Mixin aplicado en CubitDescargas.
mixin DescargasInicio on DescargasAcceso {
  /// Asegura que _metaTrack tenga metadata para un track rescatado (ya
  /// descargado) — implementación concreta en DescargasTrack (arriba).
  void _asegurarMetaTrack(
    String baseId,
    String normalizedId,
    Map<String, dynamic> trackMap,
    String source,
  );

  /// Ajustes de descarga a usar. Cuando quien inicia no los pasa, se leen del
  /// caché: la descarga SIEMPRE sigue lo que el usuario configuró (calidad,
  /// letras, video) y nunca cae a los defaults en silencio.
  Future<AjustesDescarga> ajustesDeDescarga([AjustesDescarga? dados]) async {
    if (dados != null) return dados;
    try {
      return await di.sl<CacheAjustes>().getAjustesDescarga();
    } catch (e) {
      debugPrint('[Descargas] ajustes no disponibles, usando defaults: $e');
      return const AjustesDescarga();
    }
  }
}
