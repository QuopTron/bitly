/// Servicio de re-descarga de tracks locales para mejora a FLAC.
/// Evalúa si un track local es elegible para FLAC, busca candidatos
/// online mediante los proveedores configurados y selecciona la mejor
/// coincidencia usando un sistema de scoring ponderado.
library;

import 'package:bitly/models/settings/app_settings.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/services/library/redownload/local_track_comparator.dart';
import 'package:bitly/core/bridge/bridge_client.dart';

class LocalTrackRedownloadResolution {
  final LocalLibraryItem localItem;
  final Track? match;
  final int score;
  final String reason;

  const LocalTrackRedownloadResolution({
    required this.localItem,
    required this.match,
    required this.score,
    required this.reason,
  });

  bool get canQueue => match != null;
}

class LocalTrackRedownloadService {
  static bool isFlacUpgradeEligible(LocalLibraryItem item) {
    final format = item.format?.trim().toLowerCase();
    if (format == 'flac') return false;
    return !item.filePath.toLowerCase().endsWith('.flac');
  }

  static Future<LocalTrackRedownloadResolution> resolveBestMatch(
    LocalLibraryItem item, {
    required bool includeExtensions,
  }) async {
    final query = _buildSearchQuery(item);
    final rawResults = await PlatformBridge.searchTracksWithMetadataProviders(
      query,
      limit: 10,
      includeExtensions: includeExtensions,
    );

    if (rawResults.isEmpty) {
      return LocalTrackRedownloadResolution(
        localItem: item, match: null, score: 0, reason: 'No candidates found',
      );
    }

    final scored = rawResults
        .map((raw) => (
              track: LocalTrackMatcher.parseSearchTrack(raw),
              score: LocalTrackMatcher.scoreMatch(item, raw),
            ))
        .where((e) => e.track.name.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      return LocalTrackRedownloadResolution(
        localItem: item, match: null, score: 0, reason: 'No usable candidates found',
      );
    }

    final best = scored.first;
    final runnerUp = scored.length > 1 ? scored[1] : null;
    final exactIsrc = LocalTrackMatcher.normalizedIsrc(item.isrc) != null &&
        LocalTrackMatcher.normalizedIsrc(item.isrc) == LocalTrackMatcher.normalizedIsrc(best.track.isrc);
    final isAmbiguous = !exactIsrc &&
        runnerUp != null &&
        best.score < (LocalTrackMatcher.minimumConfidenceScore + 10) &&
        (best.score - runnerUp.score) <= LocalTrackMatcher.ambiguousScoreGap;

    if (!exactIsrc && (best.score < LocalTrackMatcher.minimumConfidenceScore || isAmbiguous)) {
      return LocalTrackRedownloadResolution(
        localItem: item, match: null, score: best.score,
        reason: isAmbiguous ? 'Ambiguous match' : 'Low-confidence match',
      );
    }

    return LocalTrackRedownloadResolution(
      localItem: item, match: best.track, score: best.score,
      reason: exactIsrc ? 'Exact ISRC match' : 'High-confidence metadata match',
    );
  }

  static String preferredFlacService(AppSettings settings, ExtensionState extensionState) {
    return resolveEffectiveDownloadService(settings.defaultService, extensionState);
  }

  static String preferredFlacQualityForService(String service, ExtensionState extensionState) {
    if (service.trim().isEmpty) return 'LOSSLESS';
    return isDeezerCompatibleDownloadService(service, extensionState) ? 'FLAC' : 'LOSSLESS';
  }

  static String _buildSearchQuery(LocalLibraryItem item) {
    final artist = _primaryArtist(item.artistName);
    final album = item.albumName.trim();
    if (album.isNotEmpty && album.toLowerCase() != 'unknown album') {
      return '${item.trackName} $artist $album'.trim();
    }
    return '${item.trackName} $artist'.trim();
  }

  static String _primaryArtist(String value) {
    final parts = LocalTrackMatcher.normalizedArtistGroup(value)
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    return parts.isEmpty ? value.trim() : parts.first;
  }
}
