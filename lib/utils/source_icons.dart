import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:bitly/models/track.dart';

IconData _fa(FaIconData icon) => IconData(icon.codePoint, fontFamily: icon.fontFamily, fontPackage: icon.fontPackage);

IconData _matchSource(String s) {
  switch (s) {
    case 'spotify':
      return _fa(FontAwesomeIcons.spotify);
    case 'deezer':
      return _fa(FontAwesomeIcons.deezer);
    case 'qobuz':
      return Icons.radio;
    case 'tidal':
      return _fa(FontAwesomeIcons.tidal);
    case 'apple-music':
    case 'apple music':
    case 'apple':
      return _fa(FontAwesomeIcons.apple);
    case 'soundcloud':
    case 'sound cloud':
      return _fa(FontAwesomeIcons.soundcloud);
    case 'pandora':
      return Icons.queue_music;
    case 'amazon':
    case 'amazon music':
    case 'amazon_music':
      return _fa(FontAwesomeIcons.amazon);
    case 'ytmusic':
    case 'youtube music':
    case 'youtube_music':
      return Icons.music_note;
    case 'local':
      return Icons.folder;
    case 'builtin':
      return Icons.settings;
    default:
      return Icons.extension;
  }
}

IconData sourceIcon(String source) {
  final normalized = normalizeSource(source);
  final result = _matchSource(normalized);
  if (result != Icons.extension) return result;

  final lower = source.toLowerCase().trim();
  final words = lower.split(RegExp(r'[\s_-]+'));
  for (final w in words) {
    final r = _matchSource(w);
    if (r != Icons.extension) return r;
  }
  final tryFull = _matchSource(lower);
  if (tryFull != Icons.extension) return tryFull;

  if (lower.contains('ytmusic') || lower.contains('youtube')) {
    return Icons.music_note;
  }
  if (lower.contains('spotify')) return _fa(FontAwesomeIcons.spotify);
  if (lower.contains('deezer')) return _fa(FontAwesomeIcons.deezer);
  if (lower.contains('soundcloud') || lower.contains('sound cloud')) {
    return _fa(FontAwesomeIcons.soundcloud);
  }
  if (lower.contains('tidal')) return _fa(FontAwesomeIcons.tidal);
  if (lower.contains('apple')) return _fa(FontAwesomeIcons.apple);
  if (lower.contains('amazon')) return _fa(FontAwesomeIcons.amazon);
  if (lower.contains('qobuz')) return Icons.radio;
  if (lower.contains('pandora')) return Icons.queue_music;

  return Icons.extension;
}

IconData searchBehaviorIcon(String? iconName) {
  switch (iconName) {
    case 'video':
    case 'movie':
      return Icons.video_library;
    case 'music':
      return Icons.music_note;
    case 'podcast':
      return _fa(FontAwesomeIcons.podcast);
    case 'book':
    case 'audiobook':
      return Icons.menu_book;
    case 'cloud':
      return _fa(FontAwesomeIcons.cloud);
    case 'download':
      return Icons.download;
    default:
      return Icons.extension;
  }
}

String sourceDisplayName(String source) {
  switch (normalizeSource(source)) {
    case 'spotify':
      return 'Spotify';
    case 'deezer':
      return 'Deezer';
    case 'qobuz':
      return 'Qobuz';
    case 'tidal':
      return 'Tidal';
    case 'apple-music':
      return 'Apple Music';
    case 'soundcloud':
      return 'SoundCloud';
    case 'pandora':
      return 'Pandora';
    case 'amazon':
      return 'Amazon Music';
    case 'ytmusic':
      return 'YouTube Music';
    case 'local':
      return 'Local';
    case 'builtin':
      return 'Built-in';
    default:
      return source;
  }
}

String initialLetterFor(String name) {
  if (name.isEmpty) return '?';
  return name[0].toUpperCase();
}

Color initialColorFor(String name, {required ColorScheme colorScheme}) {
  final hash = name.hashCode;
  final colors = [
    colorScheme.primary,
    colorScheme.tertiary,
    colorScheme.error,
    const Color(0xFFE57373),
    const Color(0xFFF06292),
    const Color(0xFFBA68C8),
    const Color(0xFF64B5F6),
    const Color(0xFF4FC3F7),
    const Color(0xFF4DD0E1),
    const Color(0xFF81C784),
    const Color(0xFFAED581),
    const Color(0xFFFFD54F),
    const Color(0xFFFF8A65),
    const Color(0xFFA1887F),
    const Color(0xFF90A4AE),
  ];
  return colors[hash.abs() % colors.length];
}
