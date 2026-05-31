final RegExp _artistNameSplitPattern = RegExp(
  r'\s*(?:,|&|\bx\b)\s*|\s+\b(?:feat(?:uring)?|ft|with)\.?(?=\s|$)\s*',
  caseSensitive: false,
);

final RegExp _featureSeparator = RegExp(
  r'\s+(?:feat(?:uring)?|ft|with|vs|present(?:en)?s?)\.?\s+'
  r'|\s+[&]\s+'
  r'|\s+y\s+'
  r'|\s+\bx\b\s+'
  r'|,\s+',
  caseSensitive: false,
);

const artistTagModeJoined = 'joined';
const artistTagModeSplitVorbis = 'split_vorbis';

/// Extracts the primary artist name by stripping feature separators.
/// e.g. "Bad Bunny ft Arcangel" → "Bad Bunny"
///      "Arcangel & Bad Bunny" → "Arcangel"
///      "Feid x Karol G"       → "Feid"
String primaryArtistName(String rawArtists) {
  final raw = rawArtists.trim();
  if (raw.isEmpty) return raw;
  final parts = raw.split(_featureSeparator);
  return parts.first.trim();
}

List<String> splitArtistNames(String rawArtists) {
  final raw = rawArtists.trim();
  if (raw.isEmpty) return const [];

  return raw
      .split(_artistNameSplitPattern)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

bool shouldSplitVorbisArtistTags(String mode) {
  return mode == artistTagModeSplitVorbis;
}

List<String> splitArtistTagValues(String rawArtists) {
  final seen = <String>{};
  final values = <String>[];
  for (final part in splitArtistNames(rawArtists)) {
    final key = part.toLowerCase();
    if (seen.add(key)) {
      values.add(part);
    }
  }

  if (values.isNotEmpty) {
    return values;
  }

  final trimmed = rawArtists.trim();
  return trimmed.isEmpty ? const [] : <String>[trimmed];
}
