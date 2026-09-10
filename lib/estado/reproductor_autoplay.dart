// ─────────────────────────────────────────────────────────────
// reproductor_autoplay.dart — PART de cubit_reproductor.dart:
// autoplay (modo radio): cuando la cola se agota, busca tracks
// similares al último reproducido vía getSimilarTracks del backend
// Go y reemplaza la cola. Fire-and-forget; los errores se ignoran.
// Se conecta con: reproductor_apertura.dart (misma library).
// Parte del flujo: reproducción (fin de cola → radio).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Autoplay de tracks similares. Mixin aplicado en CubitReproductor.
mixin ReproductorAutoplay on ReproductorApertura {
  /// Busca tracks similares al último reproducido y reemplaza la cola.
  Future<void> _intentarAutoplay() async {
    try {
      final ultimo = _queueCubit.state.tracks.last;
      if (ultimo.name.isEmpty || ultimo.artists == null) return;

      final backend = di.sl<BackendService>();
      // Params planos con las keys que espera Go (trackTitle/artistName/limit)
      // — antes se enviaban anidados en 'request' con snake_case y el backend
      // recibía título/artista vacíos (buscaba "" en todos los providers).
      final json = await backend.rpcCall('getSimilarTracks', {
        'trackTitle': ultimo.name,
        'artistName': ultimo.artists,
        'limit': 10,
      });
      if (json == null || json == '' || json == '[]') return;

      final lista = jsonDecode(json.toString()) as List;
      if (lista.isEmpty) return;

      final similares = lista.map((e) {
        final m = e as Map<String, dynamic>;
        return ItemFeed(
          id: (m['id'] ?? '').toString(),
          type: 'track',
          name: (m['name'] ?? '').toString(),
          artists: (m['artistName'] ?? '').toString(),
          coverUrl: (m['coverUrl'] ?? '').toString(),
          albumName: (m['albumName'] ?? '').toString(),
          isrc: (m['isrc'] ?? '').toString(),
          source: (m['source'] ?? 'deezer').toString(),
        );
      }).toList();

      // Reemplazar toda la cola con tracks similares (modo radio).
      _queueCubit.reemplazarCola(similares);
    } catch (_) {
      // Autoplay falló silenciosamente — no hay más tracks.
    }
  }
}