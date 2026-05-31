import 'package:json_annotation/json_annotation.dart';
import 'track_utils.dart';

export 'track_utils.dart';

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
  bool get isFromExtension => source != null && source!.isNotEmpty;
  bool get isDolbyAtmos => audioModes != null && audioModes!.contains('DOLBY_ATMOS');
  bool get hasAudioQuality => audioQuality != null && audioQuality!.isNotEmpty;

  String get identityKey {
    final i = isrc?.trim();
    if (i != null && i.isNotEmpty) return 'isrc:${i.toUpperCase()}';
    return '${normalizeForMatch(name)}|${normalizeForMatch(artistName)}';
  }

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  Track copyWith({
    String? id, String? name, String? artistName, String? albumName,
    String? albumArtist, String? artistId, String? albumId, String? coverUrl,
    String? isrc, int? duration, int? trackNumber, int? discNumber,
    int? totalDiscs, String? releaseDate, String? deezerId,
    ServiceAvailability? availability, String? source, String? albumType,
    int? totalTracks, String? composer, String? itemType, String? audioQuality,
    String? audioModes, String? codec, int? bitDepth, int? sampleRate,
    List<Track>? alternateSources,
  }) {
    return Track(
      id: id ?? this.id, name: name ?? this.name,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      albumArtist: albumArtist ?? this.albumArtist,
      artistId: artistId ?? this.artistId, albumId: albumId ?? this.albumId,
      coverUrl: coverUrl ?? this.coverUrl, isrc: isrc ?? this.isrc,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      releaseDate: releaseDate ?? this.releaseDate,
      deezerId: deezerId ?? this.deezerId,
      availability: availability ?? this.availability,
      source: source ?? this.source, albumType: albumType ?? this.albumType,
      totalTracks: totalTracks ?? this.totalTracks,
      composer: composer ?? this.composer, itemType: itemType ?? this.itemType,
      audioQuality: audioQuality ?? this.audioQuality,
      audioModes: audioModes ?? this.audioModes,
      codec: codec ?? this.codec, bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      alternateSources: alternateSources ?? this.alternateSources,
    );
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
    this.tidal = false, this.qobuz = false, this.amazon = false,
    this.deezer = false, this.tidalUrl, this.qobuzUrl, this.amazonUrl,
    this.deezerUrl, this.deezerId,
  });

  factory ServiceAvailability.fromJson(Map<String, dynamic> json) =>
      _$ServiceAvailabilityFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAvailabilityToJson(this);
}