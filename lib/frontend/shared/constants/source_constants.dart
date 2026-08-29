import 'package:flutter/material.dart';

const sourceIcons = <String, IconData>{
  '': Icons.dashboard_outlined, // Todas: search all providers
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

const allSources = [
  'deezer', 'spotify-web', 'spotify', 'apple-music', 'soundcloud',
  'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
];

const sourceLabels = {
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

String formatId(String id) => id
  .replaceAll('-', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

/// Pretty, user-facing name for a source id. Prefers the curated [sourceLabels]
/// so raw backend ids (e.g. "spotify-web", "ytmusic-spotiflac") never leak into
/// the UI; falls back to a readable [formatId] for unknown ids.
String sourceDisplayName(String id) => sourceLabels[id] ?? formatId(id);

/// Maps a manifest search-filter id (e.g. "track", "songs", "albums") to the
/// canonical category used consistently for grouping search results.
String searchCategoryOf(String filterId) {
  switch (filterId.toLowerCase()) {
    case 'track': case 'tracks': case 'song': case 'songs': return 'tracks';
    case 'artist': case 'artists': return 'artists';
    case 'album': case 'albums': return 'albums';
    case 'playlist': case 'playlists': return 'playlists';
    default: return filterId;
  }
}

/// Maps a manifest filter icon string to its Material icon. Falls back to the
/// canonical category's icon when the manifest leaves it empty (e.g. amazon).
IconData searchFilterIcon(String icon, String category) {
  switch (icon) {
    case 'music': return Icons.music_note;
    case 'album': return Icons.album;
    case 'artist': return Icons.person;
    case 'playlist': return Icons.playlist_play;
    default:
      switch (category) {
        case 'tracks': return Icons.music_note;
        case 'artists': return Icons.person;
        case 'albums': return Icons.album;
        case 'playlists': return Icons.playlist_play;
        default: return Icons.search;
      }
  }
}

