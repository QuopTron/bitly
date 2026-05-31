import 'package:json_annotation/json_annotation.dart';

part 'track.g.dart';

@JsonSerializable()
class Track {
  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final String? albumArtist;
  final String? artistId;
  final String? albumId;
  final String? coverUrl;
  final String? isrc;
  final int duration;
  final int? trackNumber;
  final int? discNumber;
  final int? totalDiscs;
  final String? releaseDate;
  final String? deezerId;
  final ServiceAvailability? availability;
  final String? source;
  final String? albumType;
  final int? totalTracks;
  final String? composer;
  final String? itemType;
  final String? audioQuality;
  final String? audioModes;
  final String? codec;
  final int? bitDepth;
  final int? sampleRate;
  final List<Track>? alternateSources;

  const Track({
    required this.id,
    required this.name,
    required this.artistName,
    required this.albumName,
    this.albumArtist,
    this.artistId,
    this.albumId,
    this.coverUrl,
    this.isrc,
    required this.duration,
    this.trackNumber,
    this.discNumber,
    this.totalDiscs,
    this.releaseDate,
    this.deezerId,
    this.availability,
    this.source,
    this.albumType,
    this.totalTracks,
    this.composer,
    this.itemType,
    this.audioQuality,
    this.audioModes,
    this.codec,
    this.bitDepth,
    this.sampleRate,
    this.alternateSources,
  });

  bool get isSingle {
    switch (albumType?.toLowerCase()) {
      case 'single':
      case 'ep':
        return true;
      default:
        return false;
    }
  }

  bool get isAlbumItem => itemType == 'album';

  bool get isPlaylistItem => itemType == 'playlist';

  bool get isArtistItem => itemType == 'artist';

  bool get isCollection => isAlbumItem || isPlaylistItem || isArtistItem;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  bool get isFromExtension => source != null && source!.isNotEmpty;

  bool get isDolbyAtmos =>
      audioModes != null && audioModes!.contains('DOLBY_ATMOS');

  /// Returns a canonical identity key for deduplication:
  /// uses ISRC if available, otherwise "name|artist" normalized.
  String get identityKey {
    final i = isrc?.trim();
    if (i != null && i.isNotEmpty) return 'isrc:${i.toUpperCase()}';
    return '${normalizeForMatch(name)}|${normalizeForMatch(artistName)}';
  }

  bool get hasAudioQuality => audioQuality != null && audioQuality!.isNotEmpty;

  Track copyWith({
    String? id,
    String? name,
    String? artistName,
    String? albumName,
    String? albumArtist,
    String? artistId,
    String? albumId,
    String? coverUrl,
    String? isrc,
    int? duration,
    int? trackNumber,
    int? discNumber,
    int? totalDiscs,
    String? releaseDate,
    String? deezerId,
    ServiceAvailability? availability,
    String? source,
    String? albumType,
    int? totalTracks,
    String? composer,
    String? itemType,
    String? audioQuality,
    String? audioModes,
    String? codec,
    int? bitDepth,
    int? sampleRate,
    List<Track>? alternateSources,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      albumArtist: albumArtist ?? this.albumArtist,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      coverUrl: coverUrl ?? this.coverUrl,
      isrc: isrc ?? this.isrc,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      releaseDate: releaseDate ?? this.releaseDate,
      deezerId: deezerId ?? this.deezerId,
      availability: availability ?? this.availability,
      source: source ?? this.source,
      albumType: albumType ?? this.albumType,
      totalTracks: totalTracks ?? this.totalTracks,
      composer: composer ?? this.composer,
      itemType: itemType ?? this.itemType,
      audioQuality: audioQuality ?? this.audioQuality,
      audioModes: audioModes ?? this.audioModes,
      codec: codec ?? this.codec,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      alternateSources: alternateSources ?? this.alternateSources,
    );
  }
}

/// Deduplicates a list of tracks by identity (ISRC > name|artist),
/// merging same-song tracks from different sources into `alternateSources`
/// so only one card is shown per unique song.
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
        alternateSources: [
          ...?primary.alternateSources,
          ...alts,
        ],
      ));
    }
  }
  return result;
}

/// Normalizes text for cross-source matching.
/// Strips feat/ft, punctuation, and collapses whitespace
/// so "Song Name (feat. Artist)" matches "Song Name ft. Artist".
String normalizeForMatch(String text) {
  var s = text.toLowerCase().trim();

  // Strip common suffixes in parentheses or brackets
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

/// Maps provider/source IDs to canonical service names.
/// This ensures that `qobuz_kennyy`, `qobuz-web`, `qobuz` all resolve to `qobuz`,
/// preventing duplicate cards for the same song from different source aliases.
String normalizeSource(String? source) {
  if (source == null || source.isEmpty) return 'builtin';
  final s = source.trim().toLowerCase();
  switch (s) {
    case 'qobuz_kennyy':
    case 'qobuz-web':
    case 'qobuz':
      return 'qobuz';
    case 'spotify-web':
    case 'spotify:track':
    case 'spotify':
      return 'spotify';
    case 'tidal-web':
    case 'tidal':
      return 'tidal';
    case 'deezer':
      return 'deezer';
    case 'apple-music':
    case 'apple_music':
      return 'apple-music';
    case 'soundcloud':
      return 'soundcloud';
    case 'ytmusic-Bitly':
    case 'ytmusic':
      return 'ytmusic';
    case 'pandora':
      return 'pandora';
    case 'amazon':
    case 'amazon_music':
      return 'amazon';
    case 'local':
      return 'local';
    default:
      return s;
  }
}

@JsonSerializable()
class ServiceAvailability {
  final bool tidal;
  final bool qobuz;
  final bool amazon;
  final bool deezer;
  final String? tidalUrl;
  final String? qobuzUrl;
  final String? amazonUrl;
  final String? deezerUrl;
  final String? deezerId;

  const ServiceAvailability({
    this.tidal = false,
    this.qobuz = false,
    this.amazon = false,
    this.deezer = false,
    this.tidalUrl,
    this.qobuzUrl,
    this.amazonUrl,
    this.deezerUrl,
    this.deezerId,
  });

  factory ServiceAvailability.fromJson(Map<String, dynamic> json) =>
      _$ServiceAvailabilityFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAvailabilityToJson(this);
}
