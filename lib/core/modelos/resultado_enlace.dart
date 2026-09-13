// ─────────────────────────────────────────────────────────────
// resultado_enlace.dart — Modelo del enlace resuelto por Go.
//
// Qué es: la respuesta de resolveUrl, ya normalizada: el ítem principal
// (canción, álbum, artista o playlist) y, cuando es una colección, sus
// tracks. Así la app puede reproducir un enlace compartido sin volver a
// buscarlo por nombre.
//
// Se conecta con: modelos/item_feed.dart + backend_go (RPC resolveUrl).
// Parte del flujo: enlaces compartidos/pegados → item reproducible.
// ─────────────────────────────────────────────────────────────

import './feed/item_feed.dart';

/// Resultado de resolver un enlace de música (Spotify, YouTube, Deezer...).
class ResultadoEnlace {
  /// Ítem principal: la canción, el álbum, el artista o la playlist.
  final ItemFeed item;

  /// Tracks de la colección (álbum/playlist). Vacío para una canción suelta.
  final List<ItemFeed> tracks;

  const ResultadoEnlace({required this.item, this.tracks = const []});

  /// true cuando el enlace apunta a algo que se reproduce en lista.
  bool get esColeccion => tracks.isNotEmpty;

  /// Tracks listos para la cola: la colección o, si es una canción, ella misma.
  List<ItemFeed> get paraReproducir =>
      tracks.isNotEmpty ? tracks : [item];

  factory ResultadoEnlace.desdeJson(Map<String, dynamic> json) {
    final crudos = json['tracks'];
    final tracks = crudos is List
        ? crudos
            .whereType<Map>()
            .map((e) => ItemFeed.desdeJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ItemFeed>[];
    return ResultadoEnlace(
      item: ItemFeed.desdeJson(json),
      tracks: tracks,
    );
  }
}
