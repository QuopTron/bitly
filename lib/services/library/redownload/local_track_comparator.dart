/// Algoritmo de scoring para emparejar tracks locales con candidatos online.
/// Usa pesos por ISRC, título, artista, álbum, duración, número de pista/disco,
/// año y penalizaciones por versiones (live, karaoke, instrumental, etc.)
/// para determinar la mejor coincidencia para una re-descarga FLAC.
library;

import 'dart:math';
import 'package:bitly/models/track.dart';
import 'package:bitly/services/library/library_database.dart';

class LocalTrackMatcher {
  static const int minimumConfidenceScore = 85;
  static const int ambiguousScoreGap = 8;

  static Track parseSearchTrack(Map<String, dynamic> data) {
    final durationMs = extractDurationMs(data);
    return Track(
      id: (data['spotify_id'] ?? data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? '').toString(),
      albumArtist: data['album_artist']?.toString(),
      artistId: (data['artist_id'] ?? data['artistId'])?.toString(),
      albumId: data['album_id']?.toString(),
      coverUrl: (data['cover_url'] ?? data['images'])?.toString(),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      totalTracks: data['total_tracks'] as int?,
      composer: data['composer']?.toString(),
      source: data['source']?.toString() ?? data['provider_id']?.toString(),
      albumType: data['album_type']?.toString(),
      itemType: data['item_type']?.toString(),
    );
  }

  static int scoreMatch(LocalLibraryItem item, Map<String, dynamic> raw) {
    final track = parseSearchTrack(raw);
    var score = 0;

    final localIsrc = normalizedIsrc(item.isrc);
    final candidateIsrc = normalizedIsrc(track.isrc);
    if (localIsrc != null && candidateIsrc != null) {
      score += localIsrc == candidateIsrc ? 140 : -120;
    }

    final localTitle = normalizedTitle(item.trackName);
    final candidateTitle = normalizedTitle(track.name);
    if (localTitle == candidateTitle) {
      score += 45;
    } else if (tokenOverlap(localTitle, candidateTitle) >= 0.75) {
      score += 24;
    } else {
      score -= 25;
    }

    final localArtist = normalizedArtistGroup(item.artistName);
    final candidateArtist = normalizedArtistGroup(track.artistName);
    if (localArtist == candidateArtist) {
      score += 30;
    } else if (tokenOverlap(localArtist, candidateArtist) >= 0.6) {
      score += 16;
    } else {
      score -= 20;
    }

    final localAlbum = normalizedText(item.albumName);
    final candidateAlbum = normalizedText(track.albumName);
    if (localAlbum.isNotEmpty && candidateAlbum.isNotEmpty) {
      if (localAlbum == candidateAlbum) {
        score += 12;
      } else if (tokenOverlap(localAlbum, candidateAlbum) >= 0.7) {
        score += 6;
      }
    }

    final localDuration = item.duration ?? 0;
    final candidateDuration = track.duration;
    if (localDuration > 0 && candidateDuration > 0) {
      final diff = (localDuration - candidateDuration).abs();
      if (diff <= 2) {
        score += 20;
      } else if (diff <= 5) {
        score += 12;
      } else if (diff <= 10) {
        score += 5;
      } else if (diff > 20) {
        score -= 30;
      }
    }

    if (item.trackNumber != null && track.trackNumber != null && item.trackNumber == track.trackNumber) {
      score += 6;
    }
    if (item.discNumber != null && track.discNumber != null && item.discNumber == track.discNumber) {
      score += 4;
    }

    final localYear = extractYear(item.releaseDate);
    final candidateYear = extractYear(track.releaseDate);
    if (localYear != null && candidateYear != null && localYear == candidateYear) {
      score += 4;
    }

    score += versionPenalty(item.trackName, track.name);
    return score;
  }

  static String? normalizedIsrc(String? value) {
    final v = value?.trim().toUpperCase();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  static String normalizedTitle(String value) {
    return normalizedText(value)
        .replaceAll(RegExp(r'\b(feat|ft|featuring)\b.*$'), ' ')
        .replaceAll(RegExp(r'\b(remaster(?:ed)?|deluxe|bonus)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizedArtistGroup(String value) {
    return normalizedText(value.replaceAll(RegExp(r'\b(feat|ft|featuring|with|x)\b'), ',').replaceAll('&', ','));
  }

  static String normalizedText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9, ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double tokenOverlap(String left, String right) {
    final leftTokens = left.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toSet();
    final rightTokens = right.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0;
    return leftTokens.intersection(rightTokens).length / max(leftTokens.length, rightTokens.length);
  }

  static int versionPenalty(String localTitle, String candidateTitle) {
    const riskyMarkers = ['live', 'karaoke', 'instrumental', 'acoustic', 'radio edit', 'sped up', 'slowed'];
    final local = normalizedText(localTitle);
    final candidate = normalizedText(candidateTitle);
    var penalty = 0;
    for (final marker in riskyMarkers) {
      if (!local.contains(marker) && candidate.contains(marker)) penalty -= 18;
    }
    return penalty;
  }

  static int? extractYear(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  static int extractDurationMs(Map<String, dynamic> data) {
    final raw = data['duration_ms'];
    if (raw is num && raw > 0) return raw.toInt();
    if (raw is String) {
      final p = num.tryParse(raw.trim());
      if (p != null && p > 0) return p.toInt();
    }
    final secRaw = data['duration'];
    if (secRaw is num && secRaw > 0) return (secRaw * 1000).toInt();
    if (secRaw is String) {
      final p = num.tryParse(secRaw.trim());
      if (p != null && p > 0) return (p * 1000).toInt();
    }
    return 0;
  }
}
