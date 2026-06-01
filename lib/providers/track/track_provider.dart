import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/core/platform/platform_service.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/providers/track/track_state.dart';
import 'package:bitly/providers/track/track_models.dart';

export 'package:bitly/providers/track/track_state.dart';

final log = AppLogger('TrackProvider');
const extensionInitRetryTimeout = Duration(seconds: 30);

class TrackNotifier extends Notifier<TrackState> {
  final PlatformService platformService;
  int currentRequestId = 0;

  TrackNotifier(this.platformService);

  @override
  TrackState build() => const TrackState();

  bool isRequestValid(int requestId) => requestId == currentRequestId;

  void clear() => state = const TrackState();

  void setSearchFilter(String? filter) {
    if (state.selectedSearchFilter == filter) return;
    state = state.copyWith(selectedSearchFilter: filter, clearSelectedSearchFilter: filter == null);
  }

  void setSearchText(bool hasText) {
    if (state.hasSearchText == hasText) return;
    state = state.copyWith(hasSearchText: hasText);
  }

  void setShowingRecentAccess(bool showing) {
    if (state.isShowingRecentAccess == showing) return;
    state = state.copyWith(isShowingRecentAccess: showing);
  }

  void setTracksFromCollection({required List<Track> tracks, String? albumName, String? playlistName, String? coverUrl}) {
    state = TrackState(tracks: tracks, isLoading: false, albumName: albumName, playlistName: playlistName, coverUrl: coverUrl, hasSearchText: state.hasSearchText, isShowingRecentAccess: state.isShowingRecentAccess);
  }

  Track parseSearchTrack(Map<String, dynamic> data, {String? source}) {
    final durationMs = extractDurationMs(data);
    final itemType = data['item_type']?.toString();
    final effectiveSource = source ?? data['source']?.toString() ?? data['provider_id']?.toString();
    final spotifyId = (data['spotify_id'] ?? '').toString();
    final nativeId = (data['id'] ?? '').toString();
    final preferredId = effectiveSource != null && effectiveSource.isNotEmpty
        ? (spotifyId.contains(':') ? spotifyId : nativeId.isNotEmpty ? nativeId : spotifyId)
        : (spotifyId.isNotEmpty ? spotifyId : nativeId);
    return Track(
      id: preferredId, name: (data['name'] ?? '').toString(), artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? '').toString(), albumArtist: data['album_artist']?.toString(),
      artistId: (data['artist_id'] ?? data['artistId'])?.toString(), albumId: data['album_id']?.toString(),
      coverUrl: normalizeCoverReference((data['cover_url'] ?? data['images'])?.toString()),
      isrc: data['isrc']?.toString(), duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?, discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?, releaseDate: data['release_date']?.toString(),
      totalTracks: data['total_tracks'] as int?, source: effectiveSource,
      albumType: normalizeOptionalString(data['album_type']?.toString()),
      composer: data['composer']?.toString(), itemType: itemType,
      audioQuality: data['audio_quality']?.toString(), audioModes: data['audio_modes']?.toString(),
    );
  }

  int extractDurationMs(Map<String, dynamic> data) {
    final durationMsRaw = data['duration_ms'];
    if (durationMsRaw is num && durationMsRaw > 0) return durationMsRaw.toInt();
    if (durationMsRaw is String) { final parsed = num.tryParse(durationMsRaw.trim()); if (parsed != null && parsed > 0) return parsed.toInt(); }
    final durationSecRaw = data['duration'];
    if (durationSecRaw is num && durationSecRaw > 0) return (durationSecRaw * 1000).toInt();
    if (durationSecRaw is String) { final parsed = num.tryParse(durationSecRaw.trim()); if (parsed != null && parsed > 0) return (parsed * 1000).toInt(); }
    return 0;
  }

  ArtistAlbum parseArtistAlbum(Map<String, dynamic> data) => ArtistAlbum(
    id: data['id'] as String? ?? '', name: data['name'] as String? ?? '', releaseDate: data['release_date'] as String? ?? '',
    totalTracks: data['total_tracks'] as int? ?? 0, coverUrl: normalizeCoverReference((data['cover_url'] ?? data['images'])?.toString()),
    albumType: data['album_type'] as String? ?? 'album', artists: data['artists'] as String? ?? '', providerId: data['provider_id']?.toString(),
  );

  SearchArtist parseSearchArtist(Map<String, dynamic> data) => SearchArtist(
    id: data['id'] as String? ?? '', name: data['name'] as String? ?? '',
    imageUrl: normalizeRemoteHttpUrl(data['images']?.toString()), followers: data['followers'] as int? ?? 0, popularity: data['popularity'] as int? ?? 0,
  );

  SearchAlbum parseSearchAlbum(Map<String, dynamic> data) => SearchAlbum(
    id: data['id'] as String? ?? '', name: data['name'] as String? ?? '', artists: data['artists'] as String? ?? '',
    imageUrl: normalizeRemoteHttpUrl(data['images']?.toString()), releaseDate: data['release_date'] as String?,
    totalTracks: data['total_tracks'] as int? ?? 0, albumType: data['album_type'] as String? ?? 'album',
  );

  SearchPlaylist parseSearchPlaylist(Map<String, dynamic> data) => SearchPlaylist(
    id: data['id'] as String? ?? '', name: data['name'] as String? ?? '', owner: data['owner'] as String? ?? '',
    imageUrl: normalizeRemoteHttpUrl(data['images']?.toString()), totalTracks: data['total_tracks'] as int? ?? 0,
  );
}

final trackProvider = NotifierProvider<TrackNotifier, TrackState>(() {
  final platformService = PlatformService();
  return TrackNotifier(platformService);
});
