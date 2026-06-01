import 'package:bitly/models/track.dart';
import 'package:bitly/providers/track/track_provider.dart';

extension TrackServiceAvailabilityExtension on TrackNotifier {
  Future<void> checkAvailability(int index) async {
    if (index < 0 || index >= state.tracks.length) return;

    final track = state.tracks[index];
    if (track.isrc == null || track.isrc!.isEmpty) return;

    try {
      final availability = await platformService.checkAvailability(
        track.id,
        track.isrc!,
      );
      final updatedTrack = Track(
        id: track.id,
        name: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        albumArtist: track.albumArtist,
        artistId: track.artistId,
        albumId: track.albumId,
        coverUrl: track.coverUrl,
        isrc: track.isrc,
        duration: track.duration,
        trackNumber: track.trackNumber,
        discNumber: track.discNumber,
        releaseDate: track.releaseDate,
        albumType: track.albumType,
        totalTracks: track.totalTracks,
        source: track.source,
        composer: track.composer,
        itemType: track.itemType,
        audioQuality: track.audioQuality,
        audioModes: track.audioModes,
        availability: ServiceAvailability(
          tidal: availability['tidal'] as bool? ?? false,
          qobuz: availability['qobuz'] as bool? ?? false,
          amazon: availability['amazon'] as bool? ?? false,
          tidalUrl: availability['tidal_url'] as String?,
          qobuzUrl: availability['qobuz_url'] as String?,
          amazonUrl: availability['amazon_url'] as String?,
        ),
      );

      final tracks = List<Track>.from(state.tracks);
      tracks[index] = updatedTrack;
      state = state.copyWith(tracks: tracks);
    } catch (_) {}
  }
}
