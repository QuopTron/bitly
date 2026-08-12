import '../models/download_settings.dart';
import '../../../backend/services/download_cubit.dart';

/// Normalizes a track/album/playlist ID by removing any provider prefix
/// (e.g. "spotify-web/", "spotify:track:", "deezer:playlist:") and lowercasing.
/// Returns the raw [id] if no transformation is needed.
String normalizeTrackId(String id) {
  int lastSep = id.lastIndexOf('/');
  int lastColon = id.lastIndexOf(':');
  int split = lastSep > lastColon ? lastSep : lastColon;
  if (split > 0 && split < id.length - 1) {
    return id.substring(split + 1).toLowerCase();
  }
  return id.toLowerCase();
}

/// Builds a common metadata map for a download dispatch. Returns a
/// [Map<String, dynamic>] with keys that both the Go backend and the
/// progress-tracking system expect.
Map<String, dynamic> buildTrackMeta({
  required String trackId,
  required String trackTitle,
  required String artistName,
  required String albumName,
  required String source,
  required String isrc,
  required int durationMs,
  String? coverUrl,
}) {
  return {
    'track_id': trackId,
    'item_id': trackId,
    'track_title': trackTitle,
    'artist_name': artistName,
    'album_name': albumName,
    'source': source,
    'isrc': isrc,
    'duration_ms': durationMs,
    if (coverUrl != null) 'cover_url': coverUrl,
  };
}

/// Dispatches audio (and optionally video/lyrics) downloads for a single track.
/// Delegates to [DownloadCubit.dispatchSingleTrack] so state updates happen
/// inside the cubit where `emit` is accessible.
void dispatchDownloads({
  required DownloadCubit cubit,
  required Map<String, dynamic> commonMeta,
  required DownloadSettings settings,
  required String baseId,
  String? qualityOverride,
}) {
  cubit.dispatchSingleTrack(
    commonMeta: commonMeta,
    settings: settings,
    baseId: baseId,
    qualityOverride: qualityOverride,
  );
}
