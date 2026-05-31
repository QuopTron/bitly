import 'package:bitly/models/track.dart';

List<Track> deduplicateTracks(List<Track> tracks) {
  if (tracks.length < 2) return tracks;
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    groups.putIfAbsent(t.identityKey, () => []).add(t);
  }
  if (groups.length == tracks.length) return tracks;

  final result = <Track>[];
  for (final group in groups.values) {
    if (group.length == 1) {
      result.add(group.first);
    } else {
      final primary = group.first;
      final alts = <Track>[];
      final seenSources = <String>{normalizeSource(primary.source)};
      for (var i = 1; i < group.length; i++) {
        final alt = group[i];
        final norm = normalizeSource(alt.source);
        if (!seenSources.contains(norm)) {
          seenSources.add(norm);
          alts.add(alt);
        }
      }
      result.add(primary.copyWith(
        alternateSources: [...?primary.alternateSources, ...alts],
      ));
    }
  }
  return result;
}

String normalizeForMatch(String text) {
  var s = text.toLowerCase().trim();
  s = s.replaceAll(
    RegExp(r'[\(\[](?:[\w\s]*?(?:remaster|deluxe|expanded|anniversary|live|explicit|edit|radio|single|version|original|mix)[\w\s]*?)[\)\]]', caseSensitive: false),
    ' ',
  );
  return s
      .replaceAll(RegExp(r'[^\w\sáéíóúàèìòùäëïöüñç]'), ' ')
      .replaceAll(RegExp(r'\b(feat|ft|featuring|with|and|&)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeSource(String? source) {
  if (source == null || source.isEmpty) return 'builtin';
  final s = source.trim().toLowerCase();
  switch (s) {
    case 'qobuz_kennyy': case 'qobuz-web': case 'qobuz': return 'qobuz';
    case 'spotify-web': case 'spotify:track': case 'spotify': return 'spotify';
    case 'tidal-web': case 'tidal': return 'tidal';
    case 'deezer': return 'deezer';
    case 'apple-music': case 'apple_music': return 'apple-music';
    case 'soundcloud': return 'soundcloud';
    case 'ytmusic-Bitly': case 'ytmusic': return 'ytmusic';
    case 'pandora': return 'pandora';
    case 'amazon': case 'amazon_music': return 'amazon';
    case 'local': return 'local';
    default: return s;
  }
}