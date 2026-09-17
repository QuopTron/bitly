// ─────────────────────────────────────────────────────────────
// constantes_fuente.dart — Constantes de proveedores de música:
// iconos por fuente, lista de fuentes disponibles, etiquetas
// legibles y helpers de formato (nombre legible, categoría de
// búsqueda, icono de filtro). Centraliza los ids de proveedores
// para que las vistas no repitan strings hardcodeados.
// Se conecta con: search, feed, detail (filtros y badges de fuente).
// Parte del flujo: presentación (proveedores y búsqueda).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Icono por id de proveedor ('' = agrupado, ya no se ofrece en la búsqueda).
const iconosFuente = <String, IconData>{
  '': Icons.dashboard_outlined,
  'deezer': Icons.library_music,
  'apple-music': Icons.apple,
  'soundcloud': Icons.cloud_queue,
  'spotify-web': Icons.music_note,
  'spotify': Icons.music_note,
  'pandora': Icons.radio,
  'amazon': Icons.shopping_bag,
  'qobuz-web': Icons.album,
  'tidal-web': Icons.waves,
  'ytmusic-spotiflac': Icons.play_circle_fill,
  // El audio sale de YouTube sí o sí, así que un resultado identificado por
  // Last.fm (nombre canónico + video oficial) entra con este id y se muestra
  // como YouTube: es de donde se va a reproducir.
  'youtube': Icons.play_circle_fill,
  'internetarchive': Icons.library_books,
};

/// Lista de todas las fuentes conocidas.
const todasLasFuentes = [
  'deezer', 'spotify-web', 'spotify', 'apple-music', 'soundcloud',
  'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac', 'internetarchive',
];

/// Fuentes de RESPALDO: no son catálogos navegables, existen para que el
/// pipeline consiga el lossless exacto detrás de un ISRC (flac-rescue,
/// internetarchive, soulseek, redacted) o para traer metadata (musicbrainz).
/// Nunca se ofrecen como fuente de búsqueda — es la misma lista que
/// `fuentesSoloRespaldo` del backend (go_backend/internal/gobackend/
/// search_fuentes.go), así que si se agrega una fuente ahí hay que agregarla
/// acá.
const fuentesSoloRespaldo = <String>{
  'flac-rescue',
  'flacrescue',
  'internetarchive',
  'soulseek',
  'redacted',
  'musicbrainz',
};

/// ¿Se puede ofrecer este id en el selector de fuente de búsqueda?
/// El id vacío se acepta solo por compatibilidad interna; la UI no lo ofrece.
bool esFuenteDeBusqueda(String id) =>
    id.isEmpty || !fuentesSoloRespaldo.contains(id);

/// Etiqueta legible por id de proveedor.
const etiquetasFuente = {
  '': 'Todas',
  'deezer': 'Deezer',
  'spotify-web': 'Spotify',
  'spotify': 'Spotify API',
  'apple-music': 'Apple',
  'soundcloud': 'SoundCloud',
  'pandora': 'Pandora',
  'amazon': 'Amazon',
  'qobuz-web': 'Qobuz',
  'tidal-web': 'TIDAL',
  'ytmusic-spotiflac': 'YouTube',
  'youtube': 'YouTube',
  'internetarchive': 'Internet Archive',
};

/// Convierte un id (p.ej. "spotify-web") a texto capitalizado legible.
String formatearId(String id) => id
    .replaceAll('-', ' ')
    .split(' ')
    .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
    .join(' ');

/// Nombre legible de una fuente. Prefiere [etiquetasFuente] para que los ids
/// crudos del backend no se filtren a la UI; cae a [formatearId] si no existe.
String nombreFuente(String id) => etiquetasFuente[id] ?? formatearId(id);

/// Mapea un id de filtro de búsqueda del manifest (p.ej. "track", "songs",
/// "albums") a la categoría canónica usada para agrupar resultados.
String categoriaBusquedaDe(String filterId) {
  switch (filterId.toLowerCase()) {
    case 'track': case 'tracks': case 'song': case 'songs': return 'tracks';
    case 'artist': case 'artists': return 'artists';
    case 'album': case 'albums': return 'albums';
    case 'playlist': case 'playlists': return 'playlists';
    default: return filterId;
  }
}

/// Icono de un filtro de búsqueda. Cae al icono de la categoría canónica
/// cuando el manifest lo deja vacío (p.ej. amazon).
IconData iconoFiltroBusqueda(String icon, String categoria) {
  switch (icon) {
    case 'music': return Icons.music_note;
    case 'album': return Icons.album;
    case 'artist': return Icons.person;
    case 'playlist': return Icons.playlist_play;
    default:
      switch (categoria) {
        case 'tracks': return Icons.music_note;
        case 'artists': return Icons.person;
        case 'albums': return Icons.album;
        case 'playlists': return Icons.playlist_play;
        default: return Icons.search;
      }
  }
}