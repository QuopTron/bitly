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

/// Icono por id de proveedor ('' = todas las fuentes).
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
};

/// Lista de todas las fuentes disponibles.
const todasLasFuentes = [
  'deezer', 'spotify-web', 'spotify', 'apple-music', 'soundcloud',
  'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
];

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